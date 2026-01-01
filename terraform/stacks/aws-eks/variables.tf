variable "aws_region" {
  description = "AWS region for the stack."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use."
  type        = string
  default     = "default"
}

variable "name_prefix" {
  description = "Prefix applied to resources (used for naming/blue-green isolation)."
  type        = string
  default     = "greptile"
}

variable "environment" {
  description = "Environment name (e.g., production)."
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID where all resources will be created."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (for internet-facing load balancers)."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.31"
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible."
  type        = bool
  default     = true
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for the Greptile deployment."
  type        = string
  default     = "default"
}

variable "ecr_registry" {
  description = "ECR registry hostname (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com)."
  type        = string
}

variable "greptile_tag" {
  description = "Greptile image tag to deploy."
  type        = string
}

variable "db_password" {
  description = "PostgreSQL master password."
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "postgres"
}

variable "db_name" {
  description = "Initial PostgreSQL database name."
  type        = string
  default     = "greptile"
}

variable "db_allocated_storage" {
  description = "Initial DB storage (GiB)."
  type        = number
  default     = 400
}

variable "db_max_allocated_storage" {
  description = "Max storage autoscaling ceiling (GiB)."
  type        = number
  default     = 1000
}

variable "db_instance_class" {
  description = "DB instance class."
  type        = string
  default     = "db.m5.large"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.10"
}

variable "db_storage_type" {
  description = "RDS storage type."
  type        = string
  default     = "io1"
}

variable "db_iops" {
  description = "Provisioned IOPS for RDS (used when storage type is io1)."
  type        = number
  default     = 3000
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 14
}

variable "db_backup_window" {
  description = "Preferred backup window for RDS."
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window for RDS."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "db_copy_tags_to_snapshot" {
  description = "Copy resource tags to automated RDS snapshots."
  type        = bool
  default     = true
}

variable "db_delete_automated_backups" {
  description = "Delete automated backups immediately when the RDS instance is removed."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Skip the final snapshot when destroying the database."
  type        = bool
  default     = false
}

variable "db_final_snapshot_identifier" {
  description = "Override name for the final snapshot (when not skipping)."
  type        = string
  default     = null
}

variable "jwt_secret" {
  description = "Greptile JWT secret (>= 32 chars recommended)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.jwt_secret)) >= 32
    error_message = "jwt_secret must be at least 32 characters."
  }
}

variable "token_encryption_key" {
  description = "Greptile token encryption key (>= 32 chars recommended)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.token_encryption_key)) >= 32
    error_message = "token_encryption_key must be at least 32 characters."
  }
}

variable "ssm_secrets" {
  description = "Additional SSM SecureString parameters to create under /{name_prefix}/secrets/<key>. Keys should be kebab-case."
  type        = map(string)
  default     = {}
  sensitive   = true

  validation {
    condition = alltrue([
      for k in keys(var.ssm_secrets) : can(regex("^[a-z0-9][a-z0-9-]*$", k))
    ])
    error_message = "ssm_secrets keys must be kebab-case (lowercase letters, numbers, dashes)."
  }

  validation {
    condition = length(setintersection(
      toset(keys(var.ssm_secrets)),
      toset([
        "database-password",
        "jwt-secret",
        "token-encryption-key"
      ])
    )) == 0
    error_message = "ssm_secrets must not include reserved keys managed by first-class variables."
  }
}

variable "ssm_secrets_keys" {
  description = "Additional SSM SecureString parameter keys (kebab-case) that should be exposed to pods even if managed outside Terraform."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for k in var.ssm_secrets_keys : can(regex("^[a-z0-9][a-z0-9-]*$", k))
    ])
    error_message = "ssm_secrets_keys must be kebab-case (lowercase letters, numbers, dashes)."
  }

  validation {
    condition = length(setintersection(
      toset(var.ssm_secrets_keys),
      toset([
        "database-password",
        "jwt-secret",
        "token-encryption-key"
      ])
    )) == 0
    error_message = "ssm_secrets_keys must not include reserved keys managed by first-class variables."
  }
}

variable "ssm_config" {
  description = "Additional SSM String parameters to create under /{name_prefix}/config/<key>. Keys should be kebab-case."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.ssm_config) : can(regex("^[a-z0-9][a-z0-9-]*$", k))
    ])
    error_message = "ssm_config keys must be kebab-case (lowercase letters, numbers, dashes)."
  }

  validation {
    condition = length(setintersection(
      toset(keys(var.ssm_config)),
      toset([
        "database-host",
        "database-port",
        "database-username",
        "database-name",
        "aws-region"
      ])
    )) == 0
    error_message = "ssm_config must not include reserved keys managed by first-class variables or derived values."
  }
}

variable "ssm_config_keys" {
  description = "Additional SSM String parameter keys (kebab-case) that should be exposed to pods even if managed outside Terraform."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for k in var.ssm_config_keys : can(regex("^[a-z0-9][a-z0-9-]*$", k))
    ])
    error_message = "ssm_config_keys must be kebab-case (lowercase letters, numbers, dashes)."
  }

  validation {
    condition = length(setintersection(
      toset(var.ssm_config_keys),
      toset([
        "database-host",
        "database-port",
        "database-username",
        "database-name",
        "aws-region"
      ])
    )) == 0
    error_message = "ssm_config_keys must not include reserved keys managed by first-class variables or derived values."
  }
}

variable "cloudwatch_logs_enabled" {
  description = "Whether to create a CloudWatch Logs group for the deployment (log shipping is configured via Helm chart)."
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention_in_days" {
  description = "Retention in days for the CloudWatch log group (when enabled)."
  type        = number
  default     = 731
}

variable "cloudwatch_log_group_name" {
  description = "Override CloudWatch log group name. When null, uses /greptile/{name_prefix}/application."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}

variable "hatchet_ingress_enabled" {
  description = "Whether to expose Hatchet UI/API via an internal ALB Ingress (ops-only)."
  type        = bool
  default     = true
}

variable "hatchet_ingress_host" {
  description = "Optional host for the Hatchet ALB Ingress (leave empty to match all hosts)."
  type        = string
  default     = ""
}

variable "hatchet_ingress_annotations" {
  description = "Additional annotations to add to the Hatchet Ingresses (e.g., Cognito auth, TLS cert ARN)."
  type        = map(string)
  default     = {}
}
