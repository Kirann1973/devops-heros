# AWS Databases - DynamoDB and RDS

**Name:** Kiran N | **Roll No:** 10446 | **Session 18 - Terraform IaC, Task 2**

AWS has two very different managed database services that come up in almost every project:

| | **DynamoDB** | **RDS** |
|---|---|---|
| Type | NoSQL key-value / document | Relational (SQL) |
| Schema | Flexible, only the key is fixed | Fixed tables, columns, types |
| Servers | **Serverless** - no instances to manage | You pick an instance class and storage |
| Scaling | Automatic, practically unlimited | Vertical (bigger instance) + read replicas |
| Query | By key (GetItem / Query), no joins | Full SQL: joins, aggregations, transactions |
| Typical latency | Single-digit milliseconds at any scale | Depends on instance and query |
| Pick it when | Access patterns are known and simple, huge scale | Data is relational, complex queries, existing SQL apps |

---

# Part A - Amazon DynamoDB

## A1. NoSQL

DynamoDB is a fully managed **NoSQL** database. "NoSQL" means:

- No fixed table schema - every item can have different attributes (only the primary key is required).
- Data is accessed by **key**, not by joining tables. You design the table around your **access patterns** ("get all orders of a customer, newest first").
- Scales horizontally: data is spread across **partitions** by the partition key, so throughput grows by adding partitions, not by buying a bigger server.
- Fully managed: no servers, patches or backups to run; data replicated across 3 AZs automatically.

## A2. Tables, items and attributes

```text
Table: Orders
+------------------+---------------------+--------+-----------+---------------------+
| CustomerId (PK)  | OrderDate (SK)      | Amount | Status    | Items               |
+------------------+---------------------+--------+-----------+---------------------+
| kiran-10446      | 2026-10-01T10:15Z   | 499    | DELIVERED | ["book","pen"]      |   <- item
| kiran-10446      | 2026-10-18T08:30Z   | 1299   | SHIPPED   | ["headphones"]      |   <- item
| ravi-20001       | 2026-10-05T14:00Z   | 89     | PLACED    |                     |   <- item (no Items attribute)
+------------------+---------------------+--------+-----------+---------------------+
          ^ attribute names + values (String, Number, Binary, Boolean, Null, List, Map, Set)
```

| Term | Meaning | SQL equivalent |
|---|---|---|
| **Table** | Collection of items | Table |
| **Item** | One record, max **400 KB** | Row |
| **Attribute** | A name-value pair inside an item | Column (but optional per item) |

## A3. Partition key and sort key

The **primary key** uniquely identifies each item. Two kinds:

| Primary key | Made of | Example |
|---|---|---|
| **Simple** | Partition key only | `UserId` - one item per user |
| **Composite** | Partition key + sort key | `CustomerId` + `OrderDate` - many orders per customer, sorted by date |

- **Partition key (hash key)** - DynamoDB hashes it to decide which partition stores the item. Choose a key with **many distinct values** that spreads traffic evenly (UserId good, Status bad - only a few values = "hot partition").
- **Sort key (range key)** - orders items that share a partition key, and enables range queries: `begins_with`, `between`, `>`, `<`.
- **Secondary indexes** for other access patterns:
  - **GSI** (Global Secondary Index) - a different partition/sort key, e.g. query orders by `Status`.
  - **LSI** (Local Secondary Index) - same partition key, different sort key (only at table creation).

```bash
# Get one order (exact key)
aws dynamodb get-item --table-name Orders \
  --key '{"CustomerId":{"S":"kiran-10446"},"OrderDate":{"S":"2026-10-18T08:30Z"}}'

# All orders of one customer in October 2026 (partition key + sort key range)
aws dynamodb query --table-name Orders \
  --key-condition-expression "CustomerId = :c AND begins_with(OrderDate, :m)" \
  --expression-attribute-values '{":c":{"S":"kiran-10446"},":m":{"S":"2026-10"}}'
```

Avoid `Scan` (reads the whole table) in production paths.

## A4. Capacity, features and security

