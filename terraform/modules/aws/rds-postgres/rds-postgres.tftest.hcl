mock_provider "aws" {}

variables {
  vpc_id      = "vpc-12345678"
  subnet_ids  = ["subnet-12345678", "subnet-87654321"]
  db_password = "testpassword123"
}

run "storage_encrypted_by_default" {
  command = plan

  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "Storage encryption should be enabled by default"
  }
}

run "skip_final_snapshot_false_by_default" {
  command = plan

  assert {
    condition     = aws_db_instance.this.skip_final_snapshot == false
    error_message = "skip_final_snapshot should be false by default"
  }
}

run "port_is_5432" {
  command = plan

  assert {
    condition     = aws_db_instance.this.port == 5432
    error_message = "PostgreSQL port should be 5432"
  }
}

run "engine_is_postgres" {
  command = plan

  assert {
    condition     = aws_db_instance.this.engine == "postgres"
    error_message = "Engine should be postgres"
  }
}

run "iops_set_for_io1_storage" {
  command = plan

  variables {
    vpc_id       = "vpc-12345678"
    subnet_ids   = ["subnet-12345678", "subnet-87654321"]
    db_password  = "testpassword123"
    storage_type = "io1"
    iops         = 5000
  }

  assert {
    condition     = aws_db_instance.this.iops == 5000
    error_message = "IOPS should be set when storage_type is io1"
  }
}

run "security_group_name_uses_prefix" {
  command = plan

  assert {
    condition     = aws_security_group.this.name == "greptile-rds-sg"
    error_message = "Security group name should use default name_prefix"
  }
}

run "security_group_created" {
  command = plan

  assert {
    condition     = aws_security_group.this != null
    error_message = "Security group should be created"
  }
}

run "subnet_group_name_uses_prefix" {
  command = plan

  assert {
    condition     = aws_db_subnet_group.this.name == "greptile-rds-subnet-group"
    error_message = "Subnet group name should use default name_prefix"
  }
}

run "final_snapshot_identifier_auto_generated" {
  command = plan

  variables {
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678", "subnet-87654321"]
    db_password         = "testpassword123"
    skip_final_snapshot = false
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "greptile-postgres-db-final"
    error_message = "Final snapshot identifier should be auto-generated from db_identifier"
  }
}

run "final_snapshot_identifier_null_when_skipped" {
  command = plan

  variables {
    vpc_id              = "vpc-12345678"
    subnet_ids          = ["subnet-12345678", "subnet-87654321"]
    db_password         = "testpassword123"
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == null
    error_message = "Final snapshot identifier should be null when skip_final_snapshot is true"
  }
}

run "custom_final_snapshot_identifier" {
  command = plan

  variables {
    vpc_id                    = "vpc-12345678"
    subnet_ids                = ["subnet-12345678", "subnet-87654321"]
    db_password               = "testpassword123"
    skip_final_snapshot       = false
    final_snapshot_identifier = "my-custom-snapshot"
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "my-custom-snapshot"
    error_message = "Custom final snapshot identifier should be used when provided"
  }
}

run "custom_name_prefix" {
  command = plan

  variables {
    vpc_id      = "vpc-12345678"
    subnet_ids  = ["subnet-12345678", "subnet-87654321"]
    db_password = "testpassword123"
    name_prefix = "myapp"
  }

  assert {
    condition     = aws_security_group.this.name == "myapp-rds-sg"
    error_message = "Security group name should use custom name_prefix"
  }

  assert {
    condition     = aws_db_subnet_group.this.name == "myapp-rds-subnet-group"
    error_message = "Subnet group name should use custom name_prefix"
  }
}

run "fails_with_invalid_db_name" {
  command = plan

  variables {
    vpc_id      = "vpc-12345678"
    subnet_ids  = ["subnet-12345678", "subnet-87654321"]
    db_password = "testpassword123"
    db_name     = "123invalid"
  }

  expect_failures = [var.db_name]
}
