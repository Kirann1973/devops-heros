# 🐳 Session 6 & 7 — Docker Fundamentals, Dockerfiles & Images

| | |
|---|---|
| **Name** | Kiran N |
| **Roll No. / Enrollment No.** | 10446 |
| **Course** | DevOps Heros |
| **Sessions** | 6: Docker Fundamentals · 7: Dockerfiles & Images (multi-stage builds) |
| **Environment** | Ubuntu 26.04 LTS VM (Multipass on macOS, arm64) · Docker 29.1 |

---

## 📌 Homework Summary

| Session | Task | Status | Details |
|---|---|---|---|
| 6 | Hello World web apps in Docker: Node.js, Python, Java, Apache, React, Nginx | ✅ All 6 running | [docker-fundamentals-homework.md](docker-fundamentals-homework.md) |
| 7 | Task 1: build and run the multi-stage Dockerfile, verify on port 8080 | ✅ | [multi-stage-homework.md](multi-stage-homework.md) |
| 7 | Task 2: documentation with name, enrollment no., app and `docker ps` screenshots | ✅ | [multi-stage-homework.md](multi-stage-homework.md) |
| 7 | Task 3: deploy at least 3 different application types | ✅ 6 types | Node.js, Python, Java, Apache, React, Nginx |

---

## 📂 Folder Structure

```text
Session 6-7 docker/
├── README.md                         # this overview
├── docker-fundamentals-homework.md   # Session 6 write-up
├── multi-stage-homework.md           # Session 7 write-up
├── build_and_run.sh                  # builds + runs + verifies every app
├── docker_output.txt                 # my full output from build_and_run.sh
├── nodejs-app/       server.js, package.json, Dockerfile
├── python-app/       app.py, Dockerfile
├── java-app/         HelloWorld.java, Dockerfile (multi-stage: JDK → JRE)
├── Apache-app/       index.html, Dockerfile
├── React-app/        Vite + React source, Dockerfile (multi-stage: Node → Nginx)
├── nginx-app/        index.html, Dockerfile
├── multi-stage-dockerfile/  instructor's multi-stage Node.js app
└── screenshots/
```

---

## 🚀 Run Everything

```bash
cd "Session 6-7 docker"
chmod +x build_and_run.sh
./build_and_run.sh
```

| App | Image | Port (host → container) | Base image |
|---|---|---|---|
| Node.js | `nodejs-app` | 3001 → 3000 | `node:20-alpine` |
| Python | `python-app` | 5001 → 5000 | `python:3.12-alpine` |
| Java | `java-app` | 8081 → 8080 | `eclipse-temurin:21-jdk-alpine` → `21-jre-alpine` |
| Apache | `apache-app` | 8082 → 80 | `httpd:2.4-alpine` |
| React | `react-app` | 8083 → 80 | `node:20-alpine` → `nginx:alpine` |
| Nginx | `nginx-app` | 8084 → 80 | `nginx:alpine` |
| Multi-stage (Session 7) | `multi-stage-hw` | **8080** → 3000 | `node:24-alpine` (builder → production) |

## ✅ Result (from my VM)

```text
========== VERIFY: curl each app ==========
HTTP 200  Hello World from Node.js!
HTTP 200  Hello World from Python!
HTTP 200  Hello World from Java!
HTTP 200  title: Apache - Kiran N
HTTP 200  title: React - Kiran N
HTTP 200  title: Nginx - Kiran N
HTTP 200  Hello World from Docker Multi-Stage Build!

========== docker ps ==========
NAMES            IMAGE            STATUS              PORTS
multi-stage-hw   multi-stage-hw   Up 8 seconds        0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
nginx-app        nginx-app        Up 31 seconds       0.0.0.0:8084->80/tcp, [::]:8084->80/tcp
react-app        react-app        Up 31 seconds       0.0.0.0:8083->80/tcp, [::]:8083->80/tcp
apache-app       apache-app       Up About a minute   0.0.0.0:8082->80/tcp, [::]:8082->80/tcp
java-app         java-app         Up About a minute   0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp
python-app       python-app       Up 2 minutes        0.0.0.0:5001->5000/tcp, [::]:5001->5000/tcp
nodejs-app       nodejs-app       Up 2 minutes        0.0.0.0:3001->3000/tcp, [::]:3001->3000/tcp
```

📸 ![All apps verified](screenshots/01_docker_output_verification.png)

For the Apache, React and Nginx apps, the script prints the page `<title>`. The "Hello World" text for React is rendered in the browser:

📸 ![React app in the browser](screenshots/03_docker_app_deployment.png)

---

> ✅ **End of Session 6 & 7 — Docker Homework** · Kiran N · Roll No. 10446
