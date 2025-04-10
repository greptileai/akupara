variable "aws_region" {
  description = "Configure region to same region as Greptile AMI"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "The AWS Credential profile"
  type        = string
  default     = "default"
}