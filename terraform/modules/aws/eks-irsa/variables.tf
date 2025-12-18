variable "role_name" {
  description = "IAM role name."
  type        = string

  validation {
    condition     = length(trimspace(var.role_name)) > 0
    error_message = "role_name must be a non-empty string."
  }
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN."
  type        = string

  validation {
    condition     = length(trimspace(var.oidc_provider_arn)) > 0
    error_message = "oidc_provider_arn must be a non-empty string."
  }
}

variable "oidc_provider_url" {
  description = "OIDC provider issuer URL used in IAM condition keys. If null, the URL is derived from oidc_provider_arn. Accepts values with or without https:// and with or without a trailing slash."
  type        = string
  default     = null

  validation {
    condition     = var.oidc_provider_url == null || length(trimspace(var.oidc_provider_url)) > 0
    error_message = "oidc_provider_url must be a non-empty string when provided."
  }
}

variable "service_accounts" {
  description = "List of Kubernetes service accounts allowed to assume this role. Provide either this (non-empty) OR namespace+service_account_name for a single service account."
  type = list(object({
    namespace            = string
    service_account_name = string
  }))
  default = []

  validation {
    condition = alltrue([
      for sa in var.service_accounts :
      length(trimspace(sa.namespace)) > 0 && length(trimspace(sa.service_account_name)) > 0
    ])
    error_message = "service_accounts entries must include non-empty namespace and service_account_name."
  }

  validation {
    condition = (
      (length(var.service_accounts) > 0 && var.namespace == null && var.service_account_name == null) ||
      (length(var.service_accounts) == 0 && var.namespace != null && var.service_account_name != null)
    )
    error_message = "Configure at least one service account using exactly one style: service_accounts (non-empty) OR both namespace and service_account_name (not both)."
  }
}

variable "namespace" {
  description = "Kubernetes namespace (single-service-account convenience). Must be set together with service_account_name when service_accounts is empty."
  type        = string
  default     = null

  validation {
    condition     = var.namespace == null || length(trimspace(var.namespace)) > 0
    error_message = "namespace must be a non-empty string when provided."
  }
}

variable "service_account_name" {
  description = "Kubernetes service account name (single-service-account convenience). Must be set together with namespace when service_accounts is empty."
  type        = string
  default     = null

  validation {
    condition     = var.service_account_name == null || length(trimspace(var.service_account_name)) > 0
    error_message = "service_account_name must be a non-empty string when provided."
  }
}

variable "policy_arns" {
  description = "List of managed policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "inline_policy" {
  description = "Optional inline policy JSON document."
  type        = string
  default     = null

  validation {
    condition     = var.inline_policy == null || can(jsondecode(var.inline_policy))
    error_message = "inline_policy must be valid JSON when provided."
  }
}

variable "permissions_boundary" {
  description = "Optional permissions boundary policy ARN to apply to the role."
  type        = string
  default     = null
}

variable "path" {
  description = "Optional path for the role."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Optional maximum session duration in seconds for the role (3600-43200)."
  type        = number
  default     = null

  validation {
    condition     = var.max_session_duration == null || (var.max_session_duration >= 3600 && var.max_session_duration <= 43200)
    error_message = "max_session_duration must be between 3600 and 43200 seconds when provided."
  }
}

variable "description" {
  description = "Optional description for the IAM role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to the role."
  type        = map(string)
  default     = {}
}
