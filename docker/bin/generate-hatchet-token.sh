#!/usr/bin/env bash
# Generate Hatchet client token for Greptile authentication
# Usage: generate-hatchet-token.sh
#
# This script:
#   1. Waits for Hatchet services to be healthy
#   2. Generates a new token via hatchet-admin CLI
#   3. Updates HATCHET_CLIENT_TOKEN in .env
#   4. Creates sentinel file .hatchet-token-ready
#
# Exit codes:
#   0 - Token generated or already exists
#   1 - Error generating token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
ENV_FILE="${PROJECT_DIR}/.env"
SENTINEL_FILE="${PROJECT_DIR}/.hatchet-token-ready"

TENANT_ID_DEFAULT="707d0855-80ab-4e1f-a156-f1c4546cbf52"
TOKEN_NAME="auto-generated-by-greptile"
TOKEN_TTL="876000h"  # ~100 years
MAX_WAIT=120

log() {
  echo "[generate-hatchet-token] $1"
}

# Get value from .env file
get_env_value() {
  local key="$1"
  local value
  value=$(awk -F'=' -v k="$key" '
    $1==k {
      $1=""; sub(/^=/, ""); print $0
    }
  ' "$ENV_FILE" | head -n1)
  # Strip quotes and carriage returns
  value="${value%%$'\r'}"
  value="${value%%\"}"
  value="${value##\"}"
  value="${value%%\'}"
  value="${value##\'}"
  echo "$value"
}

# Update or add a key=value in .env
update_env_file() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    # Update existing line
    awk -v k="$key" -v v="$value" '
      BEGIN { FS=OFS="=" }
      $1==k { print k, v; next }
      { print }
    ' "$ENV_FILE" > "${ENV_FILE}.tmp"
    mv "${ENV_FILE}.tmp" "$ENV_FILE"
  else
    # Append new line
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# Validate .env exists
if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: Missing $ENV_FILE"
  exit 1
fi

# Get tenant ID from env or use default
tenant_id=$(get_env_value "HATCHET_TENANT_ID")
if [[ -z "$tenant_id" ]]; then
  tenant_id="$TENANT_ID_DEFAULT"
fi

# Check if token already exists
existing_token=$(get_env_value "HATCHET_CLIENT_TOKEN")
if [[ -f "$SENTINEL_FILE" && -n "$existing_token" ]]; then
  log "Hatchet token already generated; skipping"
  exit 0
fi

log "Ensuring Hatchet services are healthy before generating token"

# Wait for required Hatchet services using wait-for-service.sh
"${SCRIPT_DIR}/wait-for-service.sh" hatchet-rabbitmq "$MAX_WAIT" --profile hatchet
"${SCRIPT_DIR}/wait-for-service.sh" hatchet-api "$MAX_WAIT" --profile hatchet
"${SCRIPT_DIR}/wait-for-service.sh" hatchet-engine "$MAX_WAIT" --profile hatchet

log "Generating Hatchet token for tenant $tenant_id"

# Generate token via hatchet-admin CLI
set +o pipefail
new_token=$(docker compose --profile hatchet --project-directory "$PROJECT_DIR" run --rm --no-deps hatchet-setup-config \
  /hatchet/hatchet-admin token create \
  --config /hatchet/config \
  --tenant-id "$tenant_id" \
  --name "$TOKEN_NAME" \
  --expiresIn "$TOKEN_TTL" 2>&1 | tr -d '\r')
status=$?
set -o pipefail

if [[ $status -ne 0 || -z "$new_token" ]]; then
  log "ERROR: Failed to generate Hatchet token"
  log "Output: $new_token"
  exit 1
fi

log "Updating HATCHET_CLIENT_TOKEN in $ENV_FILE"
update_env_file "HATCHET_CLIENT_TOKEN" "$new_token"

# Create sentinel file to indicate token is ready
touch "$SENTINEL_FILE"
chmod 640 "$SENTINEL_FILE" 2>/dev/null || true

log "Hatchet token generated successfully"

# If running under systemd and greptile-app.service exists, trigger it
if command -v systemctl &>/dev/null && systemctl list-unit-files 2>/dev/null | grep -q '^greptile-app.service'; then
  log "Triggering greptile-app.service start"
  systemctl start greptile-app.service || true
fi
