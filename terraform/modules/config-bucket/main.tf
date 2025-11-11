locals {
  using_existing_kms = var.existing_kms_key_arn != null
  kms_key_arn        = var.create_kms_key ? aws_kms_key.this[0].arn : (local.using_existing_kms ? var.existing_kms_key_arn : null)
}

resource "aws_kms_key" "this" {
  count = var.create_kms_key ? 1 : 0

  description             = var.kms_description
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  count = var.create_kms_key ? 1 : 0

  name          = var.kms_alias_name
  target_key_id = aws_kms_key.this[0].key_id
}

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags = merge({
    Name = var.bucket_name
  }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = local.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
