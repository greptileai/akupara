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

variable "vpc_id" {
  description = "Existing VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS/Redis."
  type        = list(string)
}

variable "ec2_subnet_id" {
  description = "Subnet for the EC2 instance."
  type        = string
}

variable "ami_id" {
  description = "AMI for the EC2 instance."
  type        = string
}

variable "key_name" {
  description = "EC2 key pair for SSH."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.large"
}

variable "ec2_root_volume_size" {
  description = "Root volume size (GiB) for the EC2 instance."
  type        = number
  default     = 40
}

variable "ec2_root_volume_type" {
  description = "Root volume EBS type."
  type        = string
  default     = "gp3"
}

variable "ec2_root_volume_delete_on_termination" {
  description = "Delete the root volume when the instance is terminated."
  type        = bool
  default     = true
}

variable "ec2_root_volume_encrypted" {
  description = "Encrypt the EC2 root volume."
  type        = bool
  default     = true
}

variable "associate_public_ip" {
  description = "Assign a public IP to the EC2 instance."
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "Optional ingress overrides for the EC2 security group."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "SSH from corp network"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "App HTTP"
      from_port   = 3000
      to_port     = 3000
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "GitHub Webhooks"
      from_port   = 3010
      to_port     = 3010
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Hatchet UI"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Hatchet service"
      from_port   = 7077
      to_port     = 7077
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]
}

variable "enable_greptile_bootstrap" {
  description = "Render the Amazon Linux bootstrap that installs Docker, pulls secrets, and manages docker-compose via systemd."
  type        = bool
  default     = true
}

variable "secrets_bucket" {
  description = "S3 bucket that stores the rendered Greptile .env file (required when bootstrap is enabled)."
  type        = string
  default     = null
}

variable "secrets_object_key" {
  description = "Key inside the secrets bucket that points to the .env payload."
  type        = string
  default     = null
}

variable "secrets_kms_key_arn" {
  description = "Optional KMS key ARN if the secrets object is encrypted."
  type        = string
  default     = null
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
  description = "Max storage autoscaling (GiB)."
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
  description = "Provisioned IOPS for RDS."
  type        = number
  default     = 3000
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 14
}

variable "db_backup_window" {
  description = "Preferred RDS backup window."
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Preferred RDS maintenance window."
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "db_copy_tags_to_snapshot" {
  description = "Copy tags to automated RDS snapshots."
  type        = bool
  default     = true
}

variable "db_delete_automated_backups" {
  description = "Delete automated backups immediately when destroying the DB instance."
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
  description = "Redis auth token (required when transit encryption is enabled)."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to the stack."
  type        = map(string)
  default     = {}
}
