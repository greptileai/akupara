variable "name_prefix" {
  description = "Prefix used for naming Redis resources."
  type        = string
  default     = "greptile"
}

variable "subnet_ids" {
  description = "Private subnet IDs for the Redis subnet group."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for creating the security group."
  type        = string
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs that may access Redis."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "Optional CIDR blocks permitted to reach Redis."
  type        = list(string)
  default     = []
}

variable "replication_group_id" {
  description = "Unique identifier for the replication group."
  type        = string
  default     = "greptile-redis"
}

variable "description" {
  description = "Description for the replication group."
  type        = string
  default     = "Redis cluster for Greptile"
}

variable "node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t3.micro"
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "6.2"
}

variable "num_cache_clusters" {
  description = "Number of cache clusters (1 = primary only)."
  type        = number
  default     = 1
}

variable "at_rest_encryption_enabled" {
  description = "Enable encryption at rest."
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Enable encryption in transit."
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "Redis AUTH token (required when transit encryption is enabled)."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = (!var.transit_encryption_enabled) || (var.auth_token != null && length(var.auth_token) >= 16)
    error_message = "Provide a Redis auth_token of at least 16 characters when transit_encryption_enabled is true."
  }
}

variable "tags" {
  description = "Additional tags applied to Redis resources."
  type        = map(string)
  default     = {}
}
