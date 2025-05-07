#!/bin/bash

# Check if Docker is accessible
if ! docker info > /dev/null 2>&1; then
    echo "Error: Cannot access Docker. Please check that:"
    echo "1. Docker is installed and running"
    echo "2. Your user has permission to access Docker (try running 'docker ps')"
    echo "3. You are a member of the 'docker' group (you can add yourself with 'sudo usermod -aG docker $USER')"
    exit 1
fi

echo "Starting Hatchet services..."

# Start only Hatchet-related services
docker-compose up -d \
    postgres \
    rabbitmq \
    migration \
    setup-config \
    hatchet-engine \
    hatchet-api \
    hatchet-frontend \
    caddy

echo "Waiting for services to be healthy..."

# Wait for PostgreSQL to be healthy
while ! docker-compose ps postgres | grep "healthy" > /dev/null; do
    echo "Waiting for PostgreSQL..."
    sleep 5
done

# Wait for RabbitMQ to be healthy
while ! docker-compose ps rabbitmq | grep "healthy" > /dev/null; do
    echo "Waiting for RabbitMQ..."
    sleep 5
done

echo "All Hatchet services are up and running!"
echo "You can access the Hatchet UI at http://localhost:8080"

# Generate and save Hatchet environment variables
echo "Generating Hatchet environment variables..."
cat <<EOF > .env.hatchet
HATCHET_CLIENT_TOKEN="$(docker-compose run --no-deps setup-config /hatchet/hatchet-admin token create --config /hatchet/config --tenant-id 707d0855-80ab-4e1f-a156-f1c4546cbf52 | xargs)"
HATCHET_CLIENT_TLS_STRATEGY=none
EOF

echo "Hatchet environment variables saved to .env.hatchet"