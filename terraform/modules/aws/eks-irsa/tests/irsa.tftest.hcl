mock_provider "aws" {}

variables {
  role_name         = "test-external-secrets"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"

  namespace            = "default"
  service_account_name = "external-secrets-sa"

  policy_arns   = []
  inline_policy = null
  tags          = {}
}

run "creates_role_with_oidc_trust" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "test-external-secrets"
    error_message = "Role name must match input"
  }

  assert {
    condition     = can(jsondecode(aws_iam_role.this.assume_role_policy))
    error_message = "Assume role policy must be valid JSON"
  }
}

run "derives_oidc_provider_url_from_arn" {
  command = plan

  assert {
    condition     = local.oidc_provider_url_normalized == "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    error_message = "OIDC provider URL should be derived from oidc_provider_arn when oidc_provider_url is null"
  }
}

run "trust_policy_scoped_to_service_accounts" {
  command = plan

  assert {
    condition = contains(
      keys(jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals),
      "${local.oidc_provider_url_normalized}:sub"
    )
    error_message = "Trust policy must scope to service account subjects"
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["${local.oidc_provider_url_normalized}:aud"] == "sts.amazonaws.com"
    error_message = "Trust policy must require aud=sts.amazonaws.com"
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["${local.oidc_provider_url_normalized}:sub"]) == 1
    error_message = "Single-service-account configuration should create a single subject"
  }
}

run "supports_multiple_service_accounts" {
  command = plan

  variables {
    namespace            = null
    service_account_name = null
    service_accounts = [
      {
        namespace            = "default"
        service_account_name = "query-sa"
      },
      {
        namespace            = "default"
        service_account_name = "indexer-sa"
      }
    ]
  }

  assert {
    condition     = length(local.service_account_subjects) == 2
    error_message = "service_account_subjects should include all provided service accounts"
  }

  assert {
    condition     = contains(local.service_account_subjects, "system:serviceaccount:default:query-sa")
    error_message = "service_account_subjects should include query-sa"
  }

  assert {
    condition     = contains(local.service_account_subjects, "system:serviceaccount:default:indexer-sa")
    error_message = "service_account_subjects should include indexer-sa"
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Condition.StringEquals["${local.oidc_provider_url_normalized}:sub"]) == 2
    error_message = "Trust policy should include all service account subjects"
  }
}

run "attaches_managed_policies" {
  command = plan

  variables {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonBedrockFullAccess",
      "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 1
    error_message = "Managed policy attachments must dedupe policy_arns"
  }
}

run "creates_inline_policy_when_provided" {
  command = plan

  variables {
    inline_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "*"
      }]
    })
  }

  assert {
    condition     = length(aws_iam_role_policy.inline) == 1
    error_message = "Inline policy must be created when provided"
  }
}

run "no_inline_policy_when_null" {
  command = plan

  variables {
    inline_policy = null
  }

  assert {
    condition     = length(aws_iam_role_policy.inline) == 0
    error_message = "No inline policy should be created when input is null"
  }
}

run "normalizes_oidc_provider_url_input" {
  command = plan

  variables {
    oidc_provider_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE/"
  }

  assert {
    condition     = local.oidc_provider_url_normalized == "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    error_message = "oidc_provider_url should be normalized (no scheme, no trailing slash)"
  }
}

