# AWS EC2 On-Prem Stack

Root module that deploys the Greptile Docker-based experience on a single EC2 instance plus managed RDS and Redis.

## Layout
- Composes reusable modules from `../../modules`
- Keeps providers/backends confined to this stack
- Exposes standard outputs consumed by helm/helmfile stages

## Bootstrap workflow
When `enable_greptile_bootstrap = true` (default) the stack renders a cloud-init script that installs Docker/Compose, writes the production compose bundle to `/opt/greptile`, and enables a systemd unit that runs `docker compose up -d` on every boot. The script also:
- pulls `/opt/greptile/.env` from S3 using `secrets_bucket` + `secrets_object_key`
- runs `aws ecr get-login-password | docker login …` using the `CONTAINER_REGISTRY` value in `.env`
- executes `docker compose pull` once so every image is present before the unit starts

Make sure the `.env` you upload contains the image registry (e.g. `123456789012.dkr.ecr.us-east-1.amazonaws.com/greptile`), Redis auth token, RDS credentials, and any SaaS secrets the stack expects.

### Preparing secrets in S3
1. Create (or reuse) an encrypted bucket that your EC2 instance profile can read. The helper module at `terraform/modules/aws/config-bucket` provisions a hardened bucket + optional KMS key if you do not already have one.
2. Render `.env` from `.env.aws.example`, fill in customer-specific values, and upload it: `aws s3 cp .env s3://<bucket>/<key>`.
3. Set `secrets_bucket` and `secrets_object_key` (plus `secrets_kms_key_arn` if the object is KMS-encrypted) either via `terraform.tfvars` or CLI flags.
4. Terraform grants `s3:GetObject` + `kms:Decrypt` automatically; no manual IAM edits are required.

### ECR access
Terraform now attaches the `ecr:GetAuthorizationToken`/`BatchGetImage` policy directly to the EC2 role. Greptile’s production ECR still enforces an account allowlist, so coordinate with the Greptile infra team to keep your AWS account ID on that list before running `terraform apply`.

## Usage
### Backend conventions
S3 bucket names are globally unique, so each customer must supply their own state bucket and (optionally) DynamoDB lock table. We standardize only the object key: `tf/org/<team>/<stack>.tfstate`. Populate the placeholders in `backend.conf.example` to follow this structure:

```bash
cd terraform/stacks/aws-ec2
cp backend.conf.example backend.conf # fill in bucket/region/profile/table
terraform init -backend-config=backend.conf
terraform apply -var-file="terraform.tfvars"
```

Refer to `terraform.tfvars.example` for required variables.
