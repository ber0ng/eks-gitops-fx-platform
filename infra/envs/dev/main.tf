locals {
  name = "fxwatch-${var.environment}"
  azs  = ["${var.region}a", "${var.region}b", "${var.region}c"]
}

module "network" {
  source = "../../modules/network"

  vpc_name           = local.name
  vpc_cidr           = "10.0.0.0/16"
  azs                = local.azs
  single_nat_gateway = true
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  node_capacity_type = "SPOT"
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = ["fxwatch-api", "fxwatch-worker", "fxwatch-frontend"]
  force_delete    = true # dev only
}
