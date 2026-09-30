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
