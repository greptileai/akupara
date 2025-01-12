output "database_secret_name" {
  value = regex("^(.+)-[^-]+$", split(":", aws_db_instance.db.master_user_secret[0].secret_arn)[6])[0]
  description = "Name of the database secrets in AWS Secrets Manager"
}

output "app_secret_name" {
  value = aws_secretsmanager_secret.app_secrets.name
  description = "Name of the app secrets in AWS Secrets Manager"
}

output "llm_secret_name" {
  value = length(aws_secretsmanager_secret.llm_secrets) > 0 ? aws_secretsmanager_secret.llm_secrets[0].name : null
  description = "Name of the LLM secrets in AWS Secrets Manager"
}

output "github_secret_name" {
  value = aws_secretsmanager_secret.github_secrets.name
  description = "Name of the github secrets in AWS Secrets Manager"
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
  description = "Name of the EKS cluster"
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
  description = "Redis endpoint for Helm values"
}

output "rds_endpoint" {
  value = split(":", aws_db_instance.db.endpoint)[0]
  description = "RDS endpoint for Helm values"
}

# Output the role ARN for use in Helm values
output "external_secrets_role_arn" {
  value = aws_iam_role.external_secrets.arn
  description = "ARN of the external secrets IAM role"
}

output "indexer_role_arn" {
  value = aws_iam_role.indexer.arn
  description = "ARN of the indexer IAM role"
}

output "query_role_arn" {
  value = aws_iam_role.query.arn
  description = "ARN of the query IAM role"
}