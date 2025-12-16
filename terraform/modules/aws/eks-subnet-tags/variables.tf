variable "cluster_name" {
  description = "EKS cluster name used in the kubernetes.io/cluster/<name> subnet tag."
  type        = string

  validation {
    condition     = length(trimspace(var.cluster_name)) > 0
    error_message = "cluster_name must be a non-empty string."
  }
}

variable "public_subnet_ids" {
  description = "Subnet IDs eligible for internet-facing load balancers (kubernetes.io/role/elb)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.public_subnet_ids : length(trimspace(id)) > 0])
    error_message = "public_subnet_ids must contain non-empty subnet IDs."
  }

  validation {
    condition     = length(setintersection(toset(var.public_subnet_ids), toset(var.private_subnet_ids))) == 0
    error_message = "public_subnet_ids and private_subnet_ids must be disjoint; a subnet cannot be both public and private."
  }
}

variable "private_subnet_ids" {
  description = "Subnet IDs eligible for internal load balancers (kubernetes.io/role/internal-elb)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.private_subnet_ids : length(trimspace(id)) > 0])
    error_message = "private_subnet_ids must contain non-empty subnet IDs."
  }
}

