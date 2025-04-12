#!/bin/bash

# --- Configuration ---
EXAMPLE_ENV_FILE=".env.example" # the pre-built env template
ENV_FILE=".env" # the file configuration needed in the EC2

# --- Copy contents to .env ---
cp "$EXAMPLE_ENV_FILE" "$ENV_FILE"

# Function to safely double-quote environment variable values
quote_value() {
  local input="$1"
  printf '"%s"\n' "${input//\"/\\\"}"
}

# Function to convert .pem file to single-line string for GitHub App private key
# WIP
convert_github_app_private_key() {
    local pem_file="/opt/akupara/docker/github_app_private_key.pem"
    # Check if file exists
    if [ ! -f "$pem_file" ]; then
        echo "Error: GitHub App private key file not found at $pem_file"
        return 1
    fi
    # Safely read and join lines, ensuring newline characters are escaped
    # pem_single_line=$(awk 'BEGIN {ORS="\\n"} {gsub(/\\n/, ""); printf "%s", $0}' "$pem_file")
    #pem_single_line=$(awk '{printf "%s\\n", $0}' "$pem_file" | sed 's/\\\\n$//')
    #pem_single_line=$(awk '{printf "%s\\n", $0}' "$pem_file" | sed 's/$/\\n/g' | tr -d'\n')
    #pem_single_line=$(awk '{printf "%s\\n", $0}' "$pem_file" | tr -d '\n')
    #pem_single_line=$(awk '{printf "%s\\n", $0}' "$pem_file" | sed 's/[\\]*.$//')
    echo "$pem_single_line"
}

# Prompt the user for the tag version of Greptile
read -p "Enter the tag version of Greptile: " TAG_RAW
TAG=$(quote_value "$TAG_RAW")

# Prompt the user for Greptile's ECR registry
read -p "Enter the Greptile ECR Registry: " ECR_REGISTRY_RAW
ECR_REGISTRY=$(quote_value "$ECR_REGISTRY_RAW")

# Prompt the user for their EC2 instance IP
read -p "Enter EC2 instance IP address (exclude http://): " EC2_INSTANCE_IP_RAW
EC2_INSTANCE_IP=$(quote_value "$EC2_INSTANCE_IP_RAW")

# Prompt user for the AWS Bedrock Region
read -p "Enter region (i.e. us-east-1) of your Amazon Bedrock: " AWS_REGION_RAW
AWS_REGION=$(quote_value "$AWS_REGION_RAW")

# Prompt user for the Database host
read -p "Enter the hostname of your database (can be found from terraform output): " DB_HOST_RAW
DB_HOST=$(quote_value "$DB_HOST_RAW")

# Prompt user for the Database password
read -sp "Please enter the password for your database: " DB_PASSWORD_RAW
echo  # Add a newline after the password input
DB_PASSWORD=$(quote_value "$DB_PASSWORD_RAW")

# Prompt user for the Redis Host
read -p "Please enter the hostname of your Redis Cache: " REDIS_HOST_RAW
REDIS_HOST=$(quote_value "$REDIS_HOST_RAW")

# Prompt user for their JWT_SECRET
read -p "Please enter a random 32 character length secret for JWT: " JWT_SECRET_RAW
JWT_SECRET=$(quote_value "$JWT_SECRET_RAW")

# Prompt user for their TOKEN_ENCRYPTION_KEY
read -p "Please enter a random 32 character length key for encryption: " TOKEN_ENCRYPTION_KEY_RAW
TOKEN_ENCRYPTION_KEY=$(quote_value "$TOKEN_ENCRYPTION_KEY_RAW")

echo "Make sure you have your Github App configuration before proceeding ..."

