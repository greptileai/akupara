#!/bin/bash

# Define the list of services
GREPTILE_SERVICES=(
    greptile_api_service
    greptile_auth_service
    greptile_indexer_chunker
    greptile_indexer_summarizer
    greptile_query_service
    greptile_web_service
    greptile_webhook_service
    greptile_reviews_service
)

# Check if Docker is accessible
if ! docker info > /dev/null 2>&1; then
    echo "Error: Cannot access Docker. Please check that:"
    echo "1. Docker is installed and running"
    echo "2. Your user has permission to access Docker (try running 'docker ps')"
    echo "3. You are a member of the 'docker' group (you can add yourself with 'sudo usermod -aG docker $USER')"
    exit 1
fi

echo "Starting Greptile services..."

# Start database migrations first
echo "Running database migrations..."
docker-compose up -d postgres

# Check if migrations were successful
docker-compose up greptile_vector_db_migration --wait || { echo "Vector DB migration failed"; exit 1; }
docker-compose up greptile_db_migration --wait || { echo "DB migration failed"; exit 1; }

echo "Database migrations completed successfully."

# Start the core services
echo "Starting core services..."
docker-compose up -d --force-recreate "${GREPTILE_SERVICES[@]}"

# Copy SSL certificates to all services if CUSTOM_FILE_PATH is set
if [ -n "$CUSTOM_FILE_PATH" ]; then
    echo "Copying SSL certificates to services..."
    for service in "${GREPTILE_SERVICES[@]}"
    do
        # Get the container ID for the service
        container_id=$(docker-compose ps -q $service 2>/dev/null)
        if [ -n "$container_id" ]; then
            echo "Copying to $service (container: $container_id)..."
            docker exec $container_id mkdir -p /app/custom_data
            docker cp $CUSTOM_FILE_PATH $container_id:/app/custom_data/
        else
            echo "Warning: Could not find container for service $service"
        fi
    done
fi

echo "All Greptile services have been started."
echo "You can check service status with: docker-compose ps"
