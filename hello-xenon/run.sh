#!/bin/sh

PWD=$(pwd)
CONTAINER_NAME="hello-xenon"
IMAGE_NAME="hello-xenon"


if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}$"; then
    echo "Stopping existing container: $CONTAINER_NAME..."
    docker stop $CONTAINER_NAME >/dev/null 2>&1
    docker rm $CONTAINER_NAME >/dev/null 2>&1
else
    echo "No existing container found."
fi

# Build the Docker image
echo "Building Docker image: $IMAGE_NAME..."
if ! docker build -t $IMAGE_NAME .; then
    echo "Docker build failed. Exiting."
    exit 1
fi
echo "Docker image built successfully."

if docker run -d --name $CONTAINER_NAME -p 80:80 -v "$PWD/html:/usr/share/nginx/html" $IMAGE_NAME; then
    echo "Container is running successfully."
else
    echo "Failed to start the container."
    exit 1
fi
