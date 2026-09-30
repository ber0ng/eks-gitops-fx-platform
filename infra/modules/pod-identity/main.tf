# Only the EKS pod identity service can assume this role
data "aws_iam_policy_document" "trust_policy" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "inline_policy" {
  count  = var.policy_json == null ? 0 : 1
  name   = "${var.iam_role_name}-policy"
  role   = aws_iam_role.iam_role.id
  policy = var.policy_json
}

resource "aws_iam_role_policy_attachment" "managed_policy" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.iam_role.name
  policy_arn = each.value
}

# Links the role to one specific service account in one namespace
resource "aws_eks_pod_identity_association" "pod_identity" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.service_account
  role_arn        = aws_iam_role.iam_role.arn
}
