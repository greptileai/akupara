locals {
  tags = merge({
    Stack = "aws-ec2"
  }, var.tags)
}

############################################################
# IAM role + instance profile for the EC2 host
############################################################
resource "aws_iam_role" "ec2_bedrock" {
  name = "${var.name_prefix}-ec2-bedrock-role"

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

  tags = local.tags
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_bedrock.name
}

resource "aws_iam_role_policy_attachment" "bedrock_full_access" {
  role       = aws_iam_role.ec2_bedrock.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

############################################################
# EC2 host running Docker compose
############################################################
module "ec2_app" {
  source               = "../../modules/ec2-app"
  vpc_id               = var.vpc_id
  subnet_id            = var.ec2_subnet_id
  ami_id               = var.ami_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  name_prefix          = var.name_prefix
  iam_instance_profile = aws_iam_instance_profile.ec2.name
  associate_public_ip  = var.associate_public_ip
  ingress_rules        = var.ingress_rules
  tags                 = local.tags
}

############################################################
# PostgreSQL database
############################################################
module "rds" {
  source                     = "../../modules/rds-postgres"
  name_prefix                = "${var.name_prefix}-rds"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = [module.ec2_app.security_group_id]
  db_identifier              = "${var.name_prefix}-postgres-db"
  db_name                    = var.name_prefix
  db_username                = var.db_username
  db_password                = var.db_password
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  storage_type               = var.db_storage_type
  iops                       = var.db_iops
  skip_final_snapshot        = var.db_skip_final_snapshot
  final_snapshot_identifier  = var.db_final_snapshot_identifier
  tags                       = local.tags
}

############################################################
# Redis cache
############################################################
module "redis" {
  source                     = "../../modules/redis-cluster"
  name_prefix                = "${var.name_prefix}-redis"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = [module.ec2_app.security_group_id]
  replication_group_id       = "${var.name_prefix}-redis"
  node_type                  = var.redis_node_type
  engine_version             = var.redis_engine_version
  tags                       = local.tags
}
