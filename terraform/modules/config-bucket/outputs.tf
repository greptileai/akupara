output "bucket_name" {
  description = "Name of the configuration bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the configuration bucket."
  value       = aws_s3_bucket.this.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting the bucket (null when SSE-S3 is used)."
  value       = local.kms_key_arn
}
