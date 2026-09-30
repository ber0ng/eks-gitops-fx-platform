output "address" {
  value = aws_db_instance.db_instance.address
}

output "port" {
  value = aws_db_instance.db_instance.port
}

output "db_name" {
  value = aws_db_instance.db_instance.db_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager secret holding the username and pw"
  value       = aws_db_instance.db_instance.master_user_secret[0].secret_arn
}

output "security_group_id" {
  value = aws_security_group.sg_rds.id
}
