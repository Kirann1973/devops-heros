# Kiran N | Roll No: 10446
# Values printed after "terraform apply" and by "terraform output".
# (output blocks take description/value/sensitive, not "type")

output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.kiran_demo.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.kiran_demo.arn
}

output "bucket_region" {
  description = "AWS region of the S3 bucket."
  value       = aws_s3_bucket.kiran_demo.region
}

output "versioning_status" {
  description = "Versioning status of the bucket."
  value       = aws_s3_bucket_versioning.kiran_demo.versioning_configuration[0].status
}

output "object_uri" {
  description = "S3 URI of the uploaded file."
  value       = "s3://${aws_s3_bucket.kiran_demo.bucket}/${aws_s3_object.hello.key}"
}
