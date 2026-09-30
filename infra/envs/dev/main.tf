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

module "rds" {
  source = "../../modules/rds"

  name                       = local.name
  vpc_id                     = module.network.vpc_id
  db_subnet_group_name       = module.network.database_subnet_group_name
  allowed_security_group_ids = [module.eks.node_security_group_id]

  # Dev only
  deletion_protection   = false
  skip_final_snapshot   = true
  backup_retention_days = 1
}

