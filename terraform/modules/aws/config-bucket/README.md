# Config Bucket Module

Provision a locked-down S3 bucket (and optional KMS key) for storing Greptile bootstrap secrets such as `/opt/greptile/.env`. Operator teams can run this module ahead of the `terraform/stacks/aws-ec2` stack, upload the rendered `.env`, and then point the stack’s `secrets_bucket`/`secrets_object_key` inputs at the outputs from this module.

## Features
- Creates an S3 bucket with bucket ownership controls, public access blocks, versioning, and default server-side encryption.
- Optionally creates a dedicated CMK with automatic rotation, or you can supply an existing `kms_key_arn`.
- Forces TLS-only access by keeping the bucket private (no ACLs) and exposes outputs for easy plumbing into other stacks.

## Example
```hcl
module "greptile_config_bucket" {
  source = "https://github.com/greptileai/akupara//terraform/modules/aws/config-bucket?ref=main"

  bucket_name             = "acme-greptile-config-prod"
  create_kms_key          = true
  kms_alias_name          = "alias/acme-greptile-config"
  force_destroy           = false
  tags = {
    Environment = "prod"
    Stack       = "greptile"
  }
}

output "secrets_bucket" {
  value = module.greptile_config_bucket.bucket_name
}

output "secrets_kms_key_arn" {
  value = module.greptile_config_bucket.kms_key_arn
}
```

After applying the module:
1. Copy `terraform/stacks/aws-ec2/files/bootstrap/.env.aws.example` and fill in real values.
2. Upload it with `aws s3 cp .env s3://$(terraform output -raw secrets_bucket)/envs/prod/.env`.
3. Pass `secrets_bucket`, `secrets_object_key`, and `secrets_kms_key_arn` to the `aws-ec2` stack.
