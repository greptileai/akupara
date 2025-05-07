#!/bin/bash

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
    echo "Database migrations failed. Exiting..."
    exit 1
fi

echo "Database migrations completed successfully."

# Start the core services
echo "Starting core services..."
docker-compose up -d --force-recreate \
    greptile_api_service \
    greptile_auth_service \
    greptile_indexer_chunker \
    greptile_indexer_summarizer \
    greptile_query_service \
    greptile_web_service \
    greptile_github_service

echo "All Greptile services have been started."
echo "You can check service status with: docker-compose ps"
