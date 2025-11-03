output "endpoint" {
  description = "RDS endpoint hostname."
  value       = aws_db_instance.this.endpoint
}

output "security_group_id" {
  description = "Security group that protects the database."
  value       = aws_security_group.this.id
}

output "subnet_group" {
  description = "Name of the DB subnet group."
  value       = aws_db_subnet_group.this.name
}
