---
title: "Week 15: Container Fundamentals"
sidebar:
  order: 0
---


> **Goal:** Understand containerization concepts, run and manage containers with Docker and Podman, and work with images, volumes, and container networking.


---

## Table of Contents

| Section | Topic |
|---------|-------|
| 15.1 | [What Containers Actually Are](#151-what-containers-actually-are) |
| 15.2 | [Containers vs Virtual Machines](#152-containers-vs-virtual-machines) |
| 15.3 | [The OCI Standard](#153-the-oci-standard) |
| 15.4 | [Docker vs Podman](#154-docker-vs-podman) |
| 15.5 | [Installing Docker Engine on Ubuntu](#155-installing-docker-engine-on-ubuntu) |
| 15.6 | [Installing Podman on Rocky](#156-installing-podman-on-rocky) |
| 15.7 | [Container Lifecycle](#157-container-lifecycle) |
| 15.8 | [Understanding docker run Flags](#158-understanding-docker-run-flags) |
| 15.9 | [Interactive Containers](#159-interactive-containers) |
| 15.10 | [Working with Images](#1510-working-with-images) |
| 15.11 | [Image Layers and Copy-on-Write](#1511-image-layers-and-copy-on-write) |
| 15.12 | [Port Mapping](#1512-port-mapping) |
| 15.13 | [Environment Variables](#1513-environment-variables) |
| 15.14 | [Container Filesystem: Ephemeral by Default](#1514-container-filesystem-ephemeral-by-default) |
| 15.15 | [Volumes and Persistent Storage](#1515-volumes-and-persistent-storage) |
| 15.16 | [Container Networking](#1516-container-networking) |
| 15.17 | [Custom Networks and Service Discovery](#1517-custom-networks-and-service-discovery) |
| 15.18 | [Resource Limits](#1518-resource-limits) |
| 15.19 | [Inspecting and Debugging Containers](#1519-inspecting-and-debugging-containers) |
| 15.20 | [Cleaning Up](#1520-cleaning-up) |
| 15.21 | [Docker vs Podman Command Comparison](#1521-docker-vs-podman-command-comparison) |
| 15.22 | [Connection to the Three-Tier App](#1522-connection-to-the-three-tier-app) |

---

## 15.1 What Containers Actually Are

If you've heard that containers are "lightweight virtual machines," forget that right now. It's the most common misconception in the industry, and it leads to fundamental misunderstandings about how containers work.

A **container** is a regular Linux process (or group of processes) that the kernel isolates from other processes using two mechanisms you've already encountered in this course:

1. **Namespaces** — provide isolation. Each container gets its own view of the system: its own process tree (PID namespace), its own network stack (network namespace), its own filesystem mount points (mount namespace), its own hostname (UTS namespace), and its own user IDs (user namespace). The processes inside cannot see processes, files, or network interfaces belonging to other containers or the host.

2. **cgroups** (control groups) — provide resource limits. Back in Week 7, we briefly touched on cgroups when discussing process resource consumption. Containers use cgroups to enforce CPU, memory, and I/O limits. A container allocated 512 MB of RAM cannot exceed that — the kernel enforces it at the process level.

Let's make this concrete:

```bash
# On the host, see all processes
ps aux | wc -l
```

```text
187
```

```bash
# Start a container and see its isolated view
docker run -d --name demo nginx
docker exec demo ps aux
```

```text
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  10784  5636 ?        Ss   14:32   0:00 nginx: master process nginx -g daemon off;
nginx       29  0.0  0.0  11244  2572 ?        S    14:32   0:00 nginx: worker process
root        35  0.0  0.0   6700  1600 ?        Rs   14:33   0:00 ps aux
```

The container sees only three processes, with nginx as PID 1. But on the host, `ps aux | grep "nginx: master"` shows the same process with a host PID like 12847. It's not running in a VM — it's running on the host kernel. The kernel just limits what it can see.

**Containers are processes, not machines.** They share the host's kernel. There is no second kernel, no virtual hardware, no boot sequence. A container starts in milliseconds because there's nothing to boot.

```bash
docker rm -f demo
```

---

## 15.2 Containers vs Virtual Machines

Your Ubuntu and Rocky VMs in Parallels are full virtual machines — each one has its own kernel, its own boot process, its own memory space managed by a hypervisor. Containers are fundamentally different.

```text
      Virtual Machines                         Containers

  ┌────────┐ ┌────────┐ ┌────────┐     ┌────────┐ ┌────────┐ ┌────────┐
  │  App   │ │  App   │ │  App   │     │  App   │ │  App   │ │  App   │
  │  Libs  │ │  Libs  │ │  Libs  │     │  Libs  │ │  Libs  │ │  Libs  │
  │ Kernel │ │ Kernel │ │ Kernel │     └────────┘ └────────┘ └────────┘
  └────────┘ └────────┘ └────────┘        Container Runtime (Docker/Podman)
       Hypervisor (Parallels, KVM)               Host Kernel (shared)
            Host Operating System                Host Operating System
                Hardware                             Hardware
```

| Characteristic | Virtual Machines | Containers |
|---------------|-----------------|------------|
| Isolation | Full hardware virtualization | Kernel namespaces + cgroups |
| Kernel | Each VM has its own | Shares host kernel |
| Boot time | 30-90 seconds | Milliseconds |
| Disk footprint | Gigabytes (full OS) | Megabytes (app + deps) |
| Resource overhead | Significant (reserved RAM) | Minimal (on-demand) |
| Security boundary | Strong (hypervisor) | Weaker (shared kernel) |
| OS flexibility | Any OS | Linux containers on Linux |

Use **VMs** when you need different kernels, strong security boundaries, or non-Linux workloads. Use **containers** when you need fast startup, consistent environments, reproducible builds, and dense application packing. In practice, you often use both — containers running inside VMs — which is exactly what we're doing in this course.

---

## 15.3 The OCI Standard

The **Open Container Initiative (OCI)**, founded in 2015, defines two specifications:

1. **OCI Image Specification** — the format for container images (layers, manifests, metadata)
2. **OCI Runtime Specification** — how to run a container (the interface between engine and kernel)

What this means for you: **images and runtimes are interchangeable.** An image built with Docker runs on Podman. An image pulled from Docker Hub works with any OCI-compliant registry. This is why we can teach Docker and Podman side by side — they conform to the same standards.

---

## 15.4 Docker vs Podman

Both are OCI-compliant **container engines** with deliberately compatible CLIs. Their architectures differ:

| Feature | Docker | Podman |
|---------|--------|--------|
| Architecture | Client-server (daemon) | Daemonless (fork-exec) |
| Root daemon | `dockerd` runs as root | No persistent daemon |
| Rootless mode | Supported (extra setup) | Default and first-class |
| CLI syntax | `docker <command>` | `podman <command>` (identical) |
| Systemd integration | Separate from systemd | Generates systemd unit files |
| Default on | Ubuntu (most common) | RHEL/Rocky/Fedora |
| Socket | `/var/run/docker.sock` | Per-user socket (rootless) |

**Docker** uses a client-server model. The `docker` CLI sends requests to the `dockerd` daemon, which manages everything. If the daemon crashes, all containers are affected. Any user with access to the Docker socket effectively has root.

**Podman** is daemonless. `podman run` directly forks the container process — no intermediary. No single point of failure, rootless by default, and containers are just processes that systemd can manage natively.

Learn both. The CLI is 95% identical, so knowing one means you know the other. We'll use Docker on Ubuntu and Podman on Rocky, mirroring real-world distribution preferences.

---

## 15.5 Installing Docker Engine on Ubuntu

Always install from Docker's official repository — not the `docker.io` package or the Snap.

```bash
# Remove old/unofficial versions
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null

# Install prerequisites
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Add Docker's GPG key (same pattern as Week 6)
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow your user to run docker without sudo
sudo usermod -aG docker "$USER"
```

Log out and back in for the group change to take effect (or run `newgrp docker`).

```bash
# Verify
docker run hello-world
docker version
systemctl status docker
```

Docker is a systemd service — exactly like the services you managed in Week 11.

---

## 15.6 Installing Podman on Rocky

Podman is in Rocky's default repos. Installation is one command:

```bash
sudo dnf install -y podman
```

No daemon to start, no socket to configure, no group to join.

```bash
# Verify
podman run docker.io/library/hello-world
podman version
podman info | grep rootless
```

```text
  rootless: true
```

Rootless by default. Your containers run with your user's privileges, not root's.

---

## 15.7 Container Lifecycle

Every container goes through a predictable set of states. These commands are identical for Docker and Podman — substitute `podman` for `docker` on Rocky.

```bash
# Run a container in the background
docker run -d --name web nginx

# List running containers
docker ps

# List ALL containers (including stopped)
docker ps -a

# Stop a container (sends SIGTERM, then SIGKILL after 10s — same signals from Week 7)
docker stop web

# Start a stopped container
docker start web

# Restart (stop + start)
docker restart web

# View container logs (the container equivalent of journalctl -u from Week 11)
docker logs web

# Inspect container details (JSON)
docker inspect web

# Remove a container (must stop first, or use -f)
docker stop web && docker rm web
# Or: docker rm -f web
```

A stopped container still uses disk space. It appears in `docker ps -a` but not `docker ps`. When a container "disappears," check `docker ps -a` — it's probably just stopped.

---

## 15.8 Understanding docker run Flags

```bash
# Detached mode — runs in background
docker run -d --name web nginx

# Interactive + TTY — gives you a shell
docker run -it --name shell alpine sh

# Named container — easier to reference than random names like "quirky_ptolemy"
docker run -d --name my-server nginx

# Auto-remove when it exits — perfect for throwaway containers
docker run --rm alpine echo "I will be cleaned up"

# Common pattern: detached, named, port-mapped
docker run -d --name web -p 8080:80 nginx

# Common pattern: interactive, auto-remove
docker run -it --rm alpine sh
```

```bash
docker rm -f web shell my-server 2>/dev/null
```

---

## 15.9 Interactive Containers

### exec — Run a Command in a Running Container

```bash
docker run -d --name web nginx

# Get a shell
docker exec -it web bash
```

Inside the container, explore: `hostname`, `cat /etc/os-release`, `ps aux`, `exit`. The container keeps running after you exit — `exec` creates a new process alongside PID 1.

```bash
# Run a single command without entering the container
docker exec web cat /etc/nginx/nginx.conf
```

### attach vs exec

| Command | Connects to | Ctrl+C effect | Container keeps running? |
|---------|-------------|---------------|-------------------------|
| `exec -it ... bash` | New process | Exits the shell | Yes |
| `attach` | PID 1 | Stops the container | No |

Use `exec` for debugging. Use `attach` only when you understand the consequences.

```bash
docker rm -f web
```

---

## 15.10 Working with Images

An **image** is a read-only template used to create containers — a filesystem snapshot plus metadata.

```bash
# Pull an image
docker pull nginx

# List local images
docker images

# Remove an image (no containers can be using it)
docker rmi nginx

# Tag an image (adds a name — doesn't copy data)
docker tag nginx:latest my-registry.example.com/nginx:v1.25

# See image layers and how it was built
docker history nginx
```

### Image Naming Convention

```text
registry/namespace/repository:tag

docker.io/library/nginx:latest        # Official image from Docker Hub
docker.io/library/nginx:1.25-alpine   # Specific version, Alpine base
ghcr.io/myorg/myapp:v2.1.0           # GitHub Container Registry
quay.io/prometheus/node-exporter:latest
```

| Component | Meaning | Default |
|-----------|---------|---------|
| Registry | Where the image lives | `docker.io` |
| Namespace | Owner/organization | `library` (official images) |
| Repository | Image name | (required) |
| Tag | Version/variant | `latest` |

**Image registries** store and distribute images. Docker Hub (`docker.io`) is the default and largest. Others include GitHub Container Registry (`ghcr.io`), Quay.io (`quay.io`), and cloud-provider registries (ECR, GCR). Docker Hub has **official images** (maintained by Docker with upstream projects) and **community images** (evaluate trust before using).

The `latest` tag is not automatically the newest version — it's just the default tag when you don't specify one. In production, always pin to specific version tags.

---

## 15.11 Image Layers and Copy-on-Write

Every image is made of **layers** — read-only filesystem changes stacked on top of each other:

```text
┌─────────────────────────────┐
│  Layer 4: COPY app files    │  ← Smallest, changes most often
├─────────────────────────────┤
│  Layer 3: RUN pip install   │  ← Dependencies
├─────────────────────────────┤
│  Layer 2: RUN apt install   │  ← System packages
├─────────────────────────────┤
│  Layer 1: Base OS (Debian)  │  ← Largest, changes rarely
└─────────────────────────────┘
```

Key properties:
- **Layers are read-only** and never change once created
- **Layers are shared** — five containers from the same image share one copy on disk
- **Containers add a writable layer** on top. File changes use **copy-on-write**: the file is copied from the image layer to the container layer, then modified there. The image is untouched.

This is why starting containers is fast (no filesystem copy), multiple containers use minimal extra space, and deleting a container doesn't affect the image. We'll build our own images in Week 16, and understanding layers becomes essential for optimization.

---

## 15.12 Port Mapping

Containers have isolated network namespaces — their ports aren't accessible from the host by default. Use `-p` to map host ports to container ports.

```bash
# Map host port 8080 to container port 80
docker run -d --name web -p 8080:80 nginx
curl -s http://localhost:8080 | head -3

# Multiple mappings
docker run -d --name multi -p 8080:80 -p 8443:443 nginx

# Bind to localhost only (security best practice for databases)
docker run -d --name local -p 127.0.0.1:5432:5432 postgres:16

# Let Docker pick a random host port
docker run -d --name random -p 80 nginx
docker port random
```

```text
80/tcp -> 0.0.0.0:32768
```

```bash
docker rm -f web multi local random 2>/dev/null
```

---

## 15.13 Environment Variables

Environment variables are the primary way to configure containers. You've used them in bash scripts (Week 8) — containers use them the same way, set at creation time.

```bash
# Pass individual variables
docker run -d --name db \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=myapp \
  -e POSTGRES_DB=appdata \
  postgres:16

# Verify
docker exec db env | grep POSTGRES
```

```text
POSTGRES_PASSWORD=secretpass
POSTGRES_USER=myapp
POSTGRES_DB=appdata
```

For containers with many variables, use `--env-file`:

```bash
cat > db.env << 'EOF'
POSTGRES_PASSWORD=secretpass
POSTGRES_USER=myapp
POSTGRES_DB=appdata
EOF

docker run -d --name db2 --env-file db.env postgres:16
```

This keeps secrets out of your shell history. In production, env files are managed by your deployment system and excluded from version control.

```bash
docker rm -f db db2
rm -f db.env
```

---

## 15.14 Container Filesystem: Ephemeral by Default

**Everything written inside a container is lost when the container is removed.** This is by design.

```bash
# Write data in a container
docker run -d --name test alpine sleep 3600
docker exec test sh -c 'echo "important data" > /tmp/myfile.txt'
docker exec test cat /tmp/myfile.txt
```

```text
important data
```

```bash
# Remove and recreate — data is gone
docker rm -f test
docker run -d --name test alpine sleep 3600
docker exec test cat /tmp/myfile.txt
```

```text
cat: can't open '/tmp/myfile.txt': No such file or directory
```

Containers should be **disposable** — destroy one, create a replacement. Data that must persist belongs in volumes.

```bash
docker rm -f test
```

---

## 15.15 Volumes and Persistent Storage

**Volumes** exist outside the container's filesystem and survive container removal. There are three types:

### Named Volumes

Managed by Docker/Podman, referenced by name:

```bash
docker volume create pgdata
docker run -d --name db \
  -e POSTGRES_PASSWORD=secretpass \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

The `-v pgdata:/var/lib/postgresql/data` mounts the volume at PostgreSQL's data directory. Remove and recreate the container with the same volume — the data persists.

```bash
docker volume ls
docker volume inspect pgdata
```

### Bind Mounts

Map a specific host directory into the container:

```bash
mkdir -p ~/web-content
echo "<h1>Hello from the host</h1>" > ~/web-content/index.html

docker run -d --name web -p 8080:80 \
  -v ~/web-content:/usr/share/nginx/html:ro \
  nginx

curl -s http://localhost:8080
```

The `:ro` suffix makes it read-only inside the container. Changes on the host appear in the container immediately.

### tmpfs Mounts

In-memory storage that never touches disk — use for sensitive temporary data:

```bash
docker run -d --name secure --tmpfs /run/secrets:rw,size=64m alpine sleep 3600
```

### When to Use Which

| Scenario | Use | Why |
|----------|-----|-----|
| Database data (PostgreSQL, MariaDB) | Named volume | Managed lifecycle, portable |
| Source code (development) | Bind mount | Edit on host, see changes instantly |
| Configuration files | Bind mount | Version-controlled, mount into container |
| Temporary/sensitive data | tmpfs | Never persists to disk |

Rule of thumb: **named volumes for data the container generates**, **bind mounts for data you provide**.

```bash
docker rm -f db web secure 2>/dev/null
```

---

## 15.16 Container Networking

Containers have isolated network namespaces. Docker/Podman provides networking abstractions for communication.

### The Default Bridge Network

```bash
docker network ls
```

```text
NETWORK ID     NAME      DRIVER    SCOPE
a1b2c3d4e5f6   bridge    bridge    local
d7e8f9a0b1c2   host      host      local
f3g4h5i6j7k8   none      null      local
```

| Network | Purpose |
|---------|---------|
| `bridge` | Default; containers get isolated IPs, communicate by IP only |
| `host` | Container uses host's network directly (no isolation) |
| `none` | No networking |

On the default bridge, containers can reach each other by IP but **not by name**:

```bash
docker run -d --name a alpine sleep 3600
docker run -d --name b alpine sleep 3600

# By IP works
docker exec b ping -c 1 "$(docker inspect --format '{{.NetworkSettings.IPAddress}}' a)"

# By name fails
docker exec b ping -c 1 a 2>&1 || true
```

```text
ping: bad address 'a'
```

```bash
docker rm -f a b
```

---

## 15.17 Custom Networks and Service Discovery

Custom networks solve name resolution. Docker/Podman runs an embedded DNS server on custom networks, so containers can reach each other **by name**.

```bash
# Create a custom network
docker network create app-net

# Start containers on it
docker run -d --name db --network app-net \
  -e POSTGRES_PASSWORD=secretpass postgres:16

docker run -d --name web --network app-net nginx

# DNS resolution works
docker exec web ping -c 2 db
```

```text
PING db (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.072 ms
```

This is how applications find databases in container environments — by container name, not by IP address (which can change).

### Connecting Containers: App + Database

Let's combine custom networking with volumes — the pattern for our three-tier app:

```bash
docker network create backend

docker run -d --name pg \
  --network backend \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=webapp \
  -e POSTGRES_DB=appdata \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

sleep 3
docker exec pg pg_isready -U webapp
```

```text
/var/run/postgresql:5432 - accepting connections
```

```bash
# Prove another container can resolve and connect to "pg"
docker run -it --rm --network backend python:3.12-slim \
  python3 -c "import socket; print(socket.gethostbyname('pg'))"
```

```text
172.18.0.2
```

A real application would use `postgresql://webapp:secretpass@pg:5432/appdata` as its connection string — the container name `pg` as the hostname.

```bash
docker rm -f pg web db 2>/dev/null
docker volume rm pgdata 2>/dev/null
docker network rm app-net backend 2>/dev/null
```

---

## 15.18 Resource Limits

By default, containers can consume unlimited host resources. In production, always set limits — they use the cgroups mechanism from Section 15.1.

```bash
# Memory limit (OOM killer terminates if exceeded)
docker run -d --name mem-limited --memory 256m nginx

# CPU limit (0.5 cores)
docker run -d --name cpu-limited --cpus 0.5 nginx

# Combined
docker run -d --name production --memory 512m --cpus 1.0 nginx

# Verify
docker inspect --format '{{.HostConfig.Memory}}' mem-limited
```

```text
268435456
```

That's 256 MB in bytes, enforced by the kernel.

```bash
docker rm -f mem-limited cpu-limited production
```

---

## 15.19 Inspecting and Debugging Containers

```bash
docker run -d --name web -p 8080:80 nginx
curl -s http://localhost:8080 > /dev/null
```

### logs

```bash
docker logs web                    # All logs
docker logs --follow web           # Real-time (like tail -f)
docker logs --tail 10 web          # Last 10 lines
docker logs --since "1h" web       # Since 1 hour ago
```

### stats

```bash
docker stats --no-stream
```

```text
CONTAINER ID   NAME   CPU %   MEM USAGE / LIMIT     MEM %   NET I/O       BLOCK I/O   PIDS
a1b2c3d4e5f6   web    0.00%   7.4MiB / 7.8GiB      0.09%   2.6kB / 0B    0B / 0B     5
```

### top and diff

```bash
docker top web                     # Container processes (host PIDs)
docker diff web                    # Filesystem changes (C=changed, A=added, D=deleted)
```

### inspect

```bash
docker inspect web                                                        # Full JSON
docker inspect --format '{{.State.Status}}' web                          # Single field
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web
```

```bash
docker rm -f web
```

---

## 15.20 Cleaning Up

Containers, images, and volumes accumulate. Here's how to reclaim space:

```bash
# Remove all stopped containers
docker container prune

# Remove unused images (add -a for ALL unused, not just dangling)
docker image prune

# Remove unused volumes (careful — this deletes persistent data)
docker volume prune

# Nuclear option: everything unused (add --volumes to include volumes)
docker system prune

# Check disk usage
docker system df
```

```text
TYPE            TOTAL   ACTIVE   SIZE      RECLAIMABLE
Images          5       2        1.234GB   812.3MB (65%)
Containers      3       1        12.45MB   10.2MB (81%)
Local Volumes   2       1        256.7MB   128.3MB (50%)
```

---

## 15.21 Docker vs Podman Command Comparison

| Task | Docker | Podman |
|------|--------|--------|
| Run container | `docker run -d nginx` | `podman run -d nginx` |
| List containers | `docker ps` | `podman ps` |
| Stop/remove | `docker stop web && docker rm web` | `podman stop web && podman rm web` |
| View logs | `docker logs web` | `podman logs web` |
| Exec into container | `docker exec -it web bash` | `podman exec -it web bash` |
| Pull image | `docker pull nginx` | `podman pull nginx` |
| List images | `docker images` | `podman images` |
| Create volume | `docker volume create data` | `podman volume create data` |
| Create network | `docker network create net` | `podman network create net` |
| System cleanup | `docker system prune` | `podman system prune` |
| Build image | `docker build -t app .` | `podman build -t app .` |
| Compose | `docker compose up` | `podman compose up` |

Where they genuinely differ:

| Feature | Docker | Podman |
|---------|--------|--------|
| Needs sudo? | Yes (without `docker` group) | No (rootless default) |
| Daemon required? | Yes (`dockerd`) | No |
| Generate systemd unit | N/A | `podman generate systemd --name web` |
| Pod support | No | `podman pod create --name mypod` |
| Default registry | `docker.io` | May prompt to select |

On Rocky, `alias docker=podman` works for the vast majority of commands.

---

## 15.22 Connection to the Three-Tier App

Remember the PostgreSQL database from Week 13? You installed it directly on your VMs, configured users, created databases, and connected a Flask API over the local network. That works, but containers improve on it significantly:

```bash
# Week 13 approach: apt install postgresql, systemctl start, edit pg_hba.conf...
# Week 15 approach:
docker run -d --name pg16 \
  --network backend \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=webapp \
  -e POSTGRES_DB=appdata \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

That single command gives you a specific PostgreSQL version (regardless of distro packages), isolated from the host, with persistent data, configurable via environment variables, and reproducible on any machine with Docker or Podman.

```text
┌──────────────────────────────────────────────────────────┐
│                       Host Machine                        │
│                                                           │
│  ┌──────────┐     ┌──────────┐     ┌──────────┐         │
│  │  nginx   │────→│  Flask   │────→│ PostgreSQL│         │
│  │ (proxy)  │     │  (API)   │     │   (DB)   │         │
│  └──────────┘     └──────────┘     └──────────┘         │
│       └───────────────┴─────────────────┘                │
│                  Custom Network                           │
│                                                           │
│                Named Volume: pgdata                       │
└──────────────────────────────────────────────────────────┘
```

In Week 16, we containerize the Flask API and nginx. In Week 17, we orchestrate all three with Docker Compose. The foundation is what you learned this week: images, volumes, networks, and the container lifecycle.

---

## What's Next

This week gave you the fundamentals of containerization. Next week builds on every concept:

- **In Week 16**, you'll write Dockerfiles to build custom images, optimize builds with multi-stage Dockerfiles, and containerize the entire three-tier application.
- **In Week 17**, you'll orchestrate the stack with Docker Compose, adding health checks, restart policies, and production hardening.

The pattern continues: understand each piece individually before assembling the whole.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 15.1: Container Basics](./lab-01-container-basics)** — Pull and run containers, inspect them, work with port mapping and environment variables on both Docker and Podman
- **[Lab 15.2: Volumes & Networking](./lab-02-volumes-and-networking)** — Create persistent volumes for PostgreSQL, set up custom networks for container communication

---

## Checklist

Before moving to Week 16, confirm you can:

- [ ] Explain what containers are (namespaces + cgroups) and how they differ from VMs
- [ ] Pull images and run containers with Docker and Podman
- [ ] Map ports between host and container with -p
- [ ] Pass environment variables to containers with -e
- [ ] Execute commands inside running containers with exec -it
- [ ] Create and use named volumes for persistent data
- [ ] Use bind mounts to share host directories with containers
- [ ] Create custom networks and connect containers to them
- [ ] Verify container-to-container communication by name on custom networks
- [ ] View container logs, resource usage, and process lists
- [ ] Clean up stopped containers, unused images, and dangling volumes
- [ ] Run equivalent commands on both Docker (Ubuntu) and Podman (Rocky)

---

