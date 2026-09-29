terraform {
  backend "s3" {
    bucket       = "fxwatch-tfstate"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
