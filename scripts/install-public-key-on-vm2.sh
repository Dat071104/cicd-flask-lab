#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo JENKINS_PUBLIC_KEY='ssh-ed25519 AAAA...' bash scripts/install-public-key-on-vm2.sh"
  exit 1
fi

if [ -z "${JENKINS_PUBLIC_KEY:-}" ]; then
  echo "Missing JENKINS_PUBLIC_KEY"
  echo "Example:"
  echo "sudo JENKINS_PUBLIC_KEY='ssh-ed25519 AAAA... your-key' bash scripts/install-public-key-on-vm2.sh"
  exit 1
fi

if ! id -u jenkins >/dev/null 2>&1; then
  echo "User jenkins does not exist. Run bootstrap-vm2-jenkins-agent.sh first."
  exit 1
fi

SSH_DIR="/home/jenkins/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

install -d -m 700 -o jenkins -g jenkins "$SSH_DIR"
touch "$AUTHORIZED_KEYS"

if grep -Fqx "$JENKINS_PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
  echo "[SKIP] Public key already exists"
else
  echo "$JENKINS_PUBLIC_KEY" >>"$AUTHORIZED_KEYS"
  echo "[OK] Public key added"
fi

chown jenkins:jenkins "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

echo "Authorized key is ready for user jenkins"
