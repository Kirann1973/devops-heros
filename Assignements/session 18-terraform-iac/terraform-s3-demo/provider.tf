# Kiran N | Roll No: 10446
# The AWS provider talks to the AWS API. Credentials come from "aws configure" (~/.aws/credentials),
# never from this file. default_tags are added to every resource this project creates.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Owner     = var.owner
      RollNo    = var.roll_no
      Project   = "Session18-Terraform-IaC"
      ManagedBy = "Terraform"
    }
  }
}
