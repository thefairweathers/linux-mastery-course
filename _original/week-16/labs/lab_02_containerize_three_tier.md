# Lab 16.2: Containerize the Three-Tier App

> **Objective:** Containerize the three-tier application from Weeks 12-13: write a Dockerfile for the Flask API, create a custom nginx container, run all three containers on a custom network, and test the full request flow.
>
> **Concepts practiced:** Dockerfile, docker build, docker network, docker run, environment variables, named volumes, port mapping, health checks
>
> **Time estimate:** 50 minutes
>
> **VM(s) needed:** Ubuntu (Docker)

---

## Architecture Overview

In Weeks 12 and 13, we built this three-tier architecture using native services installed directly on the VM:

```text
Browser / curl
      │
      ▼
┌──────────────┐
│  nginx       │  port 80 (reverse proxy)
│  (native)    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Flask API   │  port 8080 (application)
│  (native)    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  PostgreSQL  │  port 5432 (database)
│  (native)    │
└──────────────┘
```

Now we're putting each tier into its own container. The architecture is identical, but every service runs in isolation. Instead of talking over `localhost`, the containers communicate over a custom Docker network using container names as hostnames.

```text
Host machine (port 80 published)
      │
      ▼
┌──────────────┐
│  web         │  nginx container (port 80)
│  (container) │  network: three-tier-net
└──────┬───────┘
       │  proxy_pass → http://api:8080
       ▼
┌──────────────┐
│  api         │  Flask API container (port 8080)
│  (container) │  network: three-tier-net
└──────┬───────┘
       │  DB_HOST=db
       ▼
┌──────────────┐
│  db          │  PostgreSQL container (port 5432)
│  (container) │  network: three-tier-net
└──────────────┘  volume: pgdata
```

This is the manual version. In Week 17, Docker Compose will automate all of this with a single `docker compose up`.

---

## Part 1: Prepare the Project

### Step 1: Create a Working Directory

```bash
mkdir -p ~/three-tier-containers
cd ~/three-tier-containers
```

### Step 2: Copy the Lab Files

Copy the provided files from the course repository's `week-16/labs/` directory:

```bash
cp /path/to/week-16/labs/Dockerfile.api .
cp /path/to/week-16/labs/Dockerfile.nginx .
cp /path/to/week-16/labs/nginx.conf .
```

> **Note:** Replace `/path/to/week-16/labs/` with the actual path where you cloned this course repository.

### Step 3: Create the requirements.txt

This is the same dependency list from Week 13:

```bash
cat > requirements.txt << 'EOF'
flask
psycopg2-binary
EOF
```

### Step 4: Create the Application File

This is the Flask Task API from Week 13 (`lab_02_app.py`), which provides CRUD endpoints for a task list backed by PostgreSQL. If you completed Week 13, you already have this file. For convenience, here's the working version:

