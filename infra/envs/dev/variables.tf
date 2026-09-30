variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to use for the EKS cluster."
  type        = string
  default     = "1.35"
}
