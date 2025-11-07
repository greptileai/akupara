###################################################
# Variables
###################################################

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where EC2 will be placed."
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet where EC2 will be placed."
}

variable "ami_id" {
  type        = string
  description = "The custom AMI ID to launch."
}

variable "instance_type" {
  type        = string
  default     = "t3.2xlarge"
  description = "EC2 instance type."
}

variable "key_name" {
  type        = string
  description = "Name of an existing key pair in AWS for SSH access."
}

variable "name_prefix" {
  type        = string
  default     = "greptile"
  description = "Prefix for naming resources (SG, EC2)."
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile to associate with the EC2 instance"
  type        = string
  default     = null
}

variable "root_volume_size" {
  type        = number
  default     = 40
  description = "Size in GiB for the root volume."
}

variable "root_volume_type" {
  type        = string
  default     = "gp3"
  description = "EBS volume type for the root volume (used when root_volume_size is set)."
}

variable "root_volume_delete_on_termination" {
  type        = bool
  default     = true
  description = "Whether the root volume should be deleted when the instance is terminated."
}

variable "root_volume_encrypted" {
  type        = bool
  default     = true
  description = "Whether the root volume should be encrypted."
}
