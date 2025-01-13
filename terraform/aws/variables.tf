variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "default"
}

variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "greptile"
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  default     = ""
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  default     = ""
}

variable "github_client_id" {
  description = "GitHub OAuth App client ID"
  type        = string
}

variable "github_client_secret" {
  description = "GitHub OAuth App client secret"
  type        = string
}

variable "github_webhook_secret" {
  description = "GitHub webhook secret"
  type        = string
}

variable "github_private_key" {
  description = "GitHub App private key"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where external-secrets will be deployed"
  type        = string
  default     = "default"
}

variable "saml_admin_email" {
  description = "SAML admin email"
  type        = string
  default     = "admin@greptile.com"
}

variable "saml_admin_password" {
  description = "SAML admin password"
  type        = string
  default     = ""
}