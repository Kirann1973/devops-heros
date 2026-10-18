# AWS IAM - Identity and Access Management

**Name:** Kiran N | **Roll No:** 10446 | **Session 18 - Terraform IaC, Task 2**

IAM decides **who** can do **what** on **which** AWS resource. It is a global service (not tied to a region) and it is free.

Every API call to AWS (console click, `aws` CLI command, `terraform apply`) is checked like this:

```text
  Who is calling?            What do they want?          On which resource?
  (user / role)        +     (action, e.g. s3:PutObject)  + (arn:aws:s3:::my-bucket/*)
          |
          v
  IAM evaluates every policy attached to the caller
          |
          +--> any explicit "Deny"  ------------------> DENIED
          +--> at least one "Allow" (and no Deny) ----> ALLOWED
          +--> nothing matches ------------------------> DENIED (implicit deny is the default)
```

---

## 1. Users

An **IAM user** is a permanent identity for one person or one application.

| Credential | Used for |
|---|---|
| Console password (+ MFA) | Signing in to the AWS web console |
| Access key ID + secret access key | AWS CLI, SDKs, Terraform |

- A new user has **no permissions** until a policy is attached.
- The **root user** (the email that opened the account) can do everything and cannot be limited. Use it only for account-level tasks, protect it with MFA, and never create access keys for it.

```bash
aws iam create-user --user-name kiran-terraform
aws iam create-access-key --user-name kiran-terraform      # shown once, store it safely
aws configure                                               # paste the keys here, never in .tf files
aws sts get-caller-identity                                 # "who am I" check
```

## 2. Groups

A **group** is a collection of users. Policies attached to the group apply to every member, so permissions are managed once per team instead of once per person.

```text
Group: developers  --(policy: ReadOnlyAccess + S3 write on dev bucket)
   |-- kiran
   |-- ravi
Group: admins      --(policy: AdministratorAccess)
   |-- lead
```

- A user can be in up to 10 groups. Groups cannot contain other groups.
- Moving a person between teams = change group membership, no policy edits.

## 3. Roles

A **role** is an identity with permissions but **no long-term password or keys**. Someone or something *assumes* the role and receives **temporary credentials** (STS, valid 15 min - 12 h).

Every role has two policies:

| Policy | Answers |
|---|---|
| **Trust policy** | *Who* is allowed to assume the role (EC2 service, Lambda, another AWS account, GitHub Actions OIDC, ...) |
| **Permissions policy** | *What* the role can do once assumed |

Typical roles:

- **EC2 instance profile** - an app on EC2 reads S3 without any keys on the server.
- **Lambda execution role** - the function writes logs to CloudWatch.
- **Cross-account role** - a user in account A works in account B.
- **OIDC role for CI/CD** - GitHub Actions deploys with short-lived credentials instead of stored secrets.

## 4. Policies

A **policy** is a JSON document of permission statements.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadWriteOneBucket",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::kiran-n-10446-session18-demo/*"
    },
    {
      "Sid": "ListThatBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::kiran-n-10446-session18-demo"
    }
  ]
}
```

| Element | Meaning |
|---|---|
| `Effect` | `Allow` or `Deny` |
| `Action` | API operations, `service:Operation` (wildcards allowed: `s3:Get*`) |
| `Resource` | ARN(s) the statement applies to |
| `Condition` | Optional extra checks: source IP, MFA present, tag values, time, ... |
| `Principal` | Only in resource-based / trust policies: *who* the statement is about |

Types of policies:

| Type | Attached to | Example |
|---|---|---|
| AWS managed | user / group / role | `ReadOnlyAccess`, `AmazonS3FullAccess` (maintained by AWS) |
| Customer managed | user / group / role | Your own reusable JSON policy (versioned) |
| Inline | exactly one identity | Deleted together with that identity |
| Resource-based | the resource itself | S3 bucket policy, SQS queue policy, KMS key policy |
| Permissions boundary | user / role | Maximum permissions an identity can ever get |
| SCP (Organizations) | AWS account / OU | Guardrail for whole accounts |

## 5. Permissions - how they are evaluated

1. By default everything is **denied** (implicit deny).
2. An `Allow` in any applicable policy grants the action.
3. An explicit `Deny` anywhere **always wins** over any Allow.
4. Boundaries and SCPs can only *limit*, never grant.

Tools to check permissions:

```bash
aws iam list-attached-user-policies --user-name kiran-terraform
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:user/kiran-terraform \
  --action-names s3:DeleteBucket
