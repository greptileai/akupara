mock_provider "aws" {}

mock_provider "tls" {
  mock_data "tls_certificate" {
    defaults = {
      certificates = [
        {
          sha1_fingerprint = "0000000000000000000000000000000000000000"
        }
      ]
    }
  }
}

variables {
  name_prefix        = "test"
  vpc_id             = "vpc-12345"
  private_subnet_ids = ["subnet-1", "subnet-2"]
  kubernetes_version = "1.31"
  tags               = { Environment = "test" }
}

run "creates_cluster_with_auto_mode" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.compute_config[0].enabled == true
    error_message = "EKS Auto Mode must be enabled"
  }

  assert {
    condition     = contains(aws_eks_cluster.this.compute_config[0].node_pools, "general-purpose")
    error_message = "general-purpose node pool must be configured"
  }
}

run "creates_oidc_provider" {
  command = plan

  assert {
    condition     = aws_iam_openid_connect_provider.eks != null
    error_message = "OIDC provider must be created for IRSA"
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.eks.client_id_list, "sts.amazonaws.com")
    error_message = "OIDC provider must allow sts.amazonaws.com"
  }
}

run "creates_required_iam_roles" {
  command = plan

  assert {
    condition     = aws_iam_role.cluster.name == "test-eks-cluster-role"
    error_message = "Cluster IAM role must use name_prefix"
  }

  assert {
    condition     = aws_iam_role.node.name == "test-eks-node-role"
    error_message = "Node IAM role must use name_prefix"
  }
}

run "enables_block_storage" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.storage_config[0].block_storage[0].enabled == true
    error_message = "Block storage must be enabled for EBS CSI"
  }
}

run "enables_load_balancing" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.kubernetes_network_config[0].elastic_load_balancing[0].enabled == true
    error_message = "Elastic load balancing must be enabled"
  }
}

run "installs_core_addons" {
  command = plan

  assert {
    condition     = aws_eks_addon.vpc_cni.addon_name == "vpc-cni"
    error_message = "vpc-cni addon must be installed"
  }

  assert {
    condition     = aws_eks_addon.kube_proxy.addon_name == "kube-proxy"
    error_message = "kube-proxy addon must be installed"
  }

  assert {
    condition     = aws_eks_addon.coredns.addon_name == "coredns"
    error_message = "coredns addon must be installed"
  }
}