```bash
cat > lab_02_app.py << 'PYEOF'
"""
Flask Task API — Week 13 (containerized in Week 16)
====================================================
CRUD API for tasks, backed by PostgreSQL.
Database connection parameters come from environment variables.
"""

from flask import Flask, jsonify, request
import psycopg2
import psycopg2.extras
import os
import time

app = Flask(__name__)


def get_db_connection():
    """Create a database connection using environment variables."""
    for attempt in range(5):
        try:
            conn = psycopg2.connect(
                host=os.environ.get("DB_HOST", "localhost"),
                port=os.environ.get("DB_PORT", "5432"),
                dbname=os.environ.get("DB_NAME", "taskdb"),
                user=os.environ.get("DB_USER", "taskapp"),
                password=os.environ.get("DB_PASS", "secretpass"),
            )
            return conn
        except psycopg2.OperationalError:
            if attempt < 4:
                time.sleep(2)
            else:
                raise


def init_db():
    """Create the tasks table if it doesn't exist."""
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS tasks (
            id SERIAL PRIMARY KEY,
            title VARCHAR(200) NOT NULL,
            status VARCHAR(20) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    cur.close()
    conn.close()


@app.route("/")
def index():
    return jsonify({
        "application": "Task API",
        "version": "1.0",
        "endpoints": ["/", "/healthz", "/tasks"]
    })


@app.route("/healthz")
def health():
    """Health check — verifies database connectivity."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1")
        cur.close()
        conn.close()
        return jsonify({"status": "healthy", "database": "connected"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 503


@app.route("/tasks", methods=["GET"])
def list_tasks():
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute("SELECT id, title, status, created_at FROM tasks ORDER BY id")
    tasks = cur.fetchall()
    cur.close()
    conn.close()
    # Convert datetime objects to strings for JSON serialization
    for task in tasks:
        task["created_at"] = task["created_at"].isoformat()
    return jsonify(tasks)


@app.route("/tasks", methods=["POST"])
def create_task():
    data = request.get_json()
    if not data or "title" not in data:
        return jsonify({"error": "title is required"}), 400
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(
        "INSERT INTO tasks (title) VALUES (%s) RETURNING id, title, status, created_at",
        (data["title"],)
    )
    task = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    task["created_at"] = task["created_at"].isoformat()
    return jsonify(task), 201


@app.route("/tasks/<int:task_id>", methods=["PUT"])
def update_task(task_id):
    data = request.get_json()
    if not data:
        return jsonify({"error": "Request body required"}), 400
    conn = get_db_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    updates = []
    values = []
    if "title" in data:
        updates.append("title = %s")
        values.append(data["title"])
    if "status" in data:
        updates.append("status = %s")
        values.append(data["status"])
    if not updates:
        return jsonify({"error": "Nothing to update"}), 400
    values.append(task_id)
    cur.execute(
        f"UPDATE tasks SET {', '.join(updates)} WHERE id = %s RETURNING id, title, status, created_at",
        values
    )
    task = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    if task is None:
        return jsonify({"error": "Task not found"}), 404
    task["created_at"] = task["created_at"].isoformat()
    return jsonify(task)


@app.route("/tasks/<int:task_id>", methods=["DELETE"])
def delete_task(task_id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("DELETE FROM tasks WHERE id = %s RETURNING id", (task_id,))
    deleted = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    if deleted is None:
        return jsonify({"error": "Task not found"}), 404
    return jsonify({"deleted": task_id}), 200


if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
PYEOF
```

---

## Part 2: Review the Dockerfiles

Before building, let's understand what each Dockerfile does.

### Step 5: Review Dockerfile.api

Open the file and read through it:

```bash
cat Dockerfile.api
```

Key design decisions in this Dockerfile:

| Line | Purpose |
|------|---------|
| `FROM python:3.12-slim` | Slim base image -- ~150 MB vs ~1 GB for the full image |
| `COPY requirements.txt` first | Layer caching: pip install only re-runs when dependencies change |
| `RUN pip install --no-cache-dir` | `--no-cache-dir` prevents pip from storing download cache in the image |
| `COPY lab_02_app.py app.py` | Renames the file inside the container for cleanliness |
| `USER appuser` | Runs as non-root -- a container security essential |
| `HEALTHCHECK` | Lets Docker (and later Compose) know if the service is healthy |
| `CMD ["python", "app.py"]` | Exec form -- no shell wrapper, proper signal handling |

### Step 6: Review Dockerfile.nginx

```bash
cat Dockerfile.nginx
```

This is simple by design: the official nginx image does the heavy lifting. We just replace the default config with our reverse proxy configuration.

### Step 7: Review nginx.conf

```bash
cat nginx.conf
```

Notice the upstream target: `server api:8080`. In Week 12, this was `127.0.0.1:8080` because the API ran on the same host. In containers, `api` is the container name, and Docker's built-in DNS resolves it to the correct IP on the custom network.

---

## Part 3: Build the Images

### Step 8: Build the API Image

```bash
cd ~/three-tier-containers
docker build -t task-api:latest -f Dockerfile.api .
```

**Expected output (last lines):**

```text
 => exporting to image
 => => naming to docker.io/library/task-api:latest
```

### Step 9: Build the nginx Image

```bash
docker build -t task-nginx:latest -f Dockerfile.nginx .
```

### Step 10: Verify Both Images

```bash
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep task-
```

**Expected output:**

```text
task-nginx:latest       43.3MB
task-api:latest         197MB
```

---

## Part 4: Create the Network and Run the Containers

### Step 11: Create the Custom Network

```bash
docker network create three-tier-net
```

