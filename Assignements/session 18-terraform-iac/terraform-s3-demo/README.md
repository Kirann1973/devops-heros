# Terraform S3 Bucket Demo

**Name:** Kiran N | **Roll No:** 10446 | **Session 18 - Terraform IaC, Task 1**

This project creates a **private, encrypted, versioned S3 bucket** in `ap-south-1` with one file inside, using only Terraform. Every resource is tagged with my name and roll number.

## Project structure

```text
terraform-s3-demo/
|-- terraform.tf          # required Terraform version + AWS provider version (~> 6.0)
|-- provider.tf           # AWS provider: region + default tags (Owner, RollNo, Project, ManagedBy)
|-- variables.tf          # inputs with types, defaults and validation rules
|-- terraform.tfvars      # my values for the inputs (no secrets)
|-- main.tf               # the 5 resources
|-- outputs.tf            # values printed after apply
|-- .terraform.lock.hcl   # exact provider version + checksums (committed)
|-- .gitignore            # keeps .terraform/, *.tfstate and plan files out of Git
|-- README.md
```

## What gets created

| Terraform address | AWS resource | Why |
|---|---|---|
| `aws_s3_bucket.kiran_demo` | The bucket `kiran-n-10446-session18-demo` | Bucket names are global, so mine includes my name and roll number |
| `aws_s3_bucket_versioning.kiran_demo` | Versioning = Enabled | Overwrites and deletes can be undone |
| `aws_s3_bucket_server_side_encryption_configuration.kiran_demo` | Default encryption SSE-S3 (AES-256) | Data encrypted at rest |
| `aws_s3_bucket_public_access_block.kiran_demo` | All 4 "Block public access" switches on | Bucket can never become public by mistake |
| `aws_s3_object.hello` | `hello.txt` | Shows an object uploaded by Terraform |

## How the files work together

```text
terraform.tf ------> which provider to download (hashicorp/aws ~> 6.0)
      |
provider.tf -------> region = var.aws_region, default_tags on every resource
      |
variables.tf <------ terraform.tfvars (my values)   <-- can be overridden: -var='bucket_name=...'
      |
main.tf -----------> bucket --> versioning / encryption / public access block --> hello.txt
      |                                (Terraform works out this order from the references)
outputs.tf --------> bucket_name, bucket_arn, bucket_region, versioning_status, object_uri
      |
terraform.tfstate -> what Terraform created (local, never committed)
```

## Prerequisites

1. Terraform >= 1.6 and AWS CLI v2. On my VM `bash ../session18_lab.sh 1` installs both.
2. AWS credentials of an IAM user (not root):

```bash
aws configure                  # access key, secret key, region ap-south-1, output json
aws sts get-caller-identity    # check who I am
```

Credentials stay in `~/.aws/credentials`. They are never written in `.tf` or `.tfvars` files.

## Terraform workflow

```bash
cd terraform-s3-demo

terraform init                  # downloads the AWS provider into .terraform/ (version from the lock file)
terraform fmt                   # formats the code (fmt -check only reports)
terraform validate              # syntax + types + references, no AWS calls
terraform plan -out=tfplan      # shows "Plan: 5 to add, 0 to change, 0 to destroy" and saves it
terraform apply tfplan          # creates exactly what the saved plan shows
terraform output                # prints the outputs
terraform show                  # everything in the state, human readable
terraform state list            # the 5 resource addresses
terraform state show aws_s3_bucket.kiran_demo
terraform plan                  # run again: "No changes" = AWS matches the code (no drift)
terraform plan -destroy         # preview the delete
terraform destroy               # deletes all 5 resources (force_destroy empties the bucket first)
```

Expected outputs after `apply`:

```text
bucket_arn = "arn:aws:s3:::kiran-n-10446-session18-demo"
bucket_name = "kiran-n-10446-session18-demo"
bucket_region = "ap-south-1"
object_uri = "s3://kiran-n-10446-session18-demo/hello.txt"
versioning_status = "Enabled"
```

## Check the bucket with the AWS CLI

```bash
aws s3 ls | grep kiran-n-10446
aws s3api get-bucket-versioning --bucket kiran-n-10446-session18-demo
aws s3api get-bucket-encryption --bucket kiran-n-10446-session18-demo
aws s3api get-public-access-block --bucket kiran-n-10446-session18-demo
aws s3api get-bucket-tagging --bucket kiran-n-10446-session18-demo
aws s3 cp s3://kiran-n-10446-session18-demo/hello.txt -
```

## Notes

- **Bucket name taken?** S3 names are unique across all AWS accounts. Use another name without editing files: `terraform plan -var='bucket_name=kiran-n-10446-s18-xyz' -out=tfplan`. The lab script does this automatically by adding my account ID.
- **Variable validation:** `bucket_name` must match S3's naming rules and `environment` must be dev/test/prod, so mistakes fail at `plan` instead of at AWS.
- **outputs.tf:** `output` blocks accept `description`, `value`, `sensitive` and `depends_on`. A `type` argument (as in the class template) makes `terraform init` fail with *"An argument named "type" is not expected here"*.
- **State:** `terraform.tfstate` holds IDs and attributes of real resources. It is git-ignored. In a team it would go in a remote S3 backend with locking.
- **Cost:** S3 storage of one small file is within the free tier. Run `terraform destroy` after the demo anyway.

All commands with my real outputs and screenshots are in [`../resultReadme.md`](../resultReadme.md).
