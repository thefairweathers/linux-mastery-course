# Lab 17.1: Compose Three-Tier Stack

> **Objective:** Translate the manually-wired three-tier app from Week 16 into a Docker Compose stack with custom networks, health checks, depends_on conditions, environment files, restart policies, and logging limits.
>
> **Concepts practiced:** compose.yml, services, volumes, networks, health checks, depends_on, env_file, restart, logging, compose.override.yml
>
> **Time estimate:** 50 minutes
>
> **VM(s) needed:** Ubuntu (Docker). Optional: Rocky (podman-compose)

---

## Overview

In Week 16, you built the three-tier stack by hand -- running `docker run` commands with networks, environment variables, and port mappings. That approach works, but it's tedious and error-prone. In this lab, you'll express the same stack declaratively in a `compose.yml` file.

By the end of this lab, a single `docker compose up -d --build` command will:

1. Build the API and nginx images from Dockerfiles
2. Create isolated frontend and backend networks
3. Create a persistent volume for PostgreSQL data
4. Start PostgreSQL, wait for its health check, start the API, wait for its health check, and start nginx
5. Serve the full request chain on port 80

---

## Part 1: Review the Manual Setup

Before writing Compose configuration, recall what you did manually in Week 16:

```bash
# 1. Created a network
docker network create app-net

# 2. Started PostgreSQL with environment variables and a volume
docker run -d --name db --network app-net \
    -e POSTGRES_DB=taskdb -e POSTGRES_USER=taskapp -e POSTGRES_PASSWORD=secretpass \
    -v pgdata:/var/lib/postgresql/data postgres:16-alpine

# 3. Built and started the API
docker build -t task-api:latest -f Dockerfile.api .
docker run -d --name api --network app-net \
    -e DB_HOST=db -e DB_NAME=taskdb -e DB_USER=taskapp -e DB_PASS=secretpass \
    task-api:latest

# 4. Built and started nginx
docker build -t task-nginx:latest -f Dockerfile.nginx .
docker run -d --name web --network app-net -p 80:80 task-nginx:latest
```

Each of those flags -- `-e`, `-v`, `-p`, `--network`, `--name` -- maps to a directive in the compose file. The translation is almost mechanical.

---

## Part 2: Prepare the Project Directory

### Step 1: Set Up the Working Directory

```bash
cd ~/week-17/labs
```

Verify the support files are present:

```bash
ls -la
```

You should see:

```text
compose.yml
compose.override.yml
.env.example
init.sql
Dockerfile.api
Dockerfile.nginx    (from Week 16 — copy if not present)
nginx.conf          (from Week 16 — copy if not present)
requirements.txt
```

If `Dockerfile.nginx` and `nginx.conf` are missing, copy them from Week 16:

```bash
cp ../../week-16/labs/Dockerfile.nginx .
cp ../../week-16/labs/nginx.conf .
```

If `lab_02_app.py` is missing, copy it from Week 13:

```bash
cp ../../week-13/labs/lab_02_app.py .
```

### Step 2: Create the .env File

```bash
cp .env.example .env
```

Open `.env` and review the values. For this lab, the defaults are fine:

```bash
cat .env
```

```text
POSTGRES_DB=taskdb
POSTGRES_USER=taskapp
POSTGRES_PASSWORD=changeme_in_production
DB_NAME=taskdb
DB_USER=taskapp
DB_PASS=changeme_in_production
```

> **Important:** In production, you would change `POSTGRES_PASSWORD` to a strong, unique password. Never use the example password on an internet-facing server.

---

## Part 3: Study the compose.yml

Open `compose.yml` and read through it carefully. The file has TODO comments explaining each section. The answers are already filled in -- this is the complete, working compose file. Your job is to understand every line.

### Step 3: Read the Compose File

```bash
cat compose.yml
```

Work through each service and answer these questions for yourself:

