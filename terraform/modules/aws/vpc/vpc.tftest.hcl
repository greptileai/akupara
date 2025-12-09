mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c"]
    }
  }
}

variables {
  name_prefix = "test"
}

run "vpc_dns_settings" {
  command = plan

  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "VPC should have DNS support enabled"
  }

  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "VPC should have DNS hostnames enabled"
  }
}

run "default_five_slots_create_twenty_deployment_subnets" {
  command = plan

  # 5 slots * 4 subnets each = 20 deployment subnets
  assert {
    condition     = length(aws_subnet.deployment) == 20
    error_message = "Should create 20 deployment subnets (5 slots * 4 subnets each)"
  }
}

run "default_four_shared_subnets" {
  command = plan

  # Default shared_subnets has 4 entries
  assert {
    condition     = length(aws_subnet.shared) == 4
    error_message = "Should create 4 shared subnets by default"
  }
}

run "nat_gateway_enabled_by_default" {
  command = plan

  # 2 NAT gateways (one per AZ)
  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Should create 2 NAT gateways when enable_nat_gateway is true (default)"
  }

  # 2 EIPs for NAT gateways
  assert {
    condition     = length(aws_eip.nat) == 2
    error_message = "Should create 2 EIPs for NAT gateways"
  }
}

run "nat_gateway_disabled" {
  command = plan

  variables {
    name_prefix        = "test"
    enable_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "Should create no NAT gateways when enable_nat_gateway is false"
  }

  assert {
    condition     = length(aws_eip.nat) == 0
    error_message = "Should create no EIPs when enable_nat_gateway is false"
  }
}

run "public_route_tables_created_per_az" {
  command = plan

  # 2 public route tables (one per AZ)
  assert {
    condition     = length(aws_route_table.public) == 2
    error_message = "Should create 2 public route tables (one per AZ)"
  }
}

run "internet_gateway_created" {
  command = plan

  assert {
    condition     = aws_internet_gateway.this != null
    error_message = "Internet gateway should be created"
  }
}

run "custom_cidr_block" {
  command = plan

  variables {
    name_prefix = "test"
    cidr_block  = "172.16.0.0/16"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "172.16.0.0/16"
    error_message = "Custom CIDR block should be used"
  }
}

run "single_slot_creates_four_subnets" {
  command = plan

  variables {
    name_prefix = "test"
    subnet_sets = [
      {
        name           = "single"
        public_a_cidr  = "10.0.0.0/24"
        public_b_cidr  = "10.0.1.0/24"
        private_a_cidr = "10.0.10.0/24"
        private_b_cidr = "10.0.11.0/24"
      }
    ]
  }

  assert {
    condition     = length(aws_subnet.deployment) == 4
    error_message = "Single slot should create 4 deployment subnets"
  }
}

run "explicit_azs_used" {
  command = plan

  variables {
    name_prefix = "test"
    azs         = ["us-west-2a", "us-west-2b"]
    subnet_sets = [
      {
        name           = "slot1"
        public_a_cidr  = "10.0.0.0/24"
        public_b_cidr  = "10.0.1.0/24"
        private_a_cidr = "10.0.10.0/24"
        private_b_cidr = "10.0.11.0/24"
      }
    ]
  }

  assert {
    condition     = aws_subnet.deployment["slot1-public-a"].availability_zone == "us-west-2a"
    error_message = "Should use explicitly provided AZs"
  }

  assert {
    condition     = aws_subnet.deployment["slot1-public-b"].availability_zone == "us-west-2b"
    error_message = "Should use explicitly provided AZs"
  }
}

run "vpc_name_uses_prefix" {
  command = plan

  variables {
    name_prefix = "myprefix"
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "myprefix-vpc"
    error_message = "VPC name should use the name_prefix"
  }
}

run "base_tags_applied" {
  command = plan

  variables {
    name_prefix = "test"
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = aws_vpc.this.tags["Component"] == "shared-network"
    error_message = "VPC should have Component=shared-network tag"
  }

  assert {
    condition     = aws_vpc.this.tags["Module"] == "vpc"
    error_message = "VPC should have Module=vpc tag"
  }

  assert {
    condition     = aws_vpc.this.tags["Environment"] == "test"
    error_message = "Custom tags should be merged"
  }
}

