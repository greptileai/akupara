#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DOCKER_ENV="$ROOT_DIR/deploy/docker-compose/.env.example"
ENV_TEMPLATE="$ROOT_DIR/deploy/kubernetes/charts/greptile/templates/configmap-env.yaml"
SECRET_TEMPLATE="$ROOT_DIR/deploy/kubernetes/charts/greptile/templates/secret.yaml"

if [[ ! -f "$DOCKER_ENV" ]]; then
  echo "deploy/docker-compose/.env.example not found"
  exit 1
fi

echo "Docker env keys not represented in chart templates (best-effort):"
while IFS= read -r key; do
  [[ -z "$key" ]] && continue
  if ! rg -q "${key}" "$ENV_TEMPLATE" "$SECRET_TEMPLATE"; then
    echo "  - $key"
  fi
done < <(grep -E "^[A-Z0-9_]+=" "$DOCKER_ENV" | cut -d'=' -f1)
