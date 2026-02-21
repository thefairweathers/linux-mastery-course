---
title: "Week 17: Docker Compose, Production Patterns & Capstone Deployment"
sidebar:
  order: 0
---


> **Goal:** Orchestrate multi-container applications with Docker Compose, implement production deployment patterns, and deploy the complete three-tier stack with proper security, backups, and monitoring.


---

## Table of Contents

| Section | Topic |
|---------|-------|
| 17.1 | [From Manual Containers to Compose](#171-from-manual-containers-to-compose) |
| 17.2 | [Docker Compose Fundamentals](#172-docker-compose-fundamentals) |
| 17.3 | [Service Configuration Deep Dive](#173-service-configuration-deep-dive) |
| 17.4 | [Health Checks and Startup Ordering](#174-health-checks-and-startup-ordering) |
| 17.5 | [Networks: Isolating Your Tiers](#175-networks-isolating-your-tiers) |
| 17.6 | [Volumes and Persistent Data](#176-volumes-and-persistent-data) |
| 17.7 | [Environment Variables and Secrets](#177-environment-variables-and-secrets) |
| 17.8 | [Override Files and Profiles](#178-override-files-and-profiles) |
| 17.9 | [Composing the Three-Tier Application](#179-composing-the-three-tier-application) |
| 17.10 | [podman-compose on Rocky](#1710-podman-compose-on-rocky) |
| 17.11 | [Production Deployment Patterns](#1711-production-deployment-patterns) |
| 17.12 | [Database Operations in Containers](#1712-database-operations-in-containers) |
| 17.13 | [Container Monitoring and Observability](#1713-container-monitoring-and-observability) |
| 17.14 | [CI/CD Concepts for Container Workflows](#1714-cicd-concepts-for-container-workflows) |
| 17.15 | [Server Hardening Checklist](#1715-server-hardening-checklist) |
| 17.16 | [Backup Strategy for the Full Stack](#1716-backup-strategy-for-the-full-stack) |
| 17.17 | [What's Next: Beyond This Course](#1717-whats-next-beyond-this-course) |

---

## 17.1 From Manual Containers to Compose

In Week 16, you built three containers by hand: a PostgreSQL database, a Flask API, and an nginx reverse proxy. You created a Docker network, ran `docker run` with a dozen flags, wired the containers together, and tested the full request chain. It worked. But consider what it took.

To bring up the stack, you ran something like this:

```bash
docker network create app-net

docker run -d --name db \
    --network app-net \
    -e POSTGRES_DB=taskdb \
    -e POSTGRES_USER=taskapp \
    -e POSTGRES_PASSWORD=secretpass \
    -v pgdata:/var/lib/postgresql/data \
    postgres:16-alpine

docker run -d --name api \
    --network app-net \
    -e DB_HOST=db -e DB_NAME=taskdb \
    -e DB_USER=taskapp -e DB_PASS=secretpass \
    -p 8080:8080 \
    task-api:latest

docker run -d --name web \
    --network app-net \
    -p 80:80 \
    task-nginx:latest
```

That's three commands with over twenty flags. Now imagine tearing it down, changing a port, rebuilding after a code change, and then bringing it all up again. Or imagine handing this to a colleague. Or imagine doing it at 2 AM when the production server needs to be rebuilt.

This is exactly the problem **Docker Compose** solves. Instead of imperative `docker run` commands, you write a declarative YAML file describing your entire stack. One command brings everything up. One command tears it down. The YAML file is version-controlled, self-documenting, and reproducible.

By the end of this week, you'll translate those manual commands into a `compose.yml` that does everything they did -- and more. Health checks, restart policies, network isolation, logging limits, environment files, development overrides. All in one file.

This is also the final week of the course. The capstone lab ties together every skill from Weeks 1 through 17: filesystem navigation, permissions, package management, process monitoring, scripting, networking, systemd, web servers, databases, security, and containers. You've built each layer individually. Now you deploy them all as one system.

---

## 17.2 Docker Compose Fundamentals

**Docker Compose** is a tool for defining and running multi-container applications. You describe your services, networks, and volumes in a YAML file, and Compose handles creating, starting, and connecting everything.

### Compose V2 -- The Modern Standard

Docker Compose V2 is a plugin built into the `docker` CLI. The command is `docker compose` (with a space), not `docker-compose` (with a hyphen). The older V1 was a standalone Python tool. If you're on a modern Docker installation (Docker Desktop or Docker Engine 24+), you already have V2.

```bash
# V2 (correct — this is what we use)
docker compose version

# V1 (legacy — avoid)
docker-compose --version
```

```text
Docker Compose version v2.27.0
```

If you see a version starting with `v2`, you're set.

### The Compose File

The default filename is `compose.yml` (previously `docker-compose.yml` -- both still work, but `compose.yml` is the current convention). Compose automatically finds this file in the current directory.

A minimal compose file:

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
```

That's it. Run `docker compose up -d` and nginx is running on port 80. Run `docker compose down` and it's gone.

### Top-Level Keys

A compose file has up to five top-level keys:

| Key | Purpose | Required? |
|-----|---------|-----------|
| `services` | Container definitions -- the core of every compose file | Yes |
| `networks` | Custom networks for inter-service communication | No (a default network is created) |
| `volumes` | Named volumes for persistent data | No |
| `configs` | Configuration files injected into containers | No (advanced) |
| `secrets` | Sensitive data injected securely into containers | No (advanced) |

For most applications, you'll use `services`, `networks`, and `volumes`. That covers everything in our three-tier stack.

### Essential Compose Commands

| Command | Purpose |
|---------|---------|
| `docker compose up -d` | Create and start all services in detached mode |
| `docker compose up -d --build` | Build images before starting (use after code changes) |
| `docker compose down` | Stop and remove containers, default network |
| `docker compose down -v` | Stop and remove containers AND named volumes (data loss) |
| `docker compose ps` | List running services and their status |
| `docker compose logs` | View logs from all services |
| `docker compose logs -f api` | Follow logs from a specific service |
| `docker compose exec db psql -U taskapp taskdb` | Run a command in a running container |
| `docker compose build` | Build or rebuild images without starting |
| `docker compose pull` | Pull the latest images |
| `docker compose restart api` | Restart a specific service |
| `docker compose stop` | Stop services without removing them |
| `docker compose config` | Validate and print the resolved compose file |

The `docker compose config` command is particularly useful -- it resolves all variable substitutions and shows you exactly what Compose will use. If your `.env` file isn't loading or a variable is wrong, this command reveals it.

### Project Names

Compose groups all resources under a **project name**, which defaults to the directory name. Every container, network, and volume gets a prefix derived from it:

```text
Directory: /opt/taskapp/
Project:   taskapp
Container: taskapp-db-1
Network:   taskapp_default
Volume:    taskapp_pgdata
```

You can override the project name with `-p`:

```bash
docker compose -p mystack up -d
```

---

## 17.3 Service Configuration Deep Dive

Each service in the `services` block represents one container. Here's a comprehensive reference of the directives you'll use.

### Image vs Build

A service can use a pre-built image or build from a Dockerfile:

```yaml
services:
  # Use a pre-built image from Docker Hub
  db:
    image: postgres:16-alpine

  # Build from a Dockerfile in the current directory
  api:
    build:
      context: .
      dockerfile: Dockerfile.api

  # Shorthand: build from a Dockerfile in the current directory
  simple:
    build: .
```

When you specify both `image` and `build`, Compose builds the image and tags it with the `image` name:

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    image: task-api:latest    # Tag the built image with this name
```

### Port Mapping

```yaml
services:
  web:
    ports:
      - "80:80"           # HOST:CONTAINER
      - "443:443"
      - "127.0.0.1:8080:8080"  # Bind to localhost only (not all interfaces)
```

The `HOST:CONTAINER` format mirrors `docker run -p`. The third example restricts access to localhost only -- useful for services that should not be directly accessible from the network.

### Command and Entrypoint

Override the image's default command or entrypoint:

```yaml
services:
  api:
    build: .
    command: ["python", "app.py", "--debug"]
    # Or as a string:
    # command: python app.py --debug

  worker:
    image: my-app:latest
    entrypoint: ["/bin/sh", "-c"]
    command: ["echo 'Worker starting' && python worker.py"]
```

### Restart Policies

Restart policies determine what happens when a container stops:

```yaml
services:
  db:
    restart: unless-stopped
```

| Policy | Behavior |
|--------|----------|
| `no` | Never restart (default) |
| `always` | Always restart, including after Docker daemon restarts |
| `on-failure` | Restart only if the container exits with a non-zero code |
| `on-failure:5` | Restart on failure, but give up after 5 attempts |
| `unless-stopped` | Like `always`, but don't restart if the container was explicitly stopped |

For production services, use `unless-stopped` or `always`. The distinction matters when you reboot the Docker host: `always` restarts the container even if you had manually stopped it; `unless-stopped` remembers that you stopped it and stays stopped.

### Logging Configuration

In Week 16, you learned about the `json-file` log driver. In Compose, configure it per service:

```yaml
services:
  api:
    logging:
      driver: json-file
      options:
        max-size: "10m"     # Rotate after 10 MB
        max-file: "3"       # Keep 3 rotated files
```

Without these limits, container logs grow unbounded. On a server running for months, this fills the disk. Always set `max-size` and `max-file` in production.

### Service Configuration Reference

| Directive | Purpose | Example |
|-----------|---------|---------|
| `image` | Base image | `postgres:16-alpine` |
| `build` | Build from Dockerfile | `build: .` or `build: {context: ., dockerfile: Dockerfile.api}` |
| `ports` | Port mappings | `"80:80"` |
| `environment` | Environment variables (list) | `- DB_HOST=db` |
| `env_file` | Load variables from file | `- .env` |
| `volumes` | Volume mounts | `- pgdata:/var/lib/postgresql/data` |
| `depends_on` | Service dependencies | See Section 17.4 |
| `restart` | Restart policy | `unless-stopped` |
| `healthcheck` | Container health check | See Section 17.4 |
| `command` | Override CMD | `["python", "app.py"]` |
| `entrypoint` | Override ENTRYPOINT | `["/docker-entrypoint.sh"]` |
| `networks` | Attach to networks | `- frontend` |
| `logging` | Log driver configuration | See above |
| `working_dir` | Working directory | `/app` |
| `user` | Run as user | `appuser` |
| `stdin_open` | Keep STDIN open (like `-i`) | `true` |
| `tty` | Allocate a pseudo-TTY (like `-t`) | `true` |

---

## 17.4 Health Checks and Startup Ordering

One of the most common mistakes in multi-container applications is assuming that because a container has started, the service inside it is ready. A PostgreSQL container takes several seconds to initialize its data directory. A Flask app needs to connect to the database before it can serve requests. If the API tries to connect before PostgreSQL is accepting connections, it crashes.

### Health Checks in Compose

A **health check** tells Docker how to verify that the service inside a container is actually working, not just running:

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
```

| Field | Meaning |
|-------|---------|
| `test` | The command to run. Exit code 0 = healthy, non-zero = unhealthy |
| `interval` | How often to run the check (default: 30s) |
| `timeout` | How long to wait for the check to complete (default: 30s) |
| `retries` | How many consecutive failures before marking unhealthy (default: 3) |
| `start_period` | Grace period after container start -- failures during this time don't count (default: 0s) |

The `$$` in `$${POSTGRES_USER}` is not a typo. In a compose file, `$` is used for variable substitution. To pass a literal `$` to the shell inside the container, you escape it as `$$`. Without this, Compose would try to substitute `${POSTGRES_USER}` from the host environment before the container ever runs.

### Health Check Examples for Common Services

```yaml
# PostgreSQL
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s

# Flask / Python HTTP service
healthcheck:
  test: ["CMD", "python", "-c",
         "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 10s

# nginx
healthcheck:
  test: ["CMD", "wget", "-qO-", "http://localhost/nginx-health"]
  interval: 30s
  timeout: 5s
  retries: 3
```

### depends_on with Health Conditions

The `depends_on` directive by itself only controls startup order -- it ensures one container starts before another. But "started" doesn't mean "ready." With health check conditions, you can wait for a service to actually be healthy:

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  api:
    build: .
    depends_on:
      db:
        condition: service_healthy     # Wait for db to pass its health check
```

| Condition | Meaning |
|-----------|---------|
| `service_started` | Default -- just wait for the container to start |
| `service_healthy` | Wait for the container's health check to pass |
| `service_completed_successfully` | Wait for the container to run and exit with code 0 |

This is a fundamental pattern for any stack with dependencies. The chain in our three-tier application:

```text
PostgreSQL (must be healthy first)
    └── Flask API (depends on healthy db)
          └── nginx (depends on healthy api)
```

Docker Compose starts them in the correct order, waiting at each step for the dependency's health check to pass. If the database takes 10 seconds to initialize, the API waits. If the API takes 5 seconds to connect and serve, nginx waits.

### Checking Health Status

```bash
# See health status in the service list
docker compose ps
```

```text
NAME             IMAGE              COMMAND                  SERVICE   STATUS                   PORTS
taskapp-db-1     postgres:16        "docker-entrypoint.s..."   db       Up 2 minutes (healthy)   5432/tcp
taskapp-api-1    task-api:latest    "python app.py"           api      Up 2 minutes (healthy)   8080/tcp
taskapp-web-1    task-nginx:latest  "/docker-entrypoint...."   web      Up 2 minutes (healthy)   0.0.0.0:80->80/tcp
```

The `(healthy)` status next to each service confirms that all health checks are passing.

---

## 17.5 Networks: Isolating Your Tiers

In Week 16, you created a single Docker network and attached all three containers to it. That works, but it means any container can reach any other container. In a production deployment, the nginx container has no business talking directly to the database.

**Custom networks** in Compose let you create isolated communication channels. This is the same network segmentation principle you learned in Week 9 with firewall rules, applied at the container level.

### The Network Architecture

```text
                        HOST
                    ┌────────────┐
                    │  port 80   │
                    └─────┬──────┘
                          │
  ┌───────────────────────┼───────────────────────┐
  │         frontend network                      │
  │                       │                       │
  │   ┌─────────┐    ┌────┴─────┐                 │
  │   │  nginx  │◄──►│ Flask API│                 │
  │   │  (web)  │    │  (api)   │                 │
  │   └─────────┘    └────┬─────┘                 │
  │                       │                       │
  └───────────────────────┼───────────────────────┘
                          │
  ┌───────────────────────┼───────────────────────┐
  │         backend network                       │
  │                       │                       │
  │                  ┌────┴──────┐                 │
  │                  │PostgreSQL │                 │
  │                  │   (db)    │                 │
  │                  └───────────┘                 │
  └───────────────────────────────────────────────┘
```

The Flask API is on both networks -- it needs to talk to nginx (frontend) and PostgreSQL (backend). The nginx container is only on the frontend network. The database is only on the backend network. Nginx cannot reach the database. This is defense in depth.

### Defining Networks in Compose

```yaml
services:
  db:
    networks:
      - backend

  api:
    networks:
      - frontend
      - backend

  web:
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
```

When you define custom networks, Compose no longer creates the default network. Each service must explicitly list the networks it should join.

### DNS Resolution on Custom Networks

Docker provides automatic DNS resolution within networks. A container can reach another container by its service name. On the `frontend` network, nginx resolves `api` to the API container's IP. On the `backend` network, the API resolves `db` to the database container's IP.

This is why the nginx configuration from Week 16 uses `server api:8080` in the upstream block -- Docker DNS resolves `api` to the API container. And this is why the Flask app uses `DB_HOST=db` -- Docker DNS resolves `db` to the database container.

### Testing Network Isolation

After deploying, verify that nginx cannot reach the database:

```bash
# This should succeed (nginx can reach the API)
docker compose exec web wget -qO- http://api:8080/healthz

# This should FAIL (nginx cannot reach the database)
docker compose exec web wget -qO- http://db:5432 2>&1 || echo "Connection refused — network isolation works"
```

If the second command fails with a DNS resolution error or connection refused, your network isolation is working correctly.

---

## 17.6 Volumes and Persistent Data

Containers are ephemeral by design. When you run `docker compose down`, the containers are destroyed. Without volumes, every piece of data inside them disappears.

**Named volumes** persist data across container lifecycles. This is critical for databases -- you don't want to lose your data every time you update a container image.

### Named Volumes in Compose

```yaml
services:
  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data       # Named volume
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro   # Bind mount (read-only)

volumes:
  pgdata:
    driver: local
```

The `pgdata:/var/lib/postgresql/data` mount uses a named volume. Docker manages the storage location (typically under `/var/lib/docker/volumes/`). The data survives `docker compose down` but is destroyed by `docker compose down -v`.

The `./init.sql:/docker-entrypoint-initdb.d/init.sql:ro` mount is a bind mount -- it maps a file on the host directly into the container. The `:ro` suffix makes it read-only. This is how we pass initialization scripts to PostgreSQL (more on this in Section 17.12).

### Volume Lifecycle

| Command | Named volumes? | Data? |
|---------|---------------|-------|
| `docker compose stop` | Preserved | Preserved |
| `docker compose down` | Preserved | Preserved |
| `docker compose down -v` | **Deleted** | **Lost** |
| `docker volume rm pgdata` | **Deleted** | **Lost** |

This means you can safely update, rebuild, and restart containers without losing database data. Just never add `-v` to `docker compose down` unless you intend to wipe everything.

### Inspecting Volumes

```bash
# List all volumes
docker volume ls

# Inspect a specific volume
docker volume inspect taskapp_pgdata
```

```json
[
    {
        "CreatedAt": "2026-02-20T10:00:00Z",
        "Driver": "local",
        "Labels": {
            "com.docker.compose.project": "taskapp",
            "com.docker.compose.volume": "pgdata"
        },
        "Mountpoint": "/var/lib/docker/volumes/taskapp_pgdata/_data",
        "Name": "taskapp_pgdata"
    }
]
```

The `Mountpoint` shows where Docker stores the actual files on the host filesystem.

---

## 17.7 Environment Variables and Secrets

Keeping configuration out of your compose file is essential. Database passwords, API keys, and environment-specific settings should never be hardcoded in YAML files that get committed to version control.

### The .env File

Compose automatically loads a file named `.env` in the same directory as `compose.yml`. Variables defined there are available for substitution in the compose file:

```bash
# .env
POSTGRES_DB=taskdb
POSTGRES_USER=taskapp
POSTGRES_PASSWORD=changeme_in_production
```

```yaml
# compose.yml
services:
  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
```

### Variable Substitution Syntax

Compose supports shell-style variable substitution with defaults:

| Syntax | Meaning |
|--------|---------|
| `${VAR}` | Value of VAR, error if unset |
| `${VAR:-default}` | Value of VAR, or `default` if unset or empty |
| `${VAR-default}` | Value of VAR, or `default` if unset (empty is OK) |
| `${VAR:?error message}` | Value of VAR, or print error and abort if unset |

```yaml
services:
  api:
    environment:
      - DB_PORT=${DB_PORT:-5432}        # Default to 5432 if not set
      - DB_HOST=${DB_HOST:?DB_HOST must be set}  # Fail if not set
```

### env_file vs environment

There are two ways to pass variables to containers. They serve different purposes:

**`env_file`** loads variables from a file and passes them into the container as environment variables. The variables go into the container, not into the compose file:

```yaml
services:
  api:
    env_file:
      - .env     # These variables are set INSIDE the container
```

**`environment`** sets variables inline. These can reference compose-level substitution:

```yaml
services:
  api:
    environment:
      - DB_HOST=db              # Hardcoded value
      - DB_PORT=${DB_PORT:-5432}  # Compose-level substitution
```

The key distinction: `env_file` variables go directly into the container. Compose-level `${VAR}` substitution happens before the container runs, using values from the host's `.env` file.

In practice, the cleanest pattern is to use `env_file` for variables the container needs and `${VAR}` substitution for compose-level configuration like image tags or port numbers.

### Secrets Management

For production, even `.env` files have limitations -- they sit on disk in plaintext. Docker Compose supports secrets for sensitive data:

```yaml
services:
  db:
    secrets:
      - db_password
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

The secret file is mounted into the container at `/run/secrets/<name>` as a read-only tmpfs. PostgreSQL's official image supports the `_FILE` suffix convention -- instead of reading the password from `POSTGRES_PASSWORD`, it reads it from the file path in `POSTGRES_PASSWORD_FILE`.

For our learning environment, `.env` files are sufficient. In production, consider secrets, a vault system (HashiCorp Vault), or your cloud provider's secrets manager.

### Verifying Variable Resolution

Before starting your stack, verify that all variables resolve correctly:

```bash
docker compose config
```

This prints the fully resolved compose file with all variables substituted. If a variable is missing, you'll see a warning or error here instead of a confusing failure at runtime.

---

## 17.8 Override Files and Profiles

Real applications need different configurations for development and production. Debug ports, live code reloading, verbose logging -- these are essential during development but dangerous in production.

### compose.override.yml

Compose automatically loads `compose.override.yml` if it exists alongside `compose.yml`. The override file merges on top of the base file:

```yaml
# compose.yml — base configuration (always loaded)
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    restart: unless-stopped
```

```yaml
# compose.override.yml — development overrides (loaded automatically)
services:
  api:
    volumes:
      - ./lab_02_app.py:/app/app.py:ro   # Live code editing
    ports:
      - "8080:8080"                       # Expose debug port
    environment:
      - FLASK_DEBUG=1                     # Enable debug mode
  db:
    ports:
      - "5432:5432"                       # Expose database for direct access
```

During development, `docker compose up` loads both files automatically. For production, explicitly exclude the override:

```bash
# Development (loads compose.yml + compose.override.yml automatically)
docker compose up -d --build

# Production (loads ONLY compose.yml)
docker compose -f compose.yml up -d --build
```

### Multiple Compose Files

You can also explicitly specify multiple files:

```bash
docker compose -f compose.yml -f compose.prod.yml up -d
```

Files are merged left to right -- later files override earlier ones. This lets you maintain a base file and separate overlays for staging, production, and CI environments.

### Profiles

**Profiles** let you define optional services that only start when explicitly activated:

```yaml
services:
  db:
    image: postgres:16-alpine
    # No profile — always starts

  api:
    build: .
    # No profile — always starts

  web:
    build: .
    # No profile — always starts

  adminer:
    image: adminer
    ports:
      - "9090:8080"
    profiles:
      - debug              # Only starts when "debug" profile is active

  pgadmin:
    image: dpage/pgadmin4
    ports:
      - "5050:80"
    profiles:
      - debug
```

```bash
# Start core services only
docker compose up -d

# Start core services + debug tools
docker compose --profile debug up -d
```

Profiles are useful for development tools, monitoring dashboards, and admin interfaces that you don't want running in production.

---

## 17.9 Composing the Three-Tier Application

Now let's bring it all together. In Week 16, you ran three `docker run` commands with manually created networks. Here's the same stack as a compose file:

```yaml
services:
  db:
    image: postgres:16-alpine
    env_file:
      - .env
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - backend

  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    environment:
      - DB_HOST=db
      - DB_PORT=5432
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python", "-c",
             "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - frontend
      - backend

  web:
    build:
      context: .
      dockerfile: Dockerfile.nginx
    ports:
      - "80:80"
    depends_on:
      api:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost/nginx-health"]
      interval: 30s
      timeout: 5s
      retries: 3
    restart: unless-stopped
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge

volumes:
  pgdata:
    driver: local
```

Compare this to the three separate `docker run` commands from Section 17.1. This compose file does everything those commands did, plus:

- Health checks on every service
- Dependency ordering that waits for health, not just startup
- Network isolation between frontend and backend
- Log rotation limits
- Restart policies
- PostgreSQL initialization via init script
- Environment loaded from a `.env` file
- One command to start: `docker compose up -d --build`
- One command to stop: `docker compose down`

### PostgreSQL Initialization

The `./init.sql:/docker-entrypoint-initdb.d/init.sql:ro` bind mount deserves explanation. The official PostgreSQL image looks for files in `/docker-entrypoint-initdb.d/` on first startup. It runs `.sql` files and `.sh` scripts in alphabetical order. This runs only when the data volume is empty -- on subsequent starts, the data already exists and the init scripts are skipped.

This is how we create the `tasks` table and seed data without manually connecting to the database. You wrote this table by hand in Week 13. Now it happens automatically.

### The Startup Sequence

When you run `docker compose up -d --build`:

1. Compose builds the API and nginx images from their Dockerfiles
2. Creates the `frontend` and `backend` networks
3. Creates the `pgdata` volume (if it doesn't exist)
4. Starts the `db` container and runs the PostgreSQL health check
5. Once `db` is healthy, starts the `api` container
6. Runs the API health check (`/healthz` endpoint)
7. Once `api` is healthy, starts the `web` container
8. All three services are running with proper startup ordering

### Testing the Full Stack

```bash
# Start everything
docker compose up -d --build

# Watch the startup sequence
docker compose logs -f

# Check health status
docker compose ps

# Test the full request chain
curl -s http://localhost/api/tasks | python3 -m json.tool

# Create a task
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Deployed with Compose"}' | python3 -m json.tool

# Verify it persisted
curl -s http://localhost/api/tasks | python3 -m json.tool
```

---

## 17.10 podman-compose on Rocky

On Rocky Linux, Docker isn't the default container runtime -- Podman is, as you learned in Week 15. **podman-compose** provides Compose-compatible orchestration for Podman.

### Installation

```bash
sudo dnf install -y podman-compose
```

### Compatibility

podman-compose reads the same `compose.yml` file. Most features work identically:

```bash
# Works the same as docker compose
podman-compose up -d --build
podman-compose ps
podman-compose logs -f
podman-compose down
```

### Known Differences

| Feature | docker compose | podman-compose |
|---------|---------------|----------------|
| Health check conditions in `depends_on` | Full support | May require workarounds |
| `docker compose exec` | Works | `podman-compose exec` works |
| Network DNS resolution | Automatic | Requires `podman network create` or CNI plugins |
| Rootless containers | Supported | Default (and preferred) |
| Build caching | Layer caching | May need `--layers` flag |

The most common issue is DNS resolution between containers. If service names don't resolve in podman-compose, ensure you're using a CNI or Netavark network backend and that the network is defined explicitly in your compose file.

For this course, we primarily use Docker on Ubuntu. If you're running Rocky, try podman-compose with the same compose file. Most things will work. Where they don't, the differences teach you about the underlying container runtime.

---

## 17.11 Production Deployment Patterns

Moving from "it works on my machine" to "it runs in production" requires attention to several areas.

### Environment Separation

Keep separate configuration for development and production:

```text
project/
├── compose.yml              # Base configuration (shared)
├── compose.override.yml     # Development overrides (auto-loaded)
├── compose.prod.yml         # Production overrides (explicit)
├── .env                     # Development environment variables
├── .env.prod                # Production environment variables
└── ...
```

```bash
# Development (auto-loads override)
docker compose up -d --build

# Production (explicit files, explicit env)
docker compose -f compose.yml -f compose.prod.yml --env-file .env.prod up -d --build
```

### Restart Policies

Every production service needs a restart policy. Without one, a crashed container stays down until a human notices:

```yaml
services:
  db:
    restart: unless-stopped   # Restarts on crash, survives host reboot

  api:
    restart: unless-stopped

  web:
    restart: unless-stopped
```

Combine this with health checks. A container stuck in a crash loop with `restart: always` will restart infinitely. Monitor container restarts with `docker compose ps` or `docker events`.

### Logging Limits

Every service needs logging limits. This bears repeating:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

Without these, a busy API logging every request will fill your disk. Set reasonable limits based on your available storage and retention needs.

### Resource Constraints

Compose supports memory and CPU limits using the `deploy` key (which works in `docker compose` as of recent versions with `--compatibility` or natively):

```yaml
services:
  db:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: "1.0"
        reservations:
          memory: 256M
          cpus: "0.5"
```

On a shared host, these prevent one runaway container from starving the others.

---

## 17.12 Database Operations in Containers

Running a database in a container is standard practice for development and increasingly common in production. The key requirements are persistence, initialization, and backup.

### Persistent Volumes

The PostgreSQL data directory must be on a named volume:

```yaml
volumes:
  - pgdata:/var/lib/postgresql/data
```

This survives container restarts, image updates, and `docker compose down`. Only `docker compose down -v` or `docker volume rm` destroys it.

### Initialization Scripts

The PostgreSQL Docker image runs scripts from `/docker-entrypoint-initdb.d/` on first start. This is where you create tables, users, and seed data:

```yaml
volumes:
  - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
```

Multiple files? They run in alphabetical order:

```text
/docker-entrypoint-initdb.d/
├── 01_schema.sql        # Create tables first
├── 02_indexes.sql       # Then indexes
└── 03_seed_data.sql     # Then seed data
```

### Connecting to a Running Database

```bash
# Connect with psql inside the container
docker compose exec db psql -U taskapp -d taskdb

# Run a single query
docker compose exec db psql -U taskapp -d taskdb -c "SELECT COUNT(*) FROM tasks;"
```

This uses the `exec` command from Week 16, running `psql` inside the already-running `db` container.

### Backup Strategies

**On-demand backup** using `pg_dump` inside the container:

```bash
# Dump the database to a file on the host
docker compose exec db pg_dump -U taskapp taskdb > backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed backup
docker compose exec db pg_dump -Fc -U taskapp taskdb > backup_$(date +%Y%m%d_%H%M%S).dump
```

**Automated backup** with a script (building on the scripting patterns from Weeks 8 and 14):

```bash
#!/bin/bash
# /usr/local/bin/backup-compose-db.sh
set -euo pipefail

BACKUP_DIR="/var/backups/taskapp"
RETENTION_DAYS=7
DATE="$(date +%Y%m%d_%H%M%S)"
COMPOSE_DIR="/opt/taskapp"

mkdir -p "$BACKUP_DIR"

# Run pg_dump inside the container
docker compose -f "$COMPOSE_DIR/compose.yml" exec -T db \
    pg_dump -Fc -U taskapp taskdb > "${BACKUP_DIR}/taskdb_${DATE}.dump"

# Verify the backup is not empty
if [ ! -s "${BACKUP_DIR}/taskdb_${DATE}.dump" ]; then
    echo "ERROR: Backup file is empty" >&2
    exit 1
fi

# Rotate old backups
find "$BACKUP_DIR" -name "*.dump" -mtime +"$RETENTION_DAYS" -delete

echo "Backup complete: taskdb_${DATE}.dump ($(du -h "${BACKUP_DIR}/taskdb_${DATE}.dump" | cut -f1))"
```

The `-T` flag in `docker compose exec -T` disables pseudo-TTY allocation, which is necessary when running non-interactively (from a script or cron job). Without `-T`, the command hangs waiting for terminal input.

Schedule it with a systemd timer (the approach from Week 11):

```ini
# /etc/systemd/system/taskapp-backup.service
[Unit]
Description=Backup TaskApp database

[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup-compose-db.sh
User=root
```

```ini
# /etc/systemd/system/taskapp-backup.timer
[Unit]
Description=Daily TaskApp database backup

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now taskapp-backup.timer
```

### Restoring from Backup

```bash
# Restore from a custom-format dump
docker compose exec -T db pg_restore -U taskapp -d taskdb --clean < /var/backups/taskapp/taskdb_20260220.dump

# Or from a plain SQL dump
docker compose exec -T db psql -U taskapp -d taskdb < /var/backups/taskapp/taskdb_20260220.sql
```

Always test your restore procedure before you need it. A backup you can't restore is not a backup.

---

## 17.13 Container Monitoring and Observability

Once your stack is deployed, you need to know it's working. Monitoring containers is different from monitoring traditional services -- containers come and go, and the tools differ.

### docker compose ps

The first check after deployment:

```bash
docker compose ps
```

```text
NAME             IMAGE              SERVICE   STATUS                   PORTS
taskapp-db-1     postgres:16        db        Up 10 minutes (healthy)  5432/tcp
taskapp-api-1    task-api:latest    api       Up 10 minutes (healthy)  8080/tcp
taskapp-web-1    task-nginx:latest  web       Up 10 minutes (healthy)  0.0.0.0:80->80/tcp
```

All three services should show `(healthy)`. If any show `(unhealthy)` or `(health: starting)`, investigate with logs.

### Resource Usage

```bash
docker stats --no-stream
```

```text
CONTAINER ID   NAME             CPU %   MEM USAGE / LIMIT   MEM %   NET I/O       BLOCK I/O
abc123         taskapp-db-1     0.05%   52.3MiB / 7.77GiB   0.66%   4.2kB / 0B    12.3MB / 8.2MB
def456         taskapp-api-1    0.02%   38.1MiB / 7.77GiB   0.48%   2.1kB / 0B    0B / 0B
ghi789         taskapp-web-1    0.00%   4.2MiB / 7.77GiB    0.05%   1.8kB / 0B    0B / 0B
```

The `--no-stream` flag shows a one-time snapshot instead of live updates. This is useful in scripts.

### Health Check Script

Build a monitoring script that checks the entire stack (building on the scripting skills from Weeks 8 and 14):

```bash
#!/bin/bash
# /usr/local/bin/check-taskapp.sh
set -euo pipefail

FAILURES=0

check_endpoint() {
    local name="$1"
    local url="$2"
    local expected="$3"

    if curl -sf "$url" | grep -q "$expected"; then
        echo "  [OK]  $name"
    else
        echo "  [FAIL] $name"
        FAILURES=$((FAILURES + 1))
    fi
}

echo "=== TaskApp Health Check ==="
echo ""
echo "Services:"

# Check containers are running and healthy
for svc in db api web; do
    status="$(docker compose ps --format json "$svc" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Health','unknown'))" 2>/dev/null || echo "not running")"
    if [ "$status" = "healthy" ]; then
        echo "  [OK]  $svc container ($status)"
    else
        echo "  [FAIL] $svc container ($status)"
        FAILURES=$((FAILURES + 1))
    fi
done

echo ""
echo "Endpoints:"
check_endpoint "nginx health" "http://localhost/nginx-health" "healthy"
check_endpoint "API health"   "http://localhost/healthz"       "healthy"
check_endpoint "API tasks"    "http://localhost/api/tasks"     "tasks"

echo ""
if [ "$FAILURES" -eq 0 ]; then
    echo "All checks passed."
else
    echo "WARNING: $FAILURES check(s) failed!"
    exit 1
fi
```

### Log Monitoring

```bash
# Follow all service logs
docker compose logs -f

# Follow a specific service
docker compose logs -f api

# Show last 100 lines from the database
docker compose logs --tail 100 db

# Show logs with timestamps
docker compose logs -t api
```

In production, consider forwarding container logs to a centralized logging system (ELK stack, Grafana Loki, or a cloud provider's logging service). The `json-file` log driver writes structured JSON, making it straightforward to parse and ship.

### Docker Events

Watch container lifecycle events in real time:

```bash
docker events --filter type=container
```

This shows container starts, stops, health check results, and OOM kills. Useful for debugging intermittent failures.

---

## 17.14 CI/CD Concepts for Container Workflows

While implementing a full CI/CD pipeline is beyond this course, understanding the concepts is essential for production container workflows.

### The Workflow

A typical container CI/CD pipeline:

```text
1. Developer pushes code to Git
2. CI server detects the change
3. CI runs tests
4. CI builds Docker images
5. CI pushes images to a container registry
6. CD deploys the new images to production
```

### Container Registries

A **container registry** stores and distributes Docker images. Docker Hub is the public default, but production deployments typically use private registries:

| Registry | Type | Notes |
|----------|------|-------|
| Docker Hub | Public/private | Default, free for public images |
| GitHub Container Registry (ghcr.io) | Public/private | Integrated with GitHub Actions |
| AWS ECR | Private | Integrated with AWS services |
| Google Artifact Registry | Private | Integrated with GCP |
| Azure Container Registry | Private | Integrated with Azure |
| Self-hosted (Harbor) | Private | Full control, open source |

### Tagging Strategy

Never use `latest` in production. Tag images with meaningful identifiers:

```bash
# Tag with version
docker build -t task-api:v1.2.3 .

# Tag with Git commit hash
docker build -t task-api:$(git rev-parse --short HEAD) .

# Tag with date
docker build -t task-api:$(date +%Y%m%d) .
```

In your compose file, reference specific tags:

```yaml
services:
  api:
    image: registry.example.com/task-api:v1.2.3
```

This ensures reproducibility. You can always roll back to a known good version by changing the tag.

---

## 17.15 Server Hardening Checklist

Before deploying containers on a server exposed to any network, harden the host. This checklist pulls together security practices from across the course.

### SSH Hardening (Week 10)

```bash
# Disable password authentication
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable root login
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Restart SSH
sudo systemctl restart sshd
```

Verify you can still log in with your SSH key before disconnecting.

### Firewall (Week 9)

Only expose the ports you need:

```bash
# Ubuntu (ufw)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Verify
sudo ufw status verbose
```

```text
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

Do not expose database ports (5432) or API debug ports (8080) to the outside. Docker publishes ports by binding to all interfaces by default. If you need to restrict this, bind to localhost in your compose file:

```yaml
ports:
  - "127.0.0.1:8080:8080"   # Only accessible from the host itself
```

### fail2ban

**fail2ban** monitors log files and bans IPs that show malicious behavior (brute-force SSH attempts, repeated 401s):

```bash
sudo apt install -y fail2ban

# Create a local configuration
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable --now fail2ban
```

The default configuration protects SSH. You can add jails for nginx and other services.

### Automatic Security Updates

```bash
# Ubuntu
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

This ensures security patches are applied automatically. Critical for any internet-facing server.

### Non-Root Containers

The Dockerfiles from Week 16 already create a non-root user:

```dockerfile
RUN useradd --create-home --shell /bin/bash appuser
USER appuser
```

Never run application containers as root unless absolutely necessary. The `USER` directive in the Dockerfile enforces this.

### Hardening Summary

| Area | Action | Week Learned |
|------|--------|-------------|
| SSH | Key-only auth, no root login | Week 10 |
| Firewall | Default deny, allow 22/80/443 only | Week 9 |
| Intrusion prevention | fail2ban on SSH | Week 10 |
| Updates | Automatic security patches | Week 6 |
| Permissions | Restrictive file permissions on secrets | Week 5 |
| Containers | Non-root user, read-only filesystems | Week 16 |
| Logging | Centralized, rotated, monitored | Weeks 8, 11 |
| Backups | Automated, tested, offsite | Weeks 13, 14 |

---

## 17.16 Backup Strategy for the Full Stack

A complete backup strategy covers more than just the database. Here's what needs to be backed up for the entire three-tier stack:

### What to Back Up

| Component | What to Back Up | How |
|-----------|----------------|-----|
| Database | PostgreSQL data | `pg_dump` inside the container |
| Application code | Source code, Dockerfiles | Git repository (already versioned) |
| Configuration | compose.yml, nginx.conf | Git repository |
| Environment | .env files | Encrypted backup (never commit to Git) |
| TLS certificates | Certs and keys | Separate secure backup |
| Volumes | Named volumes | `docker run --volumes-from` or direct copy |
| Host config | firewall rules, SSH keys, systemd units | Configuration management or manual backup |

### The 3-2-1 Rule

A sound backup strategy follows the **3-2-1 rule**:

- **3** copies of your data (original + 2 backups)
- **2** different storage media (local disk + remote/cloud)
- **1** copy offsite (different physical location)

For a learning environment, a local backup script with rotation is sufficient. For production, add offsite copies using `rsync`, `scp`, or cloud storage (S3, GCS).

### Testing Backups

Schedule regular restore tests. A backup you've never tested is a wish, not a plan:

```bash
# 1. Create a fresh database container
docker run -d --name test-restore -e POSTGRES_PASSWORD=testpass postgres:16-alpine

# 2. Wait for it to be ready
sleep 5

# 3. Restore the backup
docker exec -i test-restore psql -U postgres < /var/backups/taskapp/taskdb_latest.sql

# 4. Verify the data
docker exec test-restore psql -U postgres -d taskdb -c "SELECT COUNT(*) FROM tasks;"

# 5. Clean up
docker rm -f test-restore
```

---

## 17.17 What's Next: Beyond This Course

You've spent 17 weeks building Linux skills from the ground up. You can navigate filesystems, manage users and permissions, install packages, write scripts, configure networking and firewalls, manage services with systemd, deploy web servers and databases, and containerize applications with Docker Compose. That's a solid foundation. Here's where it leads.

### Container Orchestration: Kubernetes

Docker Compose runs containers on a single host. **Kubernetes** (K8s) runs containers across a cluster of machines. It handles scaling, self-healing, rolling updates, service discovery, and load balancing. If Docker Compose is managing a single restaurant, Kubernetes is managing the entire franchise.

Kubernetes builds directly on the concepts you've learned:

| This Course | Kubernetes Equivalent |
|-------------|----------------------|
| compose.yml | Deployment + Service YAML manifests |
| Health checks | Liveness and readiness probes |
| Named volumes | PersistentVolumeClaims |
| Docker networks | Kubernetes Services and NetworkPolicies |
| `docker compose up` | `kubectl apply -f` |
| Restart policies | Pod restart policies |
| Secrets | Kubernetes Secrets |

Start with Minikube or kind (Kubernetes in Docker) on your local machine.

### Configuration Management: Ansible and Terraform

Manually configuring servers doesn't scale. **Ansible** automates server configuration -- everything you did by hand in this course (installing packages, editing config files, managing services) can be codified in Ansible playbooks. **Terraform** manages infrastructure itself -- creating VMs, networks, DNS records, and cloud resources from code.

Together, Terraform creates the servers and Ansible configures them. Both are essential for modern infrastructure.

### Cloud Platforms

AWS, Google Cloud, and Azure all offer managed services for everything you've built manually:

| What You Built | Cloud Equivalent |
|----------------|-----------------|
| PostgreSQL on a VM | Amazon RDS, Cloud SQL, Azure Database |
| nginx reverse proxy | Application Load Balancer, Cloud CDN |
| Docker containers | ECS, Cloud Run, Azure Container Instances |
| Kubernetes | EKS, GKE, AKS |
| Server monitoring | CloudWatch, Cloud Monitoring, Azure Monitor |

Understanding how these systems work at the Linux level makes you far more effective with managed services. When the managed service breaks, you understand what's underneath.

### Certifications

If you want to validate your skills formally:

| Certification | Focus | Builds On |
|--------------|-------|-----------|
| CompTIA Linux+ | General Linux administration | Weeks 1-14 |
| LFCS (Linux Foundation Certified Sysadmin) | Practical Linux administration | Weeks 1-14 |
| Docker Certified Associate | Container operations | Weeks 15-17 |
| CKA (Certified Kubernetes Administrator) | Kubernetes cluster management | Beyond this course |
| RHCSA (Red Hat Certified System Administrator) | RHEL/Rocky administration | Weeks 1-14 (Rocky focus) |

### The Mindset

The most important thing you've gained isn't any individual command or configuration file. It's the ability to understand systems from the bottom up. When you deploy a container, you know what's happening inside it -- processes, filesystems, networking, permissions. When something breaks, you know where to look -- logs, process tables, network sockets, file permissions.

That understanding doesn't become obsolete when tools change. Docker may be replaced. Kubernetes may evolve. Cloud platforms will definitely change their interfaces. But Linux is the foundation under all of them, and the ability to reason about systems from first principles is permanent.

Keep building. Keep breaking things. Keep fixing them.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 17.1: Compose Three-Tier Stack](./lab-01-compose-three-tier)** -- Translate the manually-wired three-tier app into a Docker Compose stack with health checks, networks, and persistence
- **[Lab 17.2: Capstone Deployment](./lab-02-capstone-deployment)** -- Deploy the complete production stack with security hardening, automated backups, monitoring, and documentation

---

## Checklist

Congratulations -- you've completed the course. Confirm you can:

- [ ] Write a compose.yml with services, volumes, and custom networks
- [ ] Configure depends_on with health check conditions for proper startup ordering
- [ ] Use environment files and variable substitution in Compose
- [ ] Separate development and production configurations with override files
- [ ] Configure restart policies and logging limits for production
- [ ] Initialize a PostgreSQL container with SQL scripts
- [ ] Back up and restore a containerized database
- [ ] Harden a Linux server: SSH keys, firewall, fail2ban, automatic updates
- [ ] Deploy a complete three-tier application stack from scratch
- [ ] Monitor container health and resource usage
- [ ] Document a system architecture, backup procedures, and troubleshooting steps
- [ ] Explain how every layer of the stack works because you built each one by hand

---

