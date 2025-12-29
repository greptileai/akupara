global:
  region: ${aws_region}
  environment: ${environment}

ssm:
  prefix: ${ssm_prefix}
  kmsKeyArn: ${kms_key_arn}
  extraConfigKeys:
${indent(4, yamlencode(ssm_config_extra_keys))}
  extraSecretKeys:
${indent(4, yamlencode(ssm_secrets_extra_keys))}

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

redis:
  host: ${redis_host}

cloudwatchLogs:
  enabled: ${cloudwatch_logs_enabled}
  logGroupName: ${cloudwatch_log_group_name}

hatchet:
  ingress:
    enabled: ${hatchet_ingress_enabled}
    host: ${jsonencode(hatchet_ingress_host)}
    annotations:
${indent(6, yamlencode(hatchet_ingress_annotations))}
