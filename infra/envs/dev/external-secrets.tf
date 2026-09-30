# ESO may read only the rds master secret, nothing else in secrets manager
data "aws_iam_policy_document" "external_secret" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [module.rds.master_user_secret_arn]
  }
}

module "external_secrets_pod_identity" {
  source = "../../modules/pod-identity"

  iam_role_name   = "${local.name}-external-secrets"
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  policy_json     = data.aws_iam_policy_document.external_secret.json
}
