# Week 16: Building Images & Container Development Workflows

> **Goal:** Write production-quality Dockerfiles, implement multi-stage builds, and containerize the three-tier application from Weeks 12-13.

[← Previous Week](../week-15/README.md) · [Next Week →](../week-17/README.md)

---

## 16.1 The Dockerfile and the Containerfile

Every container image starts with a text file that describes how to build it. Docker calls this a **Dockerfile**. Podman calls it a **Containerfile**. The syntax is identical -- the only difference is the conventional filename. In this course, we'll use "Dockerfile" because it's the more widely recognized name, but know that everything you learn here works exactly the same way with Podman and a Containerfile.

A Dockerfile is a recipe. Each line is an instruction that produces a new layer in the image. When you run `docker build`, the Docker daemon reads the Dockerfile top to bottom, executes each instruction, and stacks the resulting layers into a final image.

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

Six lines. That's a complete, working Dockerfile for a Python application. Let's take it apart instruction by instruction, understanding not just what each one does, but why you'd write it that way.

---

## 16.2 FROM -- Choosing a Base Image

Every Dockerfile starts with `FROM`. It specifies the base image -- the starting point for your image. Everything else in the Dockerfile builds on top of this foundation.

```dockerfile
FROM python:3.12-slim
```

This pulls the official Python 3.12 image with the "slim" variant from Docker Hub. The choice of base image is one of the most impactful decisions you'll make. It determines the size of your final image, the tools available during the build, and the security surface area.

### Official Images

Docker Hub maintains **official images** for most major languages and tools. These are curated, regularly updated, and security-scanned. Always prefer official images over random community images.

```dockerfile
FROM python:3.12        # Official Python
FROM node:20            # Official Node.js
FROM nginx:1.25         # Official nginx
FROM postgres:16        # Official PostgreSQL
```

### Image Variants

Most official images come in several variants. Understanding the differences is essential for building efficient images.

| Variant | Based On | Size (Python 3.12) | Use Case |
|---------|----------|-------------------|----------|
| `python:3.12` | Debian Bookworm | ~1.0 GB | Building C extensions, need compilers |
| `python:3.12-slim` | Debian Bookworm (minimal) | ~150 MB | Production apps, no C compilation needed |
| `python:3.12-alpine` | Alpine Linux | ~50 MB | Smallest possible, but musl libc can cause issues |
| `python:3.12-bookworm` | Debian Bookworm (explicit) | ~1.0 GB | Same as the default, but pinned to a specific Debian release |

The `slim` variants strip out compilers, development headers, and documentation. They're the sweet spot for most production applications. Alpine images are even smaller, but they use musl libc instead of glibc, which can cause subtle compatibility issues with some Python packages that rely on compiled C extensions.

**Distroless** images from Google go even further. They contain only your application runtime and its dependencies -- no shell, no package manager, no debugging tools. Great for security, painful for debugging:

```dockerfile
FROM gcr.io/distroless/python3-debian12
```

For this course, `slim` variants are the right choice. They balance small size with practical usability.

### Pinning Versions

In production, always pin the full version:

```dockerfile
# Good -- reproducible
FROM python:3.12.1-slim

# Acceptable -- minor updates are usually safe
FROM python:3.12-slim

# Dangerous -- "latest" changes without warning
FROM python:latest
```

We'll return to tagging strategy at the end of this lesson. For now, remember: `latest` is an anti-pattern in production.

---

## 16.3 RUN -- Executing Build Commands

`RUN` executes a command inside the image during the build process. Each `RUN` instruction creates a new layer.

```dockerfile
RUN pip install --no-cache-dir -r requirements.txt
```

This runs pip inside the container being built, installing the Python packages listed in `requirements.txt`. The `--no-cache-dir` flag prevents pip from caching downloaded packages inside the image, which would waste space since you'll never run pip again in this container.

### Layer Implications

Every `RUN` instruction creates a new image layer. Layers are immutable -- once created, they can't be modified. This has a critical implication: if you create a file in one layer and delete it in the next, the file still exists in the first layer. The image is no smaller.

```dockerfile
# Bad -- the apt cache exists in the first layer forever
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*
```

```dockerfile
# Good -- everything happens in one layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*
```

