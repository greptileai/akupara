# AWS EC2 On-Prem Stack

Root module that deploys the Greptile Docker-based experience on a single EC2 instance plus managed RDS and Redis.

## Layout
- Composes reusable modules from `../../modules`
- Keeps providers/backends confined to this stack
- Exposes standard outputs consumed by helm/helmfile stages

## Usage
```bash
cd terraform/stacks/aws-ec2
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=customers/acme/aws-ec2.tfstate" \
  -backend-config="region=us-east-1"
terraform apply -var-file="terraform.tfvars"
```

Refer to `terraform.tfvars.example` for required variables.
