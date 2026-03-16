#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILES_DIR="$ROOT_DIR/charts/profiles"
EXAMPLE_FILE="$PROFILES_DIR/values.user.example.yaml"
VALUES_FILE="${1:-$PROFILES_DIR/values.user.yaml}"

HATCHET_NAMESPACE="${HATCHET_NAMESPACE:-default}"
HATCHET_RELEASE="${HATCHET_RELEASE:-hatchet-stack}"
HATCHET_TENANT_ID="${HATCHET_TENANT_ID:-707d0855-80ab-4e1f-a156-f1c4546cbf52}"
HATCHET_TOKEN_NAME="${HATCHET_TOKEN_NAME:-auto-generated-by-greptile}"
HATCHET_TOKEN_TTL="${HATCHET_TOKEN_TTL:-876000h}"
HATCHET_WAIT_SECONDS="${HATCHET_WAIT_SECONDS:-180}"

log() {
  echo "[init-values] $1"
}

fail() {
  log "ERROR: $1"
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

escape_replacement() {
  printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

get_yaml_value() {
  local key="$1"
  local line
  line=$(grep -E "^[[:space:]]${key}:" "$VALUES_FILE" | head -n1 || true)
  line="${line#*:}"
  line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  line="${line%\"}"
  line="${line#\"}"
  printf '%s' "$line"
}

is_placeholder_value() {
  local value="$1"
  [[ -z "$value" || "$value" == "REPLACE_ME" || "$value" == "REPLACE_ME_32_CHARACTERS_LONG_KEY" ]]
}

set_yaml_value_if_placeholder() {
  local key="$1"
  local new_value="$2"
  local current
  current="$(get_yaml_value "$key")"
  if ! is_placeholder_value "$current"; then
    log "Keeping existing ${key}"
    return 0
  fi

  local escaped
  escaped="$(escape_replacement "$new_value")"
  sed -i.bak -E "s|^([[:space:]]*${key}:).*|\\1 \"${escaped}\"|" "$VALUES_FILE"
  rm -f "${VALUES_FILE}.bak"
  log "Set ${key}"
}

render_envfrom_yaml() {
  local deployment="$1"
  local namespace="$2"
  local envfrom=""
  local name

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    envfrom="${envfrom}
        - secretRef:
            name: ${name}"
  done < <(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{range .spec.template.spec.containers[0].envFrom[*]}{.secretRef.name}{"\n"}{end}' 2>/dev/null | sed '/^$/d')

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    envfrom="${envfrom}
        - configMapRef:
            name: ${name}"
  done < <(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{range .spec.template.spec.containers[0].envFrom[*]}{.configMapRef.name}{"\n"}{end}' 2>/dev/null | sed '/^$/d')

  printf '%s\n' "${envfrom#\\n}"
}

generate_hatchet_token() {
  require_cmd kubectl

  local api_deployment="${HATCHET_RELEASE}-api"
  local engine_deployment="${HATCHET_RELEASE}-engine"

  if ! kubectl get deployment "$api_deployment" -n "$HATCHET_NAMESPACE" >/dev/null 2>&1; then
    log "Hatchet deployment ${api_deployment} not found; leaving HATCHET_CLIENT_TOKEN unchanged"
    return 0
  fi

  log "Waiting for Hatchet API and engine"
  kubectl wait -n "$HATCHET_NAMESPACE" --for=condition=Available "deployment/${api_deployment}" --timeout="${HATCHET_WAIT_SECONDS}s" >/dev/null
  kubectl wait -n "$HATCHET_NAMESPACE" --for=condition=Available "deployment/${engine_deployment}" --timeout="${HATCHET_WAIT_SECONDS}s" >/dev/null

  local api_image
  api_image="$(kubectl get deployment "$api_deployment" -n "$HATCHET_NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')"
  [[ -n "$api_image" ]] || fail "Unable to determine Hatchet API image"
  local admin_image="${api_image/hatchet-api:/hatchet-admin:}"
  [[ "$admin_image" != "$api_image" ]] || fail "Unable to derive Hatchet admin image from ${api_image}"

  local envfrom_yaml
  envfrom_yaml="$(render_envfrom_yaml "$api_deployment" "$HATCHET_NAMESPACE")"
  [[ -n "$envfrom_yaml" ]] || fail "Unable to determine Hatchet envFrom sources from ${api_deployment}"

  local pod_name
  pod_name="hatchet-token-gen-$(date +%s)"
  local manifest
  manifest="$(mktemp)"

  cat >"$manifest" <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${pod_name}
  namespace: ${HATCHET_NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: hatchet-admin
      image: ${admin_image}
      command:
        - /bin/sh
        - -lc
        - |
          /hatchet/hatchet-admin token create \
            --tenant-id "${HATCHET_TENANT_ID}" \
            --name "${HATCHET_TOKEN_NAME}" \
            --expiresIn "${HATCHET_TOKEN_TTL}"
      envFrom:
${envfrom_yaml}
EOF

  kubectl delete pod "$pod_name" -n "$HATCHET_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true
  kubectl apply -f "$manifest" >/dev/null
  rm -f "$manifest"

  local phase=""
  local deadline=$((SECONDS + HATCHET_WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    phase="$(kubectl get pod "$pod_name" -n "$HATCHET_NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Succeeded" || "$phase" == "Failed" ]]; then
      break
    fi
    sleep 2
  done

  local logs
  logs="$(kubectl logs "$pod_name" -n "$HATCHET_NAMESPACE" 2>/dev/null || true)"
  kubectl delete pod "$pod_name" -n "$HATCHET_NAMESPACE" --ignore-not-found >/dev/null 2>&1 || true

  local token
  token="$(printf '%s\n' "$logs" | grep -E '^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' | head -n1 | tr -d '[:space:]')"
  if [[ -z "$token" ]]; then
    fail "Failed to generate Hatchet token. Output: ${logs}"
  fi

  set_yaml_value_if_placeholder "HATCHET_CLIENT_TOKEN" "$token"
}

main() {
  require_cmd openssl
  require_cmd perl

  if [[ ! -f "$EXAMPLE_FILE" ]]; then
    fail "Missing example values file at ${EXAMPLE_FILE}"
  fi

  if [[ ! -f "$VALUES_FILE" ]]; then
    cp "$EXAMPLE_FILE" "$VALUES_FILE"
    log "Created ${VALUES_FILE} from example"
  fi

  set_yaml_value_if_placeholder "JWT_SECRET" "$(openssl rand -base64 48 | tr -d '\n')"
  set_yaml_value_if_placeholder "TOKEN_ENCRYPTION_KEY" "$(openssl rand -hex 16)"
  set_yaml_value_if_placeholder "LITELLM_MASTER_KEY" "$(openssl rand -hex 32)"

  if is_placeholder_value "$(get_yaml_value "HATCHET_CLIENT_TOKEN")"; then
    generate_hatchet_token
  else
    log "Keeping existing HATCHET_CLIENT_TOKEN"
  fi

  log "Finished bootstrapping ${VALUES_FILE}"
}

main "$@"
