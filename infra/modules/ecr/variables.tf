variable "repository_name" {
  description = "The name of the ECR repository."
  type        = list(string)
}

variable "keep_last_images" {
  description = "The number of last images to keep in the ECR repository."
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Whether to force delete the ECR repository."
  type        = bool
  default     = false
}
