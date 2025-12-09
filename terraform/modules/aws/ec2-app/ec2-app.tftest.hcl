mock_provider "aws" {}

variables {
  vpc_id    = "vpc-12345678"
  subnet_id = "subnet-12345678"
  ami_id    = "ami-12345678"
  key_name  = "test-key"
}

run "security_group_name_uses_prefix" {
  command = plan

  assert {
    condition     = aws_security_group.this.name == "greptile-ec2-sg"
    error_message = "Security group name should use default name_prefix 'greptile'"
  }
}

run "custom_name_prefix" {
  command = plan

  variables {
    vpc_id      = "vpc-12345678"
    subnet_id   = "subnet-12345678"
    ami_id      = "ami-12345678"
    key_name    = "test-key"
    name_prefix = "myapp"
  }

  assert {
    condition     = aws_security_group.this.name == "myapp-ec2-sg"
    error_message = "Security group name should use custom name_prefix"
  }

  assert {
    condition     = aws_instance.this.tags["Name"] == "myapp-ec2"
    error_message = "Instance name tag should use custom name_prefix"
  }
}

run "no_ingress_rules_by_default" {
  command = plan

  # Test that the local variable for ingress rules is empty by default
  assert {
    condition     = length(local.ingress_rules) == 0
    error_message = "Should have no ingress rules by default"
  }
}

run "ingress_rules_local_populated" {
  command = plan

  variables {
    vpc_id    = "vpc-12345678"
    subnet_id = "subnet-12345678"
    ami_id    = "ami-12345678"
    key_name  = "test-key"
    ingress_rules = [
      {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
      },
      {
        description = "HTTP"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }
    ]
  }

  assert {
    condition     = length(local.ingress_rules) == 2
    error_message = "Should have 2 ingress rules when 2 are provided"
  }
}

run "security_group_exists" {
  command = plan

  assert {
    condition     = aws_security_group.this != null
    error_message = "Security group should be created"
  }
}

run "custom_instance_type" {
  command = plan

  variables {
    vpc_id        = "vpc-12345678"
    subnet_id     = "subnet-12345678"
    ami_id        = "ami-12345678"
    key_name      = "test-key"
    instance_type = "t3.xlarge"
  }

  assert {
    condition     = aws_instance.this.instance_type == "t3.xlarge"
    error_message = "Custom instance type should be used"
  }
}

run "public_ip_disabled" {
  command = plan

  variables {
    vpc_id              = "vpc-12345678"
    subnet_id           = "subnet-12345678"
    ami_id              = "ami-12345678"
    key_name            = "test-key"
    associate_public_ip = false
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == false
    error_message = "Public IP can be disabled"
  }
}

run "user_data_replace_on_change" {
  command = plan

  assert {
    condition     = aws_instance.this.user_data_replace_on_change == true
    error_message = "user_data_replace_on_change should be true"
  }
}

run "tags_merged" {
  command = plan

  variables {
    vpc_id    = "vpc-12345678"
    subnet_id = "subnet-12345678"
    ami_id    = "ami-12345678"
    key_name  = "test-key"
    tags = {
      Environment = "test"
      Team        = "engineering"
    }
  }

  assert {
    condition     = aws_instance.this.tags["Environment"] == "test"
    error_message = "Custom tags should be merged"
  }

  assert {
    condition     = aws_instance.this.tags["Team"] == "engineering"
    error_message = "Multiple custom tags should be merged"
  }

  assert {
    condition     = aws_instance.this.tags["Name"] == "greptile-ec2"
    error_message = "Name tag should still be present"
  }
}

