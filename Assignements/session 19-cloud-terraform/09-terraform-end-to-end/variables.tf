# Kiran N | Roll No: 10446
# Inputs. My values are in terraform.tfvars; any of them can be overridden with -var.

variable "aws_region" {
  type        = string
  description = "AWS region for every resource."
  default     = "ap-south-1"
}

variable "project_name" {
  type        = string
  description = "Prefix used in resource names."
  default     = "kiran-s19"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name must be 3-20 characters: lowercase letters, numbers and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name, used in tags."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "IP range of the VPC."
  default     = "10.19.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, for example 10.19.0.0/16."
  }
}

variable "public_subnet_cidr" {
  type        = string
  description = "IP range of the public subnet (must be inside vpc_cidr)."
  default     = "10.19.1.0/24"
}

variable "instance_type" {
  type        = string
  description = "EC2 size. t3.micro is free tier eligible."
  default     = "t3.micro"
}

variable "allowed_http_cidrs" {
  type        = list(string)
  description = "Who may open the website on port 80."
  default     = ["0.0.0.0/0"]
}

variable "owner" {
  type        = string
  description = "Owner tag on every resource."
  default     = "Kiran N"
}

variable "roll_no" {
  type        = string
  description = "RollNo tag on every resource."
  default     = "10446"
}
