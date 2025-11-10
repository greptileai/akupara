#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/opt/greptile/bootstrap.env"
ENV_FILE="/opt/greptile/.env"
EXAMPLE_FILE="/opt/greptile/.env.example"

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

BUCKET="${SECRETS_BUCKET:-}"
OBJECT="${SECRETS_OBJECT_KEY:-}"
downloaded=false

if [[ -n "$BUCKET" && -n "$OBJECT" ]]; then
  TMP_FILE=$(mktemp)
  if aws s3 cp "s3://${BUCKET}/${OBJECT}" "$TMP_FILE" >/dev/null; then
    echo "[greptile-bootstrap] Pulled secrets from s3://${BUCKET}/${OBJECT}"
    mv "$TMP_FILE" "$ENV_FILE"
    chmod 640 "$ENV_FILE"
    chown root:docker "$ENV_FILE" || true
    downloaded=true
  else
    echo "[greptile-bootstrap] WARNING: Failed to download s3://${BUCKET}/${OBJECT}; falling back to existing .env" >&2
    rm -f "$TMP_FILE"
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[greptile-bootstrap] No .env found; copying placeholder example so systemd has a file to bind." >&2
  cp "$EXAMPLE_FILE" "$ENV_FILE"
  chmod 640 "$ENV_FILE"
  chown root:docker "$ENV_FILE" || true
elif [[ $downloaded == false ]]; then
  echo "[greptile-bootstrap] Reusing existing /opt/greptile/.env"
fi

if grep -q "REPLACE_ME" "$ENV_FILE"; then
  echo "[greptile-bootstrap] Placeholder secrets detected. Replace sensitive values in $ENV_FILE before starting docker compose." >&2
fi

echo "[greptile-bootstrap] Environment file ready"
