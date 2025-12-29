data "aws_caller_identity" "current" {}

locals {
  tags = merge({
    Stack       = "aws-eks"
    Environment = var.environment
  }, var.tags)

  ssm_prefix              = "/${var.name_prefix}"
  cloudwatch_log_group    = coalesce(var.cloudwatch_log_group_name, "/greptile/${var.name_prefix}/application")
  bedrock_full_access_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
  external_secrets_inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_prefix}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "ssm.${var.aws_region}.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  rds_endpoint_parts = split(":", module.rds.endpoint)
  rds_host           = local.rds_endpoint_parts[0]

  ssm_secrets_required = {
    "database-password"    = var.db_password
    "redis-auth-token"     = var.redis_auth_token
    "jwt-secret"           = var.jwt_secret
    "token-encryption-key" = var.token_encryption_key
  }

  ssm_secrets_optional = merge(
    var.anthropic_api_key != null && trimspace(var.anthropic_api_key) != "" ? { "anthropic-key" = var.anthropic_api_key } : {},
    var.openai_api_key != null && trimspace(var.openai_api_key) != "" ? { "openai-key" = var.openai_api_key } : {},
    var.github_client_secret != null && trimspace(var.github_client_secret) != "" ? { "github-client-secret" = var.github_client_secret } : {},
    var.github_webhook_secret != null && trimspace(var.github_webhook_secret) != "" ? { "github-webhook-secret" = var.github_webhook_secret } : {},
    var.github_private_key != null && trimspace(var.github_private_key) != "" ? { "github-private-key" = var.github_private_key } : {},
    var.llm_proxy_key != null && trimspace(var.llm_proxy_key) != "" ? { "llm-proxy-key" = var.llm_proxy_key } : {}
  )

  ssm_secrets = merge(local.ssm_secrets_required, local.ssm_secrets_optional, var.ssm_secrets)

  ssm_config_required = {
    "database-host"     = local.rds_host
    "database-port"     = "5432"
    "database-username" = var.db_username
    "database-name"     = var.db_name
    "redis-host"        = module.redis.primary_endpoint
    "redis-port"        = "6379"
    "aws-region"        = var.aws_region
  }

  ssm_config_optional = merge(
    var.github_client_id != null && trimspace(var.github_client_id) != "" ? { "github-client-id" = var.github_client_id } : {}
  )

  ssm_config = merge(local.ssm_config_required, local.ssm_config_optional, var.ssm_config)
}

module "eks" {
  source                 = "../../modules/aws/eks-cluster"
  name_prefix            = var.name_prefix
  vpc_id                 = var.vpc_id
  private_subnet_ids     = var.private_subnet_ids
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = var.endpoint_public_access
  tags                   = local.tags
}

module "eks_subnet_tags" {
  source = "../../modules/aws/eks-subnet-tags"

  cluster_name       = module.eks.cluster_name
  public_subnet_ids  = var.public_subnet_ids
  private_subnet_ids = var.private_subnet_ids
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.name_prefix}-aws-load-balancer-controller-policy"
  description = "Permissions for AWS Load Balancer Controller (${var.name_prefix})"
  policy      = file("${path.module}/aws-load-balancer-controller-iam-policy.json")
  tags        = local.tags
}

module "irsa_aws_load_balancer_controller" {
  source            = "../../modules/aws/eks-irsa"
  role_name         = "${var.name_prefix}-aws-load-balancer-controller-role"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace            = "kube-system"
  service_account_name = "aws-load-balancer-controller"

  # Use a stable ARN string so this module can be planned/tested without apply-time unknowns.
  policy_arns = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${aws_iam_policy.aws_load_balancer_controller.name}"]
  tags        = local.tags
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.16.0"

  timeout = 600
  wait    = true

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "defaultTargetType"
    value = "ip"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa_aws_load_balancer_controller.role_arn
  }

  depends_on = [
    module.eks,
    module.eks_subnet_tags,
    module.irsa_aws_load_balancer_controller,
  ]
}

