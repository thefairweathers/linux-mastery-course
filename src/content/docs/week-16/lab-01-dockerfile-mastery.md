---
title: "Lab 16.1: Dockerfile Mastery"
sidebar:
  order: 1
---


> **Objective:** Write Dockerfiles for three progressively complex scenarios: a static site with nginx, the Flask API with optimized layers, and a multi-stage Node.js build. Compare image sizes at each step.
>
> **Concepts practiced:** FROM, RUN, COPY, WORKDIR, EXPOSE, CMD, USER, HEALTHCHECK, multi-stage builds, .dockerignore, layer caching
>
> **Time estimate:** 45 minutes
>
> **VM(s) needed:** Ubuntu (Docker)

---

## Part 1: Static Site with nginx

We'll start simple: serve a static HTML page from an nginx container. First a naive version, then an optimized one.

### Step 1: Create the Project Directory

```bash
mkdir -p ~/dockerfile-lab/static-site
cd ~/dockerfile-lab/static-site
```

### Step 2: Create the HTML File

```bash
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dockerfile Lab</title>
</head>
<body>
    <h1>Served from a container</h1>
    <p>If you can see this, your Dockerfile works.</p>
</body>
</html>
EOF
```

### Step 3: Write the Naive Dockerfile

```bash
cat > Dockerfile << 'EOF'
FROM nginx:latest
COPY index.html /usr/share/nginx/html/index.html
EOF
```

Build and run it:

```bash
docker build -t static-site:naive .
docker run -d --name static-naive -p 8081:80 static-site:naive
```

Test:

```bash
curl -s http://localhost:8081/
```

**Expected output:**

```html
<!DOCTYPE html>
<html>
<head>
    <title>Dockerfile Lab</title>
</head>
<body>
    <h1>Served from a container</h1>
    <p>If you can see this, your Dockerfile works.</p>
</body>
</html>
```

Note the image size:

```bash
docker images static-site:naive --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

```text
REPOSITORY:TAG         SIZE
static-site:naive      188MB
```

That's 188 MB to serve one HTML file. We can do better.

### Step 4: Write the Optimized Dockerfile

```bash
cat > Dockerfile << 'EOF'
FROM nginx:alpine

LABEL maintainer="student@linuxmastery.dev"
LABEL description="Static site served by nginx"

# Remove the default nginx site
RUN rm /etc/nginx/conf.d/default.conf

# Add a minimal nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy static content
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD wget -qO- http://localhost/ || exit 1
EOF
```

Create the nginx config:

```bash
cat > nginx.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }

    location /healthz {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
```

Build and compare:

```bash
docker build -t static-site:optimized .
docker images static-site --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

**Expected output:**

```text
REPOSITORY:TAG              SIZE
static-site:optimized       43.3MB
static-site:naive           188MB
```

Clean up:

```bash
docker stop static-naive && docker rm static-naive
```

**What changed:** Switching from `nginx:latest` (Debian-based) to `nginx:alpine` cut the image size by ~77%. Alpine Linux is a minimal distribution built on musl libc and busybox, which makes it ideal for container base images. We also added a health check and labels -- good habits from the start.

---

## Part 2: Flask API with Optimized Layers

This is the Flask Task API from Week 13. We'll write a Dockerfile with proper layer caching, a non-root user, and a health check.

### Step 1: Create the Project Directory

```bash
mkdir -p ~/dockerfile-lab/flask-api
cd ~/dockerfile-lab/flask-api
```

### Step 2: Create the Application Files

The `requirements.txt`:

```bash
cat > requirements.txt << 'EOF'
flask
psycopg2-binary
gunicorn
EOF
```

A simplified version of the Week 13 API (for this exercise, we don't need a real database):

```bash
cat > app.py << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({"app": "Task API", "version": "1.0"})

@app.route("/healthz")
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
EOF
```

### Step 3: Write a Naive Dockerfile

Start with the straightforward approach:

```bash
cat > Dockerfile.naive << 'EOF'
FROM python:3.12
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
EXPOSE 8080
CMD ["python", "app.py"]
EOF
```

Build it:

```bash
docker build -t flask-api:naive -f Dockerfile.naive .
```

### Step 4: Write the Optimized Dockerfile

Now apply every optimization from the lesson:

```bash
cat > Dockerfile << 'EOF'
FROM python:3.12-slim

LABEL maintainer="student@linuxmastery.dev"
LABEL description="Flask Task API from Week 13"

# Set working directory
WORKDIR /app

# Install dependencies first — this layer only rebuilds when
# requirements.txt changes, not when application code changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code (changes frequently — last layer)
COPY app.py .

# Create a non-root user and switch to it
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

# Document the port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" || exit 1

# Run the application
CMD ["python", "app.py"]
EOF
```

Build and compare:

```bash
docker build -t flask-api:optimized .
docker images flask-api --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

**Expected output:**

```text
REPOSITORY:TAG            SIZE
flask-api:optimized       197MB
flask-api:naive           1.02GB
```

The difference is dramatic: `python:3.12` includes the full Debian toolchain, compilers, headers, and development libraries. `python:3.12-slim` strips all of that out.

### Step 5: Test Layer Caching

Edit `app.py` (change the version string to "2.0"), then rebuild:

```bash
sed -i 's/"version": "1.0"/"version": "2.0"/' app.py
docker build -t flask-api:optimized .
```

**Watch the output.** You should see `CACHED` on the `COPY requirements.txt` and `RUN pip install` steps. Only the `COPY app.py` layer and everything after it rebuilds. This is exactly why we copy `requirements.txt` first.

### Step 6: Test the Container

```bash
docker run -d --name flask-test -p 8082:8080 flask-api:optimized

# Test the endpoint
curl -s http://localhost:8082/healthz
```

```json
{"status":"healthy"}
```

Verify it runs as non-root:

```bash
docker exec flask-test whoami
```

```text
appuser
```

Check the health status:

```bash
docker inspect flask-test --format='{{.State.Health.Status}}'
```

After the start period (10 seconds), this should return `healthy`.

Clean up:

```bash
docker stop flask-test && docker rm flask-test
```

### Step 7: Create a .dockerignore

```bash
cat > .dockerignore << 'EOF'
__pycache__
*.pyc
.git
.env
.venv
*.md
Dockerfile*
.dockerignore
EOF
```

Rebuild and note that the build context sent to the daemon is smaller. The `.dockerignore` prevents irrelevant files from being included in the build context, which speeds up builds and prevents secrets (like `.env` files) from accidentally ending up in the image.

---

## Part 3: Multi-Stage Node.js Build

Multi-stage builds are the most powerful optimization technique. We'll build a Node.js app in one stage and run it in a much smaller one.

### Step 1: Create the Project Directory

```bash
mkdir -p ~/dockerfile-lab/node-app
cd ~/dockerfile-lab/node-app
```

### Step 2: Create the Application Files

Copy the provided `server.js` from the lab directory, or create it:

```bash
cat > server.js << 'JSEOF'
const http = require("http");

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    if (req.url === "/healthz") {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ status: "healthy" }));
        return;
    }

    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({
        message: "Hello from the containerized Node.js app!",
        node_version: process.version,
        timestamp: new Date().toISOString()
    }));
});

