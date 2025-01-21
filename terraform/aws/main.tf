###############################################################################
# 1) Provider and basic data
###############################################################################
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name = "${var.app_name}-eks"
}

###############################################################################
# 2) KMS Key (for encrypting RDS master password in Secrets Manager)
###############################################################################
module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.0"

  description          = "KMS key for RDS master password encryption"
  enable_key_rotation  = true
  deletion_window_in_days = 7

  # You can set key administrators, usage policies, etc., in additional inputs

  tags = {
    Name = "${var.app_name}-rds-kms"
  }
}

###############################################################################
# 3) VPC Module
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.app_name
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]     # For EKS nodes
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"] # For NLBs and NAT Gateway

  # Enable NAT Gateway for private subnet internet access
  enable_nat_gateway     = true
  single_nat_gateway     = true    # Use single NAT Gateway to save costs
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Tags required for EKS and ALB/NLB
  public_subnet_tags = {
    "kubernetes.io/role/elb"                               = 1
    "kubernetes.io/cluster/${local.cluster_name}"   = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}"   = "shared"
  }
}

###############################################################################
# 4) EKS Nodes Security Group
#    - So EKS nodes can talk to RDS/Redis using their SG references.
###############################################################################
resource "aws_security_group" "eks_nodes" {
  name        = "${var.app_name}-eks-nodes"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  # Allow all traffic between nodes
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###############################################################################
# 5) Security Group for RDS
###############################################################################
resource "aws_security_group" "rds" {
  name        = "${var.app_name}-rds"
  description = "Security group for RDS"
  vpc_id      = module.vpc.vpc_id

  # Allow PostgreSQL traffic from both EKS nodes and cluster
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [
      aws_security_group.eks_nodes.id,
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-rds-sg"
  }

  # This will help prevent the error by allowing Terraform to recreate rules
  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# 6) Security Group for Redis (ElastiCache)
###############################################################################
resource "aws_security_group" "redis" {
  name        = "${var.app_name}-redis"
  description = "Security group for Redis"
  vpc_id      = module.vpc.vpc_id

  # Allow Redis traffic from both EKS nodes and cluster
  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [
      aws_security_group.eks_nodes.id,
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-redis-sg"
  }

  # This will help prevent the error by allowing Terraform to recreate rules
  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# 7) Postgres RDS
#    - Manages random master password with AWS KMS encryption in Secrets Manager.
###############################################################################
resource "aws_db_instance" "db" {
  identifier = "${var.app_name}-db"
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = "db.m7g.large"
  allocated_storage     = 100
  max_allocated_storage = 1000
  storage_type          = "gp3"
  
  # Enable encryption with KMS
  storage_encrypted     = true
  kms_key_id           = module.kms.key_arn

  # Password management
  manage_master_user_password = true
  username = "postgres"

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Backup and maintenance
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"
  skip_final_snapshot    = true

  # Multi-AZ
  multi_az = false

  # Make sure these settings are present
  publicly_accessible    = false
  port                  = 5432

  tags = {
    Name = "${var.app_name}-rds"
  }
}

# Create DB subnet group separately
resource "aws_db_subnet_group" "this" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.app_name}-db-subnet-group"
  }
}

###############################################################################
# 8) Redis (ElastiCache) in private subnets
###############################################################################
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.app_name}-redis-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.app_name}-redis-subnet-group"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id        = "${var.app_name}-cache"
  engine            = "redis"
  node_type         = "cache.t3.micro"
  num_cache_nodes   = 1
  port              = 6379
  subnet_group_name = aws_elasticache_subnet_group.redis.name

  security_group_ids = [
    aws_security_group.redis.id
  ]

  tags = {
    Name = "${var.app_name}-redis"
  }
}

###############################################################################
# 9) EKS Cluster
###############################################################################
# 1. Create EKS Cluster Role
resource "aws_iam_role" "cluster" {
  name = "${var.app_name}-eks-cluster"

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
}

# 2. Create Node Role for Auto Mode
resource "aws_iam_role" "node" {
  name = "${var.app_name}-eks-node"

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
}

# 3. Attach required EKS policies
# Add inline policy to cluster role from EKSClusterRole.json
resource "aws_iam_role_policy" "cluster_custom_policy" {
  name = "${var.app_name}-eks-cluster-custom-policy"
  role = aws_iam_role.cluster.name
  policy = file("${path.module}/roles/EKSClusterRole.json")
}

# Add inline policy to node role from EKSWorkerRole.json
resource "aws_iam_role_policy" "node_custom_policy" {
  name = "${var.app_name}-eks-node-custom-policy"
  role = aws_iam_role.node.name
  policy = file("${path.module}/roles/EKSWorkerRole.json")
}

# 4. Create EKS Cluster with Auto Mode
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = "1.31"
  role_arn = aws_iam_role.cluster.arn

  # Disable self-managed addons for Auto Mode
  bootstrap_self_managed_addons = false

  # Enable Auto Mode compute
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  # Enable Auto Mode networking
  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  # Enable Auto Mode storage
  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids              = module.vpc.private_subnets  # Only private subnets for nodes
    endpoint_private_access = true
    endpoint_public_access  = true  # Keep this for kubectl access
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_custom_policy,
    aws_iam_role_policy_attachment.node_custom_policy
  ]
}

# 5. Enable kube-proxy add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  # Use the latest compatible version
  addon_version = "v1.30.6-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.main
  ]
}

# 6. Enable CoreDNS add-on
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"

  addon_version = "v1.11.4-eksbuild.2"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy
  ]
}

