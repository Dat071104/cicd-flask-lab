#!/bin/bash
# Security Notification Script
# Part of the metadata-driven CI/CD platform
#
# Phase 3A: notification-ready skeleton
# ======================================
# Generates security-summary.txt, security-summary.json, and
# notification-status.txt artifacts. Prepares for Telegram/Slack
# notification without requiring those channels to exist yet.
#
# Usage:
#   ./security_notify.sh <job_name> <build_number> <service> <branch> <image_tag>
#
# Expected environment variables (optional, set by Jenkins credentials in Phase 3B+):
#   TELEGRAM_BOT_TOKEN  - Telegram bot token  (credential: telegram-bot-token)
#   TELEGRAM_CHAT_ID    - Telegram chat ID    (credential: telegram-chat-id)
#   SLACK_WEBHOOK_URL   - Slack webhook URL   (credential: slack-webhook-url)
#
# If credentials are absent, notifications are safely skipped.
# Pipeline never fails due to missing notification credentials.

set -eu

JOB_NAME="${1:-unknown}"
BUILD_NUMBER="${2:-0}"
SERVICE="${3:-unknown}"
BRANCH="${4:-unknown}"
IMAGE_TAG="${5:-unknown}"

REPORTS_DIR="${WORKSPACE:-.}/reports"
mkdir -p "${REPORTS_DIR}"

# Build URL (uses Jenkins env var BUILD_URL if available)
BUILD_URL="${BUILD_URL:-https://jenkins.example.com/job/${JOB_NAME}/${BUILD_NUMBER}/}"
ARTIFACTS_URL="${BUILD_URL}artifact/reports/"

# -------------------------------------------------------
# Determine status of each pipeline stage from report files
# -------------------------------------------------------
semgrep_status="NOT SCANNED"
hadolint_status="NOT SCANNED"
trivy_high_status="NOT SCANNED"
trivy_critical_status="NOT SCANNED"
source_secret_scan_status="NOT SCANNED"
source_secret_gate_status="NOT CHECKED"
semgrep_gate_status="NOT CHECKED"
dockerhub_status="NOT PUSHED"
ansible_status="NOT DEPLOYED"
nonroot_status="NOT VERIFIED"
app_endpoint_status="UNKNOWN"

[ -f "${REPORTS_DIR}/semgrep.txt" ]                && semgrep_status="PASS (report-only)"
[ -f "${REPORTS_DIR}/hadolint.txt" ]               && hadolint_status="PASS"
[ -f "${REPORTS_DIR}/trivy-high.txt" ]             && trivy_high_status="PASS (report-only)"
[ -f "${REPORTS_DIR}/trivy-critical.txt" ]         && trivy_critical_status="PASS (gate passed)"
[ -f "${REPORTS_DIR}/non-root-proof.txt" ]         && nonroot_status="VERIFIED"
[ -f "${REPORTS_DIR}/app-endpoint.txt" ]           && app_endpoint_status="$(head -1 "${REPORTS_DIR}/app-endpoint.txt" 2>/dev/null)"
[ -f "${REPORTS_DIR}/source-secret-scan.txt" ]     && source_secret_scan_status="PASS"
[ -f "${REPORTS_DIR}/source-secret-gate.txt" ]     && source_secret_gate_status="$(head -1 "${REPORTS_DIR}/source-secret-gate.txt" 2>/dev/null)"
[ -f "${REPORTS_DIR}/semgrep-gate.txt" ]           && semgrep_gate_status="$(head -1 "${REPORTS_DIR}/semgrep-gate.txt" 2>/dev/null)"

# -----------------------------------------------
# Generate security-summary.txt
# -----------------------------------------------
cat > "${REPORTS_DIR}/security-summary.txt" <<-EOTXT
========================================
  Security Summary Report
========================================

Job Name:       ${JOB_NAME}
Build Number:   ${BUILD_NUMBER}
Service:        ${SERVICE}
Branch:         ${BRANCH}
Image Tag:      ${IMAGE_TAG}

Build URL:      ${BUILD_URL}
Artifacts URL:  ${ARTIFACTS_URL}

--- Scan Results -----------------------
Semgrep:           ${semgrep_status}
Hadolint:          ${hadolint_status}
Trivy HIGH:        ${trivy_high_status}
Trivy CRITICAL:    ${trivy_critical_status}
Source Secret:     ${source_secret_scan_status}

--- Security Gates ---------------------
Source Secret Gate:  ${source_secret_gate_status}
Semgrep Gate:        ${semgrep_gate_status}

--- Pipeline Status --------------------
Push DockerHub:    ${dockerhub_status}
Ansible Deploy:    ${ansible_status}
Non-Root User:     ${nonroot_status}
App Endpoint:      ${app_endpoint_status}

========================================
  End of Security Summary
========================================
EOTXT

echo "✅ reports/security-summary.txt written"

# -----------------------------------------------
# Generate security-summary.json
# -----------------------------------------------
cat > "${REPORTS_DIR}/security-summary.json" <<-EOJSON
{
  "job": "${JOB_NAME}",
  "build": ${BUILD_NUMBER},
  "service": "${SERVICE}",
  "branch": "${BRANCH}",
  "image_tag": "${IMAGE_TAG}",
  "build_url": "${BUILD_URL}",
  "artifacts_url": "${ARTIFACTS_URL}",
  "scans": {
    "semgrep": "${semgrep_status}",
    "hadolint": "${hadolint_status}",
    "trivy_high": "${trivy_high_status}",
    "trivy_critical": "${trivy_critical_status}",
    "source_secret": "${source_secret_scan_status}"
  },
  "gates": {
    "source_secret_gate": "${source_secret_gate_status}",
    "semgrep_gate": "${semgrep_gate_status}"
  },
  "pipeline": {
    "push_dockerhub": "${dockerhub_status}",
    "ansible_deploy": "${ansible_status}",
    "non_root": "${nonroot_status}",
    "app_endpoint": "${app_endpoint_status}"
  }
}
EOJSON

echo "✅ reports/security-summary.json written"

# -----------------------------------------------
# Notification readiness check
# -----------------------------------------------
NOTIFY_TELEGRAM="Telegram credentials not configured; skipped"
NOTIFY_SLACK="Slack webhook not configured; skipped"

if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    NOTIFY_TELEGRAM="Telegram credentials found; ready to send"
fi

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    NOTIFY_SLACK="Slack webhook found; ready to send"
fi

# -----------------------------------------------
# Generate notification-status.txt
# -----------------------------------------------
NOTIFY_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"

cat > "${REPORTS_DIR}/notification-status.txt" <<-EOTXT
========================================
  Notification Status
========================================

Timestamp:   ${NOTIFY_TIMESTAMP}
Job:         ${JOB_NAME} #${BUILD_NUMBER}

Notification Channels:
  Telegram:  ${NOTIFY_TELEGRAM}
  Slack:     ${NOTIFY_SLACK}

Expected Credential IDs (for Phase 3B+):
  telegram-bot-token  (type: Secret text)
  telegram-chat-id    (type: Secret text)
  slack-webhook-url   (type: Secret text)

NOTE: Notifications are entirely optional.
      Missing credentials never fail the pipeline.
========================================
  End of Notification Status
========================================
EOTXT

echo "✅ reports/notification-status.txt written"
echo ""
echo "=== Security summary and notification status complete ==="
