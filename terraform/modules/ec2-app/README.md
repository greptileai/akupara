# EC2 Application Module

Provisions a single EC2 instance plus its security group for running the Greptile Docker stack. It is provider-agnostic (requires an AWS provider to be set in the calling root module) and exposes inputs for networking, AMI selection, instance sizing, and ingress controls.

## Inputs
- `vpc_id` – Target VPC for the security group
- `subnet_id` – Subnet where the instance launches
- `ami_id`, `instance_type`, `key_name` – Compute configuration
- `iam_instance_profile` – Optional instance profile ARN/name
- `name_prefix` – Used for tagging/naming resources
- `associate_public_ip` – Toggle public IP
- `ingress_rules` – List of ingress definitions (protocol/ports/CIDRs)

## Outputs
- `instance_id`
- `public_ip`
- `security_group_id`

## Example
```hcl
module "ec2_app" {
  source               = "../../modules/ec2-app"
  vpc_id               = var.vpc_id
  subnet_id            = var.ec2_subnet_id
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  name_prefix          = "greptile"
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  ingress_rules = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["203.0.113.0/24"]
    }
  ]
}
```
