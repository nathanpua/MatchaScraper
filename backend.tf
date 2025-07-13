# backend.tf
terraform {
  backend "s3" {
    bucket         = "ippodo-scraper-tfstate-997092021600"
    key            = "global/s3/terraform.tfstate"
    region         = "ap-northeast-3"
    dynamodb_table = "ippodo-scraper-tf-lock"
    encrypt        = true
  }
} 