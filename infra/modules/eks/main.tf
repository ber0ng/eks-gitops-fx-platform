# I use terraform modules to create an EKS cluster and its associated resources. The modules are sourced from the Terraform Registry and are versioned to ensure compatibility with the rest of the infrastructure code.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids

  # Run kubectl from the local machine instead of the EKS control plane. This is useful for running kubectl commands from the local machine without having to SSH into the EKS control plane.
  endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  addons = {
    vpc-cni = {
      before_compute = true
    }

    eks-pod-identity-agent = {
      before_compute = true
    }

    coredns    = {}
    kube-proxy = {}
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_type
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

    }


  }
}
