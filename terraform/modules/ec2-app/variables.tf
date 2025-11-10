variable "vpc_id" {
  description = "ID of the VPC that will contain the security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the EC2 instance will be launched."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance."
  type        = string
}

variable "instance_type" {
  description = "Instance type used for the EC2 instance."
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "Existing EC2 key pair for SSH access."
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name or ARN to attach to the instance."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix applied to resource names and tags."
  type        = string
  default     = "greptile"
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP with the instance (only works in public subnets)."
  type        = bool
  default     = true
}

variable "root_volume_size" {
  description = "Size of the EC2 root volume in GiB."
  type        = number
  default     = 40
}

variable "root_volume_type" {
  description = "EBS volume type for the root volume."
  type        = string
  default     = "gp3"
}

variable "root_volume_delete_on_termination" {
  description = "Whether the root volume should be deleted when the instance is terminated."
  type        = bool
  default     = true
}

variable "root_volume_encrypted" {
  description = "Whether to encrypt the root volume."
  type        = bool
  default     = true
}

variable "ingress_rules" {
  description = "Ingress rules applied to the security group. When null, sensible defaults are used."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = null

  validation {
    condition     = var.ingress_rules != null && length(var.ingress_rules) > 0
    error_message = "Provide at least one ingress rule with corporate CIDR blocks (e.g., 10.0.0.0/8)."
  }
}

variable "tags" {
  description = "Additional tags to apply to created resources."
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Optional user data script to run on instance launch."
  type        = string
  default     = null
}
