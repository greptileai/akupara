output "role_arn" {
  description = "IAM role ARN for ServiceAccount annotation."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name."
  value       = aws_iam_role.this.name
}

output "service_account_annotations" {
  description = "ServiceAccount annotations required to use this IRSA role."
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
  }
}

output "oidc_provider_url_normalized" {
  description = "OIDC provider URL normalized for IAM condition keys (no https://, no trailing slash)."
  value       = local.oidc_provider_url_normalized
}

output "service_account_subjects" {
  description = "Computed list of service account subjects allowed to assume this role."
  value       = local.service_account_subjects
}

output "assume_role_policy_json" {
  description = "Rendered assume role policy JSON for this IRSA role."
  value       = aws_iam_role.this.assume_role_policy
}

