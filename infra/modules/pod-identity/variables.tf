variable "iam_role_name" {
  type        = string
  description = "IAM role name"
}

variable "cluster_name" {
  type = string
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the service account"
}

variable "service_account" {
  type        = string
  description = "Kubernetes service account that gets this role"
}

variable "policy_json" {
  type        = string
  description = "Inline IAM policy document for the role"
  default     = null
}

variable "managed_policy_arns" {
  type    = list(string)
  default = []
}
