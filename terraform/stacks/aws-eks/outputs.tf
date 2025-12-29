output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS instance endpoint."
  value       = module.rds.endpoint
}

output "redis_endpoint" {
  description = "Redis primary endpoint."
  value       = module.redis.primary_endpoint
}

output "ssm_prefix" {
  description = "SSM Parameter Store prefix for this deployment (e.g., /prod-blue)."
  value       = local.ssm_prefix
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt SecureString SSM parameters."
  value       = aws_kms_key.ssm.arn
}

output "external_secrets_role_arn" {
  description = "IRSA role ARN for External Secrets."
  value       = module.irsa_external_secrets.role_arn
}

output "indexer_role_arn" {
  description = "IRSA role ARN for indexer service (Bedrock)."
  value       = module.irsa_indexer.role_arn
}

output "github_role_arn" {
  description = "IRSA role ARN for GitHub integration (Bedrock)."
  value       = module.irsa_github.role_arn
}

output "gitlab_role_arn" {
  description = "IRSA role ARN for GitLab integration (Bedrock)."
  value       = module.irsa_gitlab.role_arn
}

output "cloudwatch_role_arn" {
  description = "IRSA role ARN for CloudWatch agent/log shipping."
  value       = module.irsa_cloudwatch.role_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Logs group name for application logs (when enabled)."
  value       = var.cloudwatch_logs_enabled ? aws_cloudwatch_log_group.application[0].name : null
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for this EKS cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

