#!/bin/bash
# Session 18 - Terraform IaC: install the tools, run the instructor examples, then my own S3 project on real AWS
# Kiran N | Roll No: 10446
# Run from inside the "session 18-terraform-iac" folder. Each part is saved to its own file in outputs/.
#   bash session18_lab.sh 1      -> install Terraform + AWS CLI, then run "aws configure" yourself
#   bash session18_lab.sh 2 3    -> instructor examples, then create my S3 bucket (screenshot the AWS console after this)
#   bash session18_lab.sh 4      -> destroy everything and prove it is gone

OUTDIR="$PWD/outputs"
DEMO="$PWD/terraform-s3-demo"
WORK="$HOME/terraform-kiran"       # scratch folder: downloads + shared provider cache (not part of the repo)
TF_VERSION=1.13.4
mkdir -p "$OUTDIR" "$WORK/plugin-cache" "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
export TF_PLUGIN_CACHE_DIR="$WORK/plugin-cache"                   # download the AWS provider once, not once per folder
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=true
export TF_IN_AUTOMATION=1 CHECKPOINT_DISABLE=1
set -o pipefail
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }

# AWS rejects signed requests when the clock is more than 5 minutes off, and this VM's clock drifts.
# Compare with the Date header of an AWS endpoint and correct it if needed.
fix_clock() {
  local web now diff
  web=$(curl -sI https://sts.amazonaws.com 2>/dev/null | tr -d '\r' | sed -n 's/^[Dd]ate: //p')
  [ -z "$web" ] && return
  now=$(date -u +%s); diff=$(( $(date -u -d "$web" +%s) - now ))
  if [ "${diff#-}" -gt 60 ]; then
    echo "VM clock is ${diff}s off, setting it to $web"
    sudo date -u -s "$web" >/dev/null && sudo timedatectl set-ntp true 2>/dev/null
  fi
}

# unzip that keeps the execute bit, using python (the VM has no unzip and apt is not needed)
pyunzip() {
  python3 - "$1" "$2" <<'EOF'
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    for info in z.infolist():
        path = z.extract(info, sys.argv[2])
        mode = (info.external_attr >> 16) & 0o777
        if mode:
            os.chmod(path, mode)
EOF
}

install_tools() {
  local arch aws_arch
  case "$(uname -m)" in
    aarch64|arm64) arch=arm64; aws_arch=aarch64 ;;
    *)             arch=amd64; aws_arch=x86_64 ;;
  esac
  if ! terraform version 2>/dev/null | grep -q "v$TF_VERSION"; then
    curl -fsSL -o "$WORK/terraform.zip" "https://releases.hashicorp.com/terraform/$TF_VERSION/terraform_${TF_VERSION}_linux_$arch.zip" || return 1
    rm -rf "$WORK/tf" && pyunzip "$WORK/terraform.zip" "$WORK/tf" || return 1
    mv -f "$WORK/tf/terraform" "$HOME/.local/bin/terraform" || return 1
  fi
  if ! command -v aws >/dev/null; then
    curl -fsSL -o "$WORK/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-$aws_arch.zip" || return 1
    rm -rf "$WORK/aws" && pyunzip "$WORK/awscliv2.zip" "$WORK" || return 1
    "$WORK/aws/install" -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin" --update || return 1
  fi
}

# the bucket name from terraform.tfvars, or name-<account id> if someone else in the world already owns that name
pick_bucket() {
  local name code
  name=$(sed -n 's/^bucket_name *= *"\(.*\)"/\1/p' "$DEMO/terraform.tfvars")
  code=$(aws s3api head-bucket --bucket "$name" 2>&1 | grep -o '(40[34])' | tr -d '()')
  if [ "$code" = 403 ]; then
    name="$name-$(aws sts get-caller-identity --query Account --output text)"
  fi
  echo "$name" > "$WORK/bucket"
}

# ---------------------------------------------------------------- 1. Tools + AWS access
part1() {
section s18-01-setup "Install Terraform and AWS CLI, check AWS access"
note "installing Terraform $TF_VERSION and AWS CLI v2 into ~/.local/bin"
install_tools > "$WORK/install.log" 2>&1 || { say "install failed, last lines of $WORK/install.log:"; tail -15 "$WORK/install.log" | tee -a "$OUT"; }
run "uname -m; date -u"
run "terraform version"
run "aws --version"
note 'who am I on AWS (needs "aws configure" with your access key first)'
run "aws sts get-caller-identity"
run "aws configure list"
}

