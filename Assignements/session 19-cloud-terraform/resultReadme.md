# Session 19: Cloud and Terraform in Action

| | |
|---|---|
| **Name** | Kiran N |
| **Roll No.** | 10446 |
| **Session** | 19: Cloud and Terraform in Action (end-to-end project on AWS) |
| **Repository** | [Kirann1973/devops-heros](https://github.com/Kirann1973/devops-heros), branch `assignment` |
| **My project** | [`09-terraform-end-to-end/`](09-terraform-end-to-end/): VPC + subnet + IGW + route table + security group + EC2 + S3 |
| **Architecture** | [`09-terraform-end-to-end/architecture.svg`](09-terraform-end-to-end/architecture.svg) |
| **Lab script** | [`session19_lab.sh`](session19_lab.sh), run on my Ubuntu VM (Multipass, arm64) |
| **AWS** | Account `780603796984`, IAM user `kiran-terraform`, region `ap-south-1` (Mumbai) |
| **Tools** | Terraform v1.13.4, AWS provider v6.66.0, AWS CLI v2.38.1 |

Everything below ran against my real AWS account on 18 Oct 2026. The infrastructure was created, checked with the AWS CLI, the AWS console and a browser, and then destroyed. All screenshots are in [`screenshots/`](screenshots/).

---

## Homework task

> Build an end-to-end Terraform project that demonstrates **providers, variables, resources, outputs, dependencies, AWS infrastructure, state, plan, apply and destroy**. Suggested architecture: VPC, subnet, security group, EC2, S3. Deliverables: Terraform project, AWS resources, architecture diagram, screenshots, Terraform commands, README.md.

| Deliverable | Where |
|---|---|
| Terraform project | [`09-terraform-end-to-end/`](09-terraform-end-to-end/) |
| Provider | [`versions.tf`](09-terraform-end-to-end/versions.tf): `hashicorp/aws ~> 6.0`, region from a variable, `default_tags` with my name and roll number |
| Variables | [`variables.tf`](09-terraform-end-to-end/variables.tf) (9 inputs with validation) + [`terraform.tfvars`](09-terraform-end-to-end/terraform.tfvars) |
| Resources | [`main.tf`](09-terraform-end-to-end/main.tf): 14 resources + 2 data sources, boot script [`user_data.sh.tftpl`](09-terraform-end-to-end/user_data.sh.tftpl) |
| Outputs | [`outputs.tf`](09-terraform-end-to-end/outputs.tf): 11 outputs |
| Dependencies | [Section below](#dependencies) and [Step 5](#step-5-apply) |
| AWS resources | [Steps 7 and 8](#step-7-proof-with-the-aws-cli) |
| Architecture diagram | [Below](#architecture) |
| State | [Step 6](#step-6-output-state-list-state-show) |
| Plan / apply / destroy | [Steps 4, 5 and 10](#step-4-plan) |
| Terraform commands | [How to run it again](#how-to-run-it-again) |
| Project README | [09-terraform-end-to-end/README.md](09-terraform-end-to-end/README.md) |
| Class examples 01-08 | Restored in this folder and checked in [Step 2](#step-2-class-examples-06-07-08) |

---

## Architecture

![Architecture diagram](09-terraform-end-to-end/architecture.svg)

| # | Terraform address | AWS resource |
|---|---|---|
| 1 | `aws_vpc.main` | VPC `kiran-s19-vpc`, 10.19.0.0/16 |
| 2 | `aws_subnet.public` | Subnet `kiran-s19-public-subnet`, 10.19.1.0/24 in ap-south-1a, public IP on launch |
| 3 | `aws_internet_gateway.main` | Internet gateway `kiran-s19-igw` |
| 4 | `aws_route_table.public` | Route table `kiran-s19-public-rt` with `0.0.0.0/0 -> IGW` |
| 5 | `aws_route_table_association.public` | Subnet attached to the route table (this makes it public) |
| 6 | `aws_security_group.web` | Security group `kiran-s19-web-sg` |
| 7 | `aws_vpc_security_group_ingress_rule.http` | Inbound TCP 80 from anywhere (no SSH port at all) |
| 8 | `aws_vpc_security_group_egress_rule.all` | Outbound all |
| 9 | `aws_instance.web` | EC2 `kiran-s19-web`: t3.micro, Amazon Linux 2023, IMDSv2 required, encrypted gp3, nginx from user_data |
| 10-13 | `aws_s3_bucket.reports` + versioning + encryption + public access block | Bucket `kiran-n-10446-s19-<random>`, private, versioned, AES-256 |
| 14 | `aws_s3_object.infra_report` | `reports/infrastructure.json`, written by Terraform with the IDs of everything above |

Data sources: `aws_availability_zones` (no hard-coded AZ) and `aws_ami.al2023` (latest Amazon Linux 2023, no hard-coded AMI ID).

### Dependencies

- **Implicit:** a resource that uses another resource's attribute waits for it. `aws_subnet.public` uses `aws_vpc.main.id`, the route table uses `aws_internet_gateway.main.id`, the instance uses the subnet and security group IDs, and the S3 report uses the instance's IDs and IPs.
- **Explicit (`depends_on`):**
  - The instance waits for `aws_route_table_association.public`, so the internet route exists before first boot, when `dnf install nginx` runs.
  - The S3 report waits for the bucket's encryption config.
- The order is visible in the apply output in [Step 5](#step-5-apply): VPC first, then subnet, IGW and SG, then the route table, the association, the instance, and finally the report.

---

## Step 1: Tools and AWS identity

Terraform and AWS CLI come from Session 18. I'm logged in as the IAM user `kiran-terraform`, not root, with only the EC2 and S3 permissions this project needs.

![setup](screenshots/s19-vm-01-setup.png)

## Step 2: Class examples 06, 07, 08

The class folders were restored and run through `init`, `fmt` and `validate`. All three are valid. `08-mini-project/main.tf` has one extra space in the class code (`gateway_id  =`), so `fmt -check` reports it; I left the class file as it was.

![class examples](screenshots/s19-vm-02-class-examples.png)

## Step 3: init, fmt, validate, variable validation

`init` reuses AWS provider 6.66.0 from the shared cache, pinned by `.terraform.lock.hcl`. A bad CIDR (`10.19.0.0/99`) is rejected by my `validation` block before anything is sent to AWS.

![init fmt validate](screenshots/s19-vm-03-init-validate.png)

## Step 4: plan

**Plan: 14 to add, 0 to change, 0 to destroy.** The data sources found the AZ and the latest AL2023 AMI. Below the summary is the VPC in detail, with `tags_all` showing the default tags from the provider.

![plan](screenshots/s19-vm-04-plan.png)

## Step 5: apply

Applying the saved plan created the resources in dependency order. **Apply complete! Resources: 14 added.**

![apply](screenshots/s19-vm-05-apply.png)

## Step 6: output, state list, state show

`terraform state list` shows 2 data sources + 14 resources. `state show` shows the real instance (private IP 10.19.1.87, public IP 13.232.111.174). The state file is local JSON and is git-ignored.

![output and state](screenshots/s19-vm-06-output-state.png)

## Step 7: Proof with the AWS CLI

**Network:**
- VPC 10.19.0.0/16 is available.
- The subnet is in ap-south-1a with PublicIpOnLaunch = True.
- The IGW is attached.
- The route table has `0.0.0.0/0 -> igw` and `10.19.0.0/16 -> local`.
- The security group allows only TCP 80 in, and everything out.

![network](screenshots/s19-vm-07-verify-network.png)

**EC2 and website:** the instance is running. `curl` gets **HTTP/1.1 200 OK** from nginx, with the page built by my user_data script.

![ec2 and website](screenshots/s19-vm-08-verify-ec2-web.png)

**S3:** the bucket has versioning Enabled and AES256 encryption. It holds `reports/infrastructure.json`, written by Terraform with the VPC, subnet, SG and instance details.

![s3](screenshots/s19-vm-09-verify-s3.png)

## Step 8: Proof in the AWS console and browser

| | |
|---|---|
| VPC resource map: VPC, subnet, route table, internet gateway | ![vpc resource map](screenshots/s19-aws-01-vpc-resource-map.png) |
| Public subnet, auto-assign public IPv4 = Yes | ![subnet](screenshots/s19-aws-02-subnet.png) |
| Route table: 0.0.0.0/0 to the IGW | ![route table](screenshots/s19-aws-03-route-table.png) |
| Internet gateway attached, with my tags | ![igw](screenshots/s19-aws-04-internet-gateway.png) |
| Security group: only HTTP 80 inbound | ![security group](screenshots/s19-aws-05-security-group.png) |
| EC2: AL2023 AMI, IMDSv2 Required, my subnet | ![ec2 details](screenshots/s19-aws-06-ec2-details.png) |
| EC2 tags: Owner = Kiran N, RollNo = 10446 | ![ec2 tags](screenshots/s19-aws-07-ec2-tags.png) |
| **The website in my browser** | ![website](screenshots/s19-aws-08-website-browser.png) |
| S3: `reports/infrastructure.json` | ![s3 objects](screenshots/s19-aws-09-s3-objects.png) |
| S3: versioning Enabled, tags, SSE-S3 encryption | ![s3 properties](screenshots/s19-aws-10-s3-properties.png) |

## Step 9: Drift check and a change

- **Drift check:** `terraform plan -detailed-exitcode` returns **exit code 0**. AWS matches the code, and nothing was changed outside Terraform.
- **A change:** a plan with `-var='environment=test'` shows two kinds of change:
  - The tag change is **in place** on 9 resources.
  - The new value is also inside the EC2 user_data. With `user_data_replace_on_change = true`, the instance **must be replaced**.
  - Result: **1 to add, 9 to change, 1 to destroy.** It was only planned, not applied.

![drift and change](screenshots/s19-vm-10-drift-change.png)

## Step 10: destroy

Output of `bash session19_lab.sh 6` (`outputs/s19-11-destroy.txt`):

```text
########## terraform plan -destroy, destroy, prove it is gone ##########
$ tf plan -destroy -input=false -no-color | grep -E '^Plan:'
Plan: 0 to add, 0 to change, 14 to destroy.

$ tf destroy -auto-approve -input=false | grep -E 'Destruction complete|Destroy complete'
aws_s3_object.infra_report: Destruction complete after 0s
aws_vpc_security_group_egress_rule.all: Destruction complete after 0s
aws_vpc_security_group_ingress_rule.http["0.0.0.0/0"]: Destruction complete after 0s
aws_s3_bucket_public_access_block.reports: Destruction complete after 0s
aws_s3_bucket_server_side_encryption_configuration.reports: Destruction complete after 1s
aws_s3_bucket_versioning.reports: Destruction complete after 1s
aws_s3_bucket.reports: Destruction complete after 0s
aws_instance.web: Destruction complete after 20s
aws_route_table_association.public: Destruction complete after 0s
aws_security_group.web: Destruction complete after 1s
aws_subnet.public: Destruction complete after 1s
aws_route_table.public: Destruction complete after 1s
aws_internet_gateway.main: Destruction complete after 1s
aws_vpc.main: Destruction complete after 0s
Destroy complete! Resources: 14 destroyed.

$ tf state list | wc -l
0

$ aws ec2 describe-instances --instance-ids i-0dc559bd2eac3f4ef --query 'Reservations[].Instances[].State.Name' --output text
terminated

$ (the VPC and the bucket no longer exist, so AWS answers with a NotFound error)
$ aws ec2 describe-vpcs --vpc-ids vpc-071a65d834e886163 2>&1 | grep -v '^$'; true
aws: [ERROR]: An error occurred (InvalidVpcID.NotFound) when calling the DescribeVpcs operation: The vpc ID 'vpc-071a65d834e886163' does not exist

$ aws s3api head-bucket --bucket kiran-n-10446-s19-7f54ccab589cf011503cbb7254 2>&1 | grep -v '^$'; true
aws: [ERROR]: An error occurred (404) when calling the HeadBucket operation: Not Found
```

Destroy runs in **reverse dependency order**: the report and rules go first, and the VPC goes last.

| | |
|---|---|
| EC2 instance `kiran-s19-web`: Terminated | ![ec2 terminated](screenshots/s19-aws-11-ec2-terminated.png) |
| `kiran-s19-vpc` is gone; only the account's default VPC (no name) is left | ![vpc gone](screenshots/s19-aws-12-vpc-gone.png) |

---

## Problems I hit and how I fixed them

| Problem | Cause | Fix |
|---|---|---|
| The class files in my `session 19-cloud-terraform` folder were all 0 bytes | They were committed empty earlier | Restored them from the class folder `session19-cloud-terraform/` (same file names) |
| The IAM user can't create IAM roles or read SSM parameters | `kiran-terraform` only has EC2 and S3 permissions | No instance role is needed. The AMI is found with the `aws_ami` data source instead of an SSM parameter |
| An S3 bucket name may already be taken worldwide | Bucket names are global | `bucket_prefix = "kiran-n-10446-s19-"`, so AWS adds a unique suffix |
| nginx install could fail if the instance boots before its internet route exists | The association isn't referenced by the instance, so Terraform could create them in parallel | `depends_on = [aws_route_table_association.public]` on the instance |
| `terraform.tfvars` and `.terraform.lock.hcl` would not be committed | The class `.gitignore` ignores `*.tfvars` and the lock file | Mine has no secrets, so [`09-terraform-end-to-end/.gitignore`](09-terraform-end-to-end/.gitignore) adds `!terraform.tfvars` and `!.terraform.lock.hcl` |
| Each folder would download its own ~800 MB provider (the VM disk filled up in Session 18) | One `.terraform/` per folder | Shared plugin cache (`TF_PLUGIN_CACHE_DIR`) and the same pinned lock file in every folder |

## Key learnings

1. **Provider + variables + resources + outputs** are separate files with one job each. Changing `terraform.tfvars` or `-var` changes the infrastructure without touching `main.tf`.
2. **Dependencies:** Terraform builds a graph from references. `depends_on` is only for hidden order, like the route that must exist before the server boots.
3. **A public subnet** is just a subnet whose route table sends `0.0.0.0/0` to an internet gateway. Without the association, the instance has no internet.
4. **Security groups** are allow-lists. Opening only port 80 and no SSH keeps the server small to attack; it is configured fully by user_data instead.
5. **State** is how Terraform knows what it created. `plan -detailed-exitcode` (0 = no drift) proves AWS still matches the code.
6. **Some changes replace instead of update.** Tags change in place, but a new user_data replaces the EC2 instance. The plan says this before anything happens.
7. **destroy** removes everything in reverse order, so nothing keeps costing money.

## How to run it again

```bash
multipass shell ubuntu
export PATH=$HOME/.local/bin:$PATH
cd ~/devops-heros/Assignements/"session 19-cloud-terraform"
bash session19_lab.sh 1 2 3 4 5    # tools, class examples, init -> plan -> apply, verify, drift + change plan
bash session19_lab.sh 6            # plan -destroy, destroy, prove it is gone

# or by hand
cd 09-terraform-end-to-end
terraform init && terraform fmt -check && terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
terraform state list
curl "$(terraform output -raw website_url)"
terraform plan -detailed-exitcode
terraform destroy
```
