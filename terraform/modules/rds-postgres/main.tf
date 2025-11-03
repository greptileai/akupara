resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge({
    Name = "${var.name_prefix}-rds-subnet-group"
  }, var.tags)
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.allowed_security_group_ids) > 0 ? [1] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = var.allowed_security_group_ids
      description     = "RDS access from allowed security groups"
    }
  }

  dynamic "ingress" {
    for_each = length(var.allowed_cidr_blocks) > 0 ? [1] : []
    content {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
      description = "RDS access from CIDRs"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    Name = "${var.name_prefix}-rds-sg"
  }, var.tags)
}

resource "aws_db_instance" "this" {
  identifier                   = var.db_identifier
  db_name                      = var.db_name
  engine                       = "postgres"
  engine_version               = var.engine_version
  instance_class               = var.instance_class
  allocated_storage            = var.allocated_storage
  max_allocated_storage        = var.max_allocated_storage
  storage_type                 = var.storage_type
  iops                         = var.storage_type == "io1" ? var.iops : null
  username                     = var.db_username
  password                     = var.db_password
  db_subnet_group_name         = aws_db_subnet_group.this.name
  vpc_security_group_ids       = [aws_security_group.this.id]
  multi_az                     = var.multi_az
  publicly_accessible          = var.publicly_accessible
  deletion_protection          = var.deletion_protection
  storage_encrypted            = var.storage_encrypted
  kms_key_id                   = var.kms_key_id
  backup_retention_period      = var.backup_retention_period
  backup_window                = var.backup_window
  maintenance_window           = var.maintenance_window
  performance_insights_enabled = var.performance_insights_enabled
  skip_final_snapshot          = true
  port                         = 5432

  tags = merge({
    Name = "${var.name_prefix}-rds"
  }, var.tags)
}
