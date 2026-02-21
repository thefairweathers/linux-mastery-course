---
title: "Lab 15.1: Container Basics"
sidebar:
  order: 1
---


> **Objective:** Pull and run containers (nginx, alpine, python), inspect them, exec into running containers, work with port mapping and environment variables, manage the full lifecycle. Run every exercise on BOTH Docker (Ubuntu) and Podman (Rocky).
>
> **Concepts practiced:** docker/podman run, ps, stop, rm, logs, exec, inspect, port mapping, environment variables
>
> **Time estimate:** 40 minutes
>
> **VM(s) needed:** Both Ubuntu (Docker) and Rocky (Podman)

---

## Quick Reference

Throughout this lab, every command shown uses `docker`. On Rocky, substitute `podman` for `docker`. The syntax is identical.

| Task | Docker (Ubuntu) | Podman (Rocky) |
|------|----------------|----------------|
| Run a container | `docker run ...` | `podman run ...` |
| List containers | `docker ps` | `podman ps` |
| Stop a container | `docker stop <name>` | `podman stop <name>` |
| Remove a container | `docker rm <name>` | `podman rm <name>` |
| View logs | `docker logs <name>` | `podman logs <name>` |
| Exec into container | `docker exec -it <name> bash` | `podman exec -it <name> bash` |
| Inspect | `docker inspect <name>` | `podman inspect <name>` |

---

## Part 1: Pull and Run nginx (Ubuntu)

### Step 1: Pull the nginx Image

```bash
docker pull nginx:latest
```

Verify the image is stored locally:

```bash
docker images | grep nginx
```

```text
nginx        latest    605c77e624dd   2 weeks ago   141MB
```

### Step 2: Run nginx in Detached Mode with Port Mapping

```bash
docker run -d --name web -p 8080:80 nginx
```

Let's break down every flag:
- `-d` — run in the background (detached)
- `--name web` — give it the name "web" instead of a random name
- `-p 8080:80` — map host port 8080 to container port 80
- `nginx` — the image to run

### Step 3: Verify the Container Is Running

```bash
docker ps
```

```text
CONTAINER ID   IMAGE   COMMAND                  CREATED          STATUS          PORTS                  NAMES
a1b2c3d4e5f6   nginx   "/docker-entrypoint.…"   5 seconds ago    Up 4 seconds    0.0.0.0:8080->80/tcp   web
```

Confirm the `STATUS` column shows "Up" and the `PORTS` column shows the port mapping.

### Step 4: Test with curl

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

You're serving web pages from a container. The request hits host port 8080, Docker forwards it to container port 80, and nginx responds.

### Step 5: View the Container Logs

```bash
docker logs web
```

You should see the access log entry from your curl request:

```text
172.17.0.1 - - [20/Feb/2026:15:00:01 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.81.0" "-"
```

Make a few more requests and watch the logs grow:

```bash
curl -s http://localhost:8080 > /dev/null
curl -s http://localhost:8080/nonexistent > /dev/null
docker logs --tail 3 web
```

### Step 6: Exec into the Running Container

```bash
docker exec -it web bash
```

You're now inside the nginx container. Explore:

```bash
# Inside the container
hostname
cat /etc/os-release | head -3
ls /usr/share/nginx/html/
ps aux
exit
```

Note that the container runs Debian, has its own hostname, and shows only nginx processes. After `exit`, the container continues running — `exec` does not affect the main process.

### Step 7: Stop, Start, and Restart

```bash
# Stop the container
docker stop web

# Verify it's stopped
docker ps
# Expected: no output (no running containers)

docker ps -a | grep web
# Expected: STATUS shows "Exited"

# Verify the page is unreachable
curl -s http://localhost:8080
# Expected: Connection refused

# Start it again
docker start web

# Verify it's back
curl -s http://localhost:8080 | head -1
# Expected: <!DOCTYPE html>
```

### Step 9: Clean Up

```bash
docker rm -f web
```

Verify:

```bash
docker ps -a | grep web
# Expected: no output
```

---

## Part 2: Interactive Alpine Container (Ubuntu)

### Step 1: Run Alpine Interactively

```bash
docker run -it --rm --name shell alpine sh
```

The `--rm` flag means the container is automatically removed when you exit. Perfect for throwaway sessions.