This creates an isolated bridge network with built-in DNS. Containers on this network can reach each other by name.

### Step 12: Run the PostgreSQL Container

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

Let's break down every flag:

| Flag | Purpose |
|------|---------|
| `-d` | Run in detached mode (background) |
| `--name db` | Container name -- this becomes the DNS hostname on the network |
| `--network three-tier-net` | Attach to our custom network |
| `-e POSTGRES_DB=taskdb` | Create this database on first start |
| `-e POSTGRES_USER=taskapp` | Create this user on first start |
| `-e POSTGRES_PASSWORD=secretpass` | Set the user's password |
| `-v pgdata:/var/lib/postgresql/data` | Named volume for data persistence |

Wait a few seconds for PostgreSQL to initialize, then verify:

```bash
docker logs db 2>&1 | tail -3
```

**Expected output:**

```text
...database system is ready to accept connections
```

### Step 13: Run the Flask API Container

```bash
docker run -d \
    --name api \
    --network three-tier-net \
    -e DB_HOST=db \
    -e DB_NAME=taskdb \
    -e DB_USER=taskapp \
    -e DB_PASS=secretpass \
    task-api:latest
```

Notice: we don't publish a port (`-p`). The API only needs to be reachable by the nginx container on the internal network, not from the host. The `DB_HOST=db` environment variable tells the Flask app to connect to the PostgreSQL container by its name.

Verify it started:

```bash
docker logs api 2>&1 | tail -5
```

**Expected output:**

```text
 * Serving Flask app 'app'
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8080
```

### Step 14: Run the nginx Container

```bash
docker run -d \
    --name web \
    --network three-tier-net \
    -p 80:80 \
    task-nginx:latest
```

This is the only container with a published port. All external traffic enters through nginx on port 80, just like in the Week 12 architecture.

### Step 15: Verify All Containers Are Running

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected output:**

```text
NAMES    STATUS                    PORTS
web      Up 10 seconds             0.0.0.0:80->80/tcp
api      Up 30 seconds (healthy)   8080/tcp
db       Up 45 seconds             5432/tcp
```

---

## Part 5: Test the Full Request Flow

### Step 16: Test the Root Endpoint

```bash
curl -s http://localhost/ | python3 -m json.tool
```

**Expected output:**

```json
{
    "application": "Task API",
    "version": "1.0",
    "endpoints": ["/", "/healthz", "/tasks"]
}
```

The request traveled: your machine --> nginx container (port 80) --> Flask API container (port 8080) --> response.

### Step 17: Test the Health Check

```bash
curl -s http://localhost/healthz | python3 -m json.tool
```

**Expected output:**

```json
{
    "status": "healthy",
    "database": "connected"
}
```

The API confirmed it can connect to the PostgreSQL container. All three tiers are communicating.

### Step 18: Create Tasks

```bash
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"title": "Learn Dockerfiles"}' \
    http://localhost/tasks | python3 -m json.tool
```

```json
{
    "id": 1,
    "title": "Learn Dockerfiles",
    "status": "pending",
    "created_at": "2026-02-20T15:30:00.000000"
}
```

```bash
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"title": "Build multi-stage images"}' \
    http://localhost/tasks | python3 -m json.tool
```

```bash
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"title": "Orchestrate with Compose"}' \
    http://localhost/tasks | python3 -m json.tool
```

### Step 19: List All Tasks

```bash
curl -s http://localhost/tasks | python3 -m json.tool
```

**Expected output:**

```json
[
    {
        "id": 1,
        "title": "Learn Dockerfiles",
        "status": "pending",
        "created_at": "2026-02-20T15:30:00.000000"
    },
    {
        "id": 2,
        "title": "Build multi-stage images",
        "status": "pending",
        "created_at": "2026-02-20T15:30:05.000000"
    },
    {
        "id": 3,
        "title": "Orchestrate with Compose",
        "status": "pending",
        "created_at": "2026-02-20T15:30:10.000000"
    }
]
```

### Step 20: Update a Task

```bash
curl -s -X PUT -H "Content-Type: application/json" \
    -d '{"status": "done"}' \
    http://localhost/tasks/1 | python3 -m json.tool
```

```json
{
    "id": 1,
    "title": "Learn Dockerfiles",
    "status": "done",
    "created_at": "2026-02-20T15:30:00.000000"
}
```

