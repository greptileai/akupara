locals {
  slot_output_map = {
    for slot in var.subnet_sets :
    slot.name => {
      public = {
        a = {
          id   = aws_subnet.deployment["${slot.name}-public-a"].id
          cidr = slot.public_a_cidr
          az   = local.azs[0]
        }
        b = {
          id   = aws_subnet.deployment["${slot.name}-public-b"].id
          cidr = slot.public_b_cidr
          az   = local.azs[1]
        }
      }
      private = {
        a = {
          id   = aws_subnet.deployment["${slot.name}-private-a"].id
          cidr = slot.private_a_cidr
          az   = local.azs[0]
        }
        b = {
          id   = aws_subnet.deployment["${slot.name}-private-b"].id
          cidr = slot.private_b_cidr
          az   = local.azs[1]
        }
      }
    }
  }

  shared_subnet_output = {
    for name, cfg in local.shared_subnet_configs :
    name => {
      id   = aws_subnet.shared[name].id
      cidr = cfg.cidr
      az   = cfg.az
      role = cfg.role
    }
  }
}

output "vpc_id" {
  description = "ID of the shared VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block allocated to the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_sets" {
  description = "Map of deployment slots to their public subnet metadata."
  value       = { for slot_name, slot in local.slot_output_map : slot_name => slot.public }
}

output "private_subnet_sets" {
  description = "Map of deployment slots to their private subnet metadata."
  value       = { for slot_name, slot in local.slot_output_map : slot_name => slot.private }
}

output "shared_subnets" {
  description = "Shared (non-slot) subnet metadata keyed by logical name."
  value       = local.shared_subnet_output
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by AZ (empty when NAT is disabled)."
  value       = var.enable_nat_gateway ? { for az, _ in aws_nat_gateway.this : az => aws_nat_gateway.this[az].id } : {}
}

output "public_route_table_ids" {
  description = "Public route table IDs keyed by AZ."
  value       = { for az, _ in aws_route_table.public : az => aws_route_table.public[az].id }
}
