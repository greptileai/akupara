#!/bin/bash
# Start Hatchet services (task queue infrastructure)
# Usage: ./start_hatchet.sh
#
# This script starts the Hatchet profile containers.
# Token generation is handled separately by bin/generate-hatchet-token.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Check if Docker is accessible
if ! docker info > /dev/null 2>&1; then
    echo "Error: Cannot access Docker. Please check that:"
    echo "1. Docker is installed and running"
    echo "2. Your user has permission to access Docker (try running 'docker ps')"
    echo "3. You are a member of the 'docker' group (you can add yourself with 'sudo usermod -aG docker \$USER')"
    exit 1
fi

# Set up environment files (.env, Caddyfile)
"${SCRIPT_DIR}/setup-env.sh"

echo "Starting Hatchet services..."

# Start only Hatchet-related services using the hatchet profile
docker compose --profile hatchet up -d --force-recreate

echo "Waiting for core services to be healthy..."

# Wait for essential services
"${SCRIPT_DIR}/wait-for-service.sh" hatchet-postgres 120 --profile hatchet
"${SCRIPT_DIR}/wait-for-service.sh" hatchet-rabbitmq 120 --profile hatchet

echo ""
echo "Hatchet services are up and running!"
echo "You can access the Hatchet UI at http://localhost:8080"
echo ""
echo "Next steps:"
echo "  1. Generate Hatchet token: ./bin/generate-hatchet-token.sh"
echo "  2. Start Greptile services: ./start_greptile.sh"
