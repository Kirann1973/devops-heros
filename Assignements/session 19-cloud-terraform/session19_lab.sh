#!/bin/bash
# Session 19 - Cloud & Terraform in Action: VPC + subnet + IGW + route table + security group + EC2 + S3 on real AWS
# Kiran N | Roll No: 10446
# Run from inside the "session 19-cloud-terraform" folder. Each part is saved to its own file in outputs/.
# Uses the same tools and AWS login as Session 18 (Terraform + AWS CLI in ~/.local/bin, "aws configure" done).
#   bash session19_lab.sh 1 2 3 4 5  -> check tools, class examples, create everything, verify, change demo
#   (take the AWS console + browser screenshots now)
#   bash session19_lab.sh 6          -> destroy everything and prove it is gone

OUTDIR="$PWD/outputs"
PROJ="$PWD/09-terraform-end-to-end"
WORK="$HOME/terraform-kiran"       # same scratch folder as Session 18: the AWS provider is already in the cache there
mkdir -p "$OUTDIR" "$WORK/plugin-cache"
export PATH="$HOME/.local/bin:$PATH"
export TF_PLUGIN_CACHE_DIR="$WORK/plugin-cache"
export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE=true
export TF_IN_AUTOMATION=1 CHECKPOINT_DISABLE=1
set -o pipefail
section() { OUT="$OUTDIR/$1.txt"; : > "$OUT"; echo "########## $2 ##########" | tee -a "$OUT"; }
run() { echo "\$ $*" | tee -a "$OUT"; eval "$@" 2>&1 | tee -a "$OUT"; echo | tee -a "$OUT"; }
note() { echo "\$ ($*)" | tee -a "$OUT"; }
say() { echo "$*" | tee -a "$OUT"; }
tf() { (cd "$PROJ" && terraform "$@"); }

