output "repository_urls" {
  description = "The URLs of the ECR repositories."
  value       = [for k, v in aws_ecr_repository.ecr_repository : v.repository_url]
}
