variable "bucket_name" {
  description = "Name of the S3 bucket that will store Greptile bootstrap secrets."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even when it contains objects."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Enable S3 versioning to keep previous secret revisions."
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Create a dedicated KMS key for bucket encryption. When false, provide existing_kms_key_arn or fall back to SSE-S3."
  type        = bool
  default     = true
}

variable "existing_kms_key_arn" {
  description = "Optional ARN of an existing KMS key to encrypt bucket objects (used when create_kms_key = false)."
  type        = string
  default     = null
}

variable "kms_alias_name" {
  description = "Alias assigned to the newly created KMS key."
  type        = string
  default     = "alias/greptile-config"
}

variable "kms_description" {
  description = "Description applied to the created KMS key."
  type        = string
  default     = "Greptile configuration bucket key"
}

variable "kms_deletion_window_in_days" {
  description = "Waiting period (days) before a scheduled KMS key deletion executes."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags applied to created resources."
  type        = map(string)
  default     = {}
}
