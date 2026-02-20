# Week 15: Container Fundamentals

> **Goal:** Understand containerization concepts, run and manage containers with Docker and Podman, and work with images, volumes, and container networking.

[← Previous Week](../week-14/README.md) · [Next Week →](../week-16/README.md)

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
| 15.11 | [Image Registries](#1511-image-registries) |
| 15.12 | [Image Layers and Copy-on-Write](#1512-image-layers-and-copy-on-write) |
| 15.13 | [Port Mapping](#1513-port-mapping) |
| 15.14 | [Environment Variables](#1514-environment-variables) |
| 15.15 | [Container Filesystem: Ephemeral by Default](#1515-container-filesystem-ephemeral-by-default) |
| 15.16 | [Volumes and Persistent Storage](#1516-volumes-and-persistent-storage) |
| 15.17 | [When to Use Named Volumes vs Bind Mounts](#1517-when-to-use-named-volumes-vs-bind-mounts) |
| 15.18 | [Container Networking](#1518-container-networking) |
| 15.19 | [Custom Networks and DNS-Based Service Discovery](#1519-custom-networks-and-dns-based-service-discovery) |
| 15.20 | [Connecting Containers: App + Database](#1520-connecting-containers-app--database) |
| 15.21 | [Resource Limits](#1521-resource-limits) |
| 15.22 | [Inspecting and Debugging Containers](#1522-inspecting-and-debugging-containers) |
| 15.23 | [Cleaning Up](#1523-cleaning-up) |
| 15.24 | [Docker vs Podman Command Comparison](#1524-docker-vs-podman-command-comparison) |
| 15.25 | [Connection to the Three-Tier App](#1525-connection-to-the-three-tier-app) |

---

## 15.1 What Containers Actually Are

If you've heard that containers are "lightweight virtual machines," forget that right now. It's the most common misconception in the industry, and it leads to fundamental misunderstandings about how containers work, what they can do, and where they break.

A **container** is a regular Linux process (or group of processes) that the kernel isolates from other processes using two mechanisms you've already encountered in this course:

1. **Namespaces** — provide isolation. Each container gets its own view of the system: its own process tree (PID namespace), its own network stack (network namespace), its own filesystem mount points (mount namespace), its own hostname (UTS namespace), and its own user IDs (user namespace). The processes inside the container genuinely cannot see processes, files, or network interfaces belonging to other containers or the host — not because of a hypervisor, but because the kernel simply doesn't show them.

2. **cgroups** (control groups) — provide resource limits. Back in Week 7, we briefly touched on cgroups when discussing process resource consumption. Containers use cgroups to enforce CPU, memory, and I/O limits. A container allocated 512 MB of RAM cannot use 513 MB — the kernel enforces this at the process level.

Let's make this concrete. Start a container and compare it to a regular process:

```bash
# On the host, see all processes
ps aux | wc -l
```

```text
187
```

```bash
# Start a container
docker run -d --name demo nginx

# Inside the container, the process thinks it's alone
docker exec demo ps aux
```

```text
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.1  10784  5636 ?        Ss   14:32   0:00 nginx: master process nginx -g daemon off;
nginx       29  0.0  0.0  11244  2572 ?        S    14:32   0:00 nginx: worker process
root        35  0.0  0.0   6700  1600 ?        Rs   14:33   0:00 ps aux
```

The container sees only three processes. PID 1 is nginx — not systemd, not the kernel's init. The container has its own PID namespace, so it counts from 1. But on the host:

```bash
# On the host, find the nginx process
ps aux | grep "nginx: master"
```

```text
root     12847  0.0  0.1  10784  5636 ?        Ss   14:32   0:00 nginx: master process nginx -g daemon off;
```

There it is — the same nginx process, but with a host PID of 12847. It's not running in a VM. It's running on the host kernel, in the same way any other process would. The kernel just lies to it about what it can see.

This is the crucial insight: **containers are processes, not machines.** They share the host's kernel. There is no second kernel, no virtual hardware, no boot sequence. A container starts in milliseconds because it's just a `fork()` and `exec()` with some namespace and cgroup configuration applied by the kernel.

```bash
# Clean up
docker rm -f demo
```

---

## 15.2 Containers vs Virtual Machines

Now that you understand what containers actually are, let's compare them properly to the VMs you've been running throughout this course. Your Ubuntu and Rocky VMs in Parallels are full virtual machines — each one has its own kernel, its own boot process, its own memory space managed by a hypervisor.

```text
┌────────────────────────────────────────────────────────────┐
│                    Virtual Machines                         │
│                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │   App    │  │   App    │  │   App    │                │
│  │  Libs    │  │  Libs    │  │  Libs    │                │
│  │  OS/     │  │  OS/     │  │  OS/     │                │
│  │ Kernel   │  │ Kernel   │  │ Kernel   │                │
│  └──────────┘  └──────────┘  └──────────┘                │
│           Hypervisor (Parallels, KVM, etc.)                │
│                  Host Operating System                      │
│                      Hardware                              │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                      Containers                            │
│                                                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │   App    │  │   App    │  │   App    │                │
│  │  Libs    │  │  Libs    │  │  Libs    │                │
│  └──────────┘  └──────────┘  └──────────┘                │
│       Container Runtime (Docker, Podman)                   │
│                  Host Operating System                      │
│                   Host Kernel (shared)                      │
│                      Hardware                              │
└────────────────────────────────────────────────────────────┘
```

| Characteristic | Virtual Machines | Containers |
|---------------|-----------------|------------|
| Isolation level | Full hardware virtualization | Kernel namespaces and cgroups |
| Kernel | Each VM has its own | Shares host kernel |
| Boot time | 30-90 seconds | Milliseconds to seconds |
| Disk footprint | Gigabytes (full OS) | Megabytes (just app + dependencies) |
| Resource overhead | Significant (each VM reserves RAM) | Minimal (processes use only what they need) |
| Security boundary | Strong (hypervisor separation) | Weaker (shared kernel surface) |
| OS flexibility | Any OS on any hypervisor | Linux containers on Linux kernels |
| Use case | Different OS/kernel requirements, strong isolation | Application packaging, microservices, dev environments |

### When to Use Which

Use **VMs** when you need:
- Different operating systems or kernel versions
- Strong security boundaries between workloads (multi-tenant cloud)
- Windows workloads on Linux hosts (or vice versa)
- Legacy applications that require a specific kernel

Use **containers** when you need:
- Fast startup and shutdown
- Consistent environments from development to production
- Dense packing of many applications on the same host
- Reproducible builds and deployments
- Microservice architectures

In practice, you often use both: containers running *inside* VMs. Your cloud provider gives you a VM, and you run containers within it. That's exactly what we're doing — running containers inside your Ubuntu and Rocky VMs.

---

## 15.3 The OCI Standard

In the early days of Docker (2013-2015), Docker was the only game in town. Docker images, Docker runtimes, Docker registries — everything was Docker-specific. This created a concern: what if your entire infrastructure depended on a single company's proprietary format?

The industry's answer was the **Open Container Initiative (OCI)**, founded in 2015 under the Linux Foundation. The OCI defines two critical specifications:

1. **OCI Image Specification** — defines the format for container images (the layers, manifests, and metadata that make up a packaged application)
2. **OCI Runtime Specification** — defines how to run a container (the interface between a container engine and the Linux kernel)

What this means for you: **images and runtimes are interchangeable.** An image built with Docker can be run by Podman. An image pulled from Docker Hub can be stored in any OCI-compliant registry. An image built on your laptop runs identically on a Kubernetes cluster in the cloud.

This is why we can teach Docker and Podman side by side. They speak the same language because they conform to the same standards. The commands are nearly identical, the image format is the same, and containers built with one tool run perfectly with the other.

---

## 15.4 Docker vs Podman

Both Docker and Podman are **container engines** — tools that build, pull, run, and manage containers. They're both OCI-compliant, and their CLIs are deliberately compatible. But their architectures differ in important ways.

| Feature | Docker | Podman |
|---------|--------|--------|
| Architecture | Client-server (daemon) | Daemonless (fork-exec) |
| Root daemon | `dockerd` runs as root | No persistent daemon |
| Rootless mode | Supported (extra setup) | Default and first-class |
| CLI syntax | `docker <command>` | `podman <command>` (identical) |
| Compose support | `docker compose` (built-in) | `podman-compose` or `podman compose` |
| Systemd integration | Separate from systemd | Generates systemd unit files |
| Default on | Ubuntu (most common) | RHEL/Rocky/Fedora |
| Socket | `/var/run/docker.sock` | Per-user socket (rootless) |
| Pod support | No native pods | Supports Kubernetes-style pods |

### Docker's Architecture

Docker uses a **client-server model**. When you type `docker run`, the Docker CLI sends the request to the Docker daemon (`dockerd`), which is a long-running background process. The daemon does the actual work: pulling images, creating containers, managing networks. This daemon runs as root.

```text
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  docker CLI  │────→│  dockerd (daemon) │────→│  containerd  │
│  (client)    │     │  (root, PID 1...)│     │  (runtime)   │
└──────────────┘     └──────────────────┘     └──────────────┘
                            │
                     Manages: images, containers,
                     networks, volumes
```

The daemon model has a consequence: if the daemon crashes, every container it manages is affected. It also means any user with access to the Docker socket (`/var/run/docker.sock`) effectively has root access to the host.

### Podman's Architecture

Podman is **daemonless**. When you type `podman run`, the Podman binary directly forks the container process. There is no intermediary daemon. Each container is a direct child process of the Podman command that created it.

```text
┌──────────────┐     ┌──────────────┐
│  podman CLI  │────→│  Container   │
│  (fork/exec) │     │  (process)   │
└──────────────┘     └──────────────┘
```

This means:
- No single point of failure (no daemon to crash)
- **Rootless by default** — regular users can run containers without root privileges
- Natural systemd integration — containers are just processes that systemd can manage
- Each user has their own container storage

### Which Should You Learn?

Both. The CLI is nearly identical (`docker` and `podman` are interchangeable for 95% of commands), so learning one means you effectively know the other. In this course, we'll use Docker on Ubuntu and Podman on Rocky, mirroring what you'll encounter in the real world: Docker dominates in general use and CI/CD pipelines, while Podman is the default on Red Hat Enterprise Linux and its derivatives.

---

## 15.5 Installing Docker Engine on Ubuntu

Docker is not included in Ubuntu's default repositories. The `docker.io` package in Ubuntu's universe repository is outdated, and the Snap version has known issues with file permissions. Always install from Docker's official repository.

### Step 1: Remove Old Versions

```bash
# Remove any unofficial Docker packages
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null
```

### Step 2: Install Prerequisites

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
```

### Step 3: Add Docker's GPG Key

This process should feel familiar from Week 6 when we added third-party repositories:

```bash
# Create the keyring directory
sudo install -m 0755 -d /etc/apt/keyrings

# Download and install Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set permissions on the key
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

### Step 4: Add the Repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### Step 5: Install Docker Engine

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Step 6: Allow Your User to Run Docker Without sudo

By default, Docker requires root. Adding your user to the `docker` group allows you to run `docker` commands without `sudo`:

```bash
sudo usermod -aG docker "$USER"
```

Log out and back in for the group change to take effect (or run `newgrp docker` to activate it in the current shell).

### Step 7: Verify the Installation

```bash
docker run hello-world
```

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
...
```

```bash
# Check the version
docker version
```

You should see both Client and Server versions. The Server section confirms the daemon is running.

```bash
# Check the daemon status via systemd
systemctl status docker
```

Docker is a systemd service — exactly like the services you managed in Week 11. The daemon starts automatically at boot.

---

## 15.6 Installing Podman on Rocky

Podman comes from the Red Hat ecosystem and is available in Rocky's default repositories. Installation is straightforward:

```bash
sudo dnf install -y podman
```

That's it. No daemon to start, no socket to configure, no group to join.

### Verify the Installation

```bash
podman run hello-world
```

The first time you run this, Podman may prompt you to select a registry. Choose `docker.io` (Docker Hub). You can avoid this prompt by using fully qualified image names:

```bash
podman run docker.io/library/hello-world
```

```bash
# Check the version
podman version
```

Notice there is no "Server" section in the version output — because there is no daemon.

### Rootless Verification

Since Podman runs rootless by default, verify that your container ran without root:

```bash
podman info | grep rootless
```

```text
  rootless: true
```

This is a meaningful security advantage. Your containers run with your user's privileges, not root's.

---

## 15.7 Container Lifecycle

Every container goes through a predictable lifecycle. Understanding these states is essential for debugging — when a container isn't doing what you expect, the first question is always "what state is it in?"

```text
        docker/podman run
              │
              ▼
         ┌─────────┐    docker/podman stop    ┌─────────┐
         │ Running  │───────────────────────→│ Stopped  │
         │ (Up)     │                         │ (Exited) │
         └─────────┘                         └─────────┘
              │                                    │
              │   (process exits)                   │
              ▼                                    │
         ┌─────────┐    docker/podman start   │
         │ Exited   │←─────────────────────────┘
         │          │
         └─────────┘
              │
              │  docker/podman rm
              ▼
         ┌─────────┐
         │ Removed  │
         │          │
         └─────────┘
```

Let's walk through the lifecycle with real commands. These are identical for Docker and Podman — just substitute `podman` for `docker` on Rocky.

### Run a Container

```bash
# Start an nginx container in the background
docker run -d --name web nginx
```

### List Running Containers

```bash
docker ps
```

```text
CONTAINER ID   IMAGE   COMMAND                  CREATED          STATUS          PORTS     NAMES
a1b2c3d4e5f6   nginx   "/docker-entrypoint.…"   5 seconds ago    Up 4 seconds    80/tcp    web
```

### List All Containers (Including Stopped)

```bash
docker ps -a
```

This shows containers in every state — running, exited, and created. This is the command you need when a container "disappears" — it's probably still there, just stopped.

### Stop a Container

```bash
docker stop web
```

This sends SIGTERM to the container's PID 1 process, waits 10 seconds (the default grace period), then sends SIGKILL if the process hasn't exited. This is the same signal behavior we discussed in Week 7.

### Start a Stopped Container

```bash
docker start web
```

This restarts the container with the same configuration it was created with.

### Restart a Container

```bash
docker restart web
```

Equivalent to `stop` followed by `start`.

### View Container Logs

```bash
docker logs web
```

This shows everything the container's PID 1 has written to stdout and stderr — the container equivalent of `journalctl -u <service>` from Week 11.

### Remove a Container

```bash
# Must stop first (or use -f to force)
docker stop web
docker rm web

# Or in one step
docker rm -f web
```

A stopped container still occupies disk space. Removing it frees that space. You cannot remove a running container without the `-f` (force) flag.

### Inspect a Container

```bash
docker run -d --name web nginx
docker inspect web
```

This returns a JSON document with every detail about the container: network settings, mount points, environment variables, resource limits, state, and more. It's the most comprehensive debugging tool for containers.

```bash
# Extract specific fields with --format
docker inspect --format '{{.NetworkSettings.IPAddress}}' web
```

```bash
docker rm -f web
```

---

## 15.8 Understanding docker run Flags

The `docker run` command is the most complex command you'll use. It creates and starts a container in one step. Understanding its flags is essential.

### Detached Mode: -d

```bash
# Run in the background (detached)
docker run -d --name web nginx
```

Without `-d`, the container runs in the foreground — its output streams to your terminal, and Ctrl+C stops it. With `-d`, it runs in the background and you get your shell prompt back.

### Interactive + TTY: -it

```bash
# Run interactively with a terminal
docker run -it --name shell alpine sh
```

The `-i` flag keeps stdin open. The `-t` flag allocates a pseudo-TTY. Together, they let you interact with the container as if you SSH'd into it. You'll use `-it` whenever you need a shell inside a container.

### Naming: --name

```bash
docker run -d --name my-web-server nginx
```

Without `--name`, Docker assigns a random name like `quirky_ptolemy`. Named containers are easier to reference in scripts, logs, and `docker exec` commands. Choose descriptive names.

### Auto-Remove: --rm

```bash
# Container is automatically removed when it exits
docker run --rm alpine echo "I will be cleaned up"
```

Without `--rm`, exited containers stay around (visible in `docker ps -a`) until you manually remove them. Use `--rm` for throwaway containers — quick tests, one-off commands, and interactive debugging sessions.

### Combining Flags

```bash
# A common pattern: detached, named, auto-mapped port
docker run -d --name web -p 8080:80 nginx

# Another common pattern: interactive, auto-remove
docker run -it --rm alpine sh
```

```bash
docker rm -f web 2>/dev/null
```

---

## 15.9 Interactive Containers

You'll frequently need to get inside a running container to inspect files, check configurations, or debug problems. There are two ways to do this.

### exec — Run a Command in a Running Container

```bash
# Start a background nginx container
docker run -d --name web nginx

# Get a shell inside it
docker exec -it web bash
```

You're now inside the container. Look around:

```bash
# Inside the container
hostname
cat /etc/os-release
ls /etc/nginx/
ps aux
exit
```

The container is running Debian (nginx's default base image). It has its own hostname, its own filesystem, and its own process tree. When you type `exit`, you leave the shell but the container keeps running — `exec` doesn't affect the container's main process.

### exec Without -it (Non-Interactive Commands)

```bash
# Run a single command and get the output
docker exec web cat /etc/nginx/nginx.conf

# Check what processes are running
docker exec web ps aux
```

### attach — Connect to the Main Process

```bash
docker attach web
```

`attach` connects your terminal to the container's PID 1 — the main process. For nginx, this means you'll see access logs as requests come in. The critical difference: pressing Ctrl+C with `attach` sends SIGINT to PID 1 and **stops the container**. With `exec`, Ctrl+C only stops the exec'd process.

| Command | Connects to | Ctrl+C effect | Container keeps running? |
|---------|-------------|---------------|-------------------------|
| `exec -it ... bash` | New process | Exits the shell | Yes |
| `attach` | PID 1 | Stops the container | No |

Use `exec` for debugging. Use `attach` only when you need to interact with the main process and understand that detaching (Ctrl+P, Ctrl+Q) is the safe way out.

```bash
docker rm -f web
```

---

## 15.10 Working with Images

An **image** is a read-only template used to create containers. Think of it as a snapshot of a filesystem plus metadata (what command to run, what ports to expose, what environment variables to set). Every container is created from an image.

### Pull an Image

```bash
docker pull nginx
```

```text
Using default tag: latest
latest: Pulling from library/nginx
a2abf6c4d29d: Pull complete
a9edb18cadd1: Pull complete
589b7251471a: Pull complete
186b1aaa4aa6: Pull complete
b4df32aa5a72: Pull complete
a0bcbecc962e: Pull complete
Digest: sha256:0d17b565c37bcbd895e9...
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
```

### List Local Images

```bash
docker images
```

```text
REPOSITORY   TAG       IMAGE ID       CREATED       SIZE
nginx        latest    605c77e624dd   2 weeks ago   141MB
alpine       latest    9c6f07244728   3 weeks ago   5.53MB
```

### Remove an Image

```bash
docker rmi nginx
```

You can't remove an image if a container (even a stopped one) is using it. Remove the containers first.

### Tag an Image

```bash
docker tag nginx:latest my-registry.example.com/nginx:v1.25
```

Tagging adds an additional name to an existing image. The image data isn't copied — both tags point to the same layers on disk.

### Image History

```bash
docker history nginx
```

```text
IMAGE          CREATED       CREATED BY                                      SIZE
605c77e624dd   2 weeks ago   /bin/sh -c #(nop)  CMD ["nginx" "-g" "daemon…   0B
<missing>      2 weeks ago   /bin/sh -c #(nop)  STOPSIGNAL SIGQUIT           0B
<missing>      2 weeks ago   /bin/sh -c #(nop)  EXPOSE 80                    0B
<missing>      2 weeks ago   /bin/sh -c set -x     && addgroup --system -…   61.1MB
...
```

This shows every layer in the image and the command that created it. We'll build our own images in Week 16, and this command will become essential for understanding and optimizing your builds.

### Image Naming Convention

The full image name follows a specific format:

```text
registry/namespace/repository:tag

Examples:
  docker.io/library/nginx:latest       # Official nginx image from Docker Hub
  docker.io/library/nginx:1.25-alpine  # Specific version, Alpine-based
  ghcr.io/myorg/myapp:v2.1.0          # GitHub Container Registry
  quay.io/prometheus/node-exporter:latest
```

| Component | Meaning | Default |
|-----------|---------|---------|
| Registry | Where the image lives | `docker.io` |
| Namespace | Owner/organization | `library` (for official images) |
| Repository | Image name | (required) |
| Tag | Version/variant | `latest` |

The `latest` tag is not automatically the newest version — it's just the default tag applied when you don't specify one. In production, always use specific version tags.

---

## 15.11 Image Registries

An **image registry** is a server that stores and distributes container images. When you run `docker pull nginx`, Docker contacts a registry, downloads the image layers, and caches them locally.

| Registry | URL | Purpose |
|----------|-----|---------|
| Docker Hub | `docker.io` | The default registry; largest public collection |
| GitHub Container Registry | `ghcr.io` | Tied to GitHub repos; good for open-source projects |
| Quay.io | `quay.io` | Red Hat's registry; used by many RHEL/OpenShift projects |
| Amazon ECR | `<account>.dkr.ecr.<region>.amazonaws.com` | AWS private registry |
| Google Artifact Registry | `<region>-docker.pkg.dev` | GCP private registry |

Docker Hub deserves special mention. It has two classes of images:

- **Official images** — maintained by Docker in partnership with upstream projects (e.g., `nginx`, `postgres`, `python`). These live in the `library` namespace and are shown without a namespace prefix: `nginx` is shorthand for `docker.io/library/nginx`.
- **Community images** — maintained by individuals or organizations (e.g., `bitnami/postgresql`, `grafana/grafana`). Always evaluate the publisher, download count, and update frequency before trusting a community image.

Podman works with the same registries. On Rocky, Podman is configured to search multiple registries by default:

```bash
# On Rocky, see configured registries
cat /etc/containers/registries.conf.d/*.conf
```

---

## 15.12 Image Layers and Copy-on-Write

Understanding image layers is important both for efficient disk usage and for building optimized images in Week 16.

Every image is made of **layers**. Each layer represents a set of filesystem changes — files added, modified, or deleted. Layers are stacked on top of each other to form the final filesystem.

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

Key properties of layers:

- **Layers are read-only.** Once created, a layer never changes.
- **Layers are shared.** If five containers use the `nginx` image, they share the same image layers on disk. The image is stored once.
- **Containers add a writable layer.** When a container starts, a thin read-write layer (called the **container layer**) is placed on top of the image layers. Any file changes inside the running container are written to this layer.

This is the **copy-on-write** mechanism. When a container modifies a file that exists in an image layer, the file is first copied to the container's writable layer, then modified there. The original image layer is untouched. This is why:

- Starting a container is fast (no filesystem copy needed)
- Multiple containers from the same image use minimal extra disk space
- Deleting a container (and its writable layer) has no effect on the image

```bash
# See the layers of the nginx image
docker inspect nginx | grep -A 20 '"Layers"'
```

---

## 15.13 Port Mapping

Containers have their own network namespace, which means their ports are isolated from the host by default. An nginx container listening on port 80 inside the container is not accessible from the host unless you explicitly map the port.

### Basic Port Mapping

```bash
# Map host port 8080 to container port 80
docker run -d --name web -p 8080:80 nginx
```

The syntax is `-p hostPort:containerPort`. Now you can reach nginx:

```bash
curl -s http://localhost:8080 | head -5
```

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
</head>
```

### Multiple Port Mappings

```bash
docker run -d --name multi-port -p 8080:80 -p 8443:443 nginx
```

### Bind to a Specific Interface

```bash
# Only accessible on localhost, not from the network
docker run -d --name local-only -p 127.0.0.1:8080:80 nginx
```

This is a security best practice when a container should only be accessed locally (e.g., a database that sits behind an application).

### Random Host Port

```bash
# Let Docker pick an available host port
docker run -d --name random-port -p 80 nginx

# See which port was assigned
docker port random-port
```

```text
80/tcp -> 0.0.0.0:32768
```

### View Port Mappings

```bash
docker port web
```

```text
80/tcp -> 0.0.0.0:8080
```

```bash
docker rm -f web multi-port local-only random-port 2>/dev/null
```

---

## 15.14 Environment Variables

Environment variables are the primary way to configure containers. Almost every production container reads its configuration from environment variables rather than config files. You've seen environment variables in bash scripts (Week 8) — containers use them the same way, but they're set at container creation time.

### Pass a Single Variable

```bash
docker run -d --name db \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=myapp \
  -e POSTGRES_DB=appdata \
  postgres:16
```

### Verify Variables Inside the Container

```bash
docker exec db env | grep POSTGRES
```

```text
POSTGRES_PASSWORD=secretpass
POSTGRES_USER=myapp
POSTGRES_DB=appdata
```

### Use an Environment File

For containers with many variables, use `--env-file` with a file containing `KEY=VALUE` pairs:

```bash
# Create an env file
cat > db.env << 'EOF'
POSTGRES_PASSWORD=secretpass
POSTGRES_USER=myapp
POSTGRES_DB=appdata
PGDATA=/var/lib/postgresql/data/pgdata
EOF

# Pass it to the container
docker run -d --name db --env-file db.env postgres:16
```

This keeps secrets out of your shell history and command line. In production, the env file would be managed by your deployment system and excluded from version control.

```bash
docker rm -f db
rm -f db.env
```

---

## 15.15 Container Filesystem: Ephemeral by Default

This is one of the most important concepts in container fundamentals: **everything written inside a container is lost when the container is removed.**

Let's prove it:

```bash
# Create a container and write a file
docker run -d --name test-data alpine sleep 3600
docker exec test-data sh -c 'echo "important data" > /tmp/myfile.txt'
docker exec test-data cat /tmp/myfile.txt
```

```text
important data
```

```bash
# Stop and remove the container
docker rm -f test-data

# Start a new container from the same image
docker run -d --name test-data alpine sleep 3600
docker exec test-data cat /tmp/myfile.txt
```

```text
cat: can't open '/tmp/myfile.txt': No such file or directory
```

The file is gone. The new container started with a fresh writable layer on top of the same image. The previous container's writable layer was deleted when we ran `docker rm`.

This is by design. Containers should be **disposable** — you should be able to destroy one and create a replacement at any time. But what about data that needs to persist? That's what volumes are for.

```bash
docker rm -f test-data
```

---

## 15.16 Volumes and Persistent Storage

**Volumes** are Docker/Podman's mechanism for persistent data. They exist outside the container's filesystem, so they survive container removal. There are three types of persistent storage:

### 1. Named Volumes

A **named volume** is managed by Docker/Podman. It lives in a dedicated storage area on the host (`/var/lib/docker/volumes/` for Docker) and is referenced by name.

```bash
# Create a named volume
docker volume create pgdata

# List volumes
docker volume ls
```

```text
DRIVER    VOLUME NAME
local     pgdata
```

```bash
# Use it with a container
docker run -d --name db \
  -e POSTGRES_PASSWORD=secretpass \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

The `-v pgdata:/var/lib/postgresql/data` syntax mounts the named volume `pgdata` at the path `/var/lib/postgresql/data` inside the container. PostgreSQL writes its data files there. If we remove this container and create a new one with the same volume, the data is still there.

```bash
# Inspect a volume
docker volume inspect pgdata
```

```text
[
    {
        "CreatedAt": "2026-02-20T14:32:00Z",
        "Driver": "local",
        "Labels": {},
        "Mountpoint": "/var/lib/docker/volumes/pgdata/_data",
        "Name": "pgdata",
        "Options": {},
        "Scope": "local"
    }
]
```

### 2. Bind Mounts

A **bind mount** maps a specific host directory into the container. Unlike named volumes, you control exactly where the data lives on the host.

```bash
# Create a directory on the host
mkdir -p /home/$USER/web-content
echo "<h1>Hello from the host</h1>" > /home/$USER/web-content/index.html

# Mount it into a container
docker run -d --name web \
  -p 8080:80 \
  -v /home/$USER/web-content:/usr/share/nginx/html:ro \
  nginx
```

```bash
curl -s http://localhost:8080
```

```text
<h1>Hello from the host</h1>
```

The `:ro` suffix makes the mount read-only inside the container — the container can read the files but can't modify them. This is a security best practice for content that shouldn't be writable by the container.

Bind mounts are bidirectional (unless `:ro`). Changes on the host appear in the container immediately, and changes in the container appear on the host.

### 3. tmpfs Mounts

A **tmpfs mount** stores data in the host's memory. The data is never written to disk and disappears when the container stops. Use tmpfs for sensitive data that should not persist.

```bash
docker run -d --name secure-app \
  --tmpfs /run/secrets:rw,size=64m \
  alpine sleep 3600
```

```bash
docker rm -f db web secure-app
```

### Volume Lifecycle

Named volumes persist independently from containers:

```bash
# Create volume and container
docker volume create testdata
docker run -d --name writer -v testdata:/data alpine sh -c 'echo "persist me" > /data/message.txt && sleep 3600'

# Verify data is written
docker exec writer cat /data/message.txt
```

```text
persist me
```

```bash
# Remove the container
docker rm -f writer

# The volume still exists
docker volume ls | grep testdata
```

```text
local     testdata
```

```bash
# New container, same volume — data is still there
docker run --rm -v testdata:/data alpine cat /data/message.txt
```

```text
persist me
```

```bash
docker volume rm testdata
```

---

## 15.17 When to Use Named Volumes vs Bind Mounts

This decision comes up constantly. Here's a clear framework:

| Scenario | Use | Why |
|----------|-----|-----|
| Database data (PostgreSQL, MariaDB) | Named volume | Docker/Podman manages the storage; portable, easy to back up |
| Application source code (development) | Bind mount | Edit on host, see changes in container instantly |
| Configuration files | Bind mount | Maintain config in version control, mount into container |
| Static web content in production | Named volume | Managed lifecycle, not tied to host paths |
| Log output | Named volume or host bind mount | Depends on your log aggregation strategy |
| Temporary/sensitive data | tmpfs | Never touches disk |

The rule of thumb: **use named volumes for data the container generates** (database files, uploaded content, caches) and **bind mounts for data you provide** (source code, config files, static assets).

---

## 15.18 Container Networking

Containers need to communicate — with the host, with each other, and with the outside world. Container engines provide networking abstractions to make this work.

### The Default Bridge Network

When you install Docker, it creates a default network called `bridge`. Every container you start without specifying a network joins this bridge.

```bash
docker network ls
```

```text
NETWORK ID     NAME      DRIVER    SCOPE
a1b2c3d4e5f6   bridge    bridge    local
d7e8f9a0b1c2   host      host      local
f3g4h5i6j7k8   none      null      local
```

Three default networks:

| Network | Purpose |
|---------|---------|
| `bridge` | Default network; containers get isolated IPs, communicate via IP |
| `host` | Container uses the host's network stack directly (no isolation) |
| `none` | No networking at all |

On the default bridge network, containers can communicate by IP address but **not by name.** This is a deliberate limitation that custom networks solve.

```bash
# Start two containers on the default bridge
docker run -d --name container-a alpine sleep 3600
docker run -d --name container-b alpine sleep 3600

# Get container-a's IP
docker inspect --format '{{.NetworkSettings.IPAddress}}' container-a
```

```text
172.17.0.2
```

```bash
# container-b can reach container-a by IP
docker exec container-b ping -c 2 172.17.0.2
```

```text
PING 172.17.0.2 (172.17.0.2): 56 data bytes
64 bytes from 172.17.0.2: seq=0 ttl=64 time=0.089 ms
64 bytes from 172.17.0.2: seq=1 ttl=64 time=0.078 ms
```

```bash
# But NOT by name on the default bridge
docker exec container-b ping -c 2 container-a
```

```text
ping: bad address 'container-a'
```

```bash
docker rm -f container-a container-b
```

---

## 15.19 Custom Networks and DNS-Based Service Discovery

Custom networks solve the name resolution problem. When containers are on the same custom network, they can reach each other **by container name** — Docker/Podman runs an embedded DNS server on custom networks.

### Create a Custom Network

```bash
docker network create app-net
```

### Run Containers on the Custom Network

```bash
docker run -d --name db \
  --network app-net \
  -e POSTGRES_PASSWORD=secretpass \
  postgres:16

docker run -d --name web \
  --network app-net \
  nginx
```

### Verify DNS-Based Communication

```bash
# The web container can resolve "db" by name
docker exec web ping -c 2 db
```

```text
PING db (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.072 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.066 ms
```

The name `db` resolves to the container's IP address on the `app-net` network. This is how real applications connect to their databases in containerized environments — not by IP address (which can change), but by container name (which you control).

### Inspect the Network

```bash
docker network inspect app-net
```

This shows every container attached to the network, their IP addresses, and the network configuration.

### Connect an Existing Container to a Network

```bash
docker run -d --name monitoring alpine sleep 3600
docker network connect app-net monitoring

# Now monitoring can reach both db and web by name
docker exec monitoring ping -c 1 db
docker exec monitoring ping -c 1 web
```

### Disconnect from a Network

```bash
docker network disconnect app-net monitoring
```

```bash
docker rm -f db web monitoring
docker network rm app-net
```

---

## 15.20 Connecting Containers: App + Database

Let's put the pieces together. This pattern — an application connecting to a database on a shared custom network — is the foundation for the containerized three-tier app we'll build over the next two weeks.

```bash
# Create the network
docker network create backend

# Start PostgreSQL with a named volume for persistence
docker run -d --name pg \
  --network backend \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=webapp \
  -e POSTGRES_DB=appdata \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

# Wait a moment for PostgreSQL to initialize, then verify it's ready
sleep 3
docker exec pg pg_isready -U webapp
```

```text
/var/run/postgresql:5432 - accepting connections
```

```bash
# Start a Python container on the same network and connect to PostgreSQL
docker run -it --rm \
  --network backend \
  python:3.12-slim \
  python3 -c "
import socket
addr = socket.gethostbyname('pg')
print(f'Resolved pg to {addr}')
"
```

```text
Resolved pg to 172.18.0.2
```

The Python container resolved the hostname `pg` to the PostgreSQL container's IP. In a real application, you'd set a connection string like `postgresql://webapp:secretpass@pg:5432/appdata` — using the container name as the hostname.

```bash
docker rm -f pg
docker volume rm pgdata
docker network rm backend
```

---

## 15.21 Resource Limits

By default, a container can use as much CPU and memory as the host has available. In production, this is dangerous — one misbehaving container can starve everything else. Resource limits use the cgroups mechanism we discussed in Section 15.1.

### Memory Limits

```bash
# Limit to 256 MB of RAM
docker run -d --name limited \
  --memory 256m \
  nginx
```

If the container tries to use more than 256 MB, the kernel's OOM (Out Of Memory) killer will terminate it — just like it would any process that exhausts its cgroup memory limit (Week 7).

### CPU Limits

```bash
# Limit to 0.5 CPU cores
docker run -d --name cpu-limited \
  --cpus 0.5 \
  nginx

# Limit to specific CPU cores (pin to cores 0 and 1)
docker run -d --name cpu-pinned \
  --cpuset-cpus "0,1" \
  nginx
```

### Combined Limits

```bash
docker run -d --name production-app \
  --memory 512m \
  --cpus 1.0 \
  --name prod-nginx \
  nginx
```

### Verify Limits

```bash
docker inspect --format '{{.HostConfig.Memory}}' limited
```

```text
268435456
```

That's 256 MB in bytes. Resource limits are stored in the container's metadata and enforced by the kernel.

```bash
docker rm -f limited cpu-limited cpu-pinned prod-nginx 2>/dev/null
```

---

## 15.22 Inspecting and Debugging Containers

When something goes wrong, you need to diagnose the problem without guessing. Here are the debugging tools available to you.

### logs — Container Output

```bash
docker run -d --name web -p 8080:80 nginx

# Make some requests to generate log entries
curl -s http://localhost:8080 > /dev/null
curl -s http://localhost:8080/missing > /dev/null

# View logs
docker logs web
```

```text
172.17.0.1 - - [20/Feb/2026:14:50:12 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.81.0"
172.17.0.1 - - [20/Feb/2026:14:50:13 +0000] "GET /missing HTTP/1.1" 404 153 "-" "curl/7.81.0"
```

```bash
# Follow logs in real time (like tail -f)
docker logs --follow web
# Press Ctrl+C to stop following

# Show only the last 10 lines
docker logs --tail 10 web

# Show logs since a timestamp
docker logs --since "2026-02-20T14:50:00" web
```

### stats — Live Resource Usage

```bash
docker stats --no-stream
```

```text
CONTAINER ID   NAME   CPU %   MEM USAGE / LIMIT     MEM %   NET I/O       BLOCK I/O   PIDS
a1b2c3d4e5f6   web    0.00%   7.426MiB / 7.764GiB   0.09%   2.63kB / 0B   0B / 0B     5
```

Without `--no-stream`, this updates in real time — the container equivalent of `top` from Week 7.

### top — Container Processes

```bash
docker top web
```

```text
UID    PID     PPID    C    STIME   TTY   TIME       CMD
root   12847   12826   0    14:50   ?     00:00:00   nginx: master process nginx -g daemon off;
101    12908   12847   0    14:50   ?     00:00:00   nginx: worker process
```

This shows the container's processes as seen from the host (with host PIDs).

### diff — Filesystem Changes

```bash
# See what files changed in the container's writable layer
docker diff web
```

```text
C /var
C /var/cache
C /var/cache/nginx
A /var/cache/nginx/client_temp
A /var/cache/nginx/fastcgi_temp
...
```

`C` means changed, `A` means added, `D` means deleted. This is useful for understanding what a container wrote to its filesystem.

### inspect — Full Configuration

```bash
# Get complete container metadata as JSON
docker inspect web

# Extract specific fields
docker inspect --format '{{.State.Status}}' web
docker inspect --format '{{.Config.Image}}' web
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web
```

```bash
docker rm -f web
```

---

## 15.23 Cleaning Up

Containers, images, volumes, and networks accumulate over time. Here's how to reclaim disk space.

### Remove Stopped Containers

```bash
# Remove all stopped containers
docker container prune
```

```text
WARNING! This will remove all stopped containers.
Are you sure you want to continue? [y/N] y
Deleted Containers:
a1b2c3d4e5f6
...
Total reclaimed space: 12.5MB
```

### Remove Unused Images

```bash
# Remove images not used by any container
docker image prune

# Remove ALL unused images (not just dangling ones)
docker image prune -a
```

**Dangling images** are layers that no longer have a tag pointing to them — often the result of rebuilding an image with the same tag.

### Remove Unused Volumes

```bash
# Remove volumes not attached to any container
docker volume prune
```

Be careful with this one. Volumes contain persistent data. Once pruned, the data is gone.

### Nuclear Option: System Prune

```bash
# Remove ALL unused containers, networks, images, and (optionally) volumes
docker system prune

# Include volumes (dangerous — removes persistent data)
docker system prune --volumes
```

### Check Disk Usage

```bash
docker system df
```

```text
TYPE            TOTAL   ACTIVE   SIZE      RECLAIMABLE
Images          5       2        1.234GB   812.3MB (65%)
Containers      3       1        12.45MB   10.2MB (81%)
Local Volumes   2       1        256.7MB   128.3MB (50%)
Build Cache     0       0        0B        0B
```

This tells you exactly where disk space is being used and how much can be reclaimed.

---

## 15.24 Docker vs Podman Command Comparison

For daily use, Docker and Podman commands are nearly identical. Here is a comprehensive reference table:

| Task | Docker | Podman |
|------|--------|--------|
| Run a container | `docker run -d nginx` | `podman run -d nginx` |
| List running containers | `docker ps` | `podman ps` |
| List all containers | `docker ps -a` | `podman ps -a` |
| Stop a container | `docker stop web` | `podman stop web` |
| Remove a container | `docker rm web` | `podman rm web` |
| View logs | `docker logs web` | `podman logs web` |
| Exec into container | `docker exec -it web bash` | `podman exec -it web bash` |
| Pull an image | `docker pull nginx` | `podman pull nginx` |
| List images | `docker images` | `podman images` |
| Remove an image | `docker rmi nginx` | `podman rmi nginx` |
| Create a volume | `docker volume create data` | `podman volume create data` |
| Create a network | `docker network create net` | `podman network create net` |
| Inspect anything | `docker inspect web` | `podman inspect web` |
| Resource usage | `docker stats` | `podman stats` |
| System cleanup | `docker system prune` | `podman system prune` |
| Disk usage | `docker system df` | `podman system df` |
| Build an image | `docker build -t app .` | `podman build -t app .` |
| Compose | `docker compose up` | `podman-compose up` or `podman compose up` |

Where they differ:

| Feature | Docker | Podman |
|---------|--------|--------|
| Needs `sudo`? | Yes, unless user is in `docker` group | No (rootless by default) |
| Daemon required? | Yes (`dockerd` must be running) | No |
| Socket location | `/var/run/docker.sock` | `$XDG_RUNTIME_DIR/podman/podman.sock` |
| Generate systemd unit | N/A | `podman generate systemd --name web` |
| Pod support | Not available | `podman pod create --name mypod` |
| Default registry | `docker.io` | May prompt to select or uses configured list |

On Rocky, you can even alias Docker to Podman:

```bash
alias docker=podman
```

This works for the vast majority of commands because the CLI is intentionally compatible.

---

## 15.25 Connection to the Three-Tier App

Remember the three-tier application from Week 13? You installed PostgreSQL directly on your VMs, created databases, configured users, and connected a Flask API to the database over the local network.

That approach works, but it has limitations:

- PostgreSQL's version is tied to what your distro's package manager provides
- Upgrading PostgreSQL means a careful migration process
- Replicating the exact same setup on a colleague's machine requires a long checklist
- Running multiple PostgreSQL versions for different projects creates conflicts

Now consider the container approach:

```bash
# PostgreSQL 16, isolated, persistent data, ready in seconds
docker run -d --name pg16 \
  --network backend \
  -e POSTGRES_PASSWORD=secretpass \
  -e POSTGRES_USER=webapp \
  -e POSTGRES_DB=appdata \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16
```

That single command gives you:
- A specific PostgreSQL version (`postgres:16`), regardless of what your distro offers
- Isolated from the host — no system-wide PostgreSQL installation
- Persistent data in a named volume (`pgdata`)
- Configurable via environment variables — no editing `pg_hba.conf` or `postgresql.conf` for basic setup
- Reproducible — the same command produces the same result on any machine with Docker or Podman

In Week 16, we'll containerize the Flask API and nginx reverse proxy as well. In Week 17, we'll orchestrate all three containers with Docker Compose, wiring them together with networks and volumes in a single `docker-compose.yml` file. But the foundation is what you learned this week: images, volumes, networks, and the container lifecycle.

The three-tier architecture in containers:

```text
┌─────────────────────────────────────────────────────────────┐
│                        Host Machine                          │
│                                                              │
│   ┌──────────┐      ┌──────────┐      ┌──────────┐         │
│   │  nginx   │─────→│  Flask   │─────→│ PostgreSQL│         │
│   │ (proxy)  │      │  (API)   │      │   (DB)   │         │
│   │ port 80  │      │ port 5000│      │ port 5432│         │
│   └──────────┘      └──────────┘      └──────────┘         │
│        │                  │                 │                │
│        └──────────────────┴─────────────────┘                │
│                    Custom Network                            │
│                                                              │
│                    Named Volume: pgdata                       │
└─────────────────────────────────────────────────────────────┘
```

Each component runs in its own container, communicates over a custom Docker network by name, and the database's data persists in a named volume. That's the architecture. You now have every building block to understand it.

---

## What's Next

This week gave you the fundamentals: what containers are, how to run them, how to persist data, and how to connect them. Next week builds on every one of these concepts:

- **In Week 16**, you'll write Dockerfiles to build custom images for the Flask API and nginx reverse proxy, optimize builds with multi-stage Dockerfiles, and containerize the entire three-tier application.
- **In Week 17**, you'll orchestrate the three-tier stack with Docker Compose, adding health checks, restart policies, production hardening, and automated deployment.

The pattern from this course continues: you understand each piece individually before assembling the whole.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 15.1: Container Basics](labs/lab_01_container_basics.md)** — Pull and run containers, inspect them, work with port mapping and environment variables on both Docker and Podman
- **[Lab 15.2: Volumes & Networking](labs/lab_02_volumes_and_networking.md)** — Create persistent volumes for PostgreSQL, set up custom networks for container communication

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

[← Previous Week](../week-14/README.md) · [Next Week →](../week-16/README.md)
