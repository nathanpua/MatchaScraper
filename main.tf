# main.tf

provider "aws" {
  region = "ap-northeast-3" # Specify your desired AWS region
}

#---------------------------------------
# Variables
#---------------------------------------
variable "ecr_repo_name" {
  description = "Name for the ECR repository"
  type        = string
  default     = "ippodo-scraper"
}

variable "app_name" {
  description = "A name for the application used for tagging resources"
  type        = string
  default     = "ippodo-scraper"
}

#---------------------------------------
# ECR Repository
#---------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name = var.ecr_repo_name
}

#---------------------------------------
# CloudWatch Log Group
#---------------------------------------
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/${var.app_name}"
  retention_in_days = 7
}

#---------------------------------------
# IAM Role for EC2 Instance
#---------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.app_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_policy" "ec2_cloudwatch_policy" {
  name        = "${var.app_name}-ec2-cloudwatch-policy"
  description = "Allows EC2 instance to push logs to CloudWatch"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "${aws_cloudwatch_log_group.app_logs.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_cloudwatch_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.app_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

#---------------------------------------
# IAM Role for Lambda Functions
#---------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.app_name}-lambda-policy"
  description = "Policy for Lambda to manage the Auto Scaling Group"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ],
        Effect   = "Allow",
        Resource = aws_autoscaling_group.app_asg.arn
      },
      {
        Action   = "logs:CreateLogGroup",
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_asg_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

#---------------------------------------
# EC2 Auto Scaling Group and Launch Template
#---------------------------------------
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.app_name}-"
  image_id      = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type = "t2.micro"
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              service docker start
              usermod -a -G docker ec2-user

              # Login to ECR and run the container
              aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com
              docker run -d --restart always \
                --log-driver=awslogs \
                --log-opt awslogs-region=${data.aws_region.current.name} \
                --log-opt awslogs-group=${aws_cloudwatch_log_group.app_logs.name} \
                --log-opt awslogs-stream-prefix=${var.app_name} \
                ${aws_ecr_repository.app_repo.repository_url}:latest
              EOF
  )

  tags = {
    Name = var.app_name
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "${var.app_name}-asg"
  desired_capacity    = 0 # Initially off
  max_size            = 1
  min_size            = 0
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }
}

#---------------------------------------
# Lambda Functions for Scaling
#---------------------------------------
data "archive_file" "scale_up_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/scale_up"
  output_path = "${path.module}/lambda/scale_up.zip"
}

resource "aws_lambda_function" "scale_up_lambda" {
  function_name    = "scale-up-scraper-instance"
  filename         = data.archive_file.scale_up_lambda_zip.output_path
  source_code_hash = data.archive_file.scale_up_lambda_zip.output_base64sha256
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.app_asg.name
    }
  }
}

data "archive_file" "scale_down_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/scale_down"
  output_path = "${path.module}/lambda/scale_down.zip"
}

resource "aws_lambda_function" "scale_down_lambda" {
  function_name    = "scale-down-scraper-instance"
  filename         = data.archive_file.scale_down_lambda_zip.output_path
  source_code_hash = data.archive_file.scale_down_lambda_zip.output_base64sha256
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role.arn

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.app_asg.name
    }
  }
}

#---------------------------------------
# EventBridge Schedules
#---------------------------------------
resource "aws_cloudwatch_event_rule" "start_rule" {
  name                = "start-scraper-schedule"
  description         = "Starts scraper instance at 10 AM UTC"
  schedule_expression = "cron(0 10 * * ? *)"
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_rule.name
  arn       = aws_lambda_function.scale_up_lambda.arn
  target_id = "ScaleUpLambda"
}

resource "aws_cloudwatch_event_rule" "stop_rule" {
  name                = "stop-scraper-schedule"
  description         = "Stops scraper instance at 10 PM UTC"
  schedule_expression = "cron(0 22 * * ? *)"
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  arn       = aws_lambda_function.scale_down_lambda.arn
  target_id = "ScaleDownLambda"
}

#---------------------------------------
# Data sources for dynamic values
#---------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_subnets" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
} 