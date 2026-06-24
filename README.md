# Metadata-Driven CI/CD Platform Lab

This lab upgrades the original Jenkins + Docker Flask exercise into a small metadata-driven CI/CD platform.

The Jenkins controller and SSH agent architecture stays the same:

- VM1 runs the Jenkins Controller.
- VM2 runs the SSH-launched Jenkins Agent with label `docker-agent`.
- VM2 has Docker, Docker Compose, Git, Java, and Ansible.

## Repositories

The lab is organized as three repositories. In this workspace they are represented as directories:

```text
.
|-- platform-cicd/
|-- vihire-backend/
`-- vihire-frontend/
```

`platform-cicd` owns the CI/CD platform. The service repositories own application code and Dockerfiles.

## Platform Files

```text
platform-cicd/
|-- Jenkinsfile
|-- services.yml
|-- ARCHITECTURE.md
|-- compose/
|-- inventory/
|-- playbooks/
`-- scripts/
```

The root `Jenkinsfile` mirrors `platform-cicd/Jenkinsfile` so this combined training workspace can also run directly in Jenkins.

## Service Catalog

`platform-cicd/services.yml` defines each deployable service:

- service name
- git repository
- Docker image name
- Compose file
- deploy target
- deploy path
- ports

Update placeholder GitHub and DockerHub values before running a real pipeline.

## Jenkins Parameters

The pipeline receives:

- `SERVICE`, for example `vihire-backend`
- `BRANCH`, for example `main`

## Required Jenkins Plugins

- Git
- Pipeline
- Credentials Binding
- Pipeline Utility Steps

Create a DockerHub credential in Jenkins:

- ID: `dockerhub-creds`
- Type: username/password
- Username: DockerHub username
- Password: DockerHub access token

## Deployment Flow

```text
Build -> Push DockerHub -> Ansible -> Docker Compose Up
```

The Jenkins pipeline:

1. Loads metadata from `services.yml`.
2. Clones the selected service repository.
3. Builds a Docker image.
4. Tags the image with `BUILD_NUMBER`.
5. Pushes the image to DockerHub.
6. Runs the Ansible deployment playbook.
7. Ansible runs Docker Compose on VM2.

## Setup

Bootstrap VM1 and VM2 with the original scripts:

```bash
sudo bash scripts/bootstrap-vm1-jenkins-controller.sh
sudo bash scripts/bootstrap-vm2-jenkins-agent.sh
```

Then install platform deployment tools on VM2:

```bash
sudo bash platform-cicd/scripts/setup-platform-agent.sh
```

## Platform Check

On a Linux host with Docker available:

```bash
bash platform-cicd/scripts/check-platform.sh
```

## Phase 2 — Semgrep/OpenSemgrep SAST (Report-Only)

Phase 2 adds Static Analysis Security Testing (SAST) using `semgrep/semgrep`.

- Semgrep runs immediately after source code clone and before Docker image build.
- Scans the cloned source directory using `semgrep/semgrep` Docker image.
- Report-only mode: findings do not block the pipeline in Phase 2 while rules are being calibrated.
- **Phase 3C baseline governance**: known Semgrep findings are documented in [`docs/security/semgrep-baseline-governance.md`](docs/security/semgrep-baseline-governance.md).
- Generates two reports:
  - `reports/semgrep.txt` — human-readable text output
  - `reports/semgrep.json` — structured JSON output for automation
- Reports are archived via the existing `reports/**` artifact archiving pattern.
- Phase 1 Trivy CRITICAL severity gate still blocks push/deploy until base image CVEs are remediated.

## Phase 3A: Notification-Ready Skeleton

Phase 3A adds a lightweight notification framework without requiring Telegram or Slack to exist yet.

### What it does

- Generates `reports/security-summary.txt` — a human-readable summary of all scan and pipeline stage statuses.
- Generates `reports/security-summary.json` — a structured JSON equivalent for automation.
- Generates `reports/notification-status.txt` — documents whether Telegram/Slack credentials are configured.
- All three files are archived via the existing `reports/**` artifact pattern.

### Design principles

- **No secrets in the repository.** Credential IDs (`telegram-bot-token`, `telegram-chat-id`, `slack-webhook-url`) are documented but never hardcoded or checked out.
- **Safe skip when credentials are missing.** The `security_notify.sh` script checks for optional environment variables (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`, `SLACK_WEBHOOK_URL`). If absent, it writes "not configured; skipped" and exits cleanly.
- **Pipeline never fails because of missing notification credentials.** The notification stage is informational only.
- **Ready for Phase 3B/3C.** When Telegram and Slack credentials are created in Jenkins, the pipeline only needs to add `withCredentials(...)` bindings before calling the same script.

### Expected Jenkins credential IDs (future use)

| ID                  | Type        | Mapped to env var     |
|---------------------|-------------|-----------------------|
| `telegram-bot-token` | Secret text | `TELEGRAM_BOT_TOKEN`  |
| `telegram-chat-id`   | Secret text | `TELEGRAM_CHAT_ID`    |
| `slack-webhook-url`  | Secret text | `SLACK_WEBHOOK_URL`   |

### Pipeline stage

```
Phase 3A: Security Summary & Notification Skeleton
  -> bash platform-cicd/scripts/security_notify.sh <args>
  -> writes reports/security-summary.{txt,json}
  -> writes reports/notification-status.txt
  -> archived automatically via post { always archiveArtifacts }
```

## Architecture

See `platform-cicd/ARCHITECTURE.md` for the Mermaid diagram and runtime flow.