Chain related commands with `&&` and use `\` for line continuations. The cleanup (`rm -rf /var/lib/apt/lists/*`) happens in the same layer as the install, so the cache never appears in the final image.

### Common Patterns

System package installation (Debian-based images):

```dockerfile
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

System package installation (Alpine images):

```dockerfile
RUN apk add --no-cache curl ca-certificates
```

Alpine's `--no-cache` flag is the equivalent of updating the index and cleaning up in one step.

---

## 16.4 COPY vs ADD -- Getting Files into the Image

Both `COPY` and `ADD` copy files from the build context into the image. Always prefer `COPY` unless you have a specific reason to use `ADD`.

```dockerfile
COPY requirements.txt .
COPY . .
```

`COPY` does exactly one thing: copies files from the build context into the image. It's explicit and predictable.

`ADD` does the same thing, plus two extras: it can fetch URLs and it auto-extracts compressed archives (`.tar`, `.tar.gz`, `.tar.bz2`). These "features" are surprising behavior that makes Dockerfiles harder to reason about.

```dockerfile
# COPY -- clear and explicit
COPY app.tar.gz /app/

# ADD -- silently extracts the archive
ADD app.tar.gz /app/
```

The Docker community consensus: use `COPY` for everything. If you need to download a file, use `RUN curl` or `RUN wget`. If you need to extract an archive, use `RUN tar`. Explicit is better than implicit.

---

## 16.5 WORKDIR -- Setting the Working Directory

`WORKDIR` sets the working directory for all subsequent instructions in the Dockerfile. If the directory doesn't exist, it creates it.

```dockerfile
WORKDIR /app
```

This is equivalent to `mkdir -p /app && cd /app`, but it persists across instructions. Never use `RUN cd /some/dir` -- it has no effect because each `RUN` starts in its own shell session:

```dockerfile
# Wrong -- the cd has no effect on the next RUN
RUN cd /app
RUN pip install -r requirements.txt

# Right -- WORKDIR persists
WORKDIR /app
RUN pip install -r requirements.txt
```

You can use `WORKDIR` multiple times. Relative paths are resolved against the current `WORKDIR`:

```dockerfile
WORKDIR /app
WORKDIR src    # Now in /app/src
WORKDIR /data  # Absolute path -- now in /data
```

---

## 16.6 ENV -- Environment Variables

`ENV` sets environment variables that persist both during the build and at runtime when the container runs.

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
```

`PYTHONDONTWRITEBYTECODE` prevents Python from writing `.pyc` files (useless in a container). `PYTHONUNBUFFERED` ensures print statements appear immediately in `docker logs` instead of being buffered.

You can set multiple variables in one instruction:

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080
```

Environment variables set with `ENV` can be overridden at runtime with `docker run -e`:

```bash
docker run -e PORT=9090 myimage
```

This is how you configure containers for different environments. The same image runs in development, staging, and production -- the behavior changes based on environment variables. You saw this pattern in Week 15 when you passed `POSTGRES_DB` and `POSTGRES_PASSWORD` to the PostgreSQL container.

---

## 16.7 ARG -- Build-Time Variables

`ARG` defines variables that are only available during the build. They don't exist at runtime.

```dockerfile
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim

ARG APP_VERSION=1.0.0
LABEL version="${APP_VERSION}"
```

The primary use case is version pinning. You can override `ARG` values at build time:

```bash
docker build --build-arg PYTHON_VERSION=3.11 -t myapp:latest .
```

### ARG vs ENV

| Feature | ARG | ENV |
|---------|-----|-----|
| Available during build | Yes | Yes |
| Available at runtime | No | Yes |
| Can be set with `--build-arg` | Yes | No |
| Can be set with `docker run -e` | No | Yes |
| Visible in `docker inspect` | No | Yes |

One important note: `ARG` values declared before `FROM` are only available in the `FROM` instruction itself. After `FROM`, they need to be redeclared:

```dockerfile
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-slim

# PYTHON_VERSION is no longer available here unless redeclared:
ARG PYTHON_VERSION
RUN echo "Building with Python ${PYTHON_VERSION}"
```

---

## 16.8 EXPOSE -- Documenting Ports

`EXPOSE` documents which port the containerized application listens on. It does not actually publish the port.

```dockerfile
EXPOSE 8080
```

This is purely documentation. It tells anyone reading the Dockerfile (or running `docker inspect`) that the application inside expects traffic on port 8080. To actually make the port accessible from the host, you still need `-p` at runtime:

```bash
docker run -p 8080:8080 myimage
```

This is one of the most common misconceptions in Docker. People write `EXPOSE 80` and wonder why they can't reach the container. `EXPOSE` is a hint, not a command. Think of it like a comment that tools can read.

The `-P` flag (capital P) does use `EXPOSE` -- it publishes all exposed ports to random host ports. But in practice, you'll almost always use `-p` with explicit port mappings.

---

## 16.9 USER -- Running as Non-Root

By default, processes inside a container run as root. This is a security risk. If an attacker exploits a vulnerability in your application, they have root access inside the container. While container isolation limits the blast radius, running as non-root is a critical defense-in-depth measure.

```dockerfile
# Create a non-root user
RUN useradd --create-home --shell /bin/bash appuser

# Switch to it
USER appuser
```

After the `USER` instruction, all subsequent `RUN`, `CMD`, and `ENTRYPOINT` instructions execute as that user. Place `USER` after all instructions that need root privileges (installing packages, creating directories, setting permissions).

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# These need root
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

# Create user and switch
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# This runs as appuser
CMD ["python", "app.py"]
```

Verify it works:

```bash
docker run --rm myimage whoami
```

```text
appuser
```

Alpine-based images use `adduser` instead of `useradd`:

```dockerfile
RUN adduser -D -s /bin/sh appuser
USER appuser
```

---

## 16.10 CMD vs ENTRYPOINT -- Running the Application

Both `CMD` and `ENTRYPOINT` define what command runs when the container starts. Understanding how they differ and how they combine is essential for writing predictable Dockerfiles.

### CMD

`CMD` provides the default command for the container. It can be overridden entirely at runtime:

```dockerfile
CMD ["python", "app.py"]
```

```bash
# Uses the CMD
docker run myimage

# Overrides the CMD entirely
docker run myimage python -c "print('hello')"
```

### ENTRYPOINT

`ENTRYPOINT` sets the main executable. Arguments from `CMD` (or the command line) are appended to it:

```dockerfile
ENTRYPOINT ["python"]
CMD ["app.py"]
```

```bash
# Runs: python app.py
docker run myimage

# Runs: python -c "print('hello')"
docker run myimage -c "print('hello')"
```

### Exec Form vs Shell Form

Both `CMD` and `ENTRYPOINT` have two forms:

```dockerfile
# Exec form (preferred) -- runs the command directly
CMD ["python", "app.py"]

# Shell form -- wraps in /bin/sh -c
CMD python app.py
```

Always use exec form. Shell form wraps your command in `/bin/sh -c`, which means the shell is PID 1, not your application. This prevents your application from receiving signals (like SIGTERM for graceful shutdown), because the shell absorbs them.

### How They Combine

| ENTRYPOINT | CMD | Result |
|------------|-----|--------|
| Not set | `["python", "app.py"]` | `python app.py` |
| `["python"]` | `["app.py"]` | `python app.py` |
| `["python"]` | Not set | `python` |
| `["python", "app.py"]` | `["--debug"]` | `python app.py --debug` |

The common pattern: use `ENTRYPOINT` when the container should always run the same executable, and `CMD` for default arguments that users might want to override. For most applications, `CMD` alone is sufficient:

```dockerfile
CMD ["python", "app.py"]
```

---

## 16.11 HEALTHCHECK -- Defining Container Health

`HEALTHCHECK` tells Docker how to test whether the container is still working. Without it, Docker only knows if the process is running, not if it's actually serving requests.

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1
```

| Parameter | Meaning | Default |
|-----------|---------|---------|
| `--interval` | Time between checks | 30s |
| `--timeout` | Maximum time for a check to complete | 30s |
| `--start-period` | Grace period for the container to start up | 0s |
| `--retries` | Number of consecutive failures before marking unhealthy | 3 |

The `--start-period` is particularly important for applications that take time to initialize, like our Flask API that needs to connect to PostgreSQL. During the start period, failed health checks don't count toward the retry limit.

If curl isn't available in your image (it's not in `python:slim`), use Python's built-in urllib:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" || exit 1
```

Check health status:

```bash
docker inspect mycontainer --format='{{.State.Health.Status}}'
```

```text
healthy
```

This connects directly to the `/healthz` endpoint pattern from Week 12. Every production service needs a health check endpoint, and every container should have a `HEALTHCHECK` that uses it.

---

## 16.12 LABEL -- Image Metadata

`LABEL` adds metadata to the image. It's purely informational and doesn't affect how the image runs.

```dockerfile
LABEL maintainer="student@linuxmastery.dev"
LABEL version="1.0"
LABEL description="Flask Task API"
```

Or combine them:

```dockerfile
LABEL maintainer="student@linuxmastery.dev" \
      version="1.0" \
      description="Flask Task API"
```

Labels are visible with `docker inspect` and can be used to filter images:

```bash
docker images --filter "label=maintainer=student@linuxmastery.dev"
```

---

## 16.13 .dockerignore -- Controlling the Build Context

When you run `docker build .`, the Docker daemon receives the entire directory (the **build context**) as a tar archive. This includes everything: source code, git history, node_modules, virtual environments, secret files, test data.

A `.dockerignore` file tells Docker what to exclude from the build context. It works exactly like `.gitignore`:

```text
.git
.gitignore
.env
.venv
__pycache__
*.pyc
*.pyo
node_modules
*.md
Dockerfile*
.dockerignore
docker-compose*.yml
*.log
*.tmp
.DS_Store
```

Why this matters:

1. **Build speed.** A 500 MB `node_modules` directory gets sent to the daemon on every build, even if no `COPY` instruction references it.
2. **Image size.** If you use `COPY . .`, everything in the build context ends up in the image.
3. **Security.** Without `.dockerignore`, a `COPY . .` will copy your `.env` file with database passwords, API keys, and secrets into the image. Anyone who pulls the image can extract them.

Always create a `.dockerignore` before you write your first `COPY` instruction.

---

## 16.14 Build Context

The **build context** is the set of files available to `COPY` and `ADD` instructions. It's defined by the path argument to `docker build`:

```bash
docker build -t myimage .
```

The `.` means "use the current directory as the build context." Docker packages this entire directory and sends it to the daemon. You'll see this in the build output:

```text
Sending build context to Docker daemon  2.048kB
```

If you see a number in megabytes or gigabytes, your `.dockerignore` needs work:

```text
Sending build context to Docker daemon  847.3MB
```

You can specify a different context directory:

```bash
docker build -t myimage -f docker/Dockerfile ./src
```

This uses `./src` as the build context and `docker/Dockerfile` as the Dockerfile. Paths in `COPY` instructions are always relative to the build context, not the Dockerfile location.

---

## 16.15 Layer Caching Strategy

Docker caches each layer. When you rebuild an image, Docker checks whether anything has changed for each instruction. If nothing has changed, it reuses the cached layer. The moment one instruction changes, every subsequent layer rebuilds.

This means instruction order matters enormously. The rule: put things that change least at the top, things that change most at the bottom.

### The Wrong Way

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt
CMD ["python", "app.py"]
```

Every time you change a single line of application code, `COPY . .` invalidates the cache, and `pip install` runs again -- even if `requirements.txt` hasn't changed. On a project with dozens of dependencies, that's minutes wasted on every build.

### The Right Way

```dockerfile
FROM python:3.12-slim
WORKDIR /app

# Step 1: Copy ONLY the dependency file
COPY requirements.txt .

# Step 2: Install dependencies (cached until requirements.txt changes)
RUN pip install --no-cache-dir -r requirements.txt

# Step 3: Copy the rest of the application code
COPY . .

CMD ["python", "app.py"]
```

Now when you change `app.py`, only `COPY . .` and `CMD` rebuild. The `pip install` layer is cached because `requirements.txt` hasn't changed. The same principle applies to every language:

| Language | Copy first | Then install | Then copy source |
|----------|-----------|-------------|-----------------|
| Python | `COPY requirements.txt .` | `RUN pip install -r requirements.txt` | `COPY . .` |
| Node.js | `COPY package*.json ./` | `RUN npm install` | `COPY . .` |
| Go | `COPY go.mod go.sum ./` | `RUN go mod download` | `COPY . .` |
| Rust | `COPY Cargo.toml Cargo.lock ./` | `RUN cargo fetch` | `COPY . .` |

This pattern -- dependency manifest first, install, then source code -- is the single most important optimization for Dockerfile build times.

---

## 16.16 Multi-Stage Builds

**Multi-stage builds** are the key to producing small, secure production images. The idea is simple: use one stage to build your application (with all the compilers and build tools), then copy only the finished artifacts into a minimal runtime stage.

### The Problem

A typical Python application might need build tools to install C extensions:

```dockerfile
FROM python:3.12
WORKDIR /app
RUN apt-get update && apt-get install -y gcc libpq-dev
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```

This image is over 1 GB because it includes gcc, development headers, and the entire Debian package cache. None of that is needed at runtime.

### The Solution

```dockerfile
# ---- Stage 1: Builder ----
FROM python:3.12 AS builder

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: Runtime ----
FROM python:3.12-slim

WORKDIR /app

# Copy only the installed packages from the builder
COPY --from=builder /install /usr/local

COPY . .

RUN useradd --create-home appuser
USER appuser

CMD ["python", "app.py"]
```

The `AS builder` names the first stage. `COPY --from=builder` in the second stage copies files from the first stage. The final image is based on `python:3.12-slim` and contains only the runtime dependencies, not the build tools.

### How It Works

```text
Stage 1 (builder):                    Stage 2 (runtime):
┌─────────────────────┐              ┌─────────────────────┐
│ python:3.12 (1 GB)  │              │ python:3.12-slim    │
│ + gcc, libpq-dev    │   COPY       │ (150 MB)            │
│ + pip install       │ ──────────>  │ + installed packages│
│ + all build tools   │  (only the   │ + app source code   │
│                     │   packages)  │                     │
└─────────────────────┘              └─────────────────────┘
       Discarded                          Final image
```

The builder stage is discarded. It doesn't appear in the final image. Only what you explicitly `COPY --from=builder` makes it into the output.

### Node.js Example

Multi-stage builds are even more dramatic with Node.js. The build stage has the full Node.js toolchain for `npm install`, but the runtime only needs the slim variant:

```dockerfile
# Build stage
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# Runtime stage
FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js .
COPY --from=builder /app/package.json .
RUN useradd --create-home appuser
USER appuser
EXPOSE 3000
CMD ["node", "server.js"]
```

### Go Example (Most Dramatic)

Go compiles to a static binary, so the runtime stage can be `scratch` (an empty image) or `distroless`:

```dockerfile
FROM golang:1.22 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /server
CMD ["/server"]
```

The final image contains nothing but the compiled binary -- often under 20 MB.

### Building Specific Stages

You can build just a specific stage using `--target`:

```bash
docker build --target builder -t myapp:builder .
```

This is useful for CI pipelines where you might want to run tests in the builder stage before building the production image.

---

## 16.17 Building Images

Now that we understand Dockerfiles, let's cover the `docker build` command in detail.

### Basic Build

```bash
docker build -t myapp:1.0 .
```

The `-t` flag tags the image with a name and version. The `.` specifies the build context (current directory).

### Common Build Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `-t name:tag` | Tag the image | `docker build -t myapp:1.0 .` |
| `-f path` | Specify Dockerfile location | `docker build -f docker/Dockerfile .` |
| `--no-cache` | Rebuild all layers from scratch | `docker build --no-cache -t myapp:1.0 .` |
| `--target stage` | Build a specific stage | `docker build --target builder .` |
| `--build-arg KEY=VAL` | Set build argument | `docker build --build-arg VERSION=1.0 .` |
| `--platform` | Build for a different architecture | `docker build --platform linux/arm64 .` |

### Watching the Build

The build output shows each instruction being executed, with `CACHED` next to layers that haven't changed:

```text
 => [1/6] FROM python:3.12-slim@sha256:abc...              0.0s
 => CACHED [2/6] WORKDIR /app                               0.0s
 => CACHED [3/6] COPY requirements.txt .                    0.0s
 => CACHED [4/6] RUN pip install --no-cache-dir -r req...   0.0s
 => [5/6] COPY . .                                          0.1s
 => [6/6] RUN useradd --create-home appuser                 0.3s
```

Layers 2-4 are cached. Only layers 5-6 needed to rebuild because we changed the source code.

---

## 16.18 Image Size Optimization

Image size matters. Smaller images download faster, start faster, and have a smaller attack surface. Here's a summary of every optimization technique:

| Technique | Typical Savings |
|-----------|----------------|
| Use `slim` or `alpine` base image | 60-85% |
| Multi-stage build | 50-90% |
| `--no-cache-dir` for pip | 10-50 MB |
| Clean apt cache in same `RUN` layer | 20-100 MB |
| `.dockerignore` for build context | Variable |
| `--no-install-recommends` with apt | 10-50 MB |
| Remove docs/man pages in the same layer | 5-20 MB |

Use `docker images` to compare sizes and `docker history` to find which layers are the largest:

```bash
docker history myapp:1.0
```

```text
IMAGE          CREATED        CREATED BY                                      SIZE
a1b2c3d4       5 min ago      CMD ["python" "app.py"]                         0B
e5f6g7h8       5 min ago      USER appuser                                    0B
i9j0k1l2       5 min ago      RUN /bin/sh -c useradd --create-home appuser    340kB
m3n4o5p6       5 min ago      COPY . .                                        2.05kB
q7r8s9t0       5 min ago      RUN /bin/sh -c pip install --no-cache-dir ...   14.2MB
u1v2w3x4       6 min ago      COPY requirements.txt .                         58B
y5z6a7b8       6 min ago      WORKDIR /app                                    0B
```

If you see a layer that's unexpectedly large, investigate. It usually means a cache wasn't cleaned up, or too many files were copied.

---

## 16.19 Containerizing the Three-Tier App

In Weeks 12 and 13, you built a three-tier application from native services: nginx as a reverse proxy, a Flask API connected to PostgreSQL, all running directly on your Ubuntu VM. In Week 15, you ran PostgreSQL in a container and connected it to a Flask container manually.

Now we containerize everything. Each tier gets its own Dockerfile (or uses an official image), and we wire them together on a custom Docker network.

### Tier 3: PostgreSQL (Official Image)

PostgreSQL doesn't need a custom Dockerfile. The official `postgres:16-alpine` image accepts environment variables for initialization:

```bash
docker run -d \
    --name db \
    --network three-tier-net \
    -e POSTGRES_DB=taskdb \
    -e POSTGRES_USER=taskapp \
    -e POSTGRES_PASSWORD=secretpass \
    -v pgdata:/var/lib/postgresql/data \
    postgres:16-alpine
```

Remember from Week 13 when you had to edit `pg_hba.conf` to allow your application to connect? The official Docker image handles this automatically. The `POSTGRES_USER` and `POSTGRES_PASSWORD` environment variables create the user and configure authentication. The `POSTGRES_DB` variable creates the database. All the manual configuration you did in Week 13 is replaced by three environment variables.

The named volume `pgdata` ensures your data survives container restarts, just like the `/var/lib/postgresql/data` directory on the native installation.

### Tier 2: Flask API (Custom Dockerfile)

This is the `app.py` from Week 13, now with a Dockerfile. The application code is the same -- it reads database connection parameters from environment variables and exposes CRUD endpoints for tasks.

The Dockerfile is provided as `Dockerfile.api` in the labs directory:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY lab_02_app.py app.py

RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" || exit 1

CMD ["python", "app.py"]
```

Build and run it:

```bash
docker build -t task-api:latest -f Dockerfile.api .

docker run -d \
    --name api \
    --network three-tier-net \
    -e DB_HOST=db \
    -e DB_NAME=taskdb \
    -e DB_USER=taskapp \
    -e DB_PASS=secretpass \
    task-api:latest
```

Notice: no `-p` flag. The API doesn't need to be accessible from the host. It only needs to be reachable by the nginx container on the internal Docker network. This is a security improvement over the native setup, where the API listened on all interfaces.

### Tier 1: nginx Reverse Proxy (Custom Dockerfile)

In Week 12, you configured nginx by editing files in `/etc/nginx/sites-available/`. For a container, we bake the configuration directly into the image.

The `nginx.conf` for the container setup is almost identical to Week 12's configuration, with one change: the upstream target is `api:8080` instead of `127.0.0.1:8080`. On the Docker network, containers resolve each other by name.

The `Dockerfile.nginx`:

```dockerfile
FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -qO- http://localhost/nginx-health || exit 1
```

Build and run it:

```bash
docker build -t task-nginx:latest -f Dockerfile.nginx .

docker run -d \
    --name web \
    --network three-tier-net \
    -p 80:80 \
    task-nginx:latest
```

This is the only container with a published port. All external traffic enters through nginx, which forwards to the API container internally.

### Testing the Stack

```bash
curl -s http://localhost/healthz | python3 -m json.tool
```

```json
{
    "status": "healthy",
    "database": "connected"
}
```

The request traveled: host --> nginx container (port 80) --> Flask API container (port 8080) --> PostgreSQL container (port 5432) --> response back through the chain. The same architecture as Week 13, but every component is isolated in its own container.

### Preview: Week 17

The three `docker run` commands above have roughly 20 flags between them. In Week 17, we'll replace all of this with a single `compose.yml` file and one command: `docker compose up`. But because you've done it manually, you'll understand every line in that Compose file.

---

## 16.20 Development Workflow with Containers

In production, application code is baked into the image. In development, you want to edit code on your host machine and see changes immediately in the container, without rebuilding. **Bind mounts** make this possible.

```bash
docker run -d \
    --name api-dev \
    -v "$(pwd)"/app.py:/app/app.py \
    -e DB_HOST=db \
    -p 8080:8080 \
    task-api:latest
```

The `-v "$(pwd)"/app.py:/app/app.py` flag mounts the host file over the container's copy. When you edit `app.py` on your host, the container sees the change immediately. For Flask, you can enable auto-reload by setting an environment variable:

```bash
docker run -d \
    --name api-dev \
    -v "$(pwd)":/app \
    -e FLASK_DEBUG=1 \
    -e DB_HOST=db \
    -p 8080:8080 \
    task-api:latest python -m flask run --host=0.0.0.0 --port=8080 --reload
```

### Dev vs Production Pattern

A common pattern is to use multi-stage builds with a `dev` target:

```dockerfile
# ---- Base ----
FROM python:3.12-slim AS base
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Development ----
FROM base AS dev
RUN pip install debugpy watchdog
ENV FLASK_DEBUG=1
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080", "--reload"]

# ---- Production ----
FROM base AS production
COPY . .
RUN useradd --create-home appuser
USER appuser
CMD ["python", "app.py"]
```

Build for development:

```bash
docker build --target dev -t myapp:dev .
```

Build for production:

```bash
docker build --target production -t myapp:prod .
```

The development image includes debugging tools and auto-reload. The production image is lean and runs as non-root. Same Dockerfile, different targets.

---

## 16.21 Container Logging

Containers have a simple logging model: write to **stdout** and **stderr**. Docker captures both streams and makes them available through `docker logs`:

```bash
docker logs api
docker logs --follow api
docker logs --tail 50 api
docker logs --since 5m api
```

Never write to log files inside the container. Docker can't see them, and they grow unbounded unless you manage rotation yourself. Instead, configure your application to write to stdout:

```python
import logging
import sys

# Send all logs to stdout
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
```

In production, Docker's logging driver forwards these logs to a centralized system. You can configure the driver per container or daemon-wide. The default `json-file` driver writes logs to disk as JSON. Set size limits to prevent log files from filling the host disk:

```bash
docker run -d \
    --log-driver json-file \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    myimage
```

This rotates logs at 10 MB and keeps at most 3 files. In Week 17, we'll configure this in the Compose file.

---

## 16.22 Image Security

Building secure images is not optional. Here are the essential practices:

### Run as Non-Root

You've already seen this with the `USER` instruction. Always verify:

```bash
docker run --rm myimage whoami
```

If it says `root`, your Dockerfile needs a `USER` instruction.

### Use Minimal Base Images

Every package in the base image is a potential vulnerability. `python:3.12-slim` has far fewer packages (and therefore fewer potential CVEs) than `python:3.12`.

| Base Image | Packages | Typical CVEs |
|-----------|----------|-------------|
| `python:3.12` | ~400 | 20-50 |
| `python:3.12-slim` | ~100 | 5-15 |
| `python:3.12-alpine` | ~30 | 1-5 |
| `gcr.io/distroless/python3` | ~10 | 0-3 |

### Read-Only Filesystem

Run containers with `--read-only` to prevent any writes to the container filesystem. Use `tmpfs` for directories that need to be writable:

```bash
docker run -d \
    --read-only \
    --tmpfs /tmp \
    --tmpfs /app/__pycache__ \
    myimage
```

If the container crashes with a "read-only filesystem" error, it's trying to write somewhere it shouldn't be. Add a `tmpfs` mount for that specific directory.

### Scan for Vulnerabilities

Docker Scout (built into Docker Desktop) and Trivy (an open-source scanner) check your images for known vulnerabilities:

```bash
# Docker Scout
docker scout cves myimage:1.0

# Trivy
trivy image myimage:1.0
```

Run scans in your CI pipeline and before deploying to production.

### Pin Versions

Pin every base image, every package version, and every system dependency:

```dockerfile
FROM python:3.12.1-slim-bookworm

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl=7.88.1-10+deb12u5 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

With a pinned `requirements.txt`:

```text
flask==3.0.2
psycopg2-binary==2.9.9
gunicorn==21.2.0
```

This ensures that building the same Dockerfile tomorrow produces the same image as today.

---

## 16.23 Tagging Strategy

Image tags identify specific versions of an image. A sound tagging strategy makes deployments predictable and rollbacks easy.

### latest Is an Anti-Pattern

The `latest` tag is not special to Docker. It's just the default when no tag is specified. It doesn't mean "most recent" -- it means "whatever was last pushed without a tag." In production, using `latest` means you never know what version is running.

```bash
# This pulls whatever "latest" happens to be right now
docker run myapp:latest

# This pulls a known, specific version
docker run myapp:1.2.3
```

### Recommended Strategies

| Strategy | Example | When to Use |
|----------|---------|-------------|
| Semantic versioning | `myapp:1.2.3` | Stable releases |
| Git SHA | `myapp:a1b2c3d` | CI/CD pipelines |
| Date-based | `myapp:2026-02-20` | Nightly builds |
| Git SHA + semver | `myapp:1.2.3-a1b2c3d` | Best of both worlds |

Tag images at build time:

```bash
# Tag with version
docker build -t myapp:1.2.3 .

# Also tag as latest (for convenience, not for production use)
docker tag myapp:1.2.3 myapp:latest

# Tag with git SHA
docker build -t "myapp:$(git rev-parse --short HEAD)" .
```

### Pushing to a Registry

To share images, push them to a registry:

```bash
# Login to Docker Hub
docker login

# Tag for the registry
docker tag myapp:1.2.3 yourusername/myapp:1.2.3

# Push
docker push yourusername/myapp:1.2.3
```

For private registries or GitHub Container Registry:

```bash
docker tag myapp:1.2.3 ghcr.io/yourusername/myapp:1.2.3
docker push ghcr.io/yourusername/myapp:1.2.3
```

---

## 16.24 Dockerfile Instruction Reference

Here's a complete reference table of every Dockerfile instruction covered in this lesson.

| Instruction | Purpose | Example |
|-------------|---------|---------|
| `FROM` | Set the base image | `FROM python:3.12-slim` |
| `RUN` | Execute a command during build | `RUN pip install flask` |
| `COPY` | Copy files from build context | `COPY app.py /app/` |
| `ADD` | Copy files (with URL + tar support) | `ADD archive.tar.gz /app/` |
| `WORKDIR` | Set the working directory | `WORKDIR /app` |
| `ENV` | Set environment variable (build + runtime) | `ENV PORT=8080` |
| `ARG` | Set build-time variable | `ARG VERSION=1.0` |
| `EXPOSE` | Document a port (does not publish) | `EXPOSE 8080` |
| `USER` | Set the runtime user | `USER appuser` |
| `CMD` | Default command (overridable) | `CMD ["python", "app.py"]` |
| `ENTRYPOINT` | Fixed command (args appended) | `ENTRYPOINT ["python"]` |
| `HEALTHCHECK` | Define a health check | `HEALTHCHECK CMD curl -f http://localhost/` |
| `LABEL` | Add metadata | `LABEL version="1.0"` |
| `STOPSIGNAL` | Set the signal for graceful shutdown | `STOPSIGNAL SIGTERM` |
| `VOLUME` | Create a mount point | `VOLUME /data` |
| `SHELL` | Change the default shell | `SHELL ["/bin/bash", "-c"]` |

---

## 16.25 Docker vs Podman Build Commands

As with runtime commands from Week 15, the build commands are nearly identical between Docker and Podman.

| Operation | Docker | Podman |
|-----------|--------|--------|
| Build an image | `docker build -t name .` | `podman build -t name .` |
| List images | `docker images` | `podman images` |
| Image history | `docker history name` | `podman history name` |
| Remove image | `docker rmi name` | `podman rmi name` |
| Tag an image | `docker tag src dst` | `podman tag src dst` |
| Push an image | `docker push name` | `podman push name` |
| Inspect an image | `docker inspect name` | `podman inspect name` |
| Build with specific file | `docker build -f Containerfile .` | `podman build -f Containerfile .` |

Podman looks for `Containerfile` first, then `Dockerfile`. Docker looks for `Dockerfile` only (unless you specify `-f`). The file contents are identical either way.

On your Rocky Linux VM with Podman, every Dockerfile from this lesson works without modification. Just replace `docker` with `podman` in the commands.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 16.1: Dockerfile Mastery](labs/lab_01_dockerfile_mastery.md)** -- Write Dockerfiles for three progressively complex scenarios, optimize image sizes
- **[Lab 16.2: Containerize the Three-Tier App](labs/lab_02_containerize_three_tier.md)** -- Containerize the Flask API and nginx, wire all three tiers together manually

---

## Checklist

Before moving to Week 17, confirm you can:

- [ ] Write a Dockerfile from scratch for a Python application
- [ ] Explain every common Dockerfile instruction (FROM, RUN, COPY, WORKDIR, ENV, CMD, ENTRYPOINT, USER, HEALTHCHECK)
- [ ] Use .dockerignore to exclude files from the build context
- [ ] Implement a multi-stage build that produces a minimal production image
- [ ] Optimize layer caching by ordering instructions correctly
- [ ] Build images with tags, build arguments, and specific targets
- [ ] Run containers as non-root users
- [ ] Add health checks to containers
- [ ] Containerize the three-tier application (nginx + Flask API + PostgreSQL)
- [ ] Wire three containers together on a custom network with proper environment variables
- [ ] Compare image sizes between naive and optimized Dockerfiles

---

[← Previous Week](../week-15/README.md) · [Next Week →](../week-17/README.md)
