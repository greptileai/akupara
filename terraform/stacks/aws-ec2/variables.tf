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

variable "associate_public_ip" {
  description = "Whether the EC2 instance should receive a public IP."
  type        = bool
  default     = true
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
  default = null
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
  default     = "16.3"
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

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
