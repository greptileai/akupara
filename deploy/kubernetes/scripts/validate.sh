#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="$ROOT_DIR/charts/greptile"
PROFILES_DIR="$ROOT_DIR/charts/profiles"

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required for validation but was not found in PATH"
  exit 127
fi

helm dependency update "$CHART_DIR"
helm lint "$CHART_DIR"
helm template greptile "$CHART_DIR" -f "$PROFILES_DIR/values-prod.yaml" >/dev/null
helm template greptile "$CHART_DIR" -f "$PROFILES_DIR/values-staging.yaml" >/dev/null
helm template greptile "$CHART_DIR" -f "$PROFILES_DIR/values-dev.yaml" >/dev/null

echo "Helm validation passed"
