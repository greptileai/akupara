global:
  region: ${aws_region}
  environment: ${environment}

ssm:
  prefix: ${ssm_prefix}
  kmsKeyArn: ${kms_key_arn}
  extraConfigKeys: ${jsonencode(ssm_config_extra_keys)}
  extraSecretKeys: ${jsonencode(ssm_secrets_extra_keys)}

ecr:
  registry: ${ecr_registry}

greptile:
  tag: ${greptile_tag}

irsa:
  externalSecrets: ${external_secrets_role_arn}
  indexer: ${indexer_role_arn}
  cloudwatch: ${cloudwatch_role_arn}

database:
  host: ${rds_host}

cloudwatchLogs:
  enabled: ${cloudwatch_logs_enabled}
  logGroupName: ${cloudwatch_log_group_name}

external-secrets:
  install: false
  installCRDs: false

hatchet:
  ingress:
    enabled: ${hatchet_ingress_enabled}
    host: ${jsonencode(hatchet_ingress_host)}
    annotations: ${jsonencode(hatchet_ingress_annotations)}
