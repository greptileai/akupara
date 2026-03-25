#!/usr/bin/env bash
# Set up environment files from examples if they don't exist
# Usage: setup-env.sh
#
# Creates:
#   - .env from .env.example (if not present)
#   - Caddyfile from Caddyfile.example (if not present)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

log() {
  echo "[setup-env] $1"
}

cd "$PROJECT_DIR"

# Create .env from .env.example if it doesn't exist
if [[ ! -f ".env" ]]; then
  if [[ -f ".env.example" ]]; then
    log "Creating .env from .env.example..."
    cp .env.example .env
    log ".env file created successfully"
  else
    log "ERROR: .env.example file not found"
    exit 1
  fi
else
  log ".env already exists, skipping"
fi

# Create Caddyfile from Caddyfile.example if it doesn't exist
if [[ ! -f "Caddyfile" ]]; then
  if [[ -f "Caddyfile.example" ]]; then
    log "Creating Caddyfile from Caddyfile.example..."
    cp Caddyfile.example Caddyfile
    log "Caddyfile created successfully"
  else
    log "ERROR: Caddyfile.example file not found"
    exit 1
  fi
else
  log "Caddyfile already exists, skipping"
fi

log "Environment setup complete"
