#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Check required files =="
for path in \
  Jenkinsfile \
  services.yml \
  inventory/hosts.yml \
  playbooks/deploy-service.yml \
  compose/vihire-backend.yml \
  compose/vihire-frontend.yml; do
  test -f "$path"
  echo "[OK] $path"
done

echo
echo "== Check local tools =="
for cmd in git docker ansible-playbook; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[OK] $cmd"
  else
    echo "[WARN] $cmd not found"
  fi
done

echo
echo "== Check compose templates =="
SERVICE_NAME=vihire-backend \
IMAGE_NAME=example/vihire-backend \
IMAGE_TAG=1 \
APP_BRANCH=main \
BUILD_NUMBER=1 \
HOST_PORT=5000 \
CONTAINER_PORT=5000 \
docker compose -f compose/vihire-backend.yml config >/dev/null

SERVICE_NAME=vihire-frontend \
IMAGE_NAME=example/vihire-frontend \
IMAGE_TAG=1 \
APP_BRANCH=main \
BUILD_NUMBER=1 \
HOST_PORT=8081 \
CONTAINER_PORT=80 \
docker compose -f compose/vihire-frontend.yml config >/dev/null

echo "[OK] compose templates render"
echo
echo "Platform check complete."
