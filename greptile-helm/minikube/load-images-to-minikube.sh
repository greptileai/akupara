#!/usr/bin/env bash
#
# load-images-to-minikube.sh – push a list of Greptile component images into the
#                  Minikube container runtime so the cluster can pull them
#
# Usage:
#   ./load-images-to-minikube.sh [registry] [tag]
#
#
# Example (local dev):
#   ./load-images-to-minikube.sh 600000000000.dkr.ecr.us-east-1.amazonaws.com/greptile grep-tag-x.x.x
#

set -euo pipefail

# -------- configurable inputs ----------------------------------------------
REGISTRY="${1:-600000000000.dkr.ecr.us-east-1.amazonaws.com/greptile}"
TAG="${2:-grep-tag-x.x.x}"

# Greptile components (add/remove here if you introduce new micro-services)
COMPONENTS=(
  db-migration
  vectordb-migration
  web
  auth
  api
  query
  chunker
  summarizer
  webhook
  reviews
  jobs
)
# ---------------------------------------------------------------------------

echo "🔄  Loading Greptile images into Minikube …"
echo "⤷ Registry : $REGISTRY"
echo "⤷ Tag      : $TAG"
echo

for comp in "${COMPONENTS[@]}"; do
  image="${REGISTRY}/${comp}:${TAG}"
  echo "  • $image"
  minikube image load "$image"
done

echo
echo "All images loaded successfully!"