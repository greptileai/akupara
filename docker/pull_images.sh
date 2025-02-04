#!/bin/bash
# Run this from the app root directory
# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="" # Default account ID
AWS_PROFILE="" # Default profile
ECR_REPO="greptile"
DEFAULT_SERVICES=("api" "auth" "query" "web" "chunker" "summarizer" "github" "gitlab" "db-migration" "vectordb-migration")
SERVICES=()

# Parse command line arguments
while getopts "s:a:p:" opt; do
  case $opt in
    s)
      # Split the service names by whitespace into array
      read -ra SERVICES <<< "$OPTARG"
      ;;
    a)
      AWS_ACCOUNT_ID="$OPTARG"
      ;;
    p)
      AWS_PROFILE="$OPTARG"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# If no services specified, use default list
if [ ${#SERVICES[@]} -eq 0 ]; then
    SERVICES=("${DEFAULT_SERVICES[@]}")
fi

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Login to ECR
echo "Logging in to Amazon ECR..."
aws ecr --profile ${AWS_PROFILE} get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Function to pull a service image
pull_image() {
    local service=$1
    local image_tag="0.1.4"
    local repo_name="${ECR_REPO}/${service}"
    local full_image_name="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${repo_name}:${image_tag}"
    
    echo -e "${GREEN}Pulling ${service} image from ECR...${NC}"
    
    # Specify the platform when pulling
    docker pull --platform linux/amd64 ${full_image_name} || return 1
    
    echo -e "${GREEN}Successfully pulled ${service} image!${NC}"
    echo "Image tag: ${full_image_name}"
}

# Pull all service images
for service in "${SERVICES[@]}"; do
    if pull_image ${service}; then
        echo -e "${GREEN}✓ ${service} pull completed successfully${NC}"
    else
        echo -e "${RED}✗ ${service} pull failed${NC}"
        exit 1
    fi
done

echo -e "${GREEN}All services have been pulled successfully!${NC}"
