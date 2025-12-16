global:
  region: ${aws_region}
  environment: ${environment}

ssm:
  prefix: ${ssm_prefix}
  kmsKeyArn: ${kms_key_arn}

ecr:
  registry: ${ecr_registry}

greptile:
  tag: ${greptile_tag}

irsa:
  externalSecrets: ${external_secrets_role_arn}
  indexer: ${indexer_role_arn}
  query: ${query_role_arn}
  github: ${github_role_arn}
  gitlab: ${gitlab_role_arn}
  cloudwatch: ${cloudwatch_role_arn}

database:
  host: ${rds_host}

redis:
  host: ${redis_host}

cloudwatchLogs:
  enabled: ${cloudwatch_logs_enabled}
  logGroupName: ${cloudwatch_log_group_name}
  retentionInDays: ${cloudwatch_logs_retention_in_days}

