# Amazon EC2 - Elastic Compute Cloud

**Name:** Kiran N | **Roll No:** 10446 | **Session 18 - Terraform IaC, Task 2**

EC2 gives you **virtual servers (instances)** in the cloud. You choose the operating system, CPU/RAM, disk and network, start it in minutes, and pay per second while it runs.

```text
                       Region ap-south-1 (Mumbai)
  +-------------------------------------------------------------------+
  |  VPC 10.0.0.0/16                                                  |
  |   +---------------------- Availability Zone ap-south-1a -------+  |
  |   |  Public subnet 10.0.1.0/24                                 |  |
  |   |   +------------------------------------------------------+ |  |
  |   |   | EC2 instance (t3.micro)  <- launched from an AMI     | |  |
  |   |   |   private IP 10.0.1.25   public IP 13.x.x.x          | |  |
  |   |   |   key pair: kiran-key    IAM role: ec2-s3-read       | |  |
  |   |   |   Security group: allow 22 from my IP, 80 from all   | |  |
  |   |   |   EBS root volume gp3 8 GiB  (+ data volume)         | |  |
  |   |   +------------------------------------------------------+ |  |
  |   +------------------------------------------------------------+  |
  +-------------------------------------------------------------------+
```

---

## 1. AMI - Amazon Machine Image

An **AMI** is the template an instance boots from: the OS, preinstalled software and the root volume snapshot.

| Source | Examples |
|---|---|
| AWS / vendors | Amazon Linux 2023, Ubuntu 24.04, Windows Server, Red Hat |
| AWS Marketplace | Images with software preinstalled (paid or free) |
| Your own (custom/"golden" AMI) | Built from a configured instance or with Packer |

- AMIs are **regional** (copy them to use in another region) and have an architecture: `x86_64` or `arm64` (Graviton).
- AMI IDs differ per region, so in Terraform look them up instead of hard-coding (see section 9).

## 2. Instance types

Name format: **family + generation + options . size**, e.g. `t3.micro`, `m7g.large`, `c6i.2xlarge` (`g` = Graviton/ARM, `i` = Intel, `a` = AMD).

| Family | Optimised for | Example use |
|---|---|---|
| **t** (t3, t4g) | Burstable general purpose, cheap | Dev/test, small web apps (t3.micro / t2.micro = free tier) |
| **m** (m7i, m7g) | Balanced CPU/RAM | Application servers, backends |
| **c** (c7i, c7g) | Compute | Batch jobs, CI builds, gaming, encoding |
| **r / x** | Memory | Databases, in-memory caches |
| **i / d** | Local NVMe storage | High I/O databases, data warehouses |
| **p / g / inf** | GPU / ML accelerators | Machine learning, graphics |

Pricing models: **On-Demand** (per second, no commitment), **Savings Plans / Reserved** (1-3 year commitment, up to ~70% cheaper), **Spot** (spare capacity, up to ~90% cheaper, can be interrupted), **Dedicated hosts**.

## 3. Key pairs

A **key pair** is used to log in with SSH (Linux) or to decrypt the admin password (Windows).

- AWS keeps the **public key** and puts it in `~/.ssh/authorized_keys` on the instance.
- You keep the **private key** (`.pem`). AWS shows it **only once** at creation.

```bash
aws ec2 create-key-pair --key-name kiran-key --query KeyMaterial --output text > kiran-key.pem
chmod 400 kiran-key.pem
ssh -i kiran-key.pem ubuntu@<public-ip>         # ec2-user@ for Amazon Linux
```

Lost key = no SSH. Alternatives without SSH keys: **EC2 Instance Connect** and **SSM Session Manager** (no port 22 needed).

## 4. Security groups

A **security group (SG)** is a virtual firewall attached to an instance's network interface.

- **Stateful**: if inbound traffic is allowed, the reply goes out automatically.
- **Allow rules only** (no deny). Everything not allowed is blocked inbound; all outbound is allowed by default.
- Source can be an IP range (CIDR) **or another security group** (e.g. "DB SG allows 5432 only from App SG").