server.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
});
JSEOF
```

Create a `package.json`:

```bash
cat > package.json << 'EOF'
{
    "name": "node-container-lab",
    "version": "1.0.0",
    "description": "Multi-stage Dockerfile exercise",
    "main": "server.js",
    "scripts": {
        "start": "node server.js"
    },
    "dependencies": {
        "dotenv": "^16.3.1"
    }
}
EOF
```

We include `dotenv` as a dependency to make the multi-stage build meaningful. With only built-in modules, there would be nothing to install.

### Step 3: Write a Single-Stage Dockerfile

```bash
cat > Dockerfile.single << 'EOF'
FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
EOF
```

Build it:

```bash
docker build -t node-app:single -f Dockerfile.single .
```

### Step 4: Write the Multi-Stage Dockerfile

```bash
cat > Dockerfile << 'EOF'
# ---- Stage 1: Build ----
FROM node:20 AS builder

WORKDIR /app

# Install dependencies (including devDependencies for build tools)
COPY package*.json ./
RUN npm install

# Copy source code
COPY server.js .

# ---- Stage 2: Production ----
FROM node:20-slim

LABEL maintainer="student@linuxmastery.dev"
LABEL description="Multi-stage Node.js app"

WORKDIR /app

# Copy only production dependencies and source from the build stage
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js .
COPY --from=builder /app/package.json .

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD node -e "const http = require('http'); http.get('http://localhost:3000/healthz', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

CMD ["node", "server.js"]
EOF
```

Build and compare:

```bash
docker build -t node-app:multistage .
docker images node-app --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

**Expected output:**

```text
REPOSITORY:TAG            SIZE
node-app:multistage       243MB
node-app:single           1.1GB
```

The multi-stage build uses `node:20-slim` for the runtime stage, which excludes build tools, compilers, and everything else that's only needed during installation.

### Step 5: Test It

```bash
docker run -d --name node-test -p 3000:3000 node-app:multistage
curl -s http://localhost:3000/
```

```json
{"message":"Hello from the containerized Node.js app!","node_version":"v20.11.0","timestamp":"2026-02-20T15:30:00.000Z"}
```

```bash
curl -s http://localhost:3000/healthz
```

```json
{"status":"healthy"}
```

Clean up:

```bash
docker stop node-test && docker rm node-test
```

---

## Part 4: Compare All Image Sizes

List every image you've built in this lab:

```bash
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "static-site|flask-api|node-app"
```

**Expected output (approximate):**

```text
REPOSITORY:TAG              SIZE
node-app:multistage         243MB
node-app:single             1.1GB
flask-api:optimized         197MB
flask-api:naive             1.02GB
static-site:optimized       43.3MB
static-site:naive           188MB
```

In every case, the optimized version is dramatically smaller. The patterns are consistent: use slim or alpine base images, multi-stage builds for compiled languages, and `.dockerignore` to keep the build context clean.

---

## Cleanup

Remove all lab images and containers:

```bash
docker stop $(docker ps -aq --filter "name=static-" --filter "name=flask-" --filter "name=node-") 2>/dev/null
docker rm $(docker ps -aq --filter "name=static-" --filter "name=flask-" --filter "name=node-") 2>/dev/null
docker rmi static-site:naive static-site:optimized \
    flask-api:naive flask-api:optimized \
    node-app:single node-app:multistage 2>/dev/null
```

---

## Verification Checklist

After completing this lab, confirm:

- [ ] You can write a Dockerfile from scratch for a static site, a Python app, and a Node.js app
- [ ] You understand the size difference between full and slim/alpine base images
- [ ] You can implement layer caching by copying dependency files before source code
- [ ] You can add a non-root USER to a Dockerfile
- [ ] You can add a HEALTHCHECK instruction
- [ ] You can write a multi-stage Dockerfile that builds in one stage and runs in another
- [ ] You can create a `.dockerignore` file to exclude unnecessary files from the build context
- [ ] You can compare image sizes using `docker images`

---

