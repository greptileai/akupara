# AWS EC2 On-Prem Stack

Root module that deploys the Greptile Docker-based experience on a single EC2 instance plus managed RDS and Redis.

## Layout
- Composes reusable modules from `../../modules`
- Keeps providers/backends confined to this stack
- Exposes standard outputs consumed by helm/helmfile stages

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