```

The console also has **IAM Access Analyzer** (finds resources shared outside the account and generates least-privilege policies from CloudTrail activity).

## 6. Least privilege

Give each identity **only** the actions and resources it needs, nothing more.

| Too broad | Least privilege |
|---|---|
| `"Action": "*"`, `"Resource": "*"` | `s3:GetObject` on `arn:aws:s3:::app-bucket/*` |
| `AmazonS3FullAccess` for an app that only reads | Read-only on one bucket |
| One admin key shared by the team | One user per person, admin via role + MFA |
| Permanent access keys in CI | OIDC role with temporary credentials |

Start small, watch for `AccessDenied`, and add the specific permission, instead of starting with `*` and planning to tighten later.

## 7. Best practices

- Lock away the root user: MFA on, no access keys, used only for billing/account tasks.
- Enable **MFA** for every human user.
- Prefer **IAM Identity Center (SSO)** and **roles** over long-lived users and keys.
- Manage permissions through **groups**, not per user.
- Use **roles** for workloads (EC2, Lambda, ECS, CI/CD), never keys on servers or in code.
- Never commit keys to Git (Session 17's Gitleaks scan catches this); rotate keys regularly and delete unused ones.
- Use **conditions** (`aws:MultiFactorAuthPresent`, `aws:SourceIp`, tags) for sensitive actions.
- Review regularly: IAM **credential report**, **last accessed** data, Access Analyzer.
- Turn on **CloudTrail** so every API call is logged with who made it.
- Strong password policy for console users.

## 8. Use cases

| Scenario | IAM solution |
|---|---|
| New developer joins | Create user, add to `developers` group, enforce MFA |
| App on EC2 reads S3 | EC2 role (instance profile) with read on one bucket |
| Terraform on my laptop | IAM user with keys in `~/.aws/credentials` (or SSO profile) |
| GitHub Actions deploys to AWS | OIDC identity provider + role trusted for one repo/branch |
| Auditor needs a look | `ReadOnlyAccess` / `SecurityAudit` via a role with an expiry |
| Partner company uploads files | Cross-account role or bucket policy on one prefix |

## 9. The same thing in Terraform

```hcl
resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_user" "kiran" {
  name = "kiran-n-10446"
  tags = { Owner = "Kiran N", RollNo = "10446" }
}

resource "aws_iam_user_group_membership" "kiran" {
  user   = aws_iam_user.kiran.name
  groups = [aws_iam_group.developers.name]
}

# Least-privilege policy: read/write only one bucket
resource "aws_iam_policy" "demo_bucket_rw" {
  name = "demo-bucket-read-write"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "arn:aws:s3:::kiran-n-10446-session18-demo/*" },
      { Effect = "Allow", Action = "s3:ListBucket", Resource = "arn:aws:s3:::kiran-n-10446-session18-demo" }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "developers_bucket" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.demo_bucket_rw.arn
}

# Role that EC2 instances can assume (trust policy) + read-only S3 (permissions policy)
resource "aws_iam_role" "ec2_s3_read" {
  name = "ec2-s3-read"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_read" {
  role       = aws_iam_role.ec2_s3_read.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_s3_read" {
  name = "ec2-s3-read"
  role = aws_iam_role.ec2_s3_read.name
}
```
