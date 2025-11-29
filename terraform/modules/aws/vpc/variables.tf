variable "name_prefix" {
  description = "Prefix used for naming all VPC-related resources."
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR block for the shared VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Ordered list of availability zones to use. If empty, the first two available AZs in the current region are used."
  type        = list(string)
  default     = []
}

variable "subnet_sets" {
  description = "Deployment slots (each with four subnets: public/private across two AZs)."
  type = list(object({
    name           = string
    public_a_cidr  = string
    public_b_cidr  = string
    private_a_cidr = string
    private_b_cidr = string
  }))
  default = [
    {
      name           = "slot1"
      public_a_cidr  = "10.0.0.0/24"
      public_b_cidr  = "10.0.1.0/24"
      private_a_cidr = "10.0.10.0/24"
      private_b_cidr = "10.0.11.0/24"
    },
    {
      name           = "slot2"
      public_a_cidr  = "10.0.2.0/24"
      public_b_cidr  = "10.0.3.0/24"
      private_a_cidr = "10.0.12.0/24"
      private_b_cidr = "10.0.13.0/24"
    },
    {
      name           = "slot3"
      public_a_cidr  = "10.0.4.0/24"
      public_b_cidr  = "10.0.5.0/24"
      private_a_cidr = "10.0.14.0/24"
      private_b_cidr = "10.0.15.0/24"
    },
    {
      name           = "slot4"
      public_a_cidr  = "10.0.6.0/24"
      public_b_cidr  = "10.0.7.0/24"
      private_a_cidr = "10.0.16.0/24"
      private_b_cidr = "10.0.17.0/24"
    },
    {
      name           = "slot5"
      public_a_cidr  = "10.0.8.0/24"
      public_b_cidr  = "10.0.9.0/24"
      private_a_cidr = "10.0.18.0/24"
      private_b_cidr = "10.0.19.0/24"
    }
  ]

  validation {
    condition     = length(var.subnet_sets) > 0
    error_message = "Provide at least one subnet set definition."
  }
}

variable "shared_subnets" {
  description = "Additional shared subnets for ingress-only or cross-cutting services. az_index refers to the AZ position (0 or 1)."
  type = map(object({
    type     = string # "public" or "private"
    cidr     = string
    az_index = number
  }))
  default = {
    shared_public_a = {
      type     = "public"
      cidr     = "10.0.200.0/24"
      az_index = 0
    }
    shared_public_b = {
      type     = "public"
      cidr     = "10.0.201.0/24"
      az_index = 1
    }
    shared_private_a = {
      type     = "private"
      cidr     = "10.0.210.0/24"
      az_index = 0
    }
    shared_private_b = {
      type     = "private"
      cidr     = "10.0.211.0/24"
      az_index = 1
    }
  }

  validation {
    condition = alltrue([
      for _, subnet in var.shared_subnets :
      contains(["public", "private"], lower(subnet.type)) && subnet.az_index >= 0 && subnet.az_index <= 1
    ])
    error_message = "shared_subnets entries must specify type public/private and an az_index of 0 or 1."
  }
}

variable "enable_nat_gateway" {
  description = "Create one NAT gateway per AZ for private subnet egress."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
