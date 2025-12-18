terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "greptile_aws_eks" {
  source = "github.com/greptileai/akupara//terraform/stacks/aws-eks?ref=main"

  aws_region  = var.aws_region
  aws_profile = var.aws_profile

  name_prefix   = var.name_prefix
  environment   = var.environment
  k8s_namespace = var.k8s_namespace

  vpc_id             = var.vpc_id
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids

  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = var.endpoint_public_access

  ecr_registry = var.ecr_registry
  greptile_tag = var.greptile_tag

  db_password                  = var.db_password
  db_username                  = var.db_username
  db_name                      = var.db_name
  db_allocated_storage         = var.db_allocated_storage
  db_max_allocated_storage     = var.db_max_allocated_storage
  db_instance_class            = var.db_instance_class
  db_engine_version            = var.db_engine_version
  db_storage_type              = var.db_storage_type
  db_iops                      = var.db_iops
  db_backup_retention_period   = var.db_backup_retention_period
  db_backup_window             = var.db_backup_window
  db_maintenance_window        = var.db_maintenance_window
  db_copy_tags_to_snapshot     = var.db_copy_tags_to_snapshot
  db_delete_automated_backups  = var.db_delete_automated_backups
  db_skip_final_snapshot       = var.db_skip_final_snapshot
  db_final_snapshot_identifier = var.db_final_snapshot_identifier

  redis_node_type      = var.redis_node_type
  redis_engine_version = var.redis_engine_version
  redis_auth_token     = var.redis_auth_token

  jwt_secret           = var.jwt_secret
  token_encryption_key = var.token_encryption_key

  anthropic_api_key = var.anthropic_api_key
  openai_api_key    = var.openai_api_key

  github_client_id      = var.github_client_id
  github_client_secret  = var.github_client_secret
  github_webhook_secret = var.github_webhook_secret
  github_private_key    = var.github_private_key

  ssm_secrets = var.ssm_secrets
  ssm_config  = var.ssm_config

  cloudwatch_logs_enabled           = var.cloudwatch_logs_enabled
  cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days
  cloudwatch_log_group_name         = var.cloudwatch_log_group_name

  hatchet_ingress_enabled     = var.hatchet_ingress_enabled
  hatchet_ingress_host        = var.hatchet_ingress_host
  hatchet_ingress_annotations = var.hatchet_ingress_annotations

  tags = var.tags
}

output "cluster_name" {
  value       = module.greptile_aws_eks.cluster_name
  description = "Surface stack output for convenience."
}

output "kubeconfig_command" {
  value       = module.greptile_aws_eks.kubeconfig_command
  description = "Command to configure kubectl for this EKS cluster."
}

output "rds_endpoint" {
  value       = module.greptile_aws_eks.rds_endpoint
  description = "Surface stack output for convenience."
}

output "redis_endpoint" {
  value       = module.greptile_aws_eks.redis_endpoint
  description = "Surface stack output for convenience."
}

output "ssm_prefix" {
  value       = module.greptile_aws_eks.ssm_prefix
  description = "Surface stack output for convenience."
}
