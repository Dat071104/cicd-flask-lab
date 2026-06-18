#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo bash scripts/bootstrap-vm2-jenkins-agent.sh"
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

echo "== apt update =="
apt-get update

for pkg in openssh-server curl wget git ca-certificates; do
  install_pkg_if_missing "$pkg"
done

if need_cmd java; then
  echo "[SKIP] Java already installed: $(java -version 2>&1 | head -n 1)"
else
  echo "[INSTALL] openjdk-17-jre"
  apt-get install -y openjdk-17-jre
fi

if need_cmd docker; then
  echo "[SKIP] Docker already installed: $(docker --version)"
else
  echo "== Install Docker repository =="
  install_pkg_if_missing gnupg

  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  else
    echo "[SKIP] Docker keyring already exists"
  fi

  arch="$(dpkg --print-architecture)"
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  repo_line="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable"

  if [ ! -f /etc/apt/sources.list.d/docker.list ] || ! grep -Fq "$repo_line" /etc/apt/sources.list.d/docker.list; then
    echo "$repo_line" | tee /etc/apt/sources.list.d/docker.list >/dev/null
  else
    echo "[SKIP] Docker repo already exists"
  fi

  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if command -v docker >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
  echo "[INSTALL] docker-compose-plugin"
  apt-get install -y docker-compose-plugin
else
  echo "[SKIP] Docker Compose plugin already installed"
fi

systemctl enable docker
systemctl start docker

if id -u jenkins >/dev/null 2>&1; then
  echo "[SKIP] user jenkins already exists"
else
  echo "[CREATE] user jenkins"
  useradd -m -s /bin/bash jenkins
fi

usermod -aG docker jenkins
install -d -o jenkins -g jenkins /home/jenkins/agent

if need_cmd ufw && ufw status | grep -q "Status: active"; then
  ufw allow 5000/tcp
else
  echo "[INFO] UFW inactive or not installed, skip opening port 5000"
fi

echo
echo "Run these commands to verify:"
echo "sudo -iu jenkins docker ps"
echo "docker compose version"
