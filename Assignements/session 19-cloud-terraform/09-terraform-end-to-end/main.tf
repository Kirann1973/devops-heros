# Kiran N | Roll No: 10446
# End-to-end infrastructure: VPC -> subnet -> internet gateway -> route table -> security group -> EC2 web server,
# plus a private S3 bucket that stores a JSON report about the EC2 instance.

locals {
  name = var.project_name

  common_tags = {
    Owner       = var.owner
    RollNo      = var.roll_no
    Project     = "Session19-Cloud-Terraform"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ---------------------------------------------------------------- data sources (read-only lookups)

# First availability zone of the region, instead of hard-coding "ap-south-1a"
data "aws_availability_zones" "available" {
  state = "available"
}

# Latest Amazon Linux 2023 AMI for x86_64, so no AMI ID is hard-coded
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------- network

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id # implicit dependency: subnet waits for the VPC
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-public-subnet" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "web" {
  name        = "${local.name}-web-sg"
  description = "HTTP in from allowed CIDRs, all traffic out"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-web-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_http_cidrs)

  security_group_id = aws_security_group.web.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.web.id
  description       = "All outbound (package install)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------- compute

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  # No SSH key and no port 22: the server is only reachable on port 80.
  # Instance metadata only with a session token (IMDSv2).
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    owner       = var.owner
    roll_no     = var.roll_no
    environment = var.environment
    region      = var.aws_region
  })
  user_data_replace_on_change = true

  # Explicit dependency: the instance needs the internet route to download nginx at first boot,
  # but nothing in this block references the route table, so Terraform cannot see that by itself.
  depends_on = [aws_route_table_association.public]

  tags = { Name = "${local.name}-web" }
}

# ---------------------------------------------------------------- storage

resource "aws_s3_bucket" "reports" {
  bucket_prefix = "kiran-n-10446-s19-" # AWS adds a unique suffix, so the name never clashes
  force_destroy = true

  tags = { Name = "${local.name}-reports" }
}

resource "aws_s3_bucket_versioning" "reports" {
  bucket = aws_s3_bucket.reports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket = aws_s3_bucket.reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A JSON report built from the other resources' attributes.
# Every value below is a reference, so Terraform creates this object last (implicit dependencies on EC2, VPC, subnet, SG).
resource "aws_s3_object" "infra_report" {
  bucket       = aws_s3_bucket.reports.id
  key          = "reports/infrastructure.json"
  content_type = "application/json"
  content = jsonencode({
    created_by    = "${var.owner} (${var.roll_no})"
    region        = var.aws_region
    vpc_id        = aws_vpc.main.id
    vpc_cidr      = aws_vpc.main.cidr_block
    subnet_id     = aws_subnet.public.id
    subnet_az     = aws_subnet.public.availability_zone
    sg_id         = aws_security_group.web.id
    instance_id   = aws_instance.web.id
    instance_type = aws_instance.web.instance_type
    ami_id        = aws_instance.web.ami
    public_ip     = aws_instance.web.public_ip
    private_ip    = aws_instance.web.private_ip
  })

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.reports]
}