resource "aws_kms_key" "ssm" {
  description             = "KMS key for SSM SecureString parameters (${var.name_prefix})"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "ssm" {
  name          = "alias/${var.name_prefix}-ssm"
  target_key_id = aws_kms_key.ssm.key_id
}

resource "aws_ssm_parameter" "secrets" {
  for_each = toset(keys(nonsensitive(local.ssm_secrets)))

  name   = "${local.ssm_prefix}/secrets/${each.value}"
  type   = "SecureString"
  value  = local.ssm_secrets[each.value]
  key_id = aws_kms_key.ssm.arn
  tags   = local.tags
}

resource "aws_ssm_parameter" "config" {
  for_each = local.ssm_config

  name  = "${local.ssm_prefix}/config/${each.key}"
  type  = "String"
  value = each.value
  tags  = local.tags
}

resource "aws_cloudwatch_log_group" "application" {
  count = var.cloudwatch_logs_enabled ? 1 : 0

  name              = local.cloudwatch_log_group
  retention_in_days = var.cloudwatch_logs_retention_in_days
  tags              = local.tags
}

module "irsa_external_secrets" {
  source            = "../../modules/aws/eks-irsa"
  role_name         = "${var.name_prefix}-external-secrets-role"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace            = var.k8s_namespace
  service_account_name = "external-secrets-sa"

  inline_policy = local.external_secrets_inline_policy
  tags          = local.tags
}

module "irsa_indexer" {
  source            = "../../modules/aws/eks-irsa"
  role_name         = "${var.name_prefix}-indexer-role"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace            = var.k8s_namespace
  service_account_name = "indexer-sa"

  policy_arns = [local.bedrock_full_access_arn]
  tags        = local.tags
}

module "irsa_cloudwatch" {
  source            = "../../modules/aws/eks-irsa"
  role_name         = "${var.name_prefix}-cloudwatch-role"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace            = var.k8s_namespace
  service_account_name = "cloudwatch-agent-sa"

  policy_arns = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
  tags        = local.tags
}

module "rds" {
  source                     = "../../modules/aws/rds-postgres"
  name_prefix                = "${var.name_prefix}-rds"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  db_identifier              = "${var.name_prefix}-postgres-db"
  db_name                    = var.db_name
  db_username                = var.db_username
  db_password                = var.db_password
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  storage_type               = var.db_storage_type
  iops                       = var.db_iops
  backup_retention_period    = var.db_backup_retention_period
  backup_window              = var.db_backup_window
  maintenance_window         = var.db_maintenance_window
  skip_final_snapshot        = var.db_skip_final_snapshot
  final_snapshot_identifier  = var.db_final_snapshot_identifier
  copy_tags_to_snapshot      = var.db_copy_tags_to_snapshot
  delete_automated_backups   = var.db_delete_automated_backups
  tags                       = local.tags
}

module "redis" {
  source                     = "../../modules/aws/redis-cluster"
  name_prefix                = "${var.name_prefix}-redis"
  vpc_id                     = var.vpc_id
  subnet_ids                 = var.private_subnet_ids
  allowed_security_group_ids = [module.eks.cluster_security_group_id]
  replication_group_id       = "${var.name_prefix}-redis"
  node_type                  = var.redis_node_type
  engine_version             = var.redis_engine_version
  auth_token                 = var.redis_auth_token
  tags                       = local.tags
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.k8s_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# This release uses the default `helm` provider configured in `providers.tf`,
# which points at the EKS cluster created by `module.eks` (cluster endpoint +
# CA cert) and authenticates via `aws eks get-token` (exec auth).
resource "helm_release" "greptile" {
  name      = "greptile"
  namespace = kubernetes_namespace.this.metadata[0].name
  chart     = "${path.module}/helm"

  dependency_update = true
  timeout           = 900
  wait              = true

  values = [
    templatefile("${path.module}/helm-values.yaml.tpl", {
      aws_region   = var.aws_region
      environment  = var.environment
      ecr_registry = var.ecr_registry
      greptile_tag = var.greptile_tag

      rds_host   = local.rds_host
      redis_host = module.redis.primary_endpoint

      ssm_prefix  = local.ssm_prefix
      kms_key_arn = aws_kms_key.ssm.arn

      external_secrets_role_arn = module.irsa_external_secrets.role_arn
      indexer_role_arn          = module.irsa_indexer.role_arn
      cloudwatch_role_arn       = module.irsa_cloudwatch.role_arn

      cloudwatch_logs_enabled           = var.cloudwatch_logs_enabled
      cloudwatch_log_group_name         = local.cloudwatch_log_group
      cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days

      hatchet_ingress_enabled     = var.hatchet_ingress_enabled
      hatchet_ingress_host        = var.hatchet_ingress_host
      hatchet_ingress_annotations = var.hatchet_ingress_annotations
    })
  ]

  depends_on = [
    module.eks,
    module.eks_subnet_tags,
    helm_release.aws_load_balancer_controller,
    module.rds,
    module.redis,
    module.irsa_external_secrets,
    module.irsa_indexer,
    module.irsa_cloudwatch,
    aws_ssm_parameter.secrets,
    aws_ssm_parameter.config,
  ]
}