# AWS rejects signed requests when the clock is more than 5 minutes off, and this VM's clock drifts
fix_clock() {
  local web diff
  web=$(curl -sI https://sts.amazonaws.com 2>/dev/null | tr -d '\r' | sed -n 's/^[Dd]ate: //p')
  [ -z "$web" ] && return
  diff=$(( $(date -u -d "$web" +%s) - $(date -u +%s) ))
  if [ "${diff#-}" -gt 60 ]; then
    echo "VM clock is ${diff}s off, setting it to $web"
    sudo date -u -s "$web" >/dev/null && sudo timedatectl set-ntp true 2>/dev/null
  fi
}

# ---------------------------------------------------------------- 1. Tools + AWS access
part1() {
section s19-01-setup "Tools, AWS identity, free disk space"
if ! command -v terraform >/dev/null || ! command -v aws >/dev/null; then
  say "Terraform or AWS CLI missing: run  bash '../session 18-terraform-iac/session18_lab.sh' 1  first"
fi
run "terraform version | head -1; aws --version"
run "aws sts get-caller-identity"
run "aws configure get region"
run "df -h / | tail -1"
}

# ---------------------------------------------------------------- 2. Class examples 06-08
part2() {
section s19-02-examples "Class examples 06, 07, 08: init, fmt, validate"
for d in 06-terraform-vpc 07-terraform-workflow 08-mini-project; do
  say "---- $d"
  # same pinned provider version as my project, so nothing new is downloaded
  [ -f "$d/.terraform.lock.hcl" ] || cp "$PROJ/.terraform.lock.hcl" "$d/"
  ( cd "$d" && { terraform init -input=false -no-color > "$WORK/init.log" 2>&1 && echo "init: OK" || { echo "init failed:"; grep -v '^$' "$WORK/init.log" | tail -6; }; }
    terraform fmt -check >/dev/null && echo "fmt: OK" || echo "fmt: needs formatting ($(terraform fmt -check | tr '\n' ' '))"
    terraform validate -no-color ) 2>&1 | tee -a "$OUT"
done
echo | tee -a "$OUT"
}

# ---------------------------------------------------------------- 3. My project: init -> apply
part3() {
section s19-03-init-validate "09-terraform-end-to-end: files, init, fmt, validate"
run "cd '$PROJ' && ls -1A"
run "cat '$PROJ/terraform.tfvars'"
run "tf init -input=false"
run "tf fmt -check -recursive && echo 'fmt: all files already formatted'"
run "tf validate"
note 'variable validation: a bad value is rejected before anything reaches AWS'
run "tf plan -input=false -var='vpc_cidr=10.19.0.0/99' -no-color 2>&1 | grep -A3 'Invalid value' | head -6"

section s19-04-plan "terraform plan"
note 'full plan is long (14 resources), so only the data sources, resource list and summary are shown'
run "tf plan -input=false -no-color -out=tfplan | grep -E 'Read complete|# .* will be|^Plan:|Saved the plan'"
note 'one resource from the saved plan in detail'
run "tf show -no-color tfplan | sed -n '/# aws_vpc.main will be created/,/^    }/p'"

section s19-05-apply "terraform apply (resources are created in dependency order)"
run "tf apply -input=false tfplan | grep -vE 'Still creating'"

section s19-06-output-state "terraform output, state list, state show"
run "tf output"
run "tf state list"
run "tf state show aws_instance.web | grep -E '^# |^    (ami|arn|availability_zone|instance_state|instance_type|private_ip|public_ip|subnet_id|vpc_security_group_ids)|^        \"sg-'"
note 'the state file is local JSON with real IDs; it is git-ignored'
run "ls -l '$PROJ/terraform.tfstate' && grep -m3 -E '\"(version|terraform_version|serial)\"' '$PROJ/terraform.tfstate'"
}

# ---------------------------------------------------------------- 4. Verify on AWS
part4() {
section s19-07-verify-network "AWS CLI: VPC, subnet, route table, internet gateway, security group"
VPC=$(tf output -raw vpc_id)
run "aws ec2 describe-vpcs --vpc-ids $VPC --query 'Vpcs[].{VpcId:VpcId,Cidr:CidrBlock,State:State,Name:Tags[?Key==\`Name\`]|[0].Value}' --output table"
run "aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC --query 'Subnets[].{SubnetId:SubnetId,Cidr:CidrBlock,AZ:AvailabilityZone,PublicIpOnLaunch:MapPublicIpOnLaunch}' --output table"
run "aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$VPC --query 'InternetGateways[].{IGW:InternetGatewayId,State:Attachments[0].State}' --output table"
run "aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC Name=tag:ManagedBy,Values=Terraform --query 'RouteTables[].Routes[].{Destination:DestinationCidrBlock,Target:GatewayId,State:State}' --output table"
run "aws ec2 describe-security-group-rules --filters Name=group-id,Values=$(tf output -raw security_group_id) --query 'SecurityGroupRules[].{Egress:IsEgress,Protocol:IpProtocol,From:FromPort,To:ToPort,Cidr:CidrIpv4}' --output table"

section s19-08-verify-ec2-web "AWS CLI: EC2 instance, then the website it serves"
ID=$(tf output -raw instance_id); URL=$(tf output -raw website_url)
run "aws ec2 describe-instances --instance-ids $ID --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,State:State.Name,AZ:Placement.AvailabilityZone,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress}' --output table"
note "waiting for nginx on $URL (first boot installs it, up to 4 minutes)"
for i in $(seq 1 24); do curl -s -m 5 -o /dev/null "$URL" && break; sleep 10; done
run "curl -s -m 10 -I $URL | head -3"
run "curl -s -m 10 $URL | sed -e 's/<[^>]*>/ /g' -e 's/  */ /g' | grep -v '^ *\$' | grep -vE '^ *(body|td|code)\\{'"

section s19-09-verify-s3 "AWS CLI: S3 bucket and the report Terraform wrote into it"
B=$(tf output -raw s3_bucket_name)
run "aws s3 ls | grep kiran-n-10446-s19"
run "aws s3api get-bucket-versioning --bucket $B"
run "aws s3api get-bucket-encryption --bucket $B --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault'"
run "aws s3 ls s3://$B --recursive"
run "aws s3 cp $(tf output -raw s3_report_uri) - | python3 -m json.tool"
say "Now take the AWS console screenshots and open $URL in your browser."
}

# ---------------------------------------------------------------- 5. Change + drift demo
part5() {
section s19-10-change "Drift check, then what a change would do (plan only)"
note 'nothing changed outside Terraform, so the plan is empty'
run "tf plan -input=false -detailed-exitcode | tail -3; echo \"exit code \$? (0 = no changes)\""
note 'environment=test changes the tags (in-place) and the web page in user_data (EC2 must be replaced)'
run "tf plan -input=false -no-color -var='environment=test' | grep -E 'will be updated|must be replaced|forces replacement|^Plan:'"
}

# ---------------------------------------------------------------- 6. Destroy
part6() {
section s19-11-destroy "terraform plan -destroy, destroy, prove it is gone"
VPC=$(tf output -raw vpc_id 2>/dev/null); ID=$(tf output -raw instance_id 2>/dev/null); B=$(tf output -raw s3_bucket_name 2>/dev/null)
run "tf plan -destroy -input=false -no-color | grep -E '^Plan:'"
run "tf destroy -auto-approve -input=false | grep -E 'Destruction complete|Destroy complete'"
run "tf state list | wc -l"
[ -n "$ID" ] && run "aws ec2 describe-instances --instance-ids $ID --query 'Reservations[].Instances[].State.Name' --output text"
note 'the VPC and the bucket no longer exist, so AWS answers with a NotFound error'
[ -n "$VPC" ] && run "aws ec2 describe-vpcs --vpc-ids $VPC 2>&1 | grep -v '^$'; true"
[ -n "$B" ] && run "aws s3api head-bucket --bucket $B 2>&1 | grep -v '^$'; true"
rm -f "$PROJ/tfplan"
}

fix_clock
PARTS="${*:-1}"
for p in $PARTS; do "part$p"; done
echo "Done. Outputs are in outputs/"
