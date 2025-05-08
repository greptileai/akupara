#!/bin/bash

# Define the list of services
GREPTILE_SERVICES=(
    greptile_api_service
    greptile_auth_service
    greptile_indexer_chunker
    greptile_indexer_summarizer
    greptile_query_service
    greptile_web_service
    greptile_github_service
)

# Function to set GitHub environment variables for backwards compatibility
# TODO The github env variables should be refactored in the service side app logic
#  and then this helper function can be removed
set_github_env() {
    # Default to 'cloud' if not set
    GITHUB_TYPE=${GITHUB_TYPE:-cloud}

    # Set the enabled flags based on GITHUB_TYPE
    if [ "$GITHUB_TYPE" = "enterprise" ]; then
        export GITHUB_ENABLED=false
        export GITHUB_ENTERPRISE_ENABLED=true
        # For backwards compatibility set the enterprise variables to the cloud variables
        export GITHUB_ENTERPRISE_APP_URL=${GITHUB_APP_URL}
        export GITHUB_ENTERPRISE_APP_ID=${GITHUB_APP_ID}
        export GITHUB_ENTERPRISE_APP_PRIVATE_KEY=${GITHUB_PRIVATE_KEY}
        export GITHUB_ENTERPRISE_CLIENT_ID=${GITHUB_CLIENT_ID}
        export GITHUB_ENTERPRISE_CLIENT_SECRET=${GITHUB_CLIENT_SECRET}
    else
        export GITHUB_ENABLED=true
        export GITHUB_ENTERPRISE_ENABLED=false
        # Set enterprise-specific variables to empty values to prevent warning messages
        export GITHUB_ENTERPRISE_URL=""
        export GITHUB_ENTERPRISE_API_URL=""
        export GITHUB_ENTERPRISE_APP_URL=""
        export GITHUB_ENTERPRISE_APP_ID=""
        export GITHUB_ENTERPRISE_APP_PRIVATE_KEY=""
        export GITHUB_ENTERPRISE_CLIENT_ID=""
        export GITHUB_ENTERPRISE_CLIENT_SECRET=""
    fi
}


# Check if Docker is accessible
if ! docker info > /dev/null 2>&1; then
    echo "Error: Cannot access Docker. Please check that:"
    echo "1. Docker is installed and running"
    echo "2. Your user has permission to access Docker (try running 'docker ps')"
    echo "3. You are a member of the 'docker' group (you can add yourself with 'sudo usermod -aG docker $USER')"
    exit 1
fi

echo "Starting Greptile services..."
# Set GitHub environment variables
echo "Setting GitHub environment variables..."
set_github_env

# Start database migrations first
echo "Running database migrations..."
docker-compose up -d postgres

# Check if migrations were successful
docker-compose up greptile_vector_db_migration --wait || { echo "Vector DB migration failed"; exit 1; }
docker-compose up greptile_db_migration --wait || { echo "DB migration failed"; exit 1; }
    echo "Database migrations failed. Exiting..."
    exit 1
fi

echo "Database migrations completed successfully."

# Start the core services
echo "Starting core services..."
docker-compose up -d --force-recreate "${GREPTILE_SERVICES[@]}"

# Copy SSL certificates to all services if SSL_CERTS_PATH is set
if [ -n "$SSL_CERTS_PATH" ]; then
    echo "Copying SSL certificates to services..."
    for service in "${GREPTILE_SERVICES[@]}"
    do
        # Get the container ID for the service
        container_id=$(docker-compose ps -q $service 2>/dev/null)
        if [ -n "$container_id" ]; then
            echo "Copying to $service (container: $container_id)..."
            docker exec $container_id mkdir -p /app/ssl_certs
            docker cp $SSL_CERTS_PATH $container_id:/app/ssl_certs
        else
            echo "Warning: Could not find container for service $service"
        fi
    done
fi

echo "All Greptile services have been started."
echo "You can check service status with: docker-compose ps"
