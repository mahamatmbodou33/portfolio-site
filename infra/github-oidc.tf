locals {
  oidc_host = "token.actions.githubusercontent.com"
  gh_owner  = split("/", var.github_repo)[0]
  gh_name   = split("/", var.github_repo)[1]
  # GitHub's immutable subject format: repo:owner@ID/name@ID
  sub_prefix = "repo:${local.gh_owner}@${var.github_owner_id}/${local.gh_name}@${var.github_repo_id}"
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://${local.oidc_host}"
}

locals {
  oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

data "aws_iam_policy_document" "github_trust" {
  for_each = {
    deploy = "${local.sub_prefix}:ref:refs/heads/main"
    plan   = "${local.sub_prefix}:pull_request"
    apply  = "${local.sub_prefix}:environment:production"
  }
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = [each.value]
    }
  }
}

# --- deploy role
resource "aws_iam_role" "deploy" {
  name               = "${var.project_name}-gha-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_trust["deploy"].json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.site.arn]
  }
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
  statement {
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-site"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

# --- plan role (pull requests)
resource "aws_iam_role" "tf_plan" {
  name               = "${var.project_name}-gha-tf-plan"
  assume_role_policy = data.aws_iam_policy_document.github_trust["plan"].json
}

resource "aws_iam_role_policy_attachment" "tf_plan_readonly" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "tf_plan_state" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "tf_plan_state" {
  name   = "terraform-state-lock"
  role   = aws_iam_role.tf_plan.id
  policy = data.aws_iam_policy_document.tf_plan_state.json
}

# --- apply role (production environment only)
resource "aws_iam_role" "tf_apply" {
  name               = "${var.project_name}-gha-tf-apply"
  assume_role_policy = data.aws_iam_policy_document.github_trust["apply"].json
}

resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
