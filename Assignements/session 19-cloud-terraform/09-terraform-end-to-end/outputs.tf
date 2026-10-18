# Kiran N | Roll No: 10446
# Printed after apply and by "terraform output".

output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "availability_zone" {
  description = "AZ of the public subnet."
  value       = aws_subnet.public.availability_zone
}

output "security_group_id" {
  description = "ID of the web security group."
  value       = aws_security_group.web.id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI used for the instance."
  value       = data.aws_ami.al2023.id
}

output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "Open this in a browser (nginx needs about a minute after apply)."
  value       = "http://${aws_instance.web.public_ip}"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.reports.bucket
}

output "s3_report_uri" {
  description = "S3 URI of the infrastructure report."
  value       = "s3://${aws_s3_bucket.reports.bucket}/${aws_s3_object.infra_report.key}"
}
