# Kiran N | Roll No: 10446
# Inputs of the project. The values are set in terraform.tfvars and can be overridden with -var.

variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket is created."
  default     = "ap-south-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique name of the S3 bucket."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters: lowercase letters, numbers, dots and hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Environment name used in the tags."
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test or prod."
  }
}

variable "versioning_enabled" {
  type        = bool
  description = "Keep old versions of every object."
  default     = true
}

variable "owner" {
  type        = string
  description = "Name added to every resource as the Owner tag."
  default     = "Kiran N"
}

variable "roll_no" {
  type        = string
  description = "Roll number added to every resource as the RollNo tag."
  default     = "10446"
}
