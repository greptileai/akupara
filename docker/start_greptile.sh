#!/bin/bash

echo "Starting Greptile services..."

# Start database migrations first
echo "Running database migrations..."
sudo docker-compose up -d postgres
sudo docker-compose up greptile_vector_db_migration --wait
sudo docker-compose up greptile_db_migration --wait

# Check if migrations were successful
if [ $? -ne 0 ]; then
    echo "Database migrations failed. Exiting..."
    exit 1
fi

echo "Database migrations completed successfully."

# Start the core services
echo "Starting core services..."
sudo docker-compose up -d --force-recreate \
    greptile_api_service \
    greptile_auth_service \
    greptile_indexer_chunker \
    greptile_indexer_summarizer \
    greptile_query_service \
    greptile_web_service \
    greptile_github_service

echo "All Greptile services have been started."
echo "You can check service status with: sudo docker-compose ps"
