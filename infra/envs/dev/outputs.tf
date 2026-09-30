output "vpc_id" {
  value       = module.network.vpc_id
  description = "The ID of the VPC"
}

output "database_subnet_group_name" {
  value       = module.network.database_subnet_group_name
  description = "The name of the database subnet group"
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_address" {
  value = module.rds.address
}

output "rds_secret_arn" {
  value = module.rds.master_user_secret_arn
}
