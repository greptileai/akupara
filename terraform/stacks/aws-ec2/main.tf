locals {
  tags = merge({
    Stack = "aws-ec2"
  }, var.tags)

  # Cloud-init user-data for the Greptile EC2 host.
  #
  # Size limits:
  # - EC2 UserData is size-limited (treat 16 KiB as the hard cap for the payload delivered to the instance).
  #   This is the binding constraint for this stack because we embed files directly in the user-data script.
  #
  # Current footprint (update if you change embedded files):
  # - `local.bootstrap_user_data_base64`: 14,916 bytes (~14.57 KiB), headroom: 1,468 bytes to 16 KiB.
  # - base64-decoded gzip payload:        11,187 bytes (~10.92 KiB), headroom: 5,197 bytes to 16 KiB.
  #   (Measured 2025-12-12.)
  bootstrap_user_data = var.enable_greptile_bootstrap ? templatefile(
    "${path.module}/files/bootstrap/user-data.sh.tpl",
    {
      # Large files (base64gzip)
      docker_compose_b64_gz  = base64gzip(file("${path.module}/files/bootstrap/docker-compose.aws.yml"))
      env_example_b64_gz     = base64gzip(file("${path.module}/files/bootstrap/.env.aws.example"))
      caddyfile_b64_gz       = base64gzip(file("${path.module}/files/bootstrap/Caddyfile"))
      llmproxy_config_b64_gz = base64gzip(file("${path.module}/files/bootstrap/llmproxy-config.yaml"))

      # Helper scripts (base64gzip)
      pull_secrets_b64         = base64gzip(file("${path.module}/files/bootstrap/bin/pull-secrets.sh"))
      login_registry_b64       = base64gzip(file("${path.module}/files/bootstrap/bin/login-registry.sh"))
      hatchet_token_script_b64 = base64gzip(file("${path.module}/files/bootstrap/bin/generate-hatchet-token.sh"))

      # Systemd units (base64gzip)
      systemd_images_b64        = base64gzip(file("${path.module}/files/bootstrap/systemd/greptile-images.service"))
      systemd_images_timer_b64  = base64gzip(file("${path.module}/files/bootstrap/systemd/greptile-images.timer"))
      systemd_hatchet_b64       = base64gzip(file("${path.module}/files/bootstrap/systemd/greptile-hatchet.service"))
      systemd_hatchet_token_b64 = base64gzip(file("${path.module}/files/bootstrap/systemd/greptile-hatchet-token.service"))
      systemd_app_b64           = base64gzip(file("${path.module}/files/bootstrap/systemd/greptile-app.service"))
      systemd_saml_b64          = base64gzip(file("${path.module}/files/bootstrap/systemd/greptile-saml.service"))

      # Runtime parameters (plain strings)
      secrets_bucket     = coalesce(var.secrets_bucket, "")
      secrets_object_key = coalesce(var.secrets_object_key, "")
    }
  ) : null

  bootstrap_user_data_base64 = local.bootstrap_user_data != null ? base64gzip(local.bootstrap_user_data) : null
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

resource "aws_iam_role_policy" "greptile_secrets" {
  count = var.secrets_bucket != null && var.secrets_object_key != null ? 1 : 0
  role  = aws_iam_role.ec2_bedrock.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.secrets_bucket}/${var.secrets_object_key}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.secrets_bucket}"
      }
      ], var.secrets_kms_key_arn != null ? [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.secrets_kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ] : [])
  })
}

resource "aws_iam_role_policy" "greptile_ecr_pull" {
  name = "${var.name_prefix}-allow-ecr-pull"
  role = aws_iam_role.ec2_bedrock.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################################
# EC2 host running Docker compose
############################################################
module "ec2_app" {
  source                            = "../../modules/aws/ec2-app"
  vpc_id                            = var.vpc_id
  subnet_id                         = var.ec2_subnet_id
  ami_id                            = var.ami_id
  instance_type                     = var.instance_type
  key_name                          = var.key_name
  name_prefix                       = var.name_prefix
  iam_instance_profile              = aws_iam_instance_profile.ec2.name
  associate_public_ip               = var.associate_public_ip
  root_volume_size                  = var.ec2_root_volume_size
  root_volume_type                  = var.ec2_root_volume_type
  root_volume_delete_on_termination = var.ec2_root_volume_delete_on_termination
  root_volume_encrypted             = var.ec2_root_volume_encrypted
  ingress_rules                     = var.ingress_rules
  user_data_base64                  = local.bootstrap_user_data_base64
  tags                              = local.tags
}

############################################################
# PostgreSQL database
############################################################
module "rds" {
  source                     = "../../modules/aws/rds-postgres"
  name_prefix                = "${var.name_prefix}-rds"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = [module.ec2_app.security_group_id]
  db_identifier              = "${var.name_prefix}-postgres-db"
  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  storage_type               = var.db_storage_type
  iops                       = var.db_iops
  backup_retention_period    = var.db_backup_retention_period
  backup_window              = var.db_backup_window
  maintenance_window         = var.db_maintenance_window
  skip_final_snapshot        = var.db_skip_final_snapshot
  final_snapshot_identifier  = var.db_final_snapshot_identifier
  copy_tags_to_snapshot      = var.db_copy_tags_to_snapshot
  delete_automated_backups   = var.db_delete_automated_backups
  tags                       = local.tags
}

############################################################
# Redis cache
############################################################
module "redis" {
  source                     = "../../modules/aws/redis-cluster"
  name_prefix                = "${var.name_prefix}-redis"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = [module.ec2_app.security_group_id]
  replication_group_id       = "${var.name_prefix}-redis"
  node_type                  = var.redis_node_type
  engine_version             = var.redis_engine_version
  auth_token                 = var.redis_auth_token
  tags                       = local.tags
}
