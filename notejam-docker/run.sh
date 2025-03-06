#!/bin/sh

printf "Stop and remove existing containers\n"
docker-compose down -v || {
    printf "Failed to stop containers. Check Docker status."
    exit 1
}

printf "Removing redundant resources\n"
docker system prune -af || {
    printf "Failed to clean Docker resources."
    exit 1
}

printf "Build and run all docker containers\n"
docker-compose up --build -d || {
    printf "Failed to build or start containers."
    exit 1
}

sleep 10

printf "Running database migrations\n"
docker exec -it notejam-app python manage.py syncdb || {
    printf "Failed to run syncdb."
    exit 1
}

docker exec -it notejam-app python manage.py migrate || {
    printf "Failed to run migrations."
    exit 1
}

printf "Application is now running.\n"
