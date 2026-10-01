data "aws_iam_openid_connect_provider" "oidc_provider" {
  url = "https://token.actions.githubusercontent.com"
}

# Immutable sub format pinning owner and repo IDs, e.g. repo:owner@123/name@456:ref:refs/heads/main
locals {
  subject = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"
}

# Plan role: runs on pull requests and read only

data "aws_iam_policy_document" "plan_role_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.subject}:pull_request",
        "${local.subject}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "plan_role" {
  name               = "fxwatch-gha-terraform-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_role_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "plan_role_readonly" {
  role       = aws_iam_role.plan_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan still needs to write to the state bucket to read the state file and plan changes. This is a temporary solution until we can implement a more secure approach.
data "aws_iam_policy_document" "plan_role_policy_document" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state_bucket.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.terraform_state_bucket.arn}/*"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "tfstate-access"
  role   = aws_iam_role.plan_role.id
  policy = data.aws_iam_policy_document.plan_role_policy_document.json
}

# Apply role: main branch only
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["${local.subject}:ref:refs/heads/main",
        "${local.subject}:environment:dev",
      ]
    }
  }
}

resource "aws_iam_role" "apply" {
  name               = "fxwatch-gha-terraform-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

# Broad on purpose for a sandbox account; tighten once the resource set is stable
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ECR push role: main branch only, push to fxwatch-* repos only
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecr_push_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.oidc_provider.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.subject}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "ecr_push" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/fxwatch-*",
    ]
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "fxwatch-gha-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.ecr_push_trust.json
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
