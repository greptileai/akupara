#!/usr/bin/env bash
# Registry authentication helper for AWS ECR (and optionally Docker Hub).
#
# Reads config from /opt/greptile/.env:
#   - REGISTRY_PROVIDER: ecr|dockerhub (default: ecr)
#   - CONTAINER_REGISTRY: e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/greptile
#   - AWS_ECR_REGION (optional)
#   - DOCKERHUB_USERNAME / DOCKERHUB_TOKEN (optional, if REGISTRY_PROVIDER=dockerhub)

set -euo pipefail

log() {
  echo "[login-registry] $1"
}

ENV_FILE="/opt/greptile/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Missing $ENV_FILE (run /opt/greptile/bin/pull-secrets.sh first)"
  exit 1
fi

get_env_value() {
  local key="$1"
  local value
  value="$(awk -F'=' -v k="$key" '
    $1==k {
      $1=""; sub(/^=/, ""); print $0
    }
  ' "$ENV_FILE" | tail -n1)"
  value="${value%%$'\r'}"
  value="${value%%\"}"
  value="${value##\"}"
  value="${value%%\'}"
  value="${value##\'}"
  echo "$value"
}

provider="$(get_env_value "REGISTRY_PROVIDER")"
provider="${provider:-ecr}"
registry="$(get_env_value "CONTAINER_REGISTRY")"

if [[ -z "$registry" ]]; then
  log "ERROR: CONTAINER_REGISTRY not set in $ENV_FILE"
  exit 1
fi

registry_host="${registry%%/*}"
if [[ -z "$registry_host" ]]; then
  log "ERROR: Could not parse registry host from CONTAINER_REGISTRY=$registry"
  exit 1
fi

case "$provider" in
  ecr)
    if [[ "$registry_host" != *.dkr.ecr.*.amazonaws.com ]]; then
      log "Registry $registry_host is not an AWS ECR endpoint; skipping ECR login"
      exit 0
    fi

    default_region="$(get_env_value "AWS_ECR_REGION")"
    default_region="${default_region:-}"

    registry_region="${registry_host#*.dkr.ecr.}"
    registry_region="${registry_region%.amazonaws.com}"
    if [[ -z "$registry_region" || "$registry_region" == "$registry_host" ]]; then
      registry_region="$default_region"
    fi
    if [[ -z "$registry_region" ]]; then
      registry_region="us-east-1"
    fi

    log "Logging into ECR registry $registry_host (region $registry_region)"
    aws ecr get-login-password --region "$registry_region" | docker login --username AWS --password-stdin "$registry_host"
    log "ECR login succeeded"
    ;;
  dockerhub)
    username="$(get_env_value "DOCKERHUB_USERNAME")"
    token="$(get_env_value "DOCKERHUB_TOKEN")"
    if [[ -z "$username" || -z "$token" ]]; then
      log "ERROR: DOCKERHUB_USERNAME/DOCKERHUB_TOKEN must be set when REGISTRY_PROVIDER=dockerhub"
      exit 1
    fi
    log "Logging into Docker Hub as $username"
    printf '%s' "$token" | docker login --username "$username" --password-stdin
    log "Docker Hub login succeeded"
    ;;
  *)
    log "ERROR: Unknown REGISTRY_PROVIDER '$provider' (expected ecr|dockerhub)"
    exit 1
    ;;
esac
