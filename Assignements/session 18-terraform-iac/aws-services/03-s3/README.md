# Amazon S3 - Simple Storage Service

**Name:** Kiran N | **Roll No:** 10446 | **Session 18 - Terraform IaC, Task 2**

S3 is **object storage**: you store files (objects) of any type in containers (buckets), and read them over HTTPS with an API. Storage is practically unlimited, designed for **99.999999999% (11 nines) durability**, and you pay for GB stored + requests + data out.

My Terraform project in [`../../terraform-s3-demo`](../../terraform-s3-demo) creates a real bucket with the settings explained below (versioning, encryption, public access block, one object).

```text
  Bucket: kiran-n-10446-session18-demo   (region ap-south-1)
  |
  |-- hello.txt                     <- object  (key = "hello.txt")
  |-- images/logo.png               <- object  (key = "images/logo.png", "images/" is only a prefix)
  |-- backups/2026-10-18.tar.gz     <- object
  |
  Settings: versioning | encryption | bucket policy | lifecycle rules | tags | public access block
```

---

## 1. Buckets

A **bucket** is the top-level container.

- The name is **globally unique** across all AWS accounts, 3-63 characters, lowercase letters, numbers, dots and hyphens (that is why my bucket name contains my name and roll number).
- Created in **one region**; data stays there unless you replicate it.
- Up to 10,000 buckets per account by default; no limit on objects inside.
- A bucket must be empty before it can be deleted (Terraform's `force_destroy = true` empties it first).

```bash
aws s3 mb s3://kiran-n-10446-session18-demo --region ap-south-1
aws s3 ls
aws s3 rb s3://kiran-n-10446-session18-demo --force
```

## 2. Objects

An **object** = the data + a **key** (its full name) + metadata.

| Part | Example |
|---|---|
| Key | `images/2026/logo.png` (S3 is flat; `/` only looks like folders - "prefixes") |
| Value | The file bytes, 0 B up to **5 TB** (use multipart upload above 100 MB) |
| Metadata | `Content-Type: image/png`, custom `x-amz-meta-*` headers |
| Version ID | Present when versioning is on |
| Tags | Up to 10 key=value pairs, usable in policies and lifecycle rules |

```bash
aws s3 cp hello.txt s3://kiran-n-10446-session18-demo/
aws s3 ls s3://kiran-n-10446-session18-demo/ --recursive
aws s3 sync ./site s3://kiran-n-10446-session18-demo/site/
aws s3 presign s3://kiran-n-10446-session18-demo/hello.txt --expires-in 300   # temporary share link
```

S3 has **strong read-after-write consistency**: after a successful upload, every read returns the new data.

## 3. Storage classes

| Class | For data that is... | Retrieval | Notes |
|---|---|---|---|
| **S3 Standard** | Accessed often | Milliseconds | Default, ≥3 AZs |
| **S3 Intelligent-Tiering** | Access pattern unknown | Milliseconds | Moves objects between tiers automatically |
| **S3 Standard-IA** | Infrequently accessed | Milliseconds | Cheaper storage, retrieval fee, 30-day minimum |
| **S3 One Zone-IA** | Infrequent + re-creatable | Milliseconds | One AZ only |
| **S3 Express One Zone** | Latency-critical, very hot | Single-digit ms | Directory buckets, one AZ |
| **S3 Glacier Instant Retrieval** | Archive read ~once a quarter | Milliseconds | 90-day minimum |
| **S3 Glacier Flexible Retrieval** | Archive | Minutes - hours | 90-day minimum |
| **S3 Glacier Deep Archive** | Long-term compliance archive | Up to 12-48 h | Cheapest, 180-day minimum |

```bash
aws s3 cp report.pdf s3://kiran-n-10446-session18-demo/ --storage-class STANDARD_IA
```

## 4. Versioning

With versioning **Enabled**, every overwrite creates a new version and a delete only adds a **delete marker**. Old versions can be restored.

```text
hello.txt  v3 (current)   <- aws s3 cp new file
hello.txt  v2
hello.txt  v1
"delete" hello.txt  -> delete marker on top, v1-v3 still there -> remove the marker to restore
```

- States: *Unversioned* (default) -> *Enabled* -> *Suspended* (cannot go back to unversioned).
- Protects against accidental delete/overwrite and ransomware; needed for **replication**.
- Every version is billed, so combine it with lifecycle rules that expire old versions.
- **MFA Delete** and **Object Lock** (WORM, compliance) add stronger protection.

```bash
aws s3api get-bucket-versioning --bucket kiran-n-10446-session18-demo
aws s3api list-object-versions --bucket kiran-n-10446-session18-demo --prefix hello.txt
```

## 5. Lifecycle rules

**Lifecycle rules** move or delete objects automatically based on age, prefix or tags - the main way to control S3 cost.

```text
logs/ prefix:   day 0 Standard --> day 30 Standard-IA --> day 90 Glacier Flexible --> day 365 delete
old versions:   delete non-current versions after 30 days
uploads:        abort incomplete multipart uploads after 7 days
```

## 6. Encryption

| Where | Option |
|---|---|
| **At rest (server-side)** | **SSE-S3** (AES-256, keys managed by S3 - default for all new objects since 2023) |
| | **SSE-KMS** (keys in AWS KMS: key policies, rotation, CloudTrail audit of every use) |
| | **DSSE-KMS** (two layers of KMS encryption) |
| | **SSE-C** (you send your own key with every request) |
| **At rest (client-side)** | Encrypt before uploading; AWS never sees plaintext |
| **In transit** | HTTPS/TLS; force it with a bucket policy denying `aws:SecureTransport = false` |

My demo sets the bucket's default encryption to SSE-S3 (`AES256`), and `terraform state show aws_s3_object.hello` shows `server_side_encryption = "AES256"`.

## 7. Bucket policies and access control

Access to S3 is decided by:

1. **IAM policies** on the user/role (identity side - see [01-iam](../01-iam)).
2. **Bucket policy** - a JSON resource policy on the bucket, can grant access to other accounts, services or (careful!) everyone.
3. **Block Public Access** - 4 switches at bucket/account level that override any public policy or ACL. On by default; my demo turns all four on explicitly.
4. ACLs - legacy; disabled by default ("Bucket owner enforced").

Example bucket policy - force HTTPS and allow one role to read:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": ["arn:aws:s3:::kiran-n-10446-session18-demo", "arn:aws:s3:::kiran-n-10446-session18-demo/*"],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    },
    {
      "Sid": "AppRoleRead",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::123456789012:role/ec2-s3-read" },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::kiran-n-10446-session18-demo/*"
    }
  ]
}
```

Other features: **pre-signed URLs** (time-limited access to one object), **CORS**, **access points**, **replication** (CRR/SRR), **event notifications** (trigger Lambda/SQS on upload), **static website hosting** (usually with CloudFront in front).

## 8. Use cases

| Use case | How S3 is used |
|---|---|
| **Terraform remote state** | State file in a versioned, encrypted bucket (+ lock) - see below |
| Backups and disaster recovery | EBS/RDS snapshots, database dumps, cross-region replication |
| Static website / frontend | HTML/JS/CSS in a bucket + CloudFront CDN |
| CI/CD artifacts | Build outputs, Helm charts, deployment packages |
| Logs | ALB, CloudTrail, VPC Flow Logs delivered to S3 |
| Data lake / analytics | Raw data queried with Athena, Glue, EMR |
| Media storage | User uploads, images, videos |
| Long-term archive | Glacier Deep Archive for compliance data |

Terraform remote state in S3 (shared, versioned, locked):

```hcl
terraform {
  backend "s3" {
    bucket       = "kiran-n-10446-tfstate"
    key          = "session18/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # S3-native state locking (Terraform 1.10+)
  }
}
```

## 9. The same thing in Terraform

Full working code: [`../../terraform-s3-demo/main.tf`](../../terraform-s3-demo/main.tf). Lifecycle rule example that is not in the demo:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.kiran_demo.id

  rule {
    id     = "logs-tiering"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "cleanup"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```
