locals {
  public_subnet_ids  = toset(var.public_subnet_ids)
  private_subnet_ids = toset(var.private_subnet_ids)

  all_subnet_ids  = setunion(local.public_subnet_ids, local.private_subnet_ids)
  cluster_tag_key = "kubernetes.io/cluster/${var.cluster_name}"
}

resource "aws_ec2_tag" "cluster" {
  for_each = local.all_subnet_ids

  resource_id = each.value
  key         = local.cluster_tag_key
  value       = "shared"
}

resource "aws_ec2_tag" "public_role" {
  for_each = local.public_subnet_ids

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_role" {
  for_each = local.private_subnet_ids

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}