### Step 2: Explore Inside the Container

```bash
# Inside the container
whoami
ps aux
ls /
exit
```

Only two processes: your shell (PID 1) and `ps` itself. After exiting, the container is gone (because of `--rm`) along with anything you installed. This is the ephemeral nature of containers.

---

## Part 3: Environment Variables (Ubuntu)

### Step 1: Pass Environment Variables to a Container

```bash
docker run -d --name db \
  -e POSTGRES_PASSWORD=labpassword \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  postgres:16
```

### Step 2: Verify the Variables

```bash
docker exec db env | grep POSTGRES
```

```text
POSTGRES_PASSWORD=labpassword
POSTGRES_USER=labuser
POSTGRES_DB=labdb
```

### Step 3: Verify PostgreSQL Used Them

Wait a few seconds for PostgreSQL to initialize, then check:

```bash
sleep 5
docker exec db psql -U labuser -d labdb -c '\conninfo'
```

```text
You are connected to database "labdb" as user "labuser" via socket in "/var/run/postgresql" at port "5432".
```

The environment variables configured PostgreSQL automatically — the user, password, and database were all created from the `-e` flags.

### Step 4: Clean Up

```bash
docker rm -f db
```

---

## Part 4: Run a Python Container (Ubuntu)

### Step 1: Run a Python One-Liner

```bash
docker run --rm python:3.12-slim python3 -c "
import sys
print(f'Python {sys.version}')
print('Hello from a container!')
"
```

### Step 2: Check the Image Size

```bash
docker images | grep python
```

Notice the `slim` variant is much smaller than the full `python:3.12` would be. We'll explore image optimization in Week 16.

---

## Part 5: Repeat on Rocky (Podman)

Now switch to your Rocky VM and repeat the key exercises using `podman` instead of `docker`.

### Step 1: Pull and Run nginx

```bash
podman pull docker.io/library/nginx:latest
podman run -d --name web -p 8080:80 nginx
podman ps
curl -s http://localhost:8080 | head -5
```

Note: On Rocky with Podman, you may need to use the fully qualified image name (`docker.io/library/nginx`) the first time, or Podman will prompt you to select a registry.

### Step 2: Exec and Inspect

```bash
podman exec -it web bash
# Inside: hostname, ps aux, exit

podman logs web
podman inspect --format '{{.NetworkSettings.IPAddress}}' web
```

### Step 3: Interactive Alpine

```bash
podman run -it --rm alpine sh
# Inside: whoami, ps aux, exit
```

### Step 4: Environment Variables with PostgreSQL

```bash
podman run -d --name db \
  -e POSTGRES_PASSWORD=labpassword \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  postgres:16

sleep 5
podman exec db env | grep POSTGRES
podman exec db psql -U labuser -d labdb -c '\conninfo'
```

### Step 5: Clean Up

```bash
podman rm -f web db
podman system prune -f
```

---

## Part 6: Compare Docker vs Podman Behavior

Based on your experience in this lab, fill in the comparison:

| Behavior | Docker (Ubuntu) | Podman (Rocky) |
|----------|----------------|----------------|
| Needs sudo? | ______ | ______ |
| Registry prompt on pull? | ______ | ______ |
| Daemon running? | ______ | ______ |
| Container IP format | ______ | ______ |
| `ps` output format | ______ | ______ |

Key differences you should have noticed:
- Docker requires the `docker` group or sudo; Podman runs rootless by default
- Podman may prompt to select a registry; Docker defaults to Docker Hub
- Docker has a daemon (`systemctl status docker`); Podman has no daemon
- The command syntax and output format are virtually identical

---

## Verification Checklist

On **both** VMs, confirm:

- [ ] You pulled the nginx image and verified it with `images`
- [ ] You ran nginx detached with port mapping and accessed it with curl
- [ ] You viewed container logs with `logs`
- [ ] You exec'd into a running container and explored the filesystem
- [ ] You ran an interactive Alpine container with `--rm`
- [ ] You passed environment variables to PostgreSQL and verified they took effect
- [ ] You stopped, started, and removed containers through the full lifecycle
- [ ] You ran a Python container for a one-off command
- [ ] You completed the Docker vs Podman comparison table
