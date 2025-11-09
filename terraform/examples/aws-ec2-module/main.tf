terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "greptile_aws_ec2" {
  source = "github.com/greptileai/akupara//terraform/stacks/aws-ec2?ref=main"

  aws_region                            = var.aws_region
  aws_profile                           = var.aws_profile
  name_prefix                           = var.name_prefix
  vpc_id                                = var.vpc_id
  private_subnet_ids                    = var.private_subnet_ids
  ec2_subnet_id                         = var.ec2_subnet_id
  ami_id                                = var.ami_id
  key_name                              = var.key_name
  instance_type                         = var.instance_type
  associate_public_ip                   = var.associate_public_ip
  ec2_root_volume_size                  = var.ec2_root_volume_size
  ec2_root_volume_type                  = var.ec2_root_volume_type
  ec2_root_volume_delete_on_termination = var.ec2_root_volume_delete_on_termination
  ec2_root_volume_encrypted             = var.ec2_root_volume_encrypted
  ingress_rules                         = var.ingress_rules
  db_password                           = var.db_password
  db_username                           = var.db_username
  db_allocated_storage                  = var.db_allocated_storage
  db_max_allocated_storage              = var.db_max_allocated_storage
  db_instance_class                     = var.db_instance_class
  db_engine_version                     = var.db_engine_version
  db_storage_type                       = var.db_storage_type
  db_iops                               = var.db_iops
  db_backup_retention_period            = var.db_backup_retention_period
  db_backup_window                      = var.db_backup_window
  db_maintenance_window                 = var.db_maintenance_window
  db_copy_tags_to_snapshot              = var.db_copy_tags_to_snapshot
  db_delete_automated_backups           = var.db_delete_automated_backups
  db_skip_final_snapshot                = var.db_skip_final_snapshot
  db_final_snapshot_identifier          = var.db_final_snapshot_identifier
  redis_node_type                       = var.redis_node_type
  redis_engine_version                  = var.redis_engine_version
  redis_auth_token                      = var.redis_auth_token
  tags                                  = var.tags
}

output "ec2_public_ip" {
  value       = module.greptile_aws_ec2.ec2_public_ip
  description = "Surface stack output for convenience."
}
