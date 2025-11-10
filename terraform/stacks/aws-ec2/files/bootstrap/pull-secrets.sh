#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="/opt/greptile/.env"
EXAMPLE_FILE="/opt/greptile/.env.example"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[greptile-bootstrap] No .env found; copying placeholder example so systemd has a file to bind." >&2
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  chmod 640 "$ENV_FILE"
fi

if grep -q "REPLACE_ME" "$ENV_FILE"; then
  echo "[greptile-bootstrap] Placeholder secrets detected. Update $ENV_FILE (from S3 or manual upload) before starting docker compose." >&2
  exit 0
fi

echo "[greptile-bootstrap] Environment file present; continuing"
