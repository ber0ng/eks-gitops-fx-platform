variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-2"
}

variable "state_bucket_name" {
  description = "The name of the S3 bucket to store Terraform state."
  type        = string
  default     = "fxwatch-tfstate"
}

variable "github_owner" {
  description = "The GitHub owner of the repository."
  type        = string
}

variable "github_repo" {
  description = "The GitHub repository name."
  type        = string
  default     = "eks-gitops-fx-platform"
}

variable "github_owner_id" {
  description = "The numeric ID of the GitHub repository owner."
  type        = string
}

variable "github_repo_id" {
  description = "The numeric ID of the GitHub repository."
  type        = string
}
