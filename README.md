# MatchaScraper: A Cloud-Native Stock Monitoring System

### 1. Project Overview

**Project Name:** MatchaScraper - An Advanced, Cloud-Native Stock Monitoring System  
**Date:** 2025  

### 2. Executive Summary

This document outlines the architecture for a sophisticated, containerized scraping system engineered to monitor product availability on e-commerce websites. The entire infrastructure is provisioned and managed via Terraform, demonstrating a commitment to Infrastructure as Code (IaC) best practices. Designed for maximum cost-efficiency, the system operates on a schedule, running 12 hours daily on an Amazon EC2 instance. This instance is governed by an Auto Scaling Group and orchestrated by scheduled AWS Lambda functions, ensuring both high availability and minimal operational expense.

### 3. Business Requirements

#### 3.1 Primary Objectives
- **Targeted Scraping:** Precisely scrape product data from `Ippodo` and `Nakamura`.
- **High-Frequency Checks:** Refresh and validate product stock every minute.
- **Automated Scheduling:** Operate on a strict 12-hour daily schedule, starting at 10:00 AM.
- **Instantaneous Alerts:** Deliver real-time Telegram notifications upon product restocks.

#### 3.2 Key Success Metrics
- **Cost Efficiency:** Masterfully leverage the AWS Free Tier with a `t2.micro` instance and automated shutdowns to achieve near-zero cost.
- **High Availability:** Guarantee 100% uptime during the 12-hour operational window through a resilient Auto Scaling Group.
- **Data Accuracy:** Maintain 99.9% accuracy in stock detection.
- **Alert Latency:** Achieve a sub-60-second response time from stock detection to notification delivery.

### 4. Functional Requirements

#### 4.1 Core Features
The application's core logic—scraping, stock detection, and notifications—is encapsulated within a Docker container. Its lifecycle is dynamically managed by a robust cloud infrastructure defined entirely in Terraform, ensuring consistency and reliability across all environments.

#### 4.2 Application Flow
```
10:00 AM: EventBridge triggers the "Scale-Up" Lambda function.
│
└── Lambda sets the Auto Scaling Group's desired capacity to 1.
    │
    └── The Auto Scaling Group launches a new EC2 instance.
        │
        └── The EC2 User Data script initiates the Docker container.
            │
            └── The Go application executes its continuous monitoring loop:
                ├── Scrape Ippodo & Nakamura in parallel.
                ├── Detect restocks and dispatch instant alerts.
                └── Pause for 1 minute before repeating the cycle.
            
10:00 PM: EventBridge triggers the "Scale-Down" Lambda function.
│
└── Lambda sets the Auto Scaling Group's desired capacity to 0, gracefully terminating the instance.
```

### 5. Non-Functional Requirements

#### 5.1 Scalability
- While architected for a single EC2 instance to optimize cost, the system's foundation on an Auto Scaling Group allows for effortless scaling by adjusting the `desired_capacity` in the Terraform configuration.

#### 5.2 Reliability
- The use of an EC2 Auto Scaling Group provides exceptional resilience. If the instance fails for any reason, it is automatically terminated and replaced, guaranteeing high availability throughout the operational window.

### 6. Technical Architecture

#### 6.1 Project Structure
The project follows a clean, modular structure to promote separation of concerns and maintainability:

- **/app**: Houses the Go application source code (`main.go`, `scraper.go`, etc.).
- **/terraform**: Contains all Terraform Infrastructure as Code files (`main.tf`, `backend.tf`).
- **/lambda**: Includes the source code for the serverless scaling functions.
- **/.github/workflows**: Defines the automated CI/CD pipeline (`deploy.yml`).
- **/Dockerfile**: The blueprint for building the application's Docker image.

#### 6.2 Technology Stack

**Application & Logic:**
- **Language:** 🐹 Go (Golang)
- **Web Scraping:** 🕷️ Colly
- **Notifications:** 💬 Telegram Bot API

**Infrastructure & Automation:**
- **CI/CD:** 🚀 GitHub Actions
- **Infrastructure as Code:** 💜 Terraform
- **Compute:** 🖥️ Amazon EC2 (`t2.micro`)
- **Containerization:** 🐳 Docker
- **Container Registry:** 📦 Amazon ECR
- **Secrets Management:** 🔒 AWS SSM Parameter Store
- **State Management:** 🗄️ Amazon S3 & DynamoDB
- **Logging & Monitoring:** 📊 Amazon CloudWatch
- **Scheduling:** 🕒 Amazon EventBridge
- **Serverless Automation:** ⚡ AWS Lambda
- **Resilience:** 💪 EC2 Auto Scaling Group

