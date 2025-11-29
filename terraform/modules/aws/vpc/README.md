# Shared VPC Module

This module builds a multi-slot VPC that multiple Akupara stacks can share concurrently. Each deployment slot consists of four subnets (public/private across two AZs) so you can shift traffic between stacks without redeploying the VPC. Extra shared subnets are reserved for cross-cutting services (ALBs/NLBs, interface endpoints, appliances).

## Features
- Creates a `/16` (default) VPC with DNS support, IGW, and tagging conventions.
- Five deployment slots by default, each with `public_a`, `public_b`, `private_a`, `private_b` `/24` subnets.
- Shared public/private subnets for load balancers, VPC endpoints, etc.
- Per-AZ public route tables and per-slot private route tables, pre-wired for NAT egress.
- Optional NAT gateway per AZ (on by default) with automatic fallback to the first slot’s public subnet if shared public subnets are removed.

## Inputs
| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Naming prefix for every resource. | string | n/a (required) |
| `cidr_block` | VPC CIDR range. | string | `10.0.0.0/16` |
| `azs` | Ordered list of two AZs to use. Empty = first two available AZs in the region. | list(string) | `[]` |
| `subnet_sets` | Deployment slots (four CIDRs each). Must define at least one slot. | list(object) | see defaults |
| `shared_subnets` | Additional shared subnets keyed by name with `{type, cidr, az_index}`. | map(object) | see defaults |
| `enable_nat_gateway` | When true, create one NAT gateway per AZ and wire private routes through it. | bool | `true` |
| `tags` | Extra tags merged onto every resource. | map(string) | `{}` |

> **AZ assumption**: The current implementation only provisions two AZs (A/B). Pass exactly two AZs if your region has more.

## Outputs
- `vpc_id`, `vpc_cidr_block`
- `public_subnet_sets` and `private_subnet_sets`: maps keyed by slot name; each entry has `a`/`b` structs with `id`, `cidr`, `az`.
- `shared_subnets`: metadata for the shared subnet pool.
- `nat_gateway_ids`: NAT IDs keyed by AZ (empty when disabled).
- `public_route_table_ids`: route tables per AZ.

## Usage
Create the shared VPC once in its own root module / backend:

```hcl
module "shared_vpc" {
  source      = "https://github.com/greptileai/akupara//terraform/modules/aws/vpc?ref=TAG"
  name_prefix = "greptile-fabric"
  azs         = ["us-west-2a", "us-west-2b"]
}
```

Store the state remotely (S3 backend recommended). Other stacks must **not** redeclare the VPC; instead, read its outputs via `terraform_remote_state`:

```hcl
data "terraform_remote_state" "shared_vpc" {
  backend = "s3"
  config = {
    bucket = "tf/org/networking"
    key    = "prod/shared-vpc.tfstate"
    region = "us-west-2"
  }
}

module "aws_ec2_stack" {
  source             = "https://github.com/greptileai/akupara//terraform/stacks/aws-ec2?ref=TAG"
  vpc_id             = data.terraform_remote_state.shared_vpc.outputs.vpc_id
  private_subnet_ids = [
    data.terraform_remote_state.shared_vpc.outputs.private_subnet_sets["slot1"].a.id,
    data.terraform_remote_state.shared_vpc.outputs.private_subnet_sets["slot1"].b.id,
  ]
  ec2_subnet_id      = data.terraform_remote_state.shared_vpc.outputs.public_subnet_sets["slot1"].a.id
}
```
