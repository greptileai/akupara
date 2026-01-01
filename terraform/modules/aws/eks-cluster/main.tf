locals {
  cluster_name = "${var.name_prefix}-eks"

  cluster_policy_arns = {
    eks_cluster     = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    eks_compute     = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
    eks_block_store = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
    eks_lb          = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
    eks_networking  = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  }

  node_policy_arns = {
    eks_worker_minimal = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
    ecr_pull_only      = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
    eks_cni            = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    ebs_csi_driver     = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  kube_proxy_addon_versions = {
    "1.30" = "v1.30.6-eksbuild.3"
    "1.31" = "v1.31.13-eksbuild.2"
  }

  addon_versions = {
    vpc_cni    = "v1.19.0-eksbuild.1"
    kube_proxy = lookup(local.kube_proxy_addon_versions, var.kubernetes_version, null)
    coredns    = "v1.11.4-eksbuild.2"
  }
}

resource "aws_iam_role" "cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["sts:AssumeRole", "sts:TagSession"]
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = merge({
    Name = "${var.name_prefix}-eks-cluster-role"
  }, var.tags)
}

resource "aws_iam_role" "node" {
  name = "${var.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = merge({
    Name = "${var.name_prefix}-eks-node-role"
  }, var.tags)
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = local.cluster_policy_arns

  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = local.node_policy_arns

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  bootstrap_self_managed_addons = false

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge({
    Name = local.cluster_name
  }, var.tags)

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_iam_role_policy_attachment.node,
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = local.addon_versions.vpc_cni
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.this,
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = local.addon_versions.kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"

  lifecycle {
    precondition {
      condition     = local.addon_versions.kube_proxy != null
      error_message = "No kube-proxy add-on version pin configured for Kubernetes ${var.kubernetes_version}. Add an entry to local.kube_proxy_addon_versions."
    }
  }

  depends_on = [
    aws_eks_cluster.this,
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = local.addon_versions.coredns
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role.ebs_csi,
  ]
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge({
    Name = "${var.name_prefix}-eks-oidc-provider"
  }, var.tags)
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.name_prefix}-ebs-csi-driver-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = merge({
    Name = "${var.name_prefix}-ebs-csi-driver-role"
  }, var.tags)
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = local.node_policy_arns.ebs_csi_driver
}
