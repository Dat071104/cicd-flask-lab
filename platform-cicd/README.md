# ViHire Platform CI/CD

This directory represents the `platform-cicd` repository. It owns the shared CI/CD platform for ViHire services:

- Jenkins pipeline logic
- service metadata
- Ansible inventory
- deployment playbooks
- Docker Compose templates
- setup and check scripts
- architecture documentation

The application code lives in separate service repositories:

- `vihire-backend`
- `vihire-frontend`

In this lab workspace those repositories are represented by sibling directories. In a real GitHub setup, each directory should become its own repository and `services.yml` should point at the real repository URLs.

## Repository Structure

```text
.
|-- platform-cicd/
|   |-- Jenkinsfile
|   |-- services.yml
|   |-- ARCHITECTURE.md
|   |-- compose/
|   |   |-- vihire-backend.yml
|   |   `-- vihire-frontend.yml
|   |-- inventory/
|   |   `-- hosts.yml
|   |-- playbooks/
|   |   `-- deploy-service.yml
|   `-- scripts/
|       |-- check-platform.sh
|       `-- setup-platform-agent.sh
|-- vihire-backend/
|   |-- Dockerfile
|   |-- app.py
|   `-- requirements.txt
`-- vihire-frontend/
    |-- Dockerfile
    `-- index.html
```

## Service Catalog

`services.yml` is the source of truth for deployable services. Each service entry includes:

- `name`
- `git_repository`
- `docker_image_name`
- `compose_file`
- `deploy_target`
- `deploy_path`
- `container_port`
- `host_port`

Before running Jenkins, update the placeholder values:

```yaml
git_repository: https://github.com/your-org/vihire-backend.git
docker_image_name: your-dockerhub-username/vihire-backend
```

## Jenkins Job

Keep the existing Jenkins architecture:

- VM1: Jenkins Controller
- VM2: SSH-launched Jenkins Agent with label `docker-agent`

Create a Pipeline job that uses `platform-cicd/Jenkinsfile` from SCM.

The job receives two parameters:

- `SERVICE`, for example `vihire-backend`
- `BRANCH`, for example `main`

Required Jenkins plugins:

- Git
- Pipeline
- Credentials Binding
- Pipeline Utility Steps

Create a Jenkins username/password credential:

- ID: `dockerhub-creds`
- Username: DockerHub username
- Password: DockerHub access token

## Agent Setup

Run the original VM2 bootstrap first so Docker, Docker Compose, Java, Git, and the Jenkins user exist:

```bash
sudo bash scripts/bootstrap-vm2-jenkins-agent.sh
```

Then install the platform deployment tools:

```bash
sudo bash platform-cicd/scripts/setup-platform-agent.sh
```

This installs Ansible and creates:

```text
/opt/vihire/backend
/opt/vihire/frontend
```

## Deployment Flow

```text
Build -> Push DockerHub -> Ansible -> Docker Compose Up
```

Detailed flow:

1. Jenkins reads `services.yml`.
2. Jenkins finds the selected `SERVICE`.
3. Jenkins clones the selected service repository at `BRANCH`.
4. Jenkins builds a Docker image.
5. Jenkins tags the image with `BUILD_NUMBER`.
6. Jenkins pushes the image to DockerHub.
7. Jenkins runs `playbooks/deploy-service.yml`.
8. Ansible copies the selected Compose template to the deploy path.
9. Ansible writes `.env` with image, tag, branch, build, and port metadata.
10. Ansible runs `docker compose pull`.
11. Ansible runs `docker compose up -d --remove-orphans`.

## Local Platform Check

On a Linux machine with Docker available:

```bash
bash platform-cicd/scripts/check-platform.sh
```

The script checks required files, required tools, and Compose template rendering.

## Phase 2 — Semgrep/OpenSemgrep SAST (Report-Only)

Phase 2 adds Static Analysis Security Testing (SAST) using `semgrep/semgrep`.

- Semgrep runs immediately after source code clone and before Docker image build.
- Scans the cloned source directory using the `semgrep/semgrep` Docker image.
- Report-only mode: findings do not block the pipeline in Phase 2 while rules are being calibrated.
- Generates two reports:
  - `reports/semgrep.txt` — human-readable text output
  - `reports/semgrep.json` — structured JSON output for automation
- Reports are archived via the existing `reports/**` artifact archiving pattern.
- Phase 1 Trivy CRITICAL severity gate still blocks push/deploy until base image CVEs are remediated.

## Architecture Diagram

See [ARCHITECTURE.md](ARCHITECTURE.md).
