#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo bash platform-cicd/scripts/setup-platform-agent.sh"
  exit 1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_pkg_if_missing() {
  local pkg="$1"
  if dpkg -s "$pkg" >/dev/null 2>&1; then
    echo "[SKIP] $pkg already installed"
  else
    echo "[INSTALL] $pkg"
    apt-get install -y "$pkg"
  fi
}

echo "== Install platform agent tools =="
apt-get update

for pkg in git curl ca-certificates python3 python3-apt ansible; do
  install_pkg_if_missing "$pkg"
done

if ! need_cmd docker; then
  echo "[ERROR] Docker is not installed. Run scripts/bootstrap-vm2-jenkins-agent.sh first."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[ERROR] Docker Compose plugin is not installed. Run scripts/bootstrap-vm2-jenkins-agent.sh first."
  exit 1
fi

install -d -o jenkins -g jenkins /opt/vihire/backend /opt/vihire/frontend

echo
echo "== Platform agent tools =="
git --version
ansible-playbook --version | sed -n '1p'
docker --version
docker compose version
echo
echo "Platform agent setup complete."
