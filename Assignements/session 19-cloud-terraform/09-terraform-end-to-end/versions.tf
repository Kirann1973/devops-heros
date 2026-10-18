# Kiran N | Roll No: 10446
# Terraform and provider versions (the "providers" part of the homework)
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Credentials come from "aws configure" (~/.aws/credentials), never from this repo.
# default_tags are added to every resource that supports tags.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
