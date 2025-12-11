#!/bin/bash
# Registry authentication helper for ECR or Docker Hub
# Usage: ./login_registry.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found. Run start_hatchet.sh first to create it."
    exit 1
fi

# Source environment variables
REGISTRY_PROVIDER=$(grep -E "^REGISTRY_PROVIDER=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
CONTAINER_REGISTRY=$(grep -E "^CONTAINER_REGISTRY=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
AWS_ECR_REGION=$(grep -E "^AWS_ECR_REGION=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
AWS_PROFILE=$(grep -E "^AWS_PROFILE=" "$ENV_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | grep -v '^#')

PROVIDER="${REGISTRY_PROVIDER:-dockerhub}"

if [ -z "$CONTAINER_REGISTRY" ]; then
    echo "Error: CONTAINER_REGISTRY not set in .env"
    exit 1
fi

case "$PROVIDER" in
    ecr)
        echo "Logging into AWS ECR..."
        REGION="${AWS_ECR_REGION:-us-east-1}"
        PROFILE_ARG=""
        if [ -n "$AWS_PROFILE" ]; then
            PROFILE_ARG="--profile $AWS_PROFILE"
        fi
        # Extract registry host (everything before first /)
        REGISTRY_HOST="${CONTAINER_REGISTRY%%/*}"
        aws ecr get-login-password --region "$REGION" $PROFILE_ARG \
            | docker login --username AWS --password-stdin "$REGISTRY_HOST"
        ;;
    dockerhub)
        echo "Logging into Docker Hub..."
        echo "Please enter your Docker Hub credentials or token:"
        docker login
        ;;
    *)
        echo "Error: Unknown REGISTRY_PROVIDER '$PROVIDER'. Use 'ecr' or 'dockerhub'."
        exit 1
        ;;
esac

echo "Successfully authenticated with $PROVIDER registry."
