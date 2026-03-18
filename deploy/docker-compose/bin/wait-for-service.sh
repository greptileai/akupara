#!/usr/bin/env bash
# Wait for a Docker Compose service to become healthy
# Usage: wait-for-service.sh <service-name> [max-wait-seconds] [--profile profile]
#
# Exit codes:
#   0 - Service is healthy
#   1 - Timeout waiting for service
#   2 - Service exited unexpectedly

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."

log() {
  echo "[wait-for-service] $1"
}

usage() {
  echo "Usage: $(basename "$0") <service-name> [max-wait-seconds] [--profile profile]"
  echo ""
  echo "Arguments:"
  echo "  service-name       Name of the Docker Compose service to wait for"
  echo "  max-wait-seconds   Maximum time to wait (default: 120)"
  echo "  --profile          Docker Compose profile to use (can be repeated)"
  exit 1
}

SERVICE=""
MAX_WAIT=120
PROFILES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      shift
      PROFILES+=("--profile" "$1")
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ -z "$SERVICE" ]]; then
        SERVICE="$1"
      elif [[ "$MAX_WAIT" == "120" && "$1" =~ ^[0-9]+$ ]]; then
        MAX_WAIT="$1"
      else
        echo "Error: Unknown argument: $1"
        usage
      fi
      ;;
  esac
  shift
done

if [[ -z "$SERVICE" ]]; then
  echo "Error: Service name is required"
  usage
fi

WAITED=0
INTERVAL=5

while true; do
  # Get container ID for the service
  container_id=$(docker compose --project-directory "$PROJECT_DIR" "${PROFILES[@]}" ps -q "$SERVICE" 2>/dev/null | head -n1 || true)

  if [[ -n "$container_id" ]]; then
    # Get container status and health
    status=$(docker inspect -f '{{.State.Status}}' "$container_id" 2>/dev/null || true)
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id" 2>/dev/null || true)

    # Container is ready if running and (no health check OR healthy)
    if [[ "$status" == "running" && ( -z "$health" || "$health" == "healthy" ) ]]; then
      log "$SERVICE is healthy"
      exit 0
    fi

    # Container exited unexpectedly
    if [[ "$status" == "exited" || "$status" == "dead" ]]; then
      log "ERROR: $SERVICE container exited unexpectedly (status: $status)"
      exit 2
    fi
  fi

  # Check timeout
  if [[ $WAITED -ge $MAX_WAIT ]]; then
    log "ERROR: Timeout waiting for $SERVICE to become healthy (waited ${MAX_WAIT}s)"
    exit 1
  fi

  log "Waiting for $SERVICE... (${WAITED}s)"
  sleep "$INTERVAL"
  WAITED=$((WAITED + INTERVAL))
done
