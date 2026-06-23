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
- Generates two reports:
  - `reports/semgrep.txt` — human-readable text output
  - `reports/semgrep.json` — structured JSON output for automation
- Reports are archived via the existing `reports/**` artifact archiving pattern.
- Phase 1 Trivy CRITICAL severity gate still blocks push/deploy until base image CVEs are remediated.

## Architecture

See `platform-cicd/ARCHITECTURE.md` for the Mermaid diagram and runtime flow.
