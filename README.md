# CI/CD Flask Lab Jenkins + Docker

Project này là một lab CI/CD đơn giản để demo luồng:

Jenkins build -> checkout code từ GitHub -> build Docker image -> deploy app Flask trên VM2 -> mở app tại `http://<VM2_IP>:5000`

## 1. Mục tiêu

Sau khi cấu hình xong, bạn chỉ cần vào Jenkins trên VM1, bấm **Build with Parameters**, chọn branch rồi chạy job. Jenkins sẽ:

1. Checkout source code từ GitHub public repo
2. Build image `cicd-flask-lab:<BUILD_NUMBER>`
3. Deploy app bằng `docker compose` trên VM2 Jenkins Agent

App mẫu có 2 endpoint:

- `/` trả JSON thông tin branch và build number
- `/health` trả JSON trạng thái health check

## 2. Kiến trúc lab

- Máy local/Windows: nơi sửa code, push lên GitHub
- GitHub public repo: chứa source code của project
- VM1 Ubuntu 22.04: Jenkins Controller, truy cập qua `http://<VM1_IP>:8080`
- VM2 Ubuntu 22.04: Jenkins Agent, có Docker, Docker Compose plugin, Java, Git

Luồng làm việc:

1. Bạn push code lên GitHub
2. Jenkins trên VM1 đọc Jenkinsfile trong repo
3. Jenkins chạy job trên node `docker-agent` ở VM2
4. VM2 build image và chạy container `cicd-flask-lab`
5. Bạn mở `http://<VM2_IP>:5000`

## 3. Cấu trúc project

```text
.
|-- app.py
|-- requirements.txt
|-- Dockerfile
|-- docker-compose.yml
|-- Jenkinsfile
|-- .dockerignore
|-- .gitignore
|-- README.md
|-- reports/
|   `-- FINAL_REPORT_TEMPLATE.md
`-- scripts/
    |-- bootstrap-vm1-jenkins-controller.sh
    |-- bootstrap-vm2-jenkins-agent.sh
    |-- check-prereqs.sh
    |-- install-public-key-on-vm2.sh
    |-- setup-jenkins-ssh-key-on-vm1.sh
    `-- smoke-local.sh
