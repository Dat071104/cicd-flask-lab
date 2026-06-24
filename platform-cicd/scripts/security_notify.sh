#!/bin/bash
# Security Notification Script
# Part of the metadata-driven CI/CD platform
#
# Phase 3A: notification-ready skeleton
# Phase 3D: credential-ready notification wiring with dry-run preview
# ======================================
# Generates security-summary.txt, security-summary.json,
# notification-status.txt, and notification-preview.txt artifacts.
# Sends notification message to Telegram and/or Slack if credentials
# are configured. Skips safely when credentials are missing.
# Pipeline never fails due to missing or failing notification delivery.
#
# Usage:
#   ./security_notify.sh <job_name> <build_number> <service> <branch> <image_tag>
#
# Expected environment variables (optional, set by Jenkins credentials in Phase 3D+):
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
semgrep_gate_mode="NOT CHECKED"
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
    if [ -f "${REPORTS_DIR}/semgrep-gate.txt" ]; then
        SEMG_MODE_LINE="$(grep '^Mode:' "${REPORTS_DIR}/semgrep-gate.txt" 2>/dev/null || echo "UNKNOWN")"
        semgrep_gate_mode="${SEMG_MODE_LINE#Mode: }"
    fi

# -------------------------------------------------------
# Determine the git commit hash for the notification preview
# -------------------------------------------------------
GIT_COMMIT="unknown"
if [ -d "${WORKSPACE:-.}/source/.git" ]; then
    GIT_COMMIT="$(cd "${WORKSPACE:-.}/source" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
elif [ -d source/.git ]; then
    GIT_COMMIT="$(cd source && git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
fi

# -------------------------------------------------------
# Build the notification message preview text
# -------------------------------------------------------
NOTIFY_TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%SZ')"

NL=$'\n'

PREVIEW_MSG=""
PREVIEW_MSG="${PREVIEW_MSG}=== CI/CD Build Summary ===${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Job:        ${JOB_NAME} #${BUILD_NUMBER}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Commit:     ${GIT_COMMIT}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Service:    ${SERVICE}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Branch:     ${BRANCH}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Image:      ${IMAGE_TAG}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}--- Scan Results ---${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Hadolint:              ${hadolint_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Semgrep SAST:         ${semgrep_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Semgrep Gate:         ${semgrep_gate_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Semgrep Gate Mode:    ${semgrep_gate_mode}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Source Secret Scan:   ${source_secret_scan_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Trivy HIGH:           ${trivy_high_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Trivy CRITICAL Gate:  ${trivy_critical_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Non-Root Container:   ${nonroot_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}--- Deploy ---${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Push DockerHub:       ${dockerhub_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Ansible Deploy:       ${ansible_status}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}--- Notifications ---${NL}"

# Determine Telegram and Slack status from env vars (before sending)
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_ID:-}" ]; then
    TELEGRAM_STATUS="CREDENTIALS_FOUND"
    PREVIEW_MSG="${PREVIEW_MSG}Telegram:             CREDENTIALS_FOUND${NL}"
else
    TELEGRAM_STATUS="SKIPPED_MISSING_CREDENTIALS"
    PREVIEW_MSG="${PREVIEW_MSG}Telegram:             SKIPPED_MISSING_CREDENTIALS${NL}"
fi

if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
    SLACK_STATUS="CREDENTIALS_FOUND"
    PREVIEW_MSG="${PREVIEW_MSG}Slack:                CREDENTIALS_FOUND${NL}"
else
    SLACK_STATUS="SKIPPED_MISSING_CREDENTIALS"
    PREVIEW_MSG="${PREVIEW_MSG}Slack:                SKIPPED_MISSING_CREDENTIALS${NL}"
fi

PREVIEW_MSG="${PREVIEW_MSG}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Build URL: ${BUILD_URL}${NL}"
PREVIEW_MSG="${PREVIEW_MSG}Timestamp: ${NOTIFY_TIMESTAMP}${NL}"

# -----------------------------------------------
# Write notification-preview.txt (always generated)
# -----------------------------------------------
printf '%s' "${PREVIEW_MSG}" > "${REPORTS_DIR}/notification-preview.txt"
echo "[PREVIEW] reports/notification-preview.txt written"

# -----------------------------------------------
# Actually send the message (if credentials are present)
# -----------------------------------------------
# We set +e so that curl failure does not exit the script
set +e

## Telegram
if [ "${TELEGRAM_STATUS}" = "CREDENTIALS_FOUND" ]; then
    echo "[SEND] Sending Telegram notification..."
    TELEGRAM_SEND_RESULT="$(curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${PREVIEW_MSG}" \
        -d "parse_mode=HTML" 2>&1 || true)"

    if echo "${TELEGRAM_SEND_RESULT}" | grep -q '"ok":true'; then
        TELEGRAM_STATUS="SENT_SUCCESS"
        echo "[SEND] Telegram notification sent successfully."
    else
        TELEGRAM_STATUS="SEND_FAILED"
        echo "[SEND] Telegram notification send failed (will not fail pipeline): ${TELEGRAM_SEND_RESULT}"
    fi
fi

## Slack
if [ "${SLACK_STATUS}" = "CREDENTIALS_FOUND" ]; then
    echo "[SEND] Sending Slack notification..."
    # Escape the preview message for JSON-ish payload
    SLACK_PAYLOAD="$(printf '%s' "${PREVIEW_MSG}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"${PREVIEW_MSG}\"")"
    SLACK_SEND_RESULT="$(curl -s -X POST \
        "${SLACK_WEBHOOK_URL}" \
        -H "Content-Type: application/json" \
        -d "{\"text\": ${SLACK_PAYLOAD}}" 2>&1 || true)"

    if echo "${SLACK_SEND_RESULT}" | grep -q '^ok$'; then
        SLACK_STATUS="SENT_SUCCESS"
        echo "[SEND] Slack notification sent successfully."
    else
        SLACK_STATUS="SEND_FAILED"
        echo "[SEND] Slack notification send failed (will not fail pipeline): ${SLACK_SEND_RESULT}"
    fi
fi

set -e

# -----------------------------------------------
# Update notification-status.txt with outcomes
# -----------------------------------------------

cat > "${REPORTS_DIR}/notification-status.txt" <<-EOTXT
========================================
  Notification Status
========================================

Timestamp:   ${NOTIFY_TIMESTAMP}
Job:         ${JOB_NAME} #${BUILD_NUMBER}

Notification Channels:
  Telegram:  ${TELEGRAM_STATUS}
  Slack:     ${SLACK_STATUS}

Preview:
  reports/notification-preview.txt written

Expected Credential IDs (for Phase 3D+):
  telegram-bot-token  (type: Secret text)
  telegram-chat-id    (type: Secret text)
  slack-webhook-url   (type: Secret text)

NOTE: Notifications are entirely optional.
      Missing credentials never fail the pipeline.
      Send failures never fail the pipeline.
========================================
  End of Notification Status
========================================
EOTXT

echo "✅ reports/notification-status.txt updated"

# -----------------------------------------------
# Generate security-summary.txt (same as before)
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
Semgrep Gate Mode:   ${semgrep_gate_mode}

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
# Generate security-summary.json (same as before)
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
    "semgrep_gate": "${semgrep_gate_status}",
    "semgrep_gate_mode": "${semgrep_gate_mode}"
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
echo ""
echo "=== Security summary, notification preview, and notifications complete ==="