**For the `db` service:**
- Why does it use `env_file` instead of inline `environment` variables?
- What does the `pgdata` named volume persist?
- What does the `init.sql` bind mount do, and when does it run?
- How does the health check work? What is `pg_isready`?
- Why does the health check use `$$` instead of `$`?

**For the `api` service:**
- Why is `DB_HOST` set to `db`? What resolves that name?
- Why does it need both `environment` (for DB_HOST, DB_PORT) and `env_file` (for credentials)?
- What does `condition: service_healthy` do differently than a plain `depends_on`?
- Which two networks is the API on, and why?

**For the `web` service:**
- Why is it only on the `frontend` network?
- What happens if it tries to reach the database directly?
- Why does it depend on the API being healthy, not just started?

### Step 4: Validate the Compose File

```bash
docker compose config
```

This resolves all variable substitutions and prints the final configuration. Verify that the `.env` variables appear correctly in the output. If you see `changeme_in_production` as the database password, your `.env` file loaded successfully.

---

## Part 4: Build and Start the Stack

### Step 5: Start Everything

```bash
docker compose up -d --build
```

Watch the output carefully. You should see:

1. Images being built for `api` and `web`
2. Networks `labs_frontend` and `labs_backend` being created
3. Volume `labs_pgdata` being created (first time only)
4. Containers starting in dependency order

### Step 6: Watch the Startup Sequence

```bash
docker compose logs -f
```

Watch for:
- PostgreSQL initializing and running `init.sql`
- The API connecting to the database
- nginx starting and proxying

Press `Ctrl+C` to stop following logs.

### Step 7: Check Health Status

```bash
docker compose ps
```

All three services should show `(healthy)`:

```text
NAME           IMAGE              SERVICE   STATUS                   PORTS
labs-db-1      postgres:16        db        Up 30 seconds (healthy)  5432/tcp
labs-api-1     labs-api           api       Up 25 seconds (healthy)  8080/tcp
labs-web-1     labs-web           web       Up 20 seconds (healthy)  0.0.0.0:80->80/tcp
```

If any service shows `(health: starting)`, wait a few more seconds and check again. If it shows `(unhealthy)`, check the logs:

```bash
docker compose logs db    # or api, or web
```

---

## Part 5: Test the Full Request Chain

### Step 8: Test the Endpoints

```bash
# Health check (nginx -> API)
curl -s http://localhost/healthz | python3 -m json.tool
```

```json
{
    "status": "healthy"
}
```

```bash
# List tasks (nginx -> API -> PostgreSQL)
curl -s http://localhost/api/tasks | python3 -m json.tool
```

You should see the seed data from `init.sql`:

```json
{
    "tasks": [
        {
            "id": 1,
            "title": "Set up the development environment",
            "status": "completed",
            "created_at": "..."
        },
        {
            "id": 2,
            "title": "Learn Docker Compose",
            "status": "in_progress",
            "created_at": "..."
        }
    ]
}
```

```bash
# Create a new task
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Completed Lab 17.1"}' | python3 -m json.tool
```

```bash
# Verify it was saved
curl -s http://localhost/api/tasks | python3 -m json.tool
```

### Step 9: Verify Network Isolation

```bash
# nginx CAN reach the API (both on frontend network)
docker compose exec web wget -qO- http://api:8080/healthz
```

```text
{"status":"healthy"}
```

```bash
# nginx CANNOT reach the database (db is only on backend network)
docker compose exec web sh -c "wget -qO- http://db:5432 2>&1 || echo 'Cannot reach database — isolation works'"
```

The second command should fail. This confirms that your network topology is correct: nginx talks to the API, the API talks to the database, but nginx cannot bypass the API to reach the database directly.

---

## Part 6: Persistence Test

### Step 10: Tear Down and Rebuild

```bash
# Stop and remove containers (but NOT volumes)
docker compose down

# Verify containers are gone
docker compose ps

# Bring everything back up
docker compose up -d

# Check the data
curl -s http://localhost/api/tasks | python3 -m json.tool
```

