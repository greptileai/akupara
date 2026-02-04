#!/bin/bash
# Restart Greptile services when environment variables have changed
# Usage: ./restart-greptile.sh [--force]
#
# This script:
#   1. Checks if env files (.env, .env.greptile-generated, .env.hatchet-generated) have changed
#   2. Recreates Greptile containers if changes detected or --force flag is used
#   3. Updates stored checksums for future comparisons
#
# Note: Uses --force-recreate to ensure containers pick up new environment variables.
#       A simple restart won't apply env var changes.
#
# Options:
#   --force  Force recreate even if no changes detected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
CHECKSUM_FILE="${PROJECT_DIR}/.env.checksums"

FORCE_RESTART=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE_RESTART=true
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--force]"
      echo ""
      echo "Recreates Greptile services when environment variables have changed."
      echo ""
      echo "Options:"
      echo "  --force  Force recreate even if no changes detected"
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1"
      exit 1
      ;;
  esac
  shift
done

cd "$PROJECT_DIR"

# Check if Docker is accessible
if ! docker info > /dev/null 2>&1; then
    echo "Error: Cannot access Docker. Please check that Docker is running."
    exit 1
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo "Error: .env file not found in docker directory."
    echo "Please run ./bin/start-hatchet.sh first to create the environment file."
    exit 1
fi

# Function to calculate checksum of env files
calculate_checksum() {
    local checksum=""
    for env_file in .env .env.greptile-generated .env.hatchet-generated; do
        if [[ -f "$env_file" ]]; then
            checksum="${checksum}$(md5sum "$env_file" 2>/dev/null | cut -d' ' -f1)"
        fi
    done
    echo "$checksum" | md5sum | cut -d' ' -f1
}

# Get current checksum
current_checksum=$(calculate_checksum)

# Get stored checksum
stored_checksum=""
if [[ -f "$CHECKSUM_FILE" ]]; then
    stored_checksum=$(cat "$CHECKSUM_FILE" 2>/dev/null || echo "")
fi

# Check if recreate is needed
if [[ "$FORCE_RESTART" == "true" ]]; then
    echo "Force recreate requested - recreating Greptile services..."
    RECREATE_NEEDED=true
elif [[ "$current_checksum" != "$stored_checksum" ]]; then
    echo "Environment variables have changed - recreating Greptile services..."
    RECREATE_NEEDED=true
else
    echo "No environment variable changes detected. Use --force to recreate anyway."
    exit 0
fi

# Source env files for docker-compose variable interpolation
if [[ -f .env.greptile-generated ]]; then
  set -a
  source .env.greptile-generated
  set +a
fi

# Determine compose profiles
COMPOSE_PROFILES="--profile greptile"
AUTH_SAML_ONLY=$(grep -E "^AUTH_SAML_ONLY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "false")
if [[ "${AUTH_SAML_ONLY:-false}" == "true" ]]; then
    COMPOSE_PROFILES="$COMPOSE_PROFILES --profile saml"
fi

# Recreate services to pick up new env vars
# Using --force-recreate ensures containers are recreated with new environment variables
# Note: This does NOT recreate volumes - volumes are preserved (data remains intact)
echo "Recreating Greptile services..."
docker compose $COMPOSE_PROFILES up -d --force-recreate

# Save new checksum
echo "$current_checksum" > "$CHECKSUM_FILE"

echo ""
echo "Greptile services recreated successfully."
echo "You can check service status with: docker compose ps"
