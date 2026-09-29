provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "fxwatch"
      Stack     = "bootstrap"
      ManagedBy = "Terraform"
    }
  }
}