The task you created in Step 8 ("Completed Lab 17.1") should still be there. The `pgdata` named volume preserved the database data across the `docker compose down` / `up` cycle.

### Step 11: Understand the Danger Zone

```bash
# WARNING: This destroys the database volume and all data!
# Only run this if you want to start fresh:
# docker compose down -v
```

Do NOT run this unless you want to wipe all data. The `-v` flag removes named volumes. After running it, the next `docker compose up` would re-run `init.sql` because the data directory would be empty again.

---

## Part 7: Development Overrides

### Step 12: Examine the Override File

```bash
cat compose.override.yml
```

The override file adds:
- Bind-mounted source code (live editing without rebuilds)
- Exposed debug port (8080)
- Flask debug mode
- Exposed database port (5432)

### Step 13: Test with Overrides

Since `compose.override.yml` is loaded automatically, it's already active. Verify:

```bash
# The API should be accessible on port 8080 (from the override)
curl -s http://localhost:8080/healthz | python3 -m json.tool

# The database should be accessible on port 5432 (from the override)
docker compose exec db psql -U taskapp -d taskdb -c "SELECT COUNT(*) FROM tasks;"
```

### Step 14: Production Mode (Skip Overrides)

To run without the development overrides:

```bash
# Explicitly use only the base compose file
docker compose -f compose.yml up -d --build
```

In this mode, ports 8080 and 5432 are NOT exposed to the host. Only port 80 (nginx) is accessible.

To go back to development mode:

```bash
docker compose down
docker compose up -d --build    # This loads the override automatically
```

---

## Part 8: Database Operations

### Step 15: Connect to the Database

```bash
docker compose exec db psql -U taskapp -d taskdb
```

```sql
-- List tables
\dt

-- Count tasks
SELECT COUNT(*) FROM tasks;

-- View all tasks
SELECT * FROM tasks ORDER BY id;

-- Exit
\q
```

### Step 16: Manual Backup

```bash
# Create a backup
docker compose exec -T db pg_dump -U taskapp taskdb > taskdb_backup.sql

# Verify it's not empty
wc -l taskdb_backup.sql
```

### Step 17: Test Restore

```bash
# Destroy everything (including data)
docker compose down -v

# Bring up fresh containers
docker compose up -d --build

# Wait for health checks
sleep 15

# Restore the backup
docker compose exec -T db psql -U taskapp -d taskdb < taskdb_backup.sql

# Verify the data is back
curl -s http://localhost/api/tasks | python3 -m json.tool
```

---

## Part 9 (Optional): podman-compose on Rocky

If you have a Rocky Linux VM with Podman installed:

```bash
# Install podman-compose
sudo dnf install -y podman-compose

# Copy the project files to Rocky
# (Use scp or a shared directory)

# Run the same compose file
cd ~/week-17/labs
podman-compose up -d --build

# Test
curl -s http://localhost/api/tasks | python3 -m json.tool

# Clean up
podman-compose down
```

Note any differences you encounter. Common issues include DNS resolution between containers and health check support in `depends_on`. Document what works and what doesn't.

---

## Verification Checklist

Before moving to Lab 17.2, confirm:

- [ ] `docker compose up -d --build` starts all three services
- [ ] All services show `(healthy)` in `docker compose ps`
- [ ] `curl http://localhost/api/tasks` returns tasks from the database
- [ ] Creating a task via POST persists in the database
- [ ] `docker compose down` + `docker compose up` preserves data
- [ ] nginx cannot reach the database directly (network isolation)
- [ ] `compose.override.yml` exposes debug ports in development
- [ ] `docker compose -f compose.yml up` skips overrides
- [ ] Database backup and restore work correctly
- [ ] You can explain every line of the compose.yml file

---

[← Back to Week 17 README](../README.md)
