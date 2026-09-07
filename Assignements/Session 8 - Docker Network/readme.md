# 🐳 Session 8 — Docker Networking & Volumes: Homework

---

## 📌 Overview

This session focused on **Docker Networking** and **Volumes** — two critical concepts for building multi-container applications. The practical work covers container networking, host networking, bind mounts, and overlay network research.

> **Name:** Kiran N
> **Roll No.:** 24bcs10446
> **Session:** 8 — Docker Networking & Volumes

---

## 🛠️ Commands & Concepts Used

| Command / Concept                | Description                                                      |
|----------------------------------|------------------------------------------------------------------|
| `docker network create`         | Create a custom Docker network                                   |
| `docker network connect`        | Attach a running container to an additional network              |
| `docker run --network`          | Start a container on a specific network                          |
| `docker exec ... ping`          | Test connectivity between containers                             |
| `--network host`                | Use the host's network namespace directly                        |
| `-v` (Bind Mount)               | Mount a local directory into a container                         |
| `docker-compose`                | Define and run multi-container applications                      |
| Overlay Network (VXLAN)         | Distributed networking across multiple Docker hosts              |

---

## 1️⃣ Task 1: Docker Container Networking

### 🎯 Objective

Create **3 containers** (Frontend: Nginx, Backend: Alpine, Database: MySQL), set up **3 networks**, attach the Backend to 2 networks, and verify **isolated connectivity**.

### 📋 Implementation

**Step 1** — Create three custom networks:

```bash
docker network create front-net
docker network create back-net
docker network create db-net
```

**Step 2** — Start the containers on their respective networks:

```bash
# Database on db-net
docker run -d --name database --network db-net -e MYSQL_ROOT_PASSWORD=root mysql:8.0

# Backend on back-net
docker run -d --name backend --network back-net alpine sleep infinity

# Frontend on back-net
docker run -d --name frontend --network back-net -p 8080:80 nginx
```

**Step 3** — Attach the Backend to `db-net` so it acts as a bridge:

```bash
docker network connect db-net backend
```

**Step 4** — Verify connectivity:

```bash
# Frontend → Backend (should succeed ✅)
docker exec frontend ping -c 2 backend

# Backend → Database (should succeed ✅)
docker exec backend ping -c 2 database

# Frontend → Database (should fail ❌ — isolated!)
docker exec frontend ping -c 2 database
```

### ✅ Results

| Source     | Destination | Network Path              | Result              |
|------------|-------------|---------------------------|---------------------|
| Frontend   | Backend     | `back-net`                | ✅ Ping successful  |
| Backend    | Database    | `db-net`                  | ✅ Ping successful  |
| Frontend   | Database    | No shared network         | ❌ Ping failed      |

### 🔄 Network Architecture

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  front-net        back-net           db-net          │
│                                                     │
│                 ┌──────────┐                        │
│                 │ Frontend │                        │
│                 │ (Nginx)  │                        │
│                 └────┬─────┘                        │
│                      │                              │
│                 back-net                             │
│                      │                              │
│                 ┌────┴─────┐                        │
│                 │ Backend  │                        │
│                 │ (Alpine) │                        │
│                 └────┬─────┘                        │
│                      │                              │
│                   db-net                             │
│                      │                              │
│                 ┌────┴─────┐                        │
│                 │ Database │                        │
│                 │ (MySQL)  │                        │
│                 └──────────┘                        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

> 💡 **Key Takeaway:** The Backend container is connected to **both** `back-net` and `db-net`, acting as a bridge. The Frontend and Database are **isolated** from each other — they have no shared network.

---

## 2️⃣ Task 2: Host Network

### 🎯 Objective

Create an Apache2 container using the **host network** and access it directly on port 80 without port mapping.

### 📋 Implementation

```bash
# Run Apache container with host network
docker run -d --name apache-host --network host httpd:alpine
```

```bash
# Access directly on port 80 — no -p flag needed!
curl http://localhost:80
```

### ✅ Result

- The container binds directly to the host's network namespace
- Accessible at `http://localhost:80` **without** any `-p` port mapping
- No network isolation between container and host

### ⚖️ Host Network vs Bridge Network

| Feature                  | Bridge Network (Default)     | Host Network                   |
|--------------------------|------------------------------|--------------------------------|
| Port Mapping             | Required (`-p 8080:80`)      | Not needed                     |
| Network Isolation        | ✅ Isolated                  | ❌ Shares host namespace       |
| Performance              | Slight overhead (NAT)        | Better (no NAT)                |
| Use Case                 | General purpose              | High-performance / debugging   |

> ⚠️ **Note:** On Docker Desktop / Colima for Mac, `--network host` binds the port to the VM's network namespace, not directly to macOS.

---

## 3️⃣ Task 3: Bind Mount

### 🎯 Objective

Bind mount a local folder containing `index.html` to an Nginx container, and verify **live updates** without restarting the container.

### 📋 Implementation

**Step 1** — Create a local `html/` folder with an `index.html`:

```html
<!-- html/index.html -->
<html>
<head>
  <title>Docker Swarm Assignment</title>
</head>
<body>
  <h1>Web Server is Running!</h1>
  <p>This is the 1st web server.</p>
</body>
</html>
```

**Step 2** — Run Nginx with a bind mount:

```bash
docker run -d --name web-server \
  -p 8080:80 \
  -v $(pwd)/html:/usr/share/nginx/html \
  nginx
```

**Step 3** — Verify the initial output:

```bash
curl http://localhost:8080
# Output: "Web Server is Running! This is the 1st web server."
```

**Step 4** — Modify the local `index.html` (change the text):

