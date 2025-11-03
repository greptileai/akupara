output "primary_endpoint" {
  description = "Primary endpoint of the Redis replication group."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "security_group_id" {
  description = "Security group protecting Redis."
  value       = aws_security_group.this.id
}
