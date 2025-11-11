# AWS EC2 Stack Consumption Guide

Use this example when you want to pull Greptile’s EC2-based on-prem stack into your existing Terraform codebase without copying the entire Akupara repository.

Workflow:
1. Keep your own `terraform` block, backend settings, and AWS provider (we recommend an S3 backend with keys following `tf/org/<team>/<stack>.tfstate`).
2. Reference the published stack through Git (pin to a tag such as `?ref=v0.1.0` for production).
3. Populate the networking + compute inputs plus a secure Redis auth token in `terraform.tfvars`.
4. Prepare the bootstrap secrets:
   - Copy `terraform/stacks/aws-ec2/files/bootstrap/.env.aws.example`
   - Fill in customer-specific values (DB credentials, `CONTAINER_REGISTRY`, OAuth keys, etc.)
   - Upload it to an encrypted S3 bucket and set `secrets_bucket`/`secrets_object_key` (and `secrets_kms_key_arn` if applicable).
5. Ensure your AWS account is on the Greptile ECR allowlist, then apply.
6. Consume the outputs (`ec2_public_ip`, `rds_endpoint`, `redis_endpoint`, etc.) to feed subsequent deployment phases (Helm, CI, secrets tooling).

This example is ready to copy into your repo—adjust the `source` `ref` to match the version you’ve validated internally and keep the bootstrap variables in sync with your S3 secrets.
