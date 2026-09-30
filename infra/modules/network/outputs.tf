output "vpc_id" {
  value       = aws_vpc.vpc.id
  description = "The ID of the VPC"
}

output "public_subnet_ids" {
  value       = aws_subnet.public_subnets[*].id
  description = "The IDs of the public subnets"
}

output "private_subnet_ids" {
  value       = aws_subnet.private_subnets[*].id
  description = "The IDs of the private subnets"
}

output "database_subnet_ids" {
  value       = aws_subnet.database_subnets[*].id
  description = "The IDs of the database subnets"
}

output "database_subnet_group_name" {
  value       = aws_db_subnet_group.db_subnet_group.name
  description = "The name of the database subnet group"
}
