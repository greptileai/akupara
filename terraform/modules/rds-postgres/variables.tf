variable "name_prefix" {
  description = "Prefix for naming RDS resources."
  type        = string
  default     = "greptile"
}

variable "vpc_id" {
  description = "VPC ID used for the RDS security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used to build the DB subnet group."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups that are allowed to connect to the database."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to connect to the database."
  type        = list(string)
  default     = []
}

variable "db_identifier" {
  description = "Identifier for the DB instance."
  type        = string
  default     = "greptile-postgres-db"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "greptile"
}

variable "db_username" {
  description = "Master username."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Master user password."
  type        = string
  sensitive   = true
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.3"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.m5.large"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GiB."
  type        = number
  default     = 400
}

variable "max_allocated_storage" {
  description = "Maximum storage autoscaling ceiling in GiB."
  type        = number
  default     = 1000
}

variable "storage_type" {
  description = "DB storage type (gp3, io1, etc)."
  type        = string
  default     = "io1"
}

variable "iops" {
  description = "Provisioned IOPS (required when storage_type=io1)."
  type        = number
  default     = 3000
}

variable "multi_az" {
  description = "Deploy the instance in Multi-AZ mode."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the instance is publicly accessible."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection."
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Enable storage encryption."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "Optional KMS key ARN for encryption."
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Backup retention in days."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Skip taking a final snapshot when destroying the database."
  type        = bool
  default     = false
}

variable "final_snapshot_identifier" {
  description = "Name of the final snapshot when skip_final_snapshot is false."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default     = {}
}