# Prompt the user to choose between GitHub and GitHub Enterprise
while true; do
  echo "Choose your GitHub option:"
  echo "  1) GitHub"
  echo "  2) GitHub Enterprise"
  read -p "Enter your choice (1 or 2): " GITHUB_CHOICE

  case "$GITHUB_CHOICE" in
    1)
      GITHUB_OPTION="GITHUB"
      GITHUB_ENABLED="true"
      GITHUB_ENTERPRISE_ENABLED="false"
      echo "You selected GitHub."
      # Prompt user for their GITHUB_APP_ID
      read -p "Please enter your Github app id: " GITHUB_APP_ID_RAW
      GITHUB_APP_ID=$(quote_value "$GITHUB_APP_ID_RAW")
      # Prompt user for their GITHUB_APP_URL
      read -p "Please enter your Github app url: " GITHUB_APP_URL_RAW
      GITHUB_APP_URL=$(quote_value "$GITHUB_APP_URL_RAW")
      # Prompt user for their GITHUB_CLIENT_ID
      read -p "Please enter your Github client id: " GITHUB_CLIENT_ID_RAW
      GITHUB_CLIENT_ID=$(quote_value "$GITHUB_CLIENT_ID_RAW")
      # Prompt user for their GITHUB_CLIENT_SECRET
      read -p "Please enter your Github client secret: " GITHUB_CLIENT_SECRET_RAW
      GITHUB_CLIENT_SECRET=$(quote_value "$GITHUB_CLIENT_SECRET_RAW")

      # Convert private key to single-line string
      # Fetch and wrap the PEM key contents
      #pem_single_line=$(convert_github_app_private_key)
      #GITHUB_APP_PRIVATE_KEY=$(quote_value "$pem_single_line")

      # Set Enterprise-specific variables to empty string
      GITHUB_ENTERPRISE_APP_URL="\"\""
      GITHUB_ENTERPRISE_URL="\"\""
      GITHUB_ENTERPRISE_API_URL="\"\""
      GITHUB_ENTERPRISE_APP_ID="\"\""
      GITHUB_ENTERPRISE_CLIENT_ID="\"\""
      GITHUB_ENTERPRISE_CLIENT_SECRET="\"\""
      #GITHUB_ENTERPRISE_APP_PRIVATE_KEY="\"\""
      break ;;
    2)
      GITHUB_OPTION="GITHUB_ENTERPRISE"
      GITHUB_ENABLED="false"
      GITHUB_ENTERPRISE_ENABLED="true"
      echo "You selected GitHub Enterprise."
      # Prompt user for their GITHUB_ENTERPRISE_URL
      read -p "Please enter your Github Enterprise url: " GITHUB_ENTERPRISE_URL_RAW
      GITHUB_ENTERPRISE_URL=$(quote_value "$GITHUB_ENTERPRISE_URL_RAW")
      # Prompt user for their GITHUB_ENTERPRISE_API_URL
      read -p "Please enter your Github Enterprise api url: " GITHUB_ENTERPRISE_API_URL_RAW
      GITHUB_ENTERPRISE_API_URL=$(quote_value "$GITHUB_ENTERPRISE_API_URL_RAW")
      # Prompt user for their GITHUB_ENTERPRISE_APP_ID
      read -p "Please enter your Github Enterprise app id: " GITHUB_ENTERPRISE_APP_ID_RAW
      GITHUB_ENTERPRISE_APP_ID=$(quote_value "$GITHUB_ENTERPRISE_APP_ID_RAW")
      # Prompt user for their GITHUB_ENTERPRISE_APP_URL
      read -p "Please enter your Github Enterprise app url: " GITHUB_ENTERPRISE_APP_URL_RAW
      GITHUB_ENTERPRISE_APP_URL=$(quote_value "$GITHUB_ENTERPRISE_APP_URL_RAW")
      # Prompt user for their GITHUB_ENTERPRISE_CLIENT_ID
      read -p "Please enter your Github Enterprise client id: " GITHUB_ENTERPRISE_CLIENT_ID_RAW
      GITHUB_ENTERPRISE_CLIENT_ID=$(quote_value "$GITHUB_ENTERPRISE_CLIENT_ID_RAW")
      # Prompt user for their GITHUB_ENTERPRISE_CLIENT_SECRET
      read -p "Please enter your Github Enterprise client secret: " GITHUB_ENTERPRISE_CLIENT_SECRET_RAW
      GITHUB_ENTERPRISE_CLIENT_SECRET=$(quote_value "$GITHUB_ENTERPRISE_CLIENT_SECRET_RAW")

      # Convert private key to single-line string
      #GITHUB_ENTERPRISE_APP_PRIVATE_KEY=$(convert_github_app_private_key)
      #GITHUB_APP_PRIVATE_KEY=$GITHUB_ENTERPRISE_APP_PRIVATE_KEY

      # Set regular GitHub-specific variables to empty string
      GITHUB_APP_URL="\"\""
      GITHUB_APP_ID="\"\""
      GITHUB_CLIENT_ID="\"\""
      GITHUB_CLIENT_SECRET="\"\""
      break ;;
    *)
      echo "Invalid choice. Please enter either 1 or 2."
      ;;
  esac
done

# Prompt user for their GITHUB_WEBHOOK_URL
read -p "Please enter your Github webhook url: " GITHUB_WEBHOOK_URL_RAW
GITHUB_WEBHOOK_URL=$(quote_value "$GITHUB_WEBHOOK_URL_RAW")
# Prompt user for their GITHUB_WEBHOOK_SECRET
read -p "Please enter your Github webhook secret: " GITHUB_WEBHOOK_SECRET_RAW
GITHUB_WEBHOOK_SECRET=$(quote_value "$GITHUB_WEBHOOK_SECRET_RAW")

