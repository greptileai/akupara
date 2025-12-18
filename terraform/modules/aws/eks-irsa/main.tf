locals {
  oidc_provider_url_derived = try(regex("oidc-provider/(.+)$", var.oidc_provider_arn)[0], "")
  oidc_provider_url_raw     = coalesce(var.oidc_provider_url, local.oidc_provider_url_derived)

  oidc_provider_url_normalized = trimsuffix(trimprefix(local.oidc_provider_url_raw, "https://"), "/")

  service_accounts_effective = length(var.service_accounts) > 0 ? var.service_accounts : (
    var.namespace != null && var.service_account_name != null ? [{
      namespace            = var.namespace
      service_account_name = var.service_account_name
    }] : []
  )

  service_account_subjects = [
    for sa in local.service_accounts_effective :
    "system:serviceaccount:${sa.namespace}:${sa.service_account_name}"
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${local.oidc_provider_url_normalized}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider_url_normalized}:sub" = local.service_account_subjects
        }
      }
    }]
  })
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = local.assume_role_policy
  description          = var.description
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary
  path                 = var.path

  tags = merge({
    Name = var.role_name
  }, var.tags)

  lifecycle {
    precondition {
      condition     = length(local.oidc_provider_url_normalized) > 0
      error_message = "oidc_provider_url could not be derived from oidc_provider_arn; provide oidc_provider_url explicitly (issuer URL without https://)."
    }

    precondition {
      condition     = length(local.service_account_subjects) > 0
      error_message = "Provide at least one service account via service_accounts or via namespace and service_account_name."
    }
  }
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy != null ? 1 : 0

  name   = "${var.role_name}-inline"
  role   = aws_iam_role.this.name
  policy = var.inline_policy
}
