#!/usr/bin/env bash
set -euo pipefail

cleanup="false"
if [ "${1:-}" = "--down" ]; then
  cleanup="true"
fi

docker build -t cicd-flask-lab:local .
IMAGE_TAG=local APP_BRANCH=local BUILD_NUMBER=local docker compose up -d --remove-orphans

sleep 2
curl -f http://localhost:5000/health
echo
curl http://localhost:5000/
echo
docker compose ps

if [ "$cleanup" = "true" ]; then
  docker compose down
fi
