mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}
mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [
        {
          sha1_fingerprint = "0000000000000000000000000000000000000000"
        }
      ]
    }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}

variables {
  aws_region  = "us-east-1"
  aws_profile = "default"
  name_prefix = "test-blue"
  environment = "test"
  vpc_id      = "vpc-12345"

  public_subnet_ids  = ["subnet-public-1", "subnet-public-2"]
  private_subnet_ids = ["subnet-private-1", "subnet-private-2"]

  ecr_registry = "123456789012.dkr.ecr.us-east-1.amazonaws.com"
  greptile_tag = "0.1.0"

  db_password = "test-password-123"
  db_username = "postgres"

  redis_auth_token = "redis-token-12345678"

  jwt_secret           = "test-jwt-secret-32chars-minimum!!!!"
  token_encryption_key = "test-token-encryption-key-32chars!"
}

run "creates_kms_key_for_ssm" {
  command = plan

  assert {
    condition     = aws_kms_key.ssm.enable_key_rotation == true
    error_message = "KMS key must have rotation enabled"
  }

  assert {
    condition     = aws_kms_key.ssm.deletion_window_in_days >= 7
    error_message = "KMS key must have deletion window >= 7 days"
  }
}

run "ssm_secrets_use_secure_string" {
  command = plan

  assert {
    condition     = aws_ssm_parameter.secrets["database-password"].type == "SecureString"
    error_message = "Database password must be SecureString"
  }

  assert {
    condition     = aws_ssm_parameter.secrets["jwt-secret"].type == "SecureString"
    error_message = "JWT secret must be SecureString"
  }

  assert {
    condition     = aws_ssm_parameter.secrets["redis-auth-token"].type == "SecureString"
    error_message = "Redis auth token must be SecureString"
  }
}

run "ssm_paths_use_prefix_for_isolation" {
  command = plan

  assert {
    condition     = startswith(aws_ssm_parameter.secrets["database-password"].name, "/test-blue/secrets/")
    error_message = "SSM secrets must use /{prefix}/secrets/ path"
  }

  assert {
    condition     = startswith(aws_ssm_parameter.config["database-host"].name, "/test-blue/config/")
    error_message = "SSM config must use /{prefix}/config/ path"
  }
}

run "ssm_config_uses_string_type" {
  command = plan

  assert {
    condition     = aws_ssm_parameter.config["database-host"].type == "String"
    error_message = "Config parameters should be String type"
  }

  assert {
    condition     = aws_ssm_parameter.config["redis-host"].type == "String"
    error_message = "Config parameters should be String type"
  }
}

run "creates_irsa_roles" {
  command = plan

  assert {
    condition     = module.irsa_external_secrets.role_name == "test-blue-external-secrets-role"
    error_message = "External secrets IRSA role name must use name_prefix"
  }

  assert {
    condition     = module.irsa_query.role_name == "test-blue-query-role"
    error_message = "Query IRSA role name must use name_prefix"
  }

  assert {
    condition     = module.irsa_indexer.role_name == "test-blue-indexer-role"
    error_message = "Indexer IRSA role name must use name_prefix"
  }
}
