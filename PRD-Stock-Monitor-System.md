# Process Requirement Documentation (PRD)
## Stock Monitoring System for Cloud-Native Browser Automation

### 1. Project Overview

**Project Name:** IppodoScraper - Stock Monitoring System  
**Version:** 2.0  
**Date:** 2024  
**Document Type:** Process Requirement Documentation  

### 2. Executive Summary

This document outlines the requirements for a containerized scraping system that monitors product availability on e-commerce websites. The system's infrastructure is defined using Terraform and is designed to run for 12 hours daily on an Amazon EC2 instance. The instance is managed by an Auto Scaling Group, which is automatically scaled by a scheduled AWS Lambda function to optimize costs and ensure reliability.

### 3. Business Requirements

#### 3.1 Primary Objectives
- **Targeted Scraping:** Scrape product data from predefined websites (`Ippodo` and `Nakamura`).
- **Periodic Checks:** Refresh and check product stock every minute.
- **Scheduled Operation:** Run for 12 hours daily, starting at 10:00 AM.
- **Real-time Alerts:** Send immediate Telegram notifications when products are restocked.

#### 3.2 Key Success Metrics
- **Cost Efficiency:** Leverage the AWS Free Tier with a `t2.micro` instance and scheduled shutdowns to minimize cost.
- **Availability:** Achieve 100% uptime during the 12-hour operational window via an Auto Scaling Group.
- **Accuracy:** 99.9% accuracy in stock detection.
- **Response Time:** < 60 seconds from stock detection to notification.

### 4. Functional Requirements

#### 4.1 Core Features
The application's core features, including scraping, stock detection, and notifications, remain the same. The main change is that the application is now designed to run continuously within a container, with its lifecycle managed by the cloud infrastructure defined in Terraform.

#### 4.2 Application Flow
```
10:00 AM: EventBridge triggers "Scale Up" Lambda
│
└── Lambda sets Auto Scaling Group desired count to 1.
    │
    └── ASG launches the EC2 instance.
        │
        └── EC2 User Data script starts the Docker container.
            │
            └── Go application runs continuously:
                ├── Scrape Ippodo & Nakamura
                ├── Check for restocks & send alerts
                └── Wait for 1 minute & repeat
            
10:00 PM: EventBridge triggers "Scale Down" Lambda
│
└── Lambda sets Auto Scaling Group desired count to 0, terminating the instance.
```

### 5. Non-Functional Requirements

#### 5.1 Scalability
- The system is designed for a single EC2 instance but can be scaled by adjusting the Auto Scaling Group's desired capacity in the Terraform configuration.

#### 5.2 Reliability
- The use of an EC2 Auto Scaling Group ensures the instance is automatically replaced in case of failure, providing high availability during the operational window.

### 6. Technical Architecture

#### 6.1 System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Cloud Infrastructure                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐      ┌──────────────────┐     ┌───────────┐ │
│  │ EventBridge Rule │ ─► │  ScaleUp Lambda  │ ─►│ Auto      │ │
│  │ (10 AM Cron)     │      │ (Updates ASG)    │     │ Scaling   │ │
│  └──────────────────┘      └──────────────────┘     │ Group     │ │
│                                                     └─────┬─────┘ │
│  ┌──────────────────┐      ┌──────────────────┐           │       │
│  │ EventBridge Rule │ ─► │ ScaleDown Lambda │ ◄─────────┘       │
│  │ (10 PM Cron)     │      │ (Updates ASG)    │                   │
│  └──────────────────┘      └──────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       EC2 Instance Detail                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────┐      ┌───────────────────────────┐    │
│  │ Docker Daemon          │ ─► │ IppodoScraper Container   │    │
│  └────────────────────────┘      └───────────────────────────┘    │
│                                  │                            │
│                                  └─ Go Application (running)  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 6.2 Technology Stack

**Application:**
- **Language:** Go (Golang)
- **Web Scraping:** Colly
- **Notifications:** Telegram Bot API

**Infrastructure:**
- **Infrastructure as Code:** Terraform
- **Compute:** Amazon EC2 (`t2.micro`)
- **Logging:** Amazon CloudWatch Logs
- **Containerization:** Docker, Amazon ECR (for image storage)
- **Scheduling:** Amazon EventBridge
- **Automation:** AWS Lambda
- **Resilience:** EC2 Auto Scaling Group

### 7. Cloud Infrastructure Design

#### 7.1 Cost Optimization & High Availability Strategy

1.  **Scheduled Scaling:** The primary cost-saving measure is running the EC2 instance only during the required 12-hour window. This is achieved by using Lambda functions to update the Auto Scaling Group's desired capacity.
2.  **AWS Free Tier:** The `t2.micro` instance type is eligible for the AWS Free Tier, making it ideal for this project to operate at little to no cost.
3.  **Auto Scaling for Resilience:** To ensure 100% uptime during the operational window, the EC2 instance is managed by an Auto Scaling Group. If the instance terminates unexpectedly, the ASG will launch a replacement, ensuring the application resumes automatically.

#### 7.2 Logging and Monitoring
All logs generated by the Go application (`stdout` and `stderr`) are automatically captured and sent to Amazon CloudWatch Logs. This is achieved by configuring the `awslogs` driver for the Docker container. This provides a centralized location to view, search, and monitor application logs for debugging and operational insight.

### 8. Infrastructure as Code (Terraform)

The entire AWS infrastructure should be defined in Terraform code. This includes the ECR repository, IAM roles, Lambda functions, EventBridge schedules, and the EC2 Auto Scaling Group.

#### 8.1 Terraform Configuration (`main.tf`)
This file defines all the necessary AWS resources.

```terraform
# main.tf

provider "aws" {
  region = "us-east-1" # Specify your desired AWS region
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
```

#### 8.2 Lambda Function Code
You will need to create two folders, `