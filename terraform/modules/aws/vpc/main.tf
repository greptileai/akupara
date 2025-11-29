data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_candidates = length(var.azs) > 0 ? var.azs : data.aws_availability_zones.available.names
  azs           = slice(local.az_candidates, 0, 2)

  base_tags = merge({
    Component = "shared-network"
    Module    = "vpc"
  }, var.tags)

  deployment_public_subnets = merge([
    for slot in var.subnet_sets : {
      "${slot.name}-public-a" = {
        slot   = slot.name
        role   = "public"
        letter = "a"
        az     = local.azs[0]
        cidr   = slot.public_a_cidr
      }
      "${slot.name}-public-b" = {
        slot   = slot.name
        role   = "public"
        letter = "b"
        az     = local.azs[1]
        cidr   = slot.public_b_cidr
      }
    }
  ]...)

  deployment_private_subnets = merge([
    for slot in var.subnet_sets : {
      "${slot.name}-private-a" = {
        slot   = slot.name
        role   = "private"
        letter = "a"
        az     = local.azs[0]
        cidr   = slot.private_a_cidr
      }
      "${slot.name}-private-b" = {
        slot   = slot.name
        role   = "private"
        letter = "b"
        az     = local.azs[1]
        cidr   = slot.private_b_cidr
      }
    }
  ]...)

  deployment_subnets = merge(local.deployment_public_subnets, local.deployment_private_subnets)

  shared_subnet_configs = {
    for name, cfg in var.shared_subnets :
    name => {
      group = "shared"
      role  = lower(cfg.type)
      cidr  = cfg.cidr
      az    = local.azs[cfg.az_index]
    }
  }

  shared_public_subnets = {
    for k, v in local.shared_subnet_configs :
    k => v
    if v.role == "public"
  }

  shared_private_subnets = {
    for k, v in local.shared_subnet_configs :
    k => v
    if v.role == "private"
  }

  slot_names = [for slot in var.subnet_sets : slot.name]
  first_slot = try(local.slot_names[0], null)

  shared_public_names_by_az = {
    for az in local.azs :
    az => [
      for name, cfg in local.shared_public_subnets :
      name if cfg.az == az
    ]
  }

  fallback_public_subnet_key = {
    for idx, az in local.azs :
    az => "${local.first_slot}-public-${idx == 0 ? "a" : "b"}"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-vpc"
  })

  lifecycle {
    precondition {
      condition     = length(local.azs) == 2
      error_message = "modules/vpc currently requires exactly two AZs. Pass two AZs explicitly or ensure the region exposes at least two."
    }

    precondition {
      condition     = local.first_slot != null
      error_message = "At least one entry in var.subnet_sets is required."
    }
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "deployment" {
  for_each = local.deployment_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.role == "public"

  tags = merge(local.base_tags, {
    Name        = "${var.name_prefix}-${each.value.slot}-${each.value.role}-${each.value.letter}"
    Slot        = each.value.slot
    Role        = each.value.role
    SubnetGroup = "deployment"
  })
}

resource "aws_subnet" "shared" {
  for_each = local.shared_subnet_configs

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.role == "public"

  tags = merge(local.base_tags, {
    Name        = "${var.name_prefix}-shared-${each.key}"
    Role        = each.value.role
    SubnetGroup = "shared"
  })
}

resource "aws_route_table" "public" {
  for_each = { for az in local.azs : az => az }

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-public-rt-${each.key}"
  })
}

resource "aws_route_table_association" "public_deployment" {
  for_each = local.deployment_public_subnets

  subnet_id      = aws_subnet.deployment[each.key].id
  route_table_id = aws_route_table.public[each.value.az].id
}

resource "aws_route_table_association" "public_shared" {
  for_each = local.shared_public_subnets

  subnet_id      = aws_subnet.shared[each.key].id
  route_table_id = aws_route_table.public[each.value.az].id
}

resource "aws_eip" "nat" {
  for_each = var.enable_nat_gateway ? { for az in local.azs : az => az } : {}

  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = var.enable_nat_gateway ? { for az in local.azs : az => az } : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id = coalesce(
    try(aws_subnet.shared[try(local.shared_public_names_by_az[each.key][0], "")].id, null),
    aws_subnet.deployment[local.fallback_public_subnet_key[each.key]].id
  )

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })
}

resource "aws_route_table" "private" {
  for_each = local.deployment_private_subnets

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [each.value.az] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[route.value].id
    }
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-${each.value.slot}-${each.value.role}-${each.value.letter}-rt"
    Slot = each.value.slot
    Role = each.value.role
  })
}

resource "aws_route_table_association" "private_deployment" {
  for_each = local.deployment_private_subnets

  subnet_id      = aws_subnet.deployment[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "shared_private" {
  for_each = local.shared_private_subnets

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [each.value.az] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[route.value].id
    }
  }

  tags = merge(local.base_tags, {
    Name = "${var.name_prefix}-shared-${each.key}-rt"
    Role = each.value.role
  })
}

resource "aws_route_table_association" "shared_private" {
  for_each = local.shared_private_subnets

  subnet_id      = aws_subnet.shared[each.key].id
  route_table_id = aws_route_table.shared_private[each.key].id
}
