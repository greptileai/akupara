variable "aws_region" {
  description = "AWS region for deployment."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
  default     = "default"
}

variable "name_prefix" {
  description = "Prefix for Greptile resources."
  type        = string
  default     = "example-greptile"
}

variable "environment" {
  description = "Environment name (e.g., production)."
  type        = string
  default     = "production"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace to deploy into."
  type        = string
  default     = "default"
}

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (optional; used for internet-facing load balancers)."
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (required; used for EKS, RDS, and Redis)."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS control plane."
  type        = string
  default     = "1.31"
}

variable "endpoint_public_access" {
  description = "Whether the EKS API endpoint is publicly accessible."
  type        = bool
  default     = true
}

variable "ecr_registry" {
  description = "Registry hostname/prefix (e.g., 123456789012.dkr.ecr.us-east-1.amazonaws.com/greptile)."
  type        = string
}

variable "greptile_tag" {
  description = "Greptile image tag to deploy."
  type        = string
}

variable "db_password" {
  description = "Password for PostgreSQL."
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "Username for PostgreSQL."
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
  description = "Instance class for the DB."
  type        = string
  default     = "db.m5.large"
}

variable "db_engine_version" {
  description = "PostgreSQL version."
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
  description = "Skip the final snapshot when destroying the DB."
  type        = bool
  default     = false
}

variable "db_final_snapshot_identifier" {
  description = "Optional override for the final snapshot name."
  type        = string
  default     = null
}

variable "redis_node_type" {
  description = "Redis node type."
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "6.2"
}

variable "redis_auth_token" {
  description = "Redis auth token (min 16 chars)."
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Greptile JWT secret (>= 32 chars recommended)."
  type        = string
  sensitive   = true
}

variable "token_encryption_key" {
  description = "Greptile token encryption key (>= 32 chars recommended)."
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "github_client_id" {
  description = "GitHub OAuth client ID (optional)."
  type        = string
  default     = null
}

variable "github_client_secret" {
  description = "GitHub OAuth client secret (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "github_private_key" {
  description = "GitHub App private key PEM (optional)."
  type        = string
  default     = null
  sensitive   = true
}

variable "ssm_secrets" {
  description = "Additional SSM SecureString parameters to create under /{name_prefix}/secrets/<key>."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "ssm_config" {
  description = "Additional SSM String parameters to create under /{name_prefix}/config/<key>."
  type        = map(string)
  default     = {}
}

variable "cloudwatch_logs_enabled" {
  description = "Whether to create a CloudWatch Logs group for the deployment."
  type        = bool
  default     = true
}

variable "cloudwatch_logs_retention_in_days" {
  description = "Retention in days for the CloudWatch log group (when enabled)."
  type        = number
  default     = 731
}

variable "cloudwatch_log_group_name" {
  description = "Override CloudWatch log group name."
  type        = string
  default     = null
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
  description = "Additional annotations to add to the Hatchet Ingresses."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to the stack."
  type        = map(string)
  default     = {}
}
