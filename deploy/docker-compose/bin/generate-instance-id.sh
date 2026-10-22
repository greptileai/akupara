#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDENTITY_FILE="${SCRIPT_DIR}/../.env.greptile-instance"
UUID_PATTERN='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'

if [[ ! -e "$IDENTITY_FILE" ]]; then
  random=$(openssl rand -hex 16)
  variant=$(printf '%x' "$(( (16#${random:16:1} & 3) | 8 ))")
  instance_id="${random:0:8}-${random:8:4}-4${random:13:3}-${variant}${random:17:3}-${random:20:12}"
  temporary=$(mktemp "${IDENTITY_FILE}.XXXXXX")
  trap 'rm -f "$temporary"' EXIT
  printf 'GREPTILE_INSTANCE_ID=%s\n' "$instance_id" > "$temporary"
  # Publish a complete file atomically; a concurrent setup must keep the winning ID.
  if ! ln "$temporary" "$IDENTITY_FILE" 2>/dev/null && [[ ! -f "$IDENTITY_FILE" ]]; then
    echo '[instance-id] Could not create the persistent instance ID file.' >&2
    exit 1
  fi
fi

instance_id=$(sed -n 's/^GREPTILE_INSTANCE_ID=//p' "$IDENTITY_FILE")
if [[ ! "$instance_id" =~ $UUID_PATTERN ]]; then
  echo '[instance-id] Invalid .env.greptile-instance; restore the original UUID instead of regenerating it.' >&2
  exit 1
fi

echo '[instance-id] Persistent instance ID is ready.'