# ---------------------------------------------------------------- 2. Instructor examples 01-09
part2() {
section s18-02-examples "Instructor examples: init, fmt, validate in every folder"
for d in 0*/; do
  d=${d%/}
  say "---- $d"
  # same pinned provider version as my demo (from its lock file), so the 800 MB provider is downloaded only once
  [ -f "$d/.terraform.lock.hcl" ] || cp "$DEMO/.terraform.lock.hcl" "$d/"
  ( cd "$d" && { terraform init -input=false -no-color > "$WORK/init.log" 2>&1 && echo "init: OK" || { echo "init failed:"; grep -v '^$' "$WORK/init.log" | tail -6; }; }
    terraform fmt -check >/dev/null && echo "fmt: OK" || echo "fmt: needs formatting"
    terraform validate -no-color ) 2>&1 | tee -a "$OUT"
done
echo | tee -a "$OUT"

section s18-03-variables-plan "05-variables: plan with default values, then with -var overrides"
run "cd 05-variables && terraform plan -input=false -no-color | sed -n '/Terraform will perform/,/^Plan:/p'"
run "cd 05-variables && terraform plan -input=false -no-color -var='project_name=kiran-10446' -var='environment=test' | grep -E 'bucket_prefix|Project|Environment|^Plan:'"

section s18-04-state "09-state: apply, read the state, destroy"
run "cd 09-state && terraform apply -auto-approve -input=false | tail -6"
run "cd 09-state && terraform state list"
run "cd 09-state && terraform state show aws_s3_bucket.state_demo | head -25"
run "cd 09-state && terraform output"
note 'state file is local JSON, never commit it (it is in .gitignore)'
run "cd 09-state && ls -l terraform.tfstate && grep -m3 -E '\"(version|terraform_version|serial)\"' terraform.tfstate"
run "cd 09-state && terraform destroy -auto-approve -input=false | tail -3"
run "cd 09-state && terraform state list | wc -l"
}

# ---------------------------------------------------------------- 3. My S3 project
part3() {
section s18-05-init-validate "terraform-s3-demo: init, fmt, validate"
pick_bucket
run "cd '$DEMO' && ls -1A"
run "cd '$DEMO' && cat terraform.tfvars"
note 'the provider comes from the shared cache and is checked against the hashes in .terraform.lock.hcl'
run "cd '$DEMO' && terraform init -input=false"
run "cd '$DEMO' && terraform fmt -check -recursive && echo 'fmt: all files already formatted'"
run "cd '$DEMO' && terraform validate"

section s18-06-plan "terraform-s3-demo: plan"
run "cd '$DEMO' && terraform plan -input=false -var='bucket_name=$(cat "$WORK/bucket")' -out=tfplan"
note 'summary of the saved plan file'
run "cd '$DEMO' && terraform show -no-color tfplan | grep -E '# .* will be|^Plan:'"

section s18-07-apply "terraform-s3-demo: apply"
run "cd '$DEMO' && terraform apply -input=false tfplan"
run "cd '$DEMO' && terraform output"
run "cd '$DEMO' && terraform output -raw bucket_name; echo"

section s18-08-state-show "terraform-s3-demo: show, state list and state show"
run "cd '$DEMO' && terraform show -no-color | grep -E '^# |^ +(bucket|key|status|sse_algorithm|block_public_acls|restrict_public_buckets|content_type) +='"
run "cd '$DEMO' && terraform state list"
run "cd '$DEMO' && terraform state show aws_s3_bucket.kiran_demo"
run "cd '$DEMO' && terraform state show aws_s3_object.hello | grep -E 'bucket |key |content_type|etag|server_side'"

section s18-09-aws-cli "Check the bucket with the AWS CLI"
B=$(cat "$WORK/bucket")
run "aws s3 ls | grep $B"
run "aws s3api get-bucket-location --bucket $B"
run "aws s3api get-bucket-versioning --bucket $B"
run "aws s3api get-bucket-encryption --bucket $B --query 'ServerSideEncryptionConfiguration.Rules[0]'"
run "aws s3api get-public-access-block --bucket $B"
run "aws s3api get-bucket-tagging --bucket $B --output table"
run "aws s3 ls s3://$B/"
run "aws s3 cp s3://$B/hello.txt -"
note 'drift check: nothing changed outside Terraform, so the plan is empty'
run "cd '$DEMO' && terraform plan -input=false -var='bucket_name=$B' -detailed-exitcode | tail -3; echo \"exit code \$? (0 = no changes)\""
say "Now open the AWS console > S3 > $B (region ap-south-1) and take screenshots, then run: bash session18_lab.sh 4"
}

# ---------------------------------------------------------------- 4. Destroy
part4() {
section s18-10-destroy "terraform-s3-demo: plan -destroy, destroy, prove it is gone"
B=$(cat "$WORK/bucket" 2>/dev/null || sed -n 's/^bucket_name *= *"\(.*\)"/\1/p' "$DEMO/terraform.tfvars")
run "cd '$DEMO' && terraform plan -destroy -input=false -no-color -var='bucket_name=$B' | grep -E 'will be destroyed|^Plan:'"
run "cd '$DEMO' && terraform destroy -auto-approve -input=false -var='bucket_name=$B' | grep -vE 'Still destroying|Refreshing state' | tail -9"
run "cd '$DEMO' && terraform state list | wc -l"
run "aws s3api head-bucket --bucket $B || echo 'bucket $B no longer exists'"
rm -f "$DEMO/tfplan"
}

fix_clock
PARTS="${*:-1}"
for p in $PARTS; do "part$p"; done
echo "Done. Outputs are in outputs/"
