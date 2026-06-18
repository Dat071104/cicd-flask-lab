#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo bash scripts/setup-jenkins-ssh-key-on-vm1.sh"
  exit 1
fi

JENKINS_HOME_DIR="/var/lib/jenkins"
SSH_DIR="${JENKINS_HOME_DIR}/.ssh"
KEY_PATH="${SSH_DIR}/id_ed25519"

install -d -m 700 -o jenkins -g jenkins "$SSH_DIR"

if [ -f "$KEY_PATH" ]; then
  echo "[SKIP] SSH key already exists at $KEY_PATH"
else
  sudo -u jenkins ssh-keygen -t ed25519 -N "" -f "$KEY_PATH"
fi

echo
echo "Public key:"
cat "${KEY_PATH}.pub"

echo
echo "Test command:"
echo "sudo -u jenkins ssh -i ${KEY_PATH} jenkins@<VM2_IP> 'whoami && hostname && docker ps && docker compose version'"