```bash
# Edit html/index.html — change content
```

**Step 5** — Curl again to verify live update:

```bash
curl http://localhost:8080
# Output: Updated content reflected immediately! ✅
```

### ✅ Result

| Step                       | Action                        | Result                                     |
|----------------------------|-------------------------------|--------------------------------------------|
| Initial load               | `curl localhost:8080`         | ✅ Original content displayed              |
| Modify `index.html`        | Edit the local file           | No container restart needed                |
| Re-check                   | `curl localhost:8080`         | ✅ Updated content reflected immediately   |

> 💡 **Key Takeaway:** Bind mounts allow **live file synchronization** between the host and container — changes to local files are reflected instantly without restarting.

---

## 4️⃣ Task 4: Overlay Network Research

### 🎯 What are Docker Overlay Networks?

An **overlay network** creates a distributed network among multiple Docker daemon hosts. It is the networking driver used in **Docker Swarm** to allow containers on entirely different physical/virtual machines to communicate securely and seamlessly as if they were on the same local network.

### 📋 Use Cases

| Use Case                              | Description                                                                      |
|----------------------------------------|----------------------------------------------------------------------------------|
| Multi-Host Communication              | Connecting containers that span across multiple cloud instances or servers       |
| Docker Swarm Deployments              | Native service discovery and load balancing within a Swarm cluster               |
| High Availability & Scaling           | Horizontal scaling of replicas across nodes with transparent communication       |

### 🔄 How Overlay Networks Work Across Multiple Hosts

Overlay networks use **VXLAN (Virtual Extensible LAN)** technology to encapsulate container traffic:

```
Host 1                                           Host 2
┌─────────────────────┐                ┌─────────────────────┐
│  ┌───────────────┐  │                │  ┌───────────────┐  │
│  │  Container A  │  │                │  │  Container B  │  │
│  └───────┬───────┘  │                │  └───────▲───────┘  │
│          │          │                │          │          │
│   ┌──────┴──────┐   │                │   ┌──────┴──────┐   │
│   │   Docker    │   │   VXLAN        │   │   Docker    │   │
│   │  Overlay    │───┼───Tunnel───────┼───│  Overlay    │   │
│   │  Driver     │   │                │   │  Driver     │   │
│   └──────┬──────┘   │                │   └──────┬──────┘   │
│          │          │                │          │          │
│   ┌──────┴──────┐   │                │   ┌──────┴──────┐   │
│   │  Physical   │   │   Underlay     │   │  Physical   │   │
│   │  Network    │───┼───Network──────┼───│  Network    │   │
│   └─────────────┘   │                │   └─────────────┘   │
└─────────────────────┘                └─────────────────────┘
```

**How it works step by step:**

1. **Control Plane:** Docker manages routing and service discovery using its integrated key-value store (Raft consensus in Swarm mode) to distribute keys and IP mappings.
2. **Data Plane (VXLAN):** When Container A on Host 1 wants to communicate with Container B on Host 2, Docker intercepts the packet and encapsulates it in a **VXLAN header** containing Host 2's IP address.
3. **Transit:** Host 1 sends the VXLAN packet to Host 2 over the physical (underlay) network.
4. **Delivery:** Host 2 receives the packet, decapsulates it, and delivers the original packet directly to Container B.

> 💡 **Key Takeaway:** Overlay networks make multi-host container communication transparent — containers behave as if they are on the same LAN, regardless of their physical location.

---

## 5️⃣ Bonus: Docker Compose — 3-Tier Application

A complete **3-tier application** (Frontend + Backend + Database) was built using Docker Compose with network isolation.

### 📂 Project Structure

```
demo/
├── backend/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── frontend/
│   ├── index.html
│   └── nginx.conf
└── docker-compose.yml
```

### 🔄 Architecture

```
                    ┌───────────────────┐
                    │    User Browser   │
                    └────────┬──────────┘
                             │ :8080
                    ┌────────▼──────────┐
                    │    Frontend       │
                    │   (Nginx)         │
                    │   frontend_net    │
                    └────────┬──────────┘
                             │ /api proxy
                    ┌────────▼──────────┐
                    │    Backend        │
                    │   (Flask :5000)   │
                    │ frontend_net +    │
                    │ backend_net       │
                    └────────┬──────────┘
                             │
                    ┌────────▼──────────┐
                    │    Database       │
                    │   (MySQL 8.0)     │
                    │   backend_net     │
                    └───────────────────┘
```

### 📋 Networks

| Network          | Containers Connected       | Purpose                              |
|------------------|----------------------------|--------------------------------------|
| `frontend_net`   | Frontend, Backend          | Handles user-facing HTTP traffic     |
| `backend_net`    | Backend, Database          | Secure DB communication              |

> 💡 The Frontend **cannot** directly access the Database — all data flows through the Backend, ensuring proper **network isolation**.

---

## 📝 Key Takeaways

| Concept                     | Summary                                                                      |
|-----------------------------|------------------------------------------------------------------------------|
| Custom Bridge Networks      | Allow container-to-container communication with DNS-based discovery          |
| Network Isolation           | Containers on different networks cannot communicate                          |
| Multi-Network Attachment    | A container can bridge two networks by being connected to both               |
| Host Network                | Removes network isolation; container uses host's network stack directly      |
| Bind Mounts                 | Sync local files into containers with live updates, no restart needed        |
| Overlay Networks            | Enable multi-host communication using VXLAN encapsulation                    |
| Docker Compose Networks     | Define isolated network topologies for multi-container applications          |

---

## 👤 Author

**Kiran N** — `24bcs10446`

---

> ✅ **End of Session 8 — Docker Networking & Volumes Homework**
