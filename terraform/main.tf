# main.tf

provider "aws" {
  region = var.aws_region
}

#---------------------------------------
# Variables
#---------------------------------------
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-northeast-3"
}

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
# Data Sources
#---------------------------------------
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_subnets" "default" {
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#---------------------------------------
# ECR Repository
#---------------------------------------
resource "aws_ecr_repository" "app_repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

#---------------------------------------
# CloudWatch Log Group
#---------------------------------------
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/${var.app_name}"
  retention_in_days = 7
}

#---------------------------------------
# IAM Role and Policy for EC2
#---------------------------------------
data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.app_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

data "aws_iam_policy_document" "ec2_cloudwatch_policy" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.app_logs.arn}:*"]
  }
}

data "aws_iam_policy_document" "ec2_ssm_policy" {
  statement {
    actions = [
      "ssm:GetParameters"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/ippodo-scraper/telegram-token",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/ippodo-scraper/telegram-chat-id"
    ]
  }
}

resource "aws_iam_policy" "ec2_cloudwatch_policy" {
  name        = "${var.app_name}-ec2-cloudwatch-policy"
  description = "Allows EC2 instance to push logs to CloudWatch"
  policy      = data.aws_iam_policy_document.ec2_cloudwatch_policy.json
}

resource "aws_iam_policy" "ec2_ssm_policy" {
  name        = "${var.app_name}-ec2-ssm-policy"
  description = "Allows EC2 instance to read specific SSM parameters"
  policy      = data.aws_iam_policy_document.ec2_ssm_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_ssm_policy.arn
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
# IAM Role and Policy for Lambda
#---------------------------------------
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.app_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    actions   = ["autoscaling:UpdateAutoScalingGroup", "autoscaling:DescribeAutoScalingGroups"]
    resources = [aws_autoscaling_group.app_asg.arn]
  }
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*"]
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.app_name}-lambda-policy"
  description = "Policy for Lambda to manage the Auto Scaling Group and CloudWatch Logs"
  policy      = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

#---------------------------------------
# EC2 Auto Scaling Group and Launch Template
#---------------------------------------
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.app_name}-"
  image_id      = data.aws_ami.amazon_linux_2.id
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

              # Fetch secrets from SSM Parameter Store
              TELEGRAM_TOKEN=$(aws ssm get-parameter --name "/ippodo-scraper/telegram-token" --with-decryption --query "Parameter.Value" --output text --region ${data.aws_region.current.name})
              TELEGRAM_CHAT_ID=$(aws ssm get-parameter --name "/ippodo-scraper/telegram-chat-id" --with-decryption --query "Parameter.Value" --output text --region ${data.aws_region.current.name})

              # Login to ECR
              aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com

              # Run the Docker container
              docker run -d --restart always \
                --log-driver=awslogs \
                --log-opt awslogs-region=${data.aws_region.current.name} \
                --log-opt awslogs-group=${aws_cloudwatch_log_group.app_logs.name} \
                --log-opt awslogs-stream=${var.app_name} \
                -e TELEGRAM_TOKEN="$TELEGRAM_TOKEN" \
                -e TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID" \
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

  # Ensure the ASG depends on the IAM role policies to avoid race conditions.
  depends_on = [
    aws_iam_role_policy_attachment.ec2_cloudwatch_attachment,
    aws_iam_role_policy_attachment.ec2_ecr_readonly,
    aws_iam_role_policy_attachment.ec2_ssm_attachment
  ]
}

#---------------------------------------
# Lambda Functions for Scaling
#---------------------------------------
data "archive_file" "scale_up_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/scale_up"
  output_path = "${path.module}/../lambda/scale_up.zip"
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
  source_dir  = "${path.module}/../lambda/scale_down"
  output_path = "${path.module}/../lambda/scale_down.zip"
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
# EventBridge Schedules & Permissions
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

resource "aws_lambda_permission" "allow_start_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_up_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_rule.arn
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

resource "aws_lambda_permission" "allow_stop_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_down_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_rule.arn
}

#---------------------------------------
# Outputs
#---------------------------------------
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
} 