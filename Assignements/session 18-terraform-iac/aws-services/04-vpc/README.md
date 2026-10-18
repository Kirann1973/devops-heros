# Amazon VPC - Virtual Private Cloud

**Name:** Kiran N | **Roll No:** 10446 | **Session 18 - Terraform IaC, Task 2**

A **VPC** is your own private, isolated network inside an AWS region. You choose the IP range, split it into subnets, and control exactly how traffic flows in, out and between them. Every EC2 instance, RDS database, load balancer and EKS node lives in a VPC.

## Architecture: public and private subnets in two AZs

```text
                                   Internet
                                      |
                              +-------+--------+
                              | Internet       |
                              | Gateway (IGW)  |
                              +-------+--------+
  VPC 10.0.0.0/16  (ap-south-1)       |
  +-----------------------------------+--------------------------------------+
  |        AZ ap-south-1a             |            AZ ap-south-1b            |
  |  +-----------------------------+  |  +-----------------------------+     |
  |  | PUBLIC subnet 10.0.1.0/24   |  |  | PUBLIC subnet 10.0.2.0/24   |     |
  |  |  Load balancer, bastion     |  |  |  Load balancer              |     |
  |  |  NAT Gateway (Elastic IP)   |  |  |                             |     |
  |  +--------------+--------------+  |  +-----------------------------+     |
  |   public route table: 10.0.0.0/16 -> local, 0.0.0.0/0 -> IGW             |
  |                 |                                                        |
  |  +--------------v--------------+     +-----------------------------+     |
  |  | PRIVATE subnet 10.0.11.0/24 |     | PRIVATE subnet 10.0.12.0/24 |     |
  |  |  App servers (EC2 / EKS)    |     |  App servers                |     |
  |  |  RDS primary                |     |  RDS standby (Multi-AZ)     |     |
  |  +-----------------------------+     +-----------------------------+     |
  |   private route table: 10.0.0.0/16 -> local, 0.0.0.0/0 -> NAT Gateway    |
  +--------------------------------------------------------------------------+
   Security groups protect each instance (stateful)   NACLs protect each subnet (stateless)
```

---

## 1. CIDR blocks

A VPC gets an IPv4 range written in **CIDR** notation: `network address / prefix length`. The prefix says how many bits are fixed; the rest are host addresses.

| CIDR | Addresses | Typical use |
|---|---|---|
| `10.0.0.0/16` | 65,536 | Whole VPC (allowed sizes: /16 to /28) |
| `10.0.1.0/24` | 256 (251 usable) | One subnet |
| `10.0.1.0/28` | 16 (11 usable) | Smallest subnet |
| `203.0.113.10/32` | 1 | One IP (e.g. "SSH from my IP") |
| `0.0.0.0/0` | All | "Anywhere / the internet" |

- Use private ranges (RFC 1918): `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`.
- AWS reserves **5 IPs per subnet** (first 4 + last): network, VPC router, DNS, future use, broadcast.
- Plan ranges so they **don't overlap** with other VPCs or your office network, otherwise peering/VPN won't work.
- IPv6 can be added (AWS assigns a /56 to the VPC, /64 per subnet).

## 2. Subnets

A **subnet** is a slice of the VPC CIDR that lives in **exactly one Availability Zone**.

- Spread subnets over at least 2 AZs for high availability.
- What makes a subnet "public" or "private" is **only its route table** (see section 8).
- `map_public_ip_on_launch = true` gives instances in that subnet a public IP automatically.

## 3. Route tables

