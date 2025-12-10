#!/bin/bash
# Start Greptile application services
# Usage: ./start_greptile.sh
#
# Prerequisites:
#   - .env file must exist (run start_hatchet.sh first)
#   - Hatchet services must be running
#   - HATCHET_CLIENT_TOKEN must be set (run bin/generate-hatchet-token.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Docker is accessible
if ! docker info > /dev/null 2>&1; then
    echo "Error: Cannot access Docker. Please check that:"
    echo "1. Docker is installed and running"
    echo "2. Your user has permission to access Docker (try running 'docker ps')"
    echo "3. You are a member of the 'docker' group (you can add yourself with 'sudo usermod -aG docker \$USER')"
    exit 1
fi

# Check if .env file exists
if [[ ! -f .env ]]; then
    echo "Error: .env file not found in docker directory."
    echo "Please run ./start_hatchet.sh first to create the environment file."
    exit 1
fi

# Generate application secrets if not already set
"${SCRIPT_DIR}/bin/generate-secrets.sh"

COMPOSE_PROFILES="--profile greptile"

echo "Starting Database..."
docker compose $COMPOSE_PROFILES up -d greptile-postgres

echo "Running database migrations..."
docker compose $COMPOSE_PROFILES up greptile-db-migration --wait || { echo "DB migration failed"; exit 1; }
echo "Database migrations completed successfully."

echo "Starting Greptile services..."

# Source .env to get AUTH_SAML_ONLY value
AUTH_SAML_ONLY=$(grep -E "^AUTH_SAML_ONLY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "false")

# Check if SAML authentication should be enabled
if [[ "${AUTH_SAML_ONLY:-false}" == "true" ]]; then
    echo "SAML authentication enabled - starting Jackson service..."
    COMPOSE_PROFILES="$COMPOSE_PROFILES --profile saml"
fi

# Start all app services together
docker compose $COMPOSE_PROFILES up -d --force-recreate

echo ""
echo "All Greptile services have been started."
echo "You can check service status with: docker compose ps"
