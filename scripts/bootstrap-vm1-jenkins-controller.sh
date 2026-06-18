#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo bash scripts/bootstrap-vm1-jenkins-controller.sh"
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

for pkg in openssh-server curl wget git fontconfig; do
  install_pkg_if_missing "$pkg"
done

if need_cmd java; then
  echo "[SKIP] Java already installed: $(java -version 2>&1 | head -n 1)"
else
  echo "[INSTALL] openjdk-17-jre"
  apt-get install -y openjdk-17-jre
fi

if dpkg -s jenkins >/dev/null 2>&1; then
  echo "[SKIP] Jenkins already installed"
else
  echo "== Install Jenkins repository =="
  install_pkg_if_missing ca-certificates
  install_pkg_if_missing gnupg
  install_pkg_if_missing apt-transport-https

  if [ ! -f /usr/share/keyrings/jenkins-keyring.asc ]; then
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key \
      | tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
  else
    echo "[SKIP] Jenkins keyring already exists"
  fi

  if [ ! -f /etc/apt/sources.list.d/jenkins.list ]; then
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
      | tee /etc/apt/sources.list.d/jenkins.list >/dev/null
  else
    echo "[SKIP] Jenkins repo already exists"
  fi

  apt-get update
  apt-get install -y jenkins
fi

systemctl enable jenkins
systemctl start jenkins

if need_cmd ufw && ufw status | grep -q "Status: active"; then
  ufw allow 8080/tcp
else
  echo "[INFO] UFW inactive or not installed, skip opening port 8080"
fi

echo
echo "== Jenkins status =="
systemctl --no-pager --full status jenkins | sed -n '1,8p' || true

echo
echo "Initial admin password path: /var/lib/jenkins/secrets/initialAdminPassword"
echo "Jenkins URL: http://<VM1_IP>:8080"
