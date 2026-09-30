module "aws_lbc_pod_identity" {
  source = "../../modules/pod-identity"

  iam_role_name   = "${local.name}-aws-lbc"
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  policy_json     = file("${path.module}/policies/aws-load-balancer-controller.json")
}