- **Capacity modes**: **On-demand** (pay per request, no planning - default choice) or **Provisioned** (set RCU/WCU, optional auto scaling, cheaper for steady traffic).
- **Consistency**: eventually consistent reads by default, strongly consistent reads on request; ACID **transactions** across up to 100 items.
- **TTL**: delete expired items automatically (sessions, temporary tokens).
- **Streams**: change log of every write, triggers Lambda (event-driven apps).
- **Global Tables**: multi-region, multi-active replication.
- **DAX**: in-memory cache, microsecond reads.
- **Backups**: on-demand backups + **Point-in-Time Recovery** (restore to any second in the last 35 days).
- **Security**: encrypted at rest by default (KMS), IAM policies down to item/attribute level, VPC endpoint for private access.

## A5. DynamoDB use cases

| Use case | Why DynamoDB |
|---|---|
| **Terraform state locking** (classic setup) | `LockID` table prevents two `terraform apply` runs at the same time |
| User sessions / shopping carts | Key lookups + TTL for expiry |
| Gaming leaderboards, player profiles | Massive scale, low latency |
| IoT / time-series events | Partition by device, sort by timestamp |
| Serverless APIs (API Gateway + Lambda) | No servers, pay per request |
| Metadata store (e.g. for S3 objects) | Simple key access at any scale |

---

# Part B - Amazon RDS (Relational Database Service)

RDS runs a **relational SQL database** for you. AWS handles hardware, OS and database installation, patching, backups, monitoring and failover; you handle schema, queries, users and tuning.

## B1. Engines

| Engine | Notes |
|---|---|
| **MySQL** | Most popular open source, web apps (WordPress, etc.) |
| **PostgreSQL** | Advanced open source: JSONB, extensions (PostGIS), strong SQL |
| **MariaDB** | Community fork of MySQL |
| **Oracle** | Enterprise; license included or BYOL |
| **Microsoft SQL Server** | .NET / Windows applications |
| **IBM Db2** | Enterprise workloads |
| **Amazon Aurora** (MySQL/PostgreSQL compatible) | AWS-built: storage auto-grows to 128 TB, 6 copies across 3 AZs, up to 15 low-lag replicas, Aurora Serverless v2 |

## B2. DB instances

A **DB instance** = one database server with its compute class + storage.

- **Instance classes**: `db.t4g.micro` / `db.t3.micro` (burstable, free tier), `db.m7g.*` (general), `db.r7g.*` (memory-optimised).
- **Storage**: gp3 (general SSD), io2 (provisioned IOPS), storage **autoscaling** up to a max size.
- Connect using the **endpoint** (DNS name) + port, e.g. `mydb.abc123.ap-south-1.rds.amazonaws.com:5432` - never by IP, because IPs change on failover.
- Configuration via **parameter groups** (engine settings) and **option groups**.
- No SSH access to the host - it is a managed service.

```bash
aws rds describe-db-instances \
  --query 'DBInstances[].[DBInstanceIdentifier,Engine,DBInstanceClass,DBInstanceStatus,Endpoint.Address]' --output table
psql -h kiran-db.abc123.ap-south-1.rds.amazonaws.com -U appadmin -d appdb
```

## B3. Security

- Run it in **private subnets** (a **DB subnet group** with subnets in ≥2 AZs) with `publicly_accessible = false`.
- **Security group** allows the DB port (3306 / 5432) only **from the app servers' security group** (see [04-vpc](../04-vpc)).
- **Encryption at rest** with KMS (must be chosen at creation; covers storage, backups, snapshots, replicas) and **TLS in transit**.
- Master password in **AWS Secrets Manager** (`manage_master_user_password = true`, automatic rotation) - never in code or tfvars.
- **IAM database authentication** (short-lived tokens instead of passwords) for MySQL/PostgreSQL.
- **Deletion protection**, audit logs to CloudWatch, Performance Insights / Database Insights for monitoring.

## B4. Backups

| Type | How it works |
|---|---|
| **Automated backups** | Daily snapshot in the backup window + transaction logs every ~5 min. Retention 0-35 days (0 disables). Enables **point-in-time restore** to any second in that window. |
| **Manual snapshots** | Taken when you choose (e.g. before a migration), kept until you delete them, can be copied to other regions/accounts. |
| **Final snapshot** | Taken when the instance is deleted (unless `skip_final_snapshot`). |
| **AWS Backup** | Central backup policies across RDS, DynamoDB, EBS, EFS... |

