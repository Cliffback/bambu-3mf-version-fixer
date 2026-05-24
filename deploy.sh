#!/usr/bin/env bash
set -euo pipefail

# deploy.sh — One-shot deployment script for Synology Task Scheduler
# Usage: bash deploy.sh

CONTAINER_NAME="bambu-3mf-fixer"
IMAGE_NAME="bambu-3mf-fixer:latest"
HOST_PORT="8765"

echo "=== Bambu 3MF Version Fixer Deployment ==="
echo ""

# Stop and remove existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container '${CONTAINER_NAME}'..."
    docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    echo "Removing existing container '${CONTAINER_NAME}'..."
    docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# Build fresh image
echo "Building Docker image '${IMAGE_NAME}'..."
docker build -t "${IMAGE_NAME}" .

# Run new container
echo "Starting container '${CONTAINER_NAME}' on port ${HOST_PORT}..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${HOST_PORT}:80" \
    "${IMAGE_NAME}"

echo ""
echo "Done! The app is running at:"
echo "  http://$(hostname -I | awk '{print $1}'):${HOST_PORT}"
echo ""
