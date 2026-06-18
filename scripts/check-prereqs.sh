#!/usr/bin/env bash
set -u

print_cmd_version() {
  local name="$1"
  shift
  if command -v "$1" >/dev/null 2>&1; then
    echo "[OK] ${name}: $("$@" 2>/dev/null | head -n 1)"
  else
    echo "[MISSING] ${name}"
  fi
}

echo "== OS Info =="
if [ -r /etc/os-release ]; then
  cat /etc/os-release
else
  uname -a
fi

echo
echo "== Tool Versions =="
print_cmd_version "Java" java -version
print_cmd_version "Git" git --version
print_cmd_version "Docker" docker --version

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  echo "[OK] Docker Compose plugin: $(docker compose version | head -n 1)"
else
  echo "[MISSING] Docker Compose plugin"
fi

echo
echo "== Services =="
if command -v systemctl >/dev/null 2>&1; then
  for service in jenkins ssh docker; do
    if systemctl list-unit-files "${service}.service" >/dev/null 2>&1; then
      status="$(systemctl is-active "$service" 2>/dev/null || true)"
      echo "[INFO] ${service}: ${status:-unknown}"
    else
      echo "[INFO] ${service}: not installed"
    fi
  done
else
  echo "[INFO] systemctl not available"
fi