### Step 21: Delete a Task

```bash
curl -s -X DELETE http://localhost/tasks/3 | python3 -m json.tool
```

```json
{
    "deleted": 3
}
```

Verify the deletion:

```bash
curl -s http://localhost/tasks | python3 -m json.tool
```

You should see two tasks remaining: id 1 (status "done") and id 2 (status "pending").

---

## Part 6: Verify Data Persistence

The whole point of the named volume (`pgdata`) is that data survives container restarts.

### Step 22: Stop and Remove All Containers

```bash
docker stop web api db
docker rm web api db
```

### Step 23: Verify the Volume Still Exists

```bash
docker volume ls --filter name=pgdata
```

```text
DRIVER    VOLUME NAME
local     pgdata
```

### Step 24: Start Everything Again

Run the same three `docker run` commands from Steps 12-14:

```bash
# PostgreSQL
docker run -d \
    --name db \
    --network three-tier-net \
    -e POSTGRES_DB=taskdb \
    -e POSTGRES_USER=taskapp \
    -e POSTGRES_PASSWORD=secretpass \
    -v pgdata:/var/lib/postgresql/data \
    postgres:16-alpine

# Wait for PostgreSQL to be ready
sleep 5

# Flask API
docker run -d \
    --name api \
    --network three-tier-net \
    -e DB_HOST=db \
    -e DB_NAME=taskdb \
    -e DB_USER=taskapp \
    -e DB_PASS=secretpass \
    task-api:latest

# nginx
docker run -d \
    --name web \
    --network three-tier-net \
    -p 80:80 \
    task-nginx:latest
```

### Step 25: Verify Data Survived

```bash
sleep 3
curl -s http://localhost/tasks | python3 -m json.tool
```

**Expected output:**

```json
[
    {
        "id": 1,
        "title": "Learn Dockerfiles",
        "status": "done",
        "created_at": "2026-02-20T15:30:00.000000"
    },
    {
        "id": 2,
        "title": "Build multi-stage images",
        "status": "pending",
        "created_at": "2026-02-20T15:30:05.000000"
    }
]
```

The tasks are still there. The named volume preserved the PostgreSQL data across a full container lifecycle of stop, remove, and recreate.

---

## Part 7: Inspect the Container Health

### Step 26: Check Health Status

```bash
docker inspect api --format='{{.State.Health.Status}}'
```

```text
healthy
```

```bash
docker inspect web --format='{{.State.Health.Status}}'
```

```text
healthy
```

### Step 27: View the Network

```bash
docker network inspect three-tier-net --format='{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
```

**Expected output (IPs will vary):**

```text
db: 172.18.0.2/16
api: 172.18.0.3/16
web: 172.18.0.4/16
```

All three containers are on the same network. Docker's built-in DNS allows them to resolve each other by name.

---

## Cleanup

```bash
docker stop web api db
docker rm web api db
docker network rm three-tier-net
docker volume rm pgdata
docker rmi task-api:latest task-nginx:latest
```

---

## Looking Ahead

In this lab, you ran six `docker run` commands with a total of about 20 flags. You had to start containers in the right order, wait for PostgreSQL to initialize, and remember the network name and environment variables. It works, but it's tedious and error-prone.

In Week 17, you'll define this entire stack in a single `compose.yml` file. One command -- `docker compose up` -- will replace everything you did manually in this lab. But because you did it manually first, you'll understand every line in that Compose file.

---

## Verification Checklist

After completing this lab, confirm:

- [ ] You built a Docker image for the Flask API using the provided Dockerfile
- [ ] You built a custom nginx image with the reverse proxy config baked in
- [ ] You created a custom Docker network (`three-tier-net`)
- [ ] You ran PostgreSQL, Flask API, and nginx containers on the custom network
- [ ] The full request flow works: curl --> nginx --> Flask API --> PostgreSQL --> response
- [ ] All CRUD operations work: create, list, update, delete tasks
- [ ] Data persists across container stop/remove/recreate cycles (named volume)
- [ ] The API health check confirms database connectivity
- [ ] Containers can reach each other by name on the custom network
- [ ] Only the nginx container has a published port (80)

---

[Back to Week 16 README](../README.md)
