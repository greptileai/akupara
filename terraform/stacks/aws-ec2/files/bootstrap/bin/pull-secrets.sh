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
    echo "[greptile-bootstrap] ERROR: Failed to download s3://${BUCKET}/${OBJECT}" >&2
    rm -f "$TMP_FILE"
  fi
else
  echo "[greptile-bootstrap] WARNING: SECRETS_BUCKET/SECRETS_OBJECT_KEY not set; relying on existing /opt/greptile/.env" >&2
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[greptile-bootstrap] FATAL: /opt/greptile/.env does not exist. Upload secrets to S3 and rerun." >&2
  exit 1
elif [[ $downloaded == false ]]; then
  echo "[greptile-bootstrap] Reusing existing /opt/greptile/.env"
fi

if grep -q "REPLACE_ME" "$ENV_FILE"; then
  echo "[greptile-bootstrap] Placeholder secrets detected. Replace sensitive values in $ENV_FILE before starting docker compose." >&2
fi

echo "[greptile-bootstrap] Environment file ready"
