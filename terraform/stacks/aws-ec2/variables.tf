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
  description = "Prefix applied to resources (used for tagging/naming)."
  type        = string
  default     = "greptile"
}

variable "vpc_id" {
  description = "VPC ID where all resources will be created."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for stateful services (RDS, Redis)."
  type        = list(string)
}

variable "ec2_subnet_id" {
  description = "Subnet ID for the EC2 application instance."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 application host."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair for SSH."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.large"
}

variable "ec2_root_volume_size" {
  description = "Root volume size for the EC2 instance (GiB)."
  type        = number
  default     = 40
}

variable "ec2_root_volume_type" {
  description = "Root volume EBS type."
  type        = string
  default     = "gp3"
}

variable "ec2_root_volume_delete_on_termination" {
  description = "Whether to delete the root volume when the instance terminates."
  type        = bool
  default     = true
}

variable "ec2_root_volume_encrypted" {
  description = "Whether to encrypt the EC2 root volume."
  type        = bool
  default     = true
}

variable "associate_public_ip" {
  description = "Whether the EC2 instance should receive a public IP."
  type        = bool
  default     = true
}

variable "enable_greptile_bootstrap" {
  description = "Render Amazon Linux user data that installs Docker Compose and systemd units for the Greptile stack."
  type        = bool
  default     = true
}

variable "secrets_bucket" {
  description = "S3 bucket that stores the rendered Greptile .env file (optional)."
  type        = string
  default     = null
}

variable "secrets_object_key" {
  description = "Object key inside the secrets bucket that contains the .env file."
  type        = string
  default     = null
}

variable "secrets_kms_key_arn" {
  description = "Optional KMS key ARN used to encrypt the secrets object (grants kms:Decrypt when set)."
  type        = string
  default     = null
}

variable "ingress_rules" {
  description = "Ingress rules for the EC2 security group."
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

variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "6.2"
}

variable "redis_auth_token" {
  description = "Auth token required when Redis transit encryption is enabled."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
