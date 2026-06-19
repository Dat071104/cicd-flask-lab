# Architecture

```mermaid
flowchart LR
    dev["Developer"] --> github_platform["GitHub: platform-cicd"]
    dev --> github_backend["GitHub: vihire-backend"]
    dev --> github_frontend["GitHub: vihire-frontend"]

    github_platform --> controller["VM1: Jenkins Controller"]
    controller -- "SSH agent launch" --> agent["VM2: Jenkins Agent\nlabel: docker-agent"]

    agent --> metadata["services.yml"]
    metadata --> clone["Clone selected service repo"]
    clone --> build["Docker build"]
    build --> tag["Tag image with BUILD_NUMBER"]
    tag --> hub["DockerHub"]
    hub --> ansible["Ansible playbook"]
    ansible --> compose["Docker Compose up"]
    compose --> runtime["Running service on VM2"]
```

## Runtime Flow

1. Jenkins job loads `platform-cicd/Jenkinsfile`.
2. User provides `SERVICE` and `BRANCH`.
3. Jenkins reads `services.yml` and selects the matching service metadata.
4. Jenkins clones the selected service repository branch into `source/`.
5. Jenkins builds `${docker_image_name}:${BUILD_NUMBER}`.
6. Jenkins pushes the image to DockerHub.
7. Jenkins runs Ansible against the `vm2` inventory target.
8. Ansible copies the selected Compose template and writes `.env`.
9. Docker Compose pulls and starts the requested image on VM2.
