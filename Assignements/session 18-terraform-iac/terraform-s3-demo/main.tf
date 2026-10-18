# Kiran N | Roll No: 10446
# One private, encrypted, versioned S3 bucket with one object in it.

resource "aws_s3_bucket" "kiran_demo" {
  bucket        = var.bucket_name
  force_destroy = true # lets "terraform destroy" delete the bucket even when it still has objects

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Turn versioning on (or suspend it) from a variable
resource "aws_s3_bucket_versioning" "kiran_demo" {
  bucket = aws_s3_bucket.kiran_demo.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Encrypt every object at rest with S3-managed keys (SSE-S3, AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "kiran_demo" {
  bucket = aws_s3_bucket.kiran_demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block every kind of public access to the bucket
resource "aws_s3_bucket_public_access_block" "kiran_demo" {
  bucket = aws_s3_bucket.kiran_demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A small text file uploaded by Terraform, to show an object inside the bucket
resource "aws_s3_object" "hello" {
  bucket       = aws_s3_bucket.kiran_demo.id
  key          = "hello.txt"
  content      = "Hello from Terraform! Created by ${var.owner} (Roll No: ${var.roll_no}) in ${var.aws_region}.\n"
  content_type = "text/plain"

  # upload only after encryption and versioning are in place
  depends_on = [
    aws_s3_bucket_versioning.kiran_demo,
    aws_s3_bucket_server_side_encryption_configuration.kiran_demo,
  ]
}
