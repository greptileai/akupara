###################################################
# PROVIDER CONFIG + VARIABLES
###################################################

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use for deployment"
  default     = "greptile-prod"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# VPC and subnet variables
variable "vpc_id" {
  type        = string
  description = "VPC where resources will be placed"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnet IDs (for RDS & ElastiCache)"
}

# For the EC2 module (public or private subnet)
variable "ec2_subnet_id" {
  type        = string
  description = "Subnet ID for the EC2 instance"
}


variable "db_password" {
  type        = string
  description = "RDS Postgres password"
  sensitive   = true
}

# AMI for the custom Docker image
variable "ami_id" {
  type        = string
  description = "Custom AMI ID for the EC2 instance"
}

variable "key_name" {
  type        = string
  description = "Name of existing key pair for SSH"
}

variable "instance_type" {
  type        = string
  default     = "t3.large"
  description = "Instance type for EC2"
}

###################################################
# 1) EC2 INSTANCE (via module)
###################################################

module "greptile_ec2" {
  source     = "./terraform-ec2-module"
  vpc_id     = var.vpc_id
  subnet_id  = var.ec2_subnet_id
  ami_id     = var.ami_id
  key_name   = var.key_name
  name_prefix    = "greptile"
  instance_type  = var.instance_type

  # This module is associated_public_ip_address = true in its code
  # so it will have a public IP in that subnet if it's a public subnet
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

}

output "ec2_public_ip" {
  description = "Public IP of the created EC2 instance"
  value       = module.greptile_ec2.public_ip
}

###################################################
# IAM Role for EC2 with Bedrock Access
###################################################

# Create IAM role for EC2
resource "aws_iam_role" "ec2_bedrock_role" {
  name = "greptile-ec2-bedrock-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "greptile-ec2-bedrock-role"
  }
}

# Attach the AWS managed policy for Bedrock full access
resource "aws_iam_role_policy_attachment" "bedrock_policy_attachment" {
  role       = aws_iam_role.ec2_bedrock_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

# Create an instance profile for the role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "greptile-ec2-instance-profile"
  role = aws_iam_role.ec2_bedrock_role.name
}

###################################################
# 2) RDS (Postgres)
###################################################

resource "aws_db_subnet_group" "rds_subnets" {
  name       = "greptile-rds-subnet-group"
  subnet_ids = var.private_subnets

  tags = {
    Name = "greptile-rds-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "greptile-rds-sg"
  description = "SG for RDS allowing access from EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Postgres from the EC2 SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    # reference the SG from the EC2 module
    security_groups = [module.greptile_ec2.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "greptile-rds-sg"
  }
}

resource "aws_db_instance" "postgres" {
  identifier               = "greptile-postgres-db"
  engine                   = "postgres"
  engine_version           = "16.3"
  instance_class           = "db.m5.large" 
  allocated_storage        = 400
  max_allocated_storage    = 1000            # Maximum storage threshold 1000 GiB
  username                = "postgres"
  password                = var.db_password
  db_subnet_group_name     = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids   = [aws_security_group.rds_sg.id]
  
  # Storage configuration
  storage_type            = "io1"           # Provisioned IOPS SSD
  iops                    = 3000            # Provisioned IOPS value
  storage_encrypted       = true            # Encryption enabled
  
  # Additional settings
  deletion_protection     = false            # Set to true if needed
  multi_az               = false            # Multi-AZ set to No
  parameter_group_name    = "default.postgres16"
  
  # Performance Insights
  performance_insights_enabled = false      # Turned off
  
  # Skip final snapshot when destroying
  skip_final_snapshot     = true

  tags = {
    Name = "greptile-rds-instance"
  }
}

output "rds_endpoint" {
  description = "RDS Postgres endpoint"
  value       = aws_db_instance.postgres.endpoint
}

###################################################
# 3) ElastiCache (Redis)
###################################################

resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "greptile-onprem-redis-subnet-group"
  subnet_ids = var.private_subnets

  # Add lifecycle rule to handle pre-existing subnet group
  lifecycle {
    ignore_changes = [subnet_ids]
  }

  tags = {
    Name = "greptile-onprem-redis-subnet-group"
  }
}

resource "aws_security_group" "redis_sg" {
  name        = "greptile-redis-sg"
  description = "SG for Redis allowing access from EC2"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Redis from the EC2 SG"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [module.greptile_ec2.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "greptile-redis-sg"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "greptile-redis"
  description         = "Redis cluster for Greptile"
  engine             = "redis"
  engine_version     = "6.2"
  node_type          = "cache.t3.micro"
  num_cache_clusters = 1
  subnet_group_name  = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids = [aws_security_group.redis_sg.id]

  at_rest_encryption_enabled = false
  transit_encryption_enabled = false

  tags = {
    Name = "greptile-redis-cluster"
  }
}

output "redis_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