A **route table** is a list of rules: *destination CIDR -> target*. Each subnet is associated with one route table (if not, it uses the VPC's main route table). The most specific matching route wins.

| Destination | Target | Meaning |
|---|---|---|
| `10.0.0.0/16` | `local` | Traffic inside the VPC (always present, cannot be removed) |
| `0.0.0.0/0` | `igw-...` | Internet via the Internet Gateway (public subnet) |
| `0.0.0.0/0` | `nat-...` | Internet via NAT Gateway, outbound only (private subnet) |
| `172.31.0.0/16` | `pcx-...` | Another VPC via peering |
| `192.168.0.0/16` | `vgw-...` / `tgw-...` | Office network via VPN / Transit Gateway |

## 4. Internet Gateway (IGW)

- A horizontally scaled, highly available gateway that connects the VPC to the internet. **One per VPC**, free.
- Allows **both directions**: inbound from the internet to resources with a public IP, and outbound.
- Needs: IGW attached to VPC + route `0.0.0.0/0 -> igw` + public IP on the instance + SG/NACL allowing the traffic.

## 5. NAT Gateway

- Lets instances in **private subnets** reach the internet (OS updates, pulling images, calling APIs) while **no one from the internet can start a connection to them**.
- Lives in a **public subnet**, has an **Elastic IP**; private route tables send `0.0.0.0/0` to it.
- Managed and scales automatically, but **costs per hour + per GB** - for real HA use one per AZ; for labs, destroy it when done.
- Alternatives: **VPC endpoints** (reach S3/DynamoDB and other AWS services privately without NAT), NAT instance (cheaper, self-managed).

## 6. Security groups

Instance-level, **stateful** firewall (details in [02-ec2](../02-ec2)).

- Allow rules only; return traffic is allowed automatically.
- Can reference other SGs: `db-sg` allows 5432 **from `app-sg`**, so only app servers reach the database, whatever their IPs.

## 7. Network ACLs (NACLs)

Subnet-level, **stateless** firewall - an extra layer in front of the SGs.

| | Security Group | Network ACL |
|---|---|---|
| Applies to | Network interface (instance) | Whole subnet |
| State | **Stateful** (replies allowed automatically) | **Stateless** (must allow return traffic, ephemeral ports 1024-65535) |
| Rules | Allow only | Allow **and Deny** |
| Order | All rules evaluated together | Numbered, lowest number first, first match wins |
| Default | New SG: deny all inbound, allow all outbound | Default NACL: allow all both ways |
| Typical use | Main access control | Block a bad IP range for a whole subnet |

## 8. Public vs private subnet

| | Public subnet | Private subnet |
|---|---|---|
| Route `0.0.0.0/0` goes to | **Internet Gateway** | **NAT Gateway** (or nowhere) |
| Instances get public IP | Yes | No |
| Reachable from internet | Yes (if SG allows) | **No** |
| Can reach internet | Yes | Outbound only via NAT |
| Put here | Load balancers, NAT gateway, bastion host | App servers, databases, caches, EKS nodes |

Rule of thumb: **only the things that must be reached from the internet go public**; everything else is private.

Other VPC features: **VPC Peering** / **Transit Gateway** (connect VPCs), **Site-to-Site VPN** / **Direct Connect** (connect on-prem), **VPC Flow Logs** (log accepted/rejected traffic), **VPC Endpoints** (private access to AWS services).

## 9. The same thing in Terraform

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "kiran-10446-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "kiran-igw" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 1) # 10.0.1.0/24, 10.0.2.0/24
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "kiran-public-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 11) # 10.0.11.0/24, 10.0.12.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "kiran-private-${count.index + 1}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # NAT lives in a public subnet
  depends_on    = [aws_internet_gateway.igw]
  tags          = { Name = "kiran-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "kiran-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "kiran-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Web tier SG and a DB SG that only accepts traffic from the web tier
resource "aws_security_group" "web" {
  name   = "kiran-web-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_security_group" "db" {
  name   = "kiran-db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }
}

# NACL on the private subnets: deny one bad range, allow the rest
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  ingress {
    rule_no    = 90
    action     = "deny"
    protocol   = "-1"
    cidr_block = "198.51.100.0/24"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}
```

Useful CLI commands:

```bash
aws ec2 describe-vpcs --query 'Vpcs[].[VpcId,CidrBlock,IsDefault]' --output table
aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-0123 \
  --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]' --output table
aws ec2 describe-route-tables --filters Name=vpc-id,Values=vpc-0123
```