| Direction | Port | Source | Why |
|---|---|---|---|
| Inbound | 22 (SSH) | `my.ip.address/32` | Admin access only from my IP |
| Inbound | 80, 443 | `0.0.0.0/0` | Public website |
| Outbound | all | `0.0.0.0/0` | Updates, API calls |

Never open 22 or database ports to `0.0.0.0/0`.

## 5. EBS - Elastic Block Store

**EBS volumes** are network disks for EC2. They live in one AZ and keep data when the instance stops.

| Type | Use |
|---|---|
| **gp3** (default SSD) | Most workloads; baseline 3000 IOPS, tune IOPS/throughput separately |
| **io2** | Provisioned IOPS SSD for critical databases |
| **st1 / sc1** | HDD for big sequential data / cold data |

- **Snapshots** are point-in-time backups to S3, used to restore or copy volumes (and to build AMIs).
- Enable **encryption** (KMS) - it covers data at rest, snapshots and traffic to the instance.
- Root volume is deleted on termination by default (`DeleteOnTermination`); extra data volumes are kept.
- Different from **instance store**: fast local disk that is **lost** when the instance stops.

## 6. Public IP vs private IP

| | Private IP | Public IP | Elastic IP |
|---|---|---|---|
| From | Subnet CIDR (e.g. 10.0.1.25) | AWS pool | AWS pool, owned by your account |
| Reachable from | Inside the VPC (and VPN/peering) | Internet | Internet |
| Changes on stop/start? | No | **Yes**, new IP every start | No, fixed until you release it |
| Cost | Free | Charged per hour (all public IPv4) | Charged per hour |

An instance gets a public IP only if it is in a **public subnet** (route to an Internet Gateway) with auto-assign public IP on, or you attach an Elastic IP. Private instances reach the internet through a **NAT gateway**.

## 7. Instance lifecycle

```text
            launch
              |
              v
          [pending] ----> [running] <---------- start ----------+
                           |   |  \                              |
                  reboot   |   |   \ stop                        |
             (same host,   |   |    v                            |
              same IPs)    +---+  [stopping] ---> [stopped] -----+
                               |                    (no compute charge,
                     terminate |                     EBS still charged,
                               v                     public IP released)
                       [shutting-down] ---> [terminated]  (gone; root EBS deleted)
```

- **Stop/Start**: the instance may move to new hardware; private IP and EBS data stay, public IP changes.
- **Hibernate**: RAM saved to EBS, resume faster.
- **Terminate**: permanent. Turn on *termination protection* for important servers.
- **User data**: a script that runs at first boot (install packages, start the app).
- Scaling: **Launch Templates** + **Auto Scaling Groups** add/remove instances automatically, an **Elastic Load Balancer** spreads traffic across them.

## 8. Use cases

| Use case | Typical setup |
|---|---|
| Web/application servers | ASG of t3/m7 instances behind an ALB |
| Jenkins / CI build agents | c-family, Spot instances for cheap builds |
| Self-managed databases | r-family + io2 EBS (or use RDS instead) |
| Bastion / jump host | Small instance in public subnet, SSH from your IP only |
| Kubernetes worker nodes | EKS managed node groups (EC2 underneath) |
| Batch / ML training | Spot or GPU (p/g) instances |
| Lift-and-shift of on-prem servers | Same OS/app, now on EC2 |

## 9. The same thing in Terraform

```hcl
# Latest Ubuntu 24.04 AMI in the current region (no hard-coded AMI ID)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "kiran" {
  key_name   = "kiran-key"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub")) # my SSH public key, private key never leaves my laptop
}

resource "aws_security_group" "web" {
  name        = "kiran-web-sg"
  description = "SSH from my IP, HTTP from anywhere"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.10/32"] # my public IP
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.kiran.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y && apt-get install -y nginx
    echo "Kiran N - 10446 - Session 18" > /var/www/html/index.html
  EOF

  tags = { Name = "kiran-web", Owner = "Kiran N", RollNo = "10446" }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
```

Useful CLI commands:

```bash
aws ec2 describe-instances --filters Name=tag:Owner,Values="Kiran N" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,PublicIpAddress]' --output table
aws ec2 stop-instances --instance-ids i-0123456789abcdef0
aws ec2 terminate-instances --instance-ids i-0123456789abcdef0
```
