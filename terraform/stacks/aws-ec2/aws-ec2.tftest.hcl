mock_provider "aws" {}

variables {
  vpc_id                    = "vpc-12345678"
  private_subnet_ids        = ["subnet-12345678", "subnet-87654321"]
  ec2_subnet_id             = "subnet-ec212345"
  ami_id                    = "ami-12345678"
  key_name                  = "test-key"
  db_password               = "testpassword123"
  redis_auth_token          = "testtoken12345678"
  enable_greptile_bootstrap = false
}

run "iam_role_created" {
  command = plan

  assert {
    condition     = aws_iam_role.ec2_bedrock.name == "greptile-ec2-bedrock-role"
    error_message = "IAM role should use default name_prefix"
  }
}

run "iam_instance_profile_created" {
  command = plan

  assert {
    condition     = aws_iam_instance_profile.ec2.name == "greptile-ec2-instance-profile"
    error_message = "Instance profile should use default name_prefix"
  }
}

run "bedrock_policy_attached" {
  command = plan

  assert {
    condition     = aws_iam_role_policy_attachment.bedrock_full_access.policy_arn == "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
    error_message = "Bedrock full access policy should be attached"
  }
}

run "ecr_pull_policy_created" {
  command = plan

  assert {
    condition     = aws_iam_role_policy.greptile_ecr_pull.name == "greptile-allow-ecr-pull"
    error_message = "ECR pull policy should be created"
  }
}

run "no_secrets_policy_without_bucket" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.greptile_secrets) == 0
    error_message = "No secrets policy should be created without secrets_bucket"
  }
}

run "secrets_policy_created_with_bucket" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
    ec2_subnet_id      = "subnet-ec212345"
    ami_id             = "ami-12345678"
    key_name           = "test-key"
    db_password        = "testpassword123"
    redis_auth_token   = "testtoken12345678"
    secrets_bucket     = "my-secrets-bucket"
    secrets_object_key = "greptile/.env"
  }

  assert {
    condition     = length(aws_iam_role_policy.greptile_secrets) == 1
    error_message = "Secrets policy should be created when secrets_bucket is set"
  }
}

run "default_name_prefix" {
  command = plan

  assert {
    condition     = aws_iam_role.ec2_bedrock.name == "greptile-ec2-bedrock-role"
    error_message = "Default name_prefix should be greptile"
  }
}

run "custom_name_prefix" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
    ec2_subnet_id      = "subnet-ec212345"
    ami_id             = "ami-12345678"
    key_name           = "test-key"
    db_password        = "testpassword123"
    redis_auth_token   = "testtoken12345678"
    name_prefix        = "myapp"
  }

  assert {
    condition     = aws_iam_role.ec2_bedrock.name == "myapp-ec2-bedrock-role"
    error_message = "Custom name_prefix should be used"
  }

  assert {
    condition     = aws_iam_instance_profile.ec2.name == "myapp-ec2-instance-profile"
    error_message = "Custom name_prefix should be used for instance profile"
  }
}

run "stack_tag_applied" {
  command = plan

  assert {
    condition     = aws_iam_role.ec2_bedrock.tags["Stack"] == "aws-ec2"
    error_message = "Stack tag should be applied to IAM role"
  }
}

run "custom_tags_merged" {
  command = plan

  variables {
    vpc_id             = "vpc-12345678"
    private_subnet_ids = ["subnet-12345678", "subnet-87654321"]
    ec2_subnet_id      = "subnet-ec212345"
    ami_id             = "ami-12345678"
    key_name           = "test-key"
    db_password        = "testpassword123"
    redis_auth_token   = "testtoken12345678"
    tags = {
      Environment = "test"
    }
  }

  assert {
    condition     = aws_iam_role.ec2_bedrock.tags["Environment"] == "test"
    error_message = "Custom tags should be merged"
  }

  assert {
    condition     = aws_iam_role.ec2_bedrock.tags["Stack"] == "aws-ec2"
    error_message = "Stack tag should still be present"
  }
}

run "ec2_module_instantiated" {
  command = plan

  assert {
    condition     = module.ec2_app != null
    error_message = "EC2 app module should be instantiated"
  }
}

run "rds_module_instantiated" {
  command = plan

  assert {
    condition     = module.rds != null
    error_message = "RDS module should be instantiated"
  }
}

run "redis_module_instantiated" {
  command = plan

  assert {
    condition     = module.redis != null
    error_message = "Redis module should be instantiated"
  }
}

run "bootstrap_user_data_with_secrets" {
  command = plan

  variables {
    vpc_id                    = "vpc-12345678"
    private_subnet_ids        = ["subnet-12345678", "subnet-87654321"]
    ec2_subnet_id             = "subnet-ec212345"
    ami_id                    = "ami-12345678"
    key_name                  = "test-key"
    db_password               = "testpassword123"
    redis_auth_token          = "testtoken12345678"
    enable_greptile_bootstrap = true
    secrets_bucket            = "my-secrets-bucket"
    secrets_object_key        = "greptile/.env"
  }

  assert {
    condition     = local.bootstrap_user_data != null
    error_message = "Bootstrap user data should be set when enable_greptile_bootstrap is true"
  }
}

run "bootstrap_user_data_disabled" {
  command = plan

  # Uses default variables which has enable_greptile_bootstrap = false
  assert {
    condition     = local.bootstrap_user_data == null
    error_message = "Bootstrap user data should be null when enable_greptile_bootstrap is false"
  }

  assert {
    condition     = local.bootstrap_user_data_base64 == null
    error_message = "Bootstrap user data base64 should be null when bootstrap is disabled"
  }
}

run "default_webhook_port_matches_compose" {
  command = plan

  # The default ingress rule for webhooks must match the port exposed in
  # docker-compose.aws.yml (greptile-webhook: ports "3007:3007").
  # If this test fails, ensure the SG rule and compose file are aligned.
  assert {
    condition     = contains([for r in var.ingress_rules : r.from_port if r.description == "GitHub Webhooks"], 3007)
    error_message = "Default webhook ingress port should be 3007 to match docker-compose.aws.yml"
  }
}

