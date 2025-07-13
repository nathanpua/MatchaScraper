# Stock Monitoring System for Cloud-Native Browser Automation

### 1. Project Overview

**Project Name:** MatchaScraper - Stock Monitoring System  
**Date:** 2025  

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

#### 6.1 Project Structure
The project is organized into distinct directories to separate concerns:

- **/app**: Contains all the Go application source code (`main.go`, `scraper.go`, etc.).
- **/terraform**: Contains all the Terraform infrastructure as code files (`main.tf`, `backend.tf`, etc.).
- **/lambda**: Contains the source code for the AWS Lambda functions that handle scaling.
- **/.github/workflows**: Contains the CI/CD pipeline definition (`deploy.yml`).
- **/Dockerfile**: The recipe for building the application's Docker image.

#### 6.2 Technology Stack

**Application:**
- **Language:** Go (Golang)
- **Web Scraping:** Colly
- **Notifications:** Telegram Bot API

**Infrastructure & Deployment:**
- **CI/CD:** GitHub Actions
- **Infrastructure as Code:** Terraform
- **Compute:** Amazon EC2 (`t2.micro`)
- **Containerization:** Docker
- **Container Registry:** Amazon ECR
- **Secrets Management:** AWS SSM Parameter Store
- **State Management:** Amazon S3 & DynamoDB (for Terraform remote state)
- **Logging:** Amazon CloudWatch Logs
- **Scheduling:** Amazon EventBridge
- **Automation:** AWS Lambda
- **Resilience:** EC2 Auto Scaling Group

#### 6.3 System Architecture

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

### 7. CI/CD Pipeline
The entire build and deployment process is automated using GitHub Actions. A push to the `main` branch triggers a workflow that performs the following steps:

1.  **Authenticate with AWS**: Securely authenticates with AWS using OpenID Connect (OIDC), avoiding the need for static access keys.
2.  **Build & Push Docker Image**: Builds a new Docker image from the source code in the `/app` directory.
3.  **Push to ECR**: Tags the image and pushes it to the Amazon ECR repository.
4.  **Deploy Infrastructure**: Executes `terraform apply` from the `/terraform` directory to update the cloud infrastructure.

```
┌─────────────────┐      ┌──────────────────────────┐      ┌──────────────────┐      ┌────────────────────┐      ┌──────────────────┐
│ Push to `main`  ├─►│ 1. Authenticate & Log In │ ─► │ 2. Build Image   │ ─► │ 3. Push to ECR     │ ─► │ 4. Terraform Apply │
└─────────────────┘      └──────────────────────────┘      └──────────────────┘      └────────────────────┘      └──────────────────┘
```

### 8. Cloud Infrastructure & Deployment

#### 8.1 Secrets Management
All secrets, including the `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`, are securely stored in **AWS SSM Parameter Store** as `SecureString` parameters. The EC2 instance is granted specific IAM permissions to access only these required parameters at runtime. This approach avoids hardcoding secrets or passing them through CI/CD environment variables.

#### 8.2 Infrastructure as Code (Terraform)
The cloud infrastructure is defined entirely in Terraform, located in the `/terraform` directory.

**Remote State Management**
To ensure a consistent state between local development and CI/CD pipeline runs, Terraform is configured with a remote backend. The state is stored in an S3 bucket, and a DynamoDB table is used for state locking to prevent concurrent modification issues.

*backend.tf*
```terraform
terraform {
  backend "s3" {
    bucket         = "ippodo-scraper-tfstate-997092021600"
    key            = "global/s3/terraform.tfstate"
    region         = "ap-northeast-3"
    dynamodb_table = "ippodo-scraper-tf-lock"
    encrypt        = true
  }
}
```

**Dynamic Secret Injection**
The EC2 launch template's user data script is responsible for fetching the secrets from SSM Parameter Store just before starting the container. This ensures that the application always has the latest credentials without them being exposed in the infrastructure code.

*Snippet from user data in `terraform/main.tf`*
```bash
#!/bin/bash
# ... docker setup ...

# Fetch secrets from SSM Parameter Store
TELEGRAM_TOKEN=$(aws ssm get-parameter --name "/ippodo-scraper/telegram-token" --with-decryption --query "Parameter.Value" --output text)
TELEGRAM_CHAT_ID=$(aws ssm get-parameter --name "/ippodo-scraper/telegram-chat-id" --with-decryption --query "Parameter.Value" --output text)

# ... login to ECR ...

# Run the Docker container with secrets injected as environment variables
docker run -d --restart always \
  -e TELEGRAM_TOKEN="$TELEGRAM_TOKEN" \
  -e TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID" \
  ...
```

#### 8.3 Deployment Process
Deployment is fully automated. To deploy any changes to the application or infrastructure, simply push your commits to the `main` branch.

**Initial One-Time Setup:**
Before the first deployment, the following resources must be created manually in AWS:
1.  **S3 Bucket** for Terraform state.
2.  **DynamoDB Table** for Terraform state locking.
3.  **SSM Parameters** for the Telegram token and chat ID.