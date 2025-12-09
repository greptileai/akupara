mock_provider "aws" {}

variables {
  bucket_name = "test-config-bucket"
}

run "kms_key_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_kms_key.this) == 1
    error_message = "KMS key should be created by default"
  }
}

run "kms_alias_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_kms_alias.this) == 1
    error_message = "KMS alias should be created by default"
  }
}

run "kms_key_rotation_enabled" {
  command = plan

  assert {
    condition     = aws_kms_key.this[0].enable_key_rotation == true
    error_message = "KMS key rotation should be enabled"
  }
}

run "sse_configuration_resource_exists" {
  command = plan

  # Verify SSE configuration resource is created (existence check)
  assert {
    condition     = aws_s3_bucket_server_side_encryption_configuration.this != null
    error_message = "SSE configuration resource should be created"
  }
}

run "using_existing_kms_local_true_when_set" {
  command = plan

  variables {
    bucket_name          = "test-config-bucket"
    create_kms_key       = false
    existing_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/test"
  }

  assert {
    condition     = local.using_existing_kms == true
    error_message = "using_existing_kms local should be true when existing_kms_key_arn is set"
  }
}

run "no_kms_key_when_disabled" {
  command = plan

  variables {
    bucket_name    = "test-config-bucket"
    create_kms_key = false
  }

  assert {
    condition     = length(aws_kms_key.this) == 0
    error_message = "No KMS key should be created when create_kms_key is false"
  }
}

run "no_kms_alias_when_disabled" {
  command = plan

  variables {
    bucket_name    = "test-config-bucket"
    create_kms_key = false
  }

  assert {
    condition     = length(aws_kms_alias.this) == 0
    error_message = "No KMS alias should be created when create_kms_key is false"
  }
}

run "versioning_enabled_by_default" {
  command = plan

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 1
    error_message = "Versioning should be enabled by default"
  }
}

run "versioning_disabled" {
  command = plan

  variables {
    bucket_name        = "test-config-bucket"
    versioning_enabled = false
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 0
    error_message = "Versioning resource should not be created when disabled"
  }
}

run "public_access_blocked" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls should be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy should be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls should be true"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets should be true"
  }
}

run "bucket_ownership_enforced" {
  command = plan

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "Object ownership should be BucketOwnerEnforced"
  }
}

run "bucket_name_set" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "test-config-bucket"
    error_message = "Bucket name should match input"
  }
}

run "force_destroy_enabled" {
  command = plan

  variables {
    bucket_name   = "test-config-bucket"
    force_destroy = true
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == true
    error_message = "Force destroy can be enabled"
  }
}

run "bucket_name_tag" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.tags["Name"] == "test-config-bucket"
    error_message = "Bucket should have Name tag matching bucket_name"
  }
}

run "custom_tags_merged" {
  command = plan

  variables {
    bucket_name = "test-config-bucket"
    tags = {
      Environment = "test"
      Team        = "engineering"
    }
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Environment"] == "test"
    error_message = "Custom tags should be merged"
  }

  assert {
    condition     = aws_s3_bucket.this.tags["Team"] == "engineering"
    error_message = "Multiple custom tags should be merged"
  }
}

run "custom_kms_alias" {
  command = plan

  variables {
    bucket_name    = "test-config-bucket"
    kms_alias_name = "alias/my-custom-key"
  }

  assert {
    condition     = aws_kms_alias.this[0].name == "alias/my-custom-key"
    error_message = "Custom KMS alias name should be used"
  }
}

run "existing_kms_key_no_new_key_created" {
  command = plan

  variables {
    bucket_name          = "test-config-bucket"
    create_kms_key       = false
    existing_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = length(aws_kms_key.this) == 0
    error_message = "No new KMS key should be created when using existing key"
  }

  assert {
    condition     = length(aws_kms_alias.this) == 0
    error_message = "No new KMS alias should be created when using existing key"
  }
}

