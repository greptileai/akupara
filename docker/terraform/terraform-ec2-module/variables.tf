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
  default     = "t3.xlarge"
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
