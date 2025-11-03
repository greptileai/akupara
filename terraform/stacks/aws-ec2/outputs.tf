output "ec2_public_ip" {
  description = "Public IP of the Greptile EC2 host."
  value       = module.ec2_app.public_ip
}

output "ec2_security_group_id" {
  description = "Security group protecting the EC2 host."
  value       = module.ec2_app.security_group_id
}

output "rds_endpoint" {
  description = "Endpoint of the PostgreSQL instance."
  value       = module.rds.endpoint
}

output "redis_endpoint" {
  description = "Primary endpoint of the Redis replication group."
  value       = module.redis.primary_endpoint
}

output "rds_security_group_id" {
  description = "Security group for the RDS instance."
  value       = module.rds.security_group_id
}

output "redis_security_group_id" {
  description = "Security group for the Redis cluster."
  value       = module.redis.security_group_id
}
