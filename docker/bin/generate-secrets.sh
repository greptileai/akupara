#!/usr/bin/env bash
# Generate application secrets if they don't already exist
# Usage: generate-secrets.sh [--check-only]
#
# Checks for secrets in order of precedence:
#   1. .env (user-provided values)
#   2. .env.greptile-generated (previously auto-generated)
#
# If missing from both, generates to .env.greptile-generated file.
# Docker Compose loads this as an additional env_file.
#
# Secrets managed:
#   - JWT_SECRET
#   - TOKEN_ENCRYPTION_KEY
#   - LLM_PROXY_KEY (also sets LITELLM_MASTER_KEY to the same value)
#
# Options:
#   --check-only  Only check if secrets exist, don't generate

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
ENV_FILE="${PROJECT_DIR}/.env"
SECRETS_FILE="${PROJECT_DIR}/.env.greptile-generated"

CHECK_ONLY=false

log() {
  echo "[generate-secrets] $1"
}

# Generate random 32-character alphanumeric string
generate_random_string() {
  # Use openssl rand (non-blocking, fast, widely available)
  # Base64 gives us alphanumeric + / + =, so we filter to alphanumeric only
  # We generate 24 bytes (32 base64 chars) then filter to get 32 alphanumeric chars
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -d '\n' | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32
  # Fallback: use /dev/urandom (may block on low-entropy systems)
  else
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32
  fi
}

# Generate LiteLLM master key (must start with 'sk-' for virtual key compatibility)
generate_litellm_key() {
  # Generate 32 random alphanumeric chars and prefix with 'sk-'
  # Total length will be 35 chars (sk- + 32 chars)
  echo "sk-$(generate_random_string)"
}

# Check if a key has a non-empty value in a file
key_has_value_in_file() {
  local key="$1"
  local file="$2"
  [[ -f "$file" ]] && grep -qE "^${key}=.+" "$file" 2>/dev/null
}

# Get value of a key from a file
get_value_from_file() {
  local key="$1"
  local file="$2"
  if [[ -f "$file" ]]; then
    grep -E "^${key}=" "$file" 2>/dev/null | head -n1 | cut -d'=' -f2- | tr -d "'\""
  fi
}

# Check if secret exists (in .env or .env.greptile-generated)
secret_exists() {
  local key="$1"
  key_has_value_in_file "$key" "$ENV_FILE" || key_has_value_in_file "$key" "$SECRETS_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY=true
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--check-only]"
      echo ""
      echo "Generates secrets to .env.greptile-generated if not already set in .env"
      echo ""
      echo "Options:"
      echo "  --check-only  Only check if secrets exist, don't generate"
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1"
      exit 1
      ;;
  esac
  shift
done

# Validate .env exists
if [[ ! -f "$ENV_FILE" ]]; then
  log "ERROR: .env file not found at $ENV_FILE"
  log "Run setup-env.sh first to create .env from .env.example"
  exit 1
fi

SECRETS_TO_GENERATE=(
  "JWT_SECRET"
  "TOKEN_ENCRYPTION_KEY"
  "LLM_PROXY_KEY"
)

missing_secrets=()

# Check which secrets are missing
for secret in "${SECRETS_TO_GENERATE[@]}"; do
  if key_has_value_in_file "$secret" "$ENV_FILE"; then
    log "OK: $secret (from .env)"
  elif key_has_value_in_file "$secret" "$SECRETS_FILE"; then
    log "OK: $secret (from .env.greptile-generated)"
  else
    missing_secrets+=("$secret")
    if [[ "$CHECK_ONLY" == "true" ]]; then
      log "MISSING: $secret"
    fi
  fi
done

if [[ "$CHECK_ONLY" == "true" ]]; then
  if [[ ${#missing_secrets[@]} -gt 0 ]]; then
    log "${#missing_secrets[@]} secret(s) missing"
    exit 1
  else
    log "All secrets present"
    exit 0
  fi
fi

# Generate missing secrets to .env.greptile-generated
if [[ ${#missing_secrets[@]} -gt 0 ]]; then
  log "Generating ${#missing_secrets[@]} secret(s) to $SECRETS_FILE"

  # Read existing secrets file or start fresh
  declare -A existing_secrets
  if [[ -f "$SECRETS_FILE" ]]; then
    while IFS='=' read -r key value; do
      # Skip comments and empty lines
      [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
      existing_secrets["$key"]="$value"
    done < "$SECRETS_FILE"
  fi

  # Add missing secrets
  for secret in "${missing_secrets[@]}"; do
    log "Generating $secret..."
    # LLM_PROXY_KEY must start with 'sk-' for LiteLLM compatibility
    if [[ "$secret" == "LLM_PROXY_KEY" ]]; then
      existing_secrets["$secret"]=$(generate_litellm_key)
      # Also set LITELLM_MASTER_KEY to the same value
      existing_secrets["LITELLM_MASTER_KEY"]="${existing_secrets[$secret]}"
      log "Setting LITELLM_MASTER_KEY to same value as LLM_PROXY_KEY"
    else
      existing_secrets["$secret"]=$(generate_random_string)
    fi
  done
  
  # Ensure LITELLM_MASTER_KEY is set if LLM_PROXY_KEY exists but LITELLM_MASTER_KEY doesn't
  if [[ -n "${existing_secrets[LLM_PROXY_KEY]:-}" ]] && [[ -z "${existing_secrets[LITELLM_MASTER_KEY]:-}" ]]; then
    existing_secrets["LITELLM_MASTER_KEY"]="${existing_secrets[LLM_PROXY_KEY]}"
    log "Setting LITELLM_MASTER_KEY to existing LLM_PROXY_KEY value"
  fi

  # Write all secrets to file
  cat > "$SECRETS_FILE" << EOF
# Auto-generated by Greptile - do not edit
# To override, set values in .env instead (takes precedence)
EOF

  for key in "${!existing_secrets[@]}"; do
    echo "${key}=${existing_secrets[$key]}" >> "$SECRETS_FILE"
  done

  chmod 640 "$SECRETS_FILE" 2>/dev/null || true

  log "Generated ${#missing_secrets[@]} secret(s)"
else
  log "All secrets already present"
fi
