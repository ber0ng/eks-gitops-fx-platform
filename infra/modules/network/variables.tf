variable "vpc_name" {
  description = "The name of the VPC to create"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "A list of availability zones to use for the subnets"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Whether to create a single NAT gateway or one per AZ"
  type        = bool
  default     = true
}
