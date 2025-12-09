mock_provider "aws" {}

variables {
  vpc_id     = "vpc-12345678"
  subnet_ids = ["subnet-12345678", "subnet-87654321"]
  auth_token = "testtoken12345678"
}

run "transit_encryption_enabled_by_default" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.transit_encryption_enabled == true
    error_message = "Transit encryption should be enabled by default"
  }
}

run "auth_token_set_when_transit_encryption_enabled" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.auth_token != null
    error_message = "Auth token should be set when transit encryption is enabled"
  }
}

run "auth_token_null_when_transit_encryption_disabled" {
  command = plan

  variables {
    vpc_id                     = "vpc-12345678"
    subnet_ids                 = ["subnet-12345678", "subnet-87654321"]
    transit_encryption_enabled = false
  }

  assert {
    condition     = aws_elasticache_replication_group.this.auth_token == null
    error_message = "Auth token should be null when transit encryption is disabled"
  }
}

run "replication_group_created" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this != null
    error_message = "Replication group should be created"
  }
}

run "maintenance_window_set" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.maintenance_window == "sun:05:00-sun:06:00"
    error_message = "Maintenance window should be sun:05:00-sun:06:00"
  }
}

run "apply_immediately_enabled" {
  command = plan

  assert {
    condition     = aws_elasticache_replication_group.this.apply_immediately == true
    error_message = "Apply immediately should be enabled"
  }
}

run "custom_replication_group_id" {
  command = plan

  variables {
    vpc_id               = "vpc-12345678"
    subnet_ids           = ["subnet-12345678", "subnet-87654321"]
    auth_token           = "testtoken12345678"
    replication_group_id = "myapp-redis"
  }

  assert {
    condition     = aws_elasticache_replication_group.this.replication_group_id == "myapp-redis"
    error_message = "Custom replication group ID should be used"
  }
}

run "security_group_name_uses_prefix" {
  command = plan

  assert {
    condition     = aws_security_group.this.name == "greptile-redis-sg"
    error_message = "Security group name should use default name_prefix"
  }
}

run "subnet_group_name_uses_prefix" {
  command = plan

  assert {
    condition     = aws_elasticache_subnet_group.this.name == "greptile-redis-subnet-group"
    error_message = "Subnet group name should use default name_prefix"
  }
}

run "custom_name_prefix" {
  command = plan

  variables {
    vpc_id      = "vpc-12345678"
    subnet_ids  = ["subnet-12345678", "subnet-87654321"]
    auth_token  = "testtoken12345678"
    name_prefix = "myapp"
  }

  assert {
    condition     = aws_security_group.this.name == "myapp-redis-sg"
    error_message = "Security group name should use custom name_prefix"
  }

  assert {
    condition     = aws_elasticache_subnet_group.this.name == "myapp-redis-subnet-group"
    error_message = "Subnet group name should use custom name_prefix"
  }
}

run "fails_without_auth_token_when_transit_encryption_enabled" {
  command = plan

  variables {
    vpc_id                     = "vpc-12345678"
    subnet_ids                 = ["subnet-12345678", "subnet-87654321"]
    transit_encryption_enabled = true
    auth_token                 = null
  }

  expect_failures = [var.auth_token]
}

run "fails_with_short_auth_token" {
  command = plan

  variables {
    vpc_id                     = "vpc-12345678"
    subnet_ids                 = ["subnet-12345678", "subnet-87654321"]
    transit_encryption_enabled = true
    auth_token                 = "short"
  }

  expect_failures = [var.auth_token]
}