# 7. Enable VPC CNI add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  # Use the latest compatible version
  addon_version = "v1.19.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on = [
    aws_eks_cluster.main
  ]
}

###############################################################################
# 10) Your existing Secrets Manager resources (LLM, GitHub, App)
###############################################################################
# LLM Secrets
resource "aws_secretsmanager_secret" "llm_secrets" {
  count = var.openai_api_key != "" || var.anthropic_api_key != "" ? 1 : 0
  name  = "${var.app_name}-llm-secrets"
}

resource "aws_secretsmanager_secret_version" "llm_secrets" {
  count         = var.openai_api_key != "" || var.anthropic_api_key != "" ? 1 : 0
  secret_id     = aws_secretsmanager_secret.llm_secrets[0].id
  secret_string = jsonencode({
    "openai-key"    = coalesce(var.openai_api_key, "")
    "anthropic-key" = coalesce(var.anthropic_api_key, "")
  })
}

# GitHub Secrets
resource "aws_secretsmanager_secret" "github_secrets" {
  name = "${var.app_name}-github-secrets"
}

resource "aws_secretsmanager_secret_version" "github_secrets" {
  secret_id = aws_secretsmanager_secret.github_secrets.id
  secret_string = jsonencode({
    "clientId"      = var.github_client_id
    "clientSecret"  = var.github_client_secret
    "webhookSecret" = var.github_webhook_secret
    "privateKey"    = var.github_private_key
  })
}

# App Secrets
resource "aws_secretsmanager_secret" "app_secrets" {
  name = "${var.app_name}-app-secrets"
}

resource "random_id" "jwt_secret" {
  byte_length = 32
}

resource "random_password" "jackson_admin_password" {
  length  = 16
  special = false
}

resource "random_password" "jackson_client_secret_verifier" {
  length  = 32
  special = false
}

resource "random_password" "jackson_db_encryption_key" {
  length  = 32
  special = false
}

resource "tls_private_key" "jackson_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "jackson_cert" {
  private_key_pem = tls_private_key.jackson_key.private_key_pem

  subject {
    common_name = "${var.app_name}.local"
  }

  validity_period_hours = 8760  # 365 days

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "random_password" "boxyhq_api_key" {
  length  = 32
  special = false
}

# For more information: https://boxyhq.com/docs/jackson/deploy/env-variables
resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    "jwtSecret"                   = random_id.jwt_secret.b64_std
    "boxyhqApiKey"                = random_password.boxyhq_api_key.result
    "boxyhqSamlId"                = "dummy" # This should be ok: https://boxyhq.com/docs/jackson/deploy/env-variables#client_secret_verifier
    "jacksonAdminCredentials"     = "${var.saml_admin_email}:${var.saml_admin_password != "" ? var.saml_admin_password : random_password.jackson_admin_password.result}"
    "jacksonClientSecretVerifier" = random_password.jackson_client_secret_verifier.result
    "jacksonDbEncryptionKey"      = random_password.jackson_db_encryption_key.result
    "jacksonPrivateKey"           = base64encode(tls_private_key.jackson_key.private_key_pem)
    "jacksonPublicKey"            = base64encode(tls_self_signed_cert.jackson_cert.cert_pem)
  })
}

###############################################################################
# 11) OIDC Provider for EKS
###############################################################################

# Create OIDC Provider for the EKS cluster
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

###############################################################################
# 12) IRSA (attach to EKS pods)
###############################################################################

resource "aws_iam_policy" "bedrock" {
  name   = "${var.app_name}-bedrock-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeDomainInferenceProfiles"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      }
    ]
  })
}

# External Secrets IRSA
resource "aws_iam_role" "external_secrets" {
  name = "${var.app_name}-external-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:external-secrets-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "external_secrets" {
  name = "${var.app_name}-external-secrets-access"
  role = aws_iam_role.external_secrets.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
          "secretsmanager:ListSecrets"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# Query IRSA
resource "aws_iam_role" "query" {
  name = "${var.app_name}-query-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:query-sa"
          }
        }
      }
    ]
  })
}

# Indexer IRSA
resource "aws_iam_role" "indexer" {
  name = "${var.app_name}-indexer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:indexer-sa"
          }
        }
      }
    ]
  })
}

# Github IRSA
resource "aws_iam_role" "github" {
  name = "${var.app_name}-github-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:github-sa"
          }
        }
      }
    ]
  })
}

# Gitlab IRSA
resource "aws_iam_role" "gitlab" {
  name = "${var.app_name}-gitlab-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:gitlab-sa"
          }
        }
      }
    ]
  })
}

# Cloudwatch Agent IRSA
resource "aws_iam_role" "cloudwatch_agent" {
  name = "${var.app_name}-cloudwatch-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub": "system:serviceaccount:default:cloudwatch-agent-sa"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "query_bedrock" {
  policy_arn = aws_iam_policy.bedrock.arn
  role       = aws_iam_role.query.name
}

resource "aws_iam_role_policy_attachment" "indexer_bedrock" {
  policy_arn = aws_iam_policy.bedrock.arn
  role       = aws_iam_role.indexer.name
}

resource "aws_iam_role_policy_attachment" "github" {
  role       = aws_iam_role.github.name
  policy_arn = aws_iam_policy.bedrock.arn
}

resource "aws_iam_role_policy_attachment" "gitlab" {
  role       = aws_iam_role.gitlab.name
  policy_arn = aws_iam_policy.bedrock.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  name       = "${var.app_name}-cloudwatch-agent-policy"
  policy     = file("${path.module}/roles/CloudwatchAgentRole.json")
}

