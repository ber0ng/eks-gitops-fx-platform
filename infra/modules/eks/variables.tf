variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the EKS cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "node_instance_type" {
  description = "The EC2 instance type for the EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "node_capacity_type" {
  description = "The capacity type for the EKS worker nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be either 'ON_DEMAND' or 'SPOT'."
  }
}

variable "node_min_size" {
  description = "The minimum number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "The maximum number of worker nodes in the EKS node group"
  type        = number
  default     = 3
}

variable "node_desired_size" {
  description = "The desired number of worker nodes in the EKS node group"
  type        = number
  default     = 2
}
