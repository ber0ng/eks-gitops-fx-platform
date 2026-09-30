provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "fxwatch"
      Stack     = var.environment
      ManagedBy = "Terraform"
    }
  }
}