A restore always creates a **new** DB instance with a new endpoint.

## B5. Multi-AZ

High availability: RDS keeps a **synchronous standby** copy in a different Availability Zone.

```text
            app ---> endpoint kiran-db.xxx.rds.amazonaws.com (DNS)
                          |
        AZ ap-south-1a    |                AZ ap-south-1b
     +----------------+   |  synchronous  +----------------+
     |  PRIMARY       |<--+-------------->|  STANDBY       |
     |  (reads+writes)|   replication     |  (no traffic)  |
     +----------------+                   +----------------+
     primary fails -> DNS switches to standby automatically (~60-120 s), same endpoint
```

- For **availability**, not performance: the standby serves no reads (in the classic one-standby setup).
- Automatic failover on host/AZ failure, storage failure, or during patching/instance resize.
- **Multi-AZ DB cluster** option: 2 readable standbys and faster (~35 s) failover.

## B6. Read replicas

For **read scaling**: **asynchronous** copies that serve **read-only** queries.

| | Multi-AZ standby | Read replica |
|---|---|---|
| Purpose | High availability / failover | Performance (scale reads) |
| Replication | Synchronous | Asynchronous (small lag) |
| Serves traffic | No | Yes, reads only, own endpoint |
| Location | Other AZ, same region | Same AZ, other AZ, or **other region** |
| Promotion | Automatic on failure | Manual "promote" -> becomes standalone DB (used for DR) |

Up to 15 read replicas per source (MySQL/MariaDB/PostgreSQL). Send reporting/analytics/read-heavy API traffic to replicas, writes to the primary.

## B7. RDS use cases

| Use case | Why RDS |
|---|---|
| Web and mobile app backends | Users, products, orders with relations and transactions |
| E-commerce / banking | ACID transactions, consistency, complex queries |
| CMS (WordPress, Drupal) | Built for MySQL |
| ERP / CRM / existing enterprise apps | Oracle, SQL Server lift-and-shift without managing servers |
| Reporting dashboards | Read replicas for heavy SELECT queries |
| Microservices with relational data | One small instance (or Aurora Serverless) per service |

---

## The same thing in Terraform

```hcl
# DynamoDB: Orders table (composite key) + the classic Terraform lock table
resource "aws_dynamodb_table" "orders" {
  name         = "Orders"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "CustomerId"
  range_key    = "OrderDate"

  attribute {
    name = "CustomerId"
    type = "S"
  }

  attribute {
    name = "OrderDate"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusIndex"
    projection_type = "ALL"

    key_schema {
      attribute_name = "Status"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "OrderDate"
      key_type       = "RANGE"
    }
  }

  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Owner = "Kiran N", RollNo = "10446" }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# RDS PostgreSQL: private, encrypted, Multi-AZ, backups, password in Secrets Manager
resource "aws_db_subnet_group" "db" {
  name       = "kiran-db-subnets"
  subnet_ids = ["subnet-private-a", "subnet-private-b"] # private subnets from 04-vpc
}

resource "aws_db_instance" "postgres" {
  identifier     = "kiran-db"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100 # storage autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = "appdb"
  username                    = "appadmin"
  manage_master_user_password = true # generated + rotated in Secrets Manager

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = ["sg-db"] # allows 5432 only from the app SG
  publicly_accessible    = false

  multi_az                  = true
  backup_retention_period   = 7
  backup_window             = "20:00-21:00" # UTC
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "kiran-db-final"

  tags = { Owner = "Kiran N", RollNo = "10446" }
}

resource "aws_db_instance" "postgres_replica" {
  identifier          = "kiran-db-replica"
  replicate_source_db = aws_db_instance.postgres.identifier
  instance_class      = "db.t4g.micro"
  publicly_accessible = false
  skip_final_snapshot = true
}
```

Cost warning: Multi-AZ and read replicas double/triple the instance cost - for practice use a single `db.t4g.micro` (free tier) and destroy it afterwards.