#### 6.3 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     AWS Cloud Infrastructure                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐      ┌──────────────────┐     ┌───────────┐ │
│  │ 🕒 EventBridge   │ ─► │  ⚡ ScaleUp Lambda │ ─►│ 💪 Auto   │ │
│  │    (10 AM Cron)  │      │   (Updates ASG)  │     │   Scaling │ │
│  └──────────────────┘      └──────────────────┘     │   Group   │ │
│                                                     └─────┬─────┘ │
│  ┌──────────────────┐      ┌──────────────────┐           │       │
│  │ 🕒 EventBridge   │ ─► │ ⚡ ScaleDown      │ ◄─────────┘       │
│  │    (10 PM Cron)  │      │    Lambda        │                   │
│  └──────────────────┘      └──────────────────┘                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       EC2 Instance Detail                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────┐      ┌───────────────────────────┐    │
│  │ 🐳 Docker Daemon       │ ─► │ 🍵 MatchaScraper Container  │    │
│  └────────────────────────┘      └───────────────────────────┘    │
│                                  │                            │
│                                  └─ Go Application (running)  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7. CI/CD Pipeline
The entire build, test, and deployment lifecycle is fully automated using GitHub Actions. A push to the `main` branch triggers a workflow that executes the following strategic steps:

1.  **Secure AWS Authentication**: Leverages OpenID Connect (OIDC) for a secure, passwordless authentication with AWS, eliminating the need for long-lived access keys.
2.  **Build & Test Docker Image**: Constructs a new Docker image from the source code and runs validation checks.
3.  **Push to Amazon ECR**: Tags the new image and pushes it to the private Amazon ECR repository.
4.  **Deploy Infrastructure with Terraform**: Atomically applies infrastructure changes using `terraform apply`, ensuring the production environment always reflects the `main` branch.

```
┌─────────────────┐      ┌──────────────────────────┐      ┌──────────────────┐      ┌────────────────────┐      ┌──────────────────┐
│ Push to `main`  ├─►│ 1. Authenticate & Log In │ ─► │ 2. Build Image   │ ─► │ 3. Push to ECR     │ ─► │ 4. Terraform Apply │
└─────────────────┘      └──────────────────────────┘      └──────────────────┘      └────────────────────┘      └──────────────────┘
```

### 8. Cloud Infrastructure & Deployment

#### 8.1 Advanced Secrets Management
All secrets, including the `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`, are stored securely in **AWS SSM Parameter Store** as `SecureString` parameters. This follows security best practices by centralizing and encrypting sensitive data. The EC2 instance is granted a fine-grained IAM Role with permissions to access only these specific parameters at runtime, adhering to the principle of least privilege. This modern approach completely avoids hardcoding secrets or exposing them in CI/CD pipelines.

#### 8.2 Infrastructure as Code (Terraform)
The entire cloud environment is declaratively defined in Terraform, ensuring it is version-controlled, repeatable, and transparent.

**Remote State & Locking**
To enable seamless collaboration and reliable CI/CD runs, Terraform is configured with a remote backend. The state is persisted in an S3 bucket with versioning enabled, while a DynamoDB table provides robust state locking to prevent race conditions and ensure transactional integrity during deployments.

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
At runtime, the EC2 instance's user data script dynamically fetches secrets from the SSM Parameter Store just before launching the container. This ensures the application always starts with the latest credentials without ever exposing them within the infrastructure code or instance metadata.

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

#### 8.3 Zero-Touch Deployment
The deployment process is fully automated. To roll out any change, developers simply push commits to the `main` branch, and the CI/CD pipeline handles the rest.

**Initial One-Time Setup:**
Before the first deployment, the following AWS resources must be created manually to bootstrap the Terraform backend and secrets:
1.  **S3 Bucket** for Terraform state storage.
2.  **DynamoDB Table** for Terraform state locking.
3.  **SSM Parameters** for the Telegram token and chat ID.

### 9. Cost-Effectiveness & AWS Free Tier Analysis

This project is meticulously designed to be extremely cost-effective, with an estimated monthly cost of **$0.00** for any user within their first 12 months of the AWS Free Tier.

Here is a detailed breakdown of the cost analysis:

| Service                       | Usage Details (12 hours/day)          | Free Tier Allowance (Monthly) | Estimated Cost |
| ----------------------------- | ------------------------------------- | ----------------------------- | :------------: |
| **Amazon EC2 (`t2.micro`)**   | 360 hours/month                       | 750 hours                     |     **$0.00**      |
| **Amazon ECR**                | < 500 MB storage                      | 500 MB                        |     **$0.00**      |
| **AWS Lambda**                | 60 requests/month                     | 1,000,000 requests            |     **$0.00**      |
| **Amazon EventBridge**        | 60 scheduled events/month             | 14,000,000 events             |     **$0.00**      |
| **SSM Parameter Store**       | < 100 API calls/month (Standard)      | 10,000 API calls              |     **$0.00**      |
| **Amazon S3**                 | < 1 GB storage (Terraform state)      | 5 GB                          |     **$0.00**      |
| **Amazon DynamoDB**           | Minimal RCU/WCU (Terraform lock)      | 25 RCU / 25 WCU               |     **$0.00**      |
| **Amazon CloudWatch**         | < 5 GB logs/month                     | 5 GB                          |     **$0.00**      |
| **Data Transfer**             | Minimal (notifications, image pull)   | 100 GB                        |     **$0.00**      |
| **Total Estimated Cost**      |                                       |                               |   **~$0.00**   |

*Note: This estimate assumes usage remains within the AWS Free Tier limits. Costs may vary based on actual usage and any changes to AWS pricing.*