```

## 4. Chạy local bằng Docker

Điều kiện: máy có Docker và Docker Compose plugin.

### Bước 1: build image

```bash
docker build -t cicd-flask-lab:local .
```

### Bước 2: chạy app

Nếu bạn đang chạy trên Linux/macOS:

```bash
IMAGE_TAG=local APP_BRANCH=local BUILD_NUMBER=local docker compose up -d --remove-orphans
```

Nếu bạn đang chạy local test trên Windows PowerShell thì không dùng cú pháp trên. Dùng:

```powershell
$env:IMAGE_TAG="local"
$env:APP_BRANCH="local"
$env:BUILD_NUMBER="local"
docker compose up -d --remove-orphans
```

### Bước 3: kiểm tra

```bash
curl http://localhost:5000/health
curl http://localhost:5000/
docker compose ps
```

### Dừng app nếu cần

```bash
docker compose down
```

## 5. Đưa code lên GitHub public repo

Nếu thư mục này chưa là Git repo:

```bash
git init
git add .
git commit -m "Initial CI/CD Flask lab"
git branch -M main
git remote add origin <GITHUB_REPO_URL>
git push -u origin main
```

Nếu repo đã có sẵn:

```bash
git add .
git commit -m "Update CI/CD lab files"
git push
```

Lưu ý: repo nên để public để Jenkins clone đơn giản hơn cho lab cơ bản.

## 6. Cài VM1 Jenkins Controller

Chạy script:

```bash
chmod +x scripts/bootstrap-vm1-jenkins-controller.sh
sudo bash scripts/bootstrap-vm1-jenkins-controller.sh
```

Script này sẽ:

- `apt update`
- cài `openssh-server`, `curl`, `wget`, `git`, `fontconfig` nếu thiếu
- cài Java nếu thiếu
- cài Jenkins nếu thiếu
- enable/start Jenkins
- mở UFW port `8080` nếu UFW đang active

Sau khi chạy xong, mở:

```text
http://<VM1_IP>:8080
```

Lấy initial admin password:

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

## 7. Cài VM2 Jenkins Agent

Chạy script:

```bash
chmod +x scripts/bootstrap-vm2-jenkins-agent.sh
sudo bash scripts/bootstrap-vm2-jenkins-agent.sh
```

Script này sẽ:

- `apt update`
- cài `openssh-server`, `curl`, `wget`, `git`, `ca-certificates` nếu thiếu
- cài Java nếu thiếu
- cài Docker Engine nếu thiếu
- cài Docker Compose plugin nếu thiếu
- enable/start Docker
- tạo user `jenkins` nếu chưa có
- thêm user `jenkins` vào group `docker`
- tạo thư mục `/home/jenkins/agent`
- mở UFW port `5000` nếu UFW đang active

## 8. Tạo SSH key từ VM1 sang VM2

Trên VM1 chạy:

```bash
chmod +x scripts/setup-jenkins-ssh-key-on-vm1.sh
sudo bash scripts/setup-jenkins-ssh-key-on-vm1.sh
```

Script sẽ tạo key cho user Jenkins tại:

```text
/var/lib/jenkins/.ssh/id_ed25519
```

Nó cũng sẽ in public key để bạn copy sang VM2.

## 9. Cài public key lên VM2

Trên VM2 chạy:

```bash
chmod +x scripts/install-public-key-on-vm2.sh
sudo JENKINS_PUBLIC_KEY='ssh-ed25519 AAAA... your-key' bash scripts/install-public-key-on-vm2.sh
```

Script sẽ:

- tạo `/home/jenkins/.ssh` nếu thiếu
- thêm key vào `authorized_keys` nếu chưa có
- set quyền đúng cho `.ssh` và `authorized_keys`

## 10. Cấu hình Jenkins node

Trên Jenkins UI:

1. Vào **Manage Jenkins**
2. Vào **Nodes**
3. Tạo node mới tên ví dụ: `vm2-agent`
4. Chọn **Permanent Agent**
5. Cấu hình:

- Remote root directory: `/home/jenkins/agent`
- Labels: `docker-agent`
- Launch method: **Launch agents via SSH**
- Host: `<VM2_IP>`
- Credentials: tạo SSH credential cho user `jenkins` dùng private key của `/var/lib/jenkins/.ssh/id_ed25519`

Sau khi lưu, node phải về trạng thái online.

## 11. Tạo Jenkins Pipeline job

1. Chọn **New Item**
2. Nhập tên job, ví dụ `cicd-flask-lab`
3. Chọn **Pipeline**
4. Tick **This project is parameterized**
5. Thêm parameter kiểu **String Parameter**

- Name: `BRANCH`
- Default Value: `main`

6. Ở phần Pipeline:

- Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: `<GITHUB_REPO_URL>`
- Branch Specifier: `*/${BRANCH}`
- Script Path: `Jenkinsfile`

Lưu job lại.

Lưu ý:

- Trong lab này, branch thật để build do parameter `BRANCH` điều khiển trong Jenkinsfile
- Job chạy thủ công, không cần webhook

## 12. Cách demo

1. Push code lên GitHub public repo
2. Chạy script VM1
3. Chạy script VM2
4. Kết nối SSH Jenkins -> VM2
5. Tạo node label `docker-agent`
6. Tạo Pipeline job có parameter `BRANCH`
7. Bấm **Build with Parameters**
8. Chọn `main`
9. Chờ pipeline chạy đủ 3 stage:

- Checkout
- Build
- Deploy

10. Mở:

```text
http://<VM2_IP>:5000
```

## 13. Lỗi thường gặp

### Jenkins UI không mở được port 8080

- Kiểm tra service:

```bash
sudo systemctl status jenkins
```

- Kiểm tra firewall:

```bash
sudo ufw status
```

- Nếu đang chặn, mở port:

```bash
sudo ufw allow 8080/tcp
```

### Agent offline

- Kiểm tra VM1 SSH sang VM2:

```bash
sudo -u jenkins ssh -i /var/lib/jenkins/.ssh/id_ed25519 jenkins@<VM2_IP> 'whoami && hostname'
```

- Kiểm tra Java trên VM2:

```bash
java -version
```

- Kiểm tra thư mục agent:

```bash
ls -ld /home/jenkins/agent
```

### Docker permission denied

- Kiểm tra user `jenkins` đã vào group docker chưa:

```bash
id jenkins
```

- Nếu vừa thêm group, logout/login lại hoặc reboot VM2.

### docker compose not found

- Kiểm tra:

```bash
docker compose version
```

- Nếu không có, chạy lại script VM2.

### App không mở được port 5000

- Kiểm tra container:

```bash
docker ps
docker compose ps
docker logs cicd-flask-lab
```

- Kiểm tra firewall VM2:

```bash
sudo ufw allow 5000/tcp
```

## 14. Checklist nộp lab

- Có GitHub public repo
- Có file `Jenkinsfile`
- Jenkins Controller chạy trên VM1
- Jenkins Agent online trên VM2
- Build Jenkins chạy qua 3 stage
- App mở được tại `http://<VM2_IP>:5000`
- Có ảnh chụp Jenkins job success
- Có ảnh chụp app đang chạy
- Có report điền theo template trong `reports/FINAL_REPORT_TEMPLATE.md`
