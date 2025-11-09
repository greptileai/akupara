# AWS EC2 Stack Consumption Guide

Use this example when you want to pull Greptile’s EC2-based on‑prem stack into your existing Terraform codebase without copying the entire Akupara repository.

Workflow:
1. Keep your own `terraform` block, backend settings, and AWS provider (we recommend an S3 backend with keys following `tf/org/<team>/<stack>.tfstate`).
2. Reference the published stack through Git (pin to a tag such as `?ref=v0.1.0` for production).
3. Provide the required VPC/subnet IDs, AMI, SSH key, database settings, and a Redis auth token via variables or tfvars.
4. Consume the outputs (`ec2_public_ip`, `rds_endpoint`, `redis_endpoint`, etc.) to feed subsequent deployment phases (Helm, CI, secrets tooling).

This example is ready to copy into your repo—adjust the `source` `ref` to match the version you’ve validated internally.