# --- Overwrite .env configuration ---
if [ -f "$ENV_FILE" ]; then
  echo "Overwriting environment variables in $ENV_FILE"
  sed -i "s|^TAG=.*$|TAG=$TAG|" "$ENV_FILE"
  sed -i "s|^ECR_REGISTRY=.*$|ECR_REGISTRY=$ECR_REGISTRY|" "$ENV_FILE"
  sed -i "s|^EC2_INSTANCE_IP=.*$|EC2_INSTANCE_IP=$EC2_INSTANCE_IP|" "$ENV_FILE"
  sed -i "s|^AWS_REGION=.*$|AWS_REGION=$AWS_REGION|" "$ENV_FILE"

  sed -i "s|^DB_HOST=.*$|DB_HOST=$DB_HOST|" "$ENV_FILE"
  sed -i "s|^DB_PASSWORD=.*$|DB_PASSWORD=$DB_PASSWORD|" "$ENV_FILE"

  sed -i "s|^REDIS_HOST=.*$|REDIS_HOST=$REDIS_HOST|" "$ENV_FILE"
  sed -i "s|^JWT_SECRET=.*$|JWT_SECRET=$JWT_SECRET|" "$ENV_FILE"
  sed -i "s|^TOKEN_ENCRYPTION_KEY=.*$|TOKEN_ENCRYPTION_KEY=$TOKEN_ENCRYPTION_KEY|" "$ENV_FILE"

  sed -i "s|^GITHUB_ENABLED=.*$|GITHUB_ENABLED=$GITHUB_ENABLED|" "$ENV_FILE"
  sed -i "s|^GITHUB_ENTERPRISE_ENABLED=.*$|GITHUB_ENTERPRISE_ENABLED=$GITHUB_ENTERPRISE_ENABLED|" "$ENV_FILE"

  sed -i "s|^GITHUB_APP_ID=.*$|GITHUB_APP_ID=${GITHUB_APP_ID}|" "$ENV_FILE"
  sed -i "s|^GITHUB_APP_URL=.*$|GITHUB_APP_URL=${GITHUB_APP_URL}|" "$ENV_FILE"
  #sed -i "s|^GITHUB_APP_PRIVATE_KEY=.*$|GITHUB_APP_PRIVATE_KEY=${GITHUB_APP_PRIVATE_KEY}|" "$ENV_FILE"
  sed -i "s|^GITHUB_CLIENT_ID=.*$|GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID|" "$ENV_FILE"
  sed -i "s|^GITHUB_CLIENT_SECRET=.*$|GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET|" "$ENV_FILE"

  sed -i "s|^GITHUB_ENTERPRISE_URL=.*$|GITHUB_ENTERPRISE_URL=$GITHUB_ENTERPRISE_URL|" "$ENV_FILE"
  sed -i "s|^GITHUB_ENTERPRISE_API_URL=.*$|GITHUB_ENTERPRISE_API_URL=$GITHUB_ENTERPRISE_API_URL|" "$ENV_FILE"
  sed -i "s|^GITHUB_ENTERPRISE_APP_ID=.*$|GITHUB_ENTERPRISE_APP_ID=$GITHUB_ENTERPRISE_APP_ID|" "$ENV_FILE"
  sed -i "s|^GITHUB_ENTERPRISE_APP_URL=.*$|GITHUB_ENTERPRISE_APP_URL=$GITHUB_ENTERPRISE_APP_URL|" "$ENV_FILE"
  #sed -i "s|^GITHUB_ENTERPRISE_APP_PRIVATE_KEY=.*$|GITHUB_ENTERPRISE_APP_PRIVATE_KEY=${GITHUB_ENTERPRISE_APP_PRIVATE_KEY}|" "$ENV_FILE"
  sed -i "s|^GITHUB_ENTERPRISE_CLIENT_ID=.*$|GITHUB_ENTERPRISE_CLIENT_ID=$GITHUB_ENTERPRISE_CLIENT_ID|" "$ENV_FILE"
  sed -i "s|^GITHUB_ENTERPRISE_CLIENT_SECRET=.*$|GITHUB_ENTERPRISE_CLIENT_SECRET=$GITHUB_ENTERPRISE_CLIENT_SECRET|" "$ENV_FILE"

  sed -i "s|^GITHUB_WEBHOOK_URL=.*$|GITHUB_WEBHOOK_URL=$GITHUB_WEBHOOK_URL|" "$ENV_FILE"
  sed -i "s|^GITHUB_WEBHOOK_SECRET=.*$|GITHUB_WEBHOOK_SECRET=$GITHUB_WEBHOOK_SECRET|" "$ENV_FILE"
else
  echo "Error: $ENV_FILE not found."
fi

echo "Environment variables in $ENV_FILE have been updated."

echo "Installation script finished."

exit 0