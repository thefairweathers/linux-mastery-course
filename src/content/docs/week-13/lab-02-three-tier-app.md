---
title: "Lab 13.2: Three-Tier Application"
sidebar:
  order: 2
---


> **Objective:** Build the full three-tier application on Ubuntu: PostgreSQL database with a tasks table, Flask API with CRUD endpoints, and nginx reverse proxy. Test with curl.
>
> **Concepts practiced:** Three-tier architecture, PostgreSQL, Flask + psycopg2, nginx reverse proxy, curl, environment variables, /healthz
>
> **Time estimate:** 50 minutes
>
> **VM(s) needed:** Ubuntu

---

## Overview

In Week 12, you built a Flask API (`app.py`) that served static JSON responses through an nginx reverse proxy. That API had no persistent storage — data disappeared when the process stopped.

This lab evolves that application into a three-tier stack:

```text
Client (curl) → nginx (:80) → Flask API (:8080) → PostgreSQL (:5432)
```

The Flask application in `lab_02_app.py` has four TODO markers where you'll write the SQL queries that connect the API to the database. This is the same application you'll containerize in Weeks 16-17.

---

## Part 1: Database Setup

### Step 1: Create the Database

```bash
sudo -u postgres psql
```

```sql
-- Create the task database
CREATE DATABASE taskdb;

-- Connect to it
\c taskdb

-- Create the tasks table
CREATE TABLE tasks (
    id          SERIAL PRIMARY KEY,
    title       VARCHAR(200) NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Verify
\d tasks
```

You should see:

```text
                                        Table "public.tasks"
   Column   |            Type             | Collation | Nullable |              Default
------------+-----------------------------+-----------+----------+-----------------------------------
 id         | integer                     |           | not null | nextval('tasks_id_seq'::regclass)
 title      | character varying(200)      |           | not null |
 status     | character varying(20)       |           | not null | 'pending'::character varying
 created_at | timestamp without time zone |           |          | now()
Indexes:
    "tasks_pkey" PRIMARY KEY, btree (id)
```

### Step 2: Create the Application User

The API should never connect as the postgres superuser. Create a dedicated user with only the permissions it needs:

```sql
-- Create the role
CREATE ROLE taskapp WITH LOGIN PASSWORD 'taskpass123';

-- Grant database access
GRANT CONNECT ON DATABASE taskdb TO taskapp;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO taskapp;

-- Grant table permissions (SELECT, INSERT, UPDATE, DELETE only)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO taskapp;

-- Grant sequence usage (needed for SERIAL columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO taskapp;

-- Apply to future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO taskapp;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO taskapp;

-- Exit
\q
```

### Step 3: Test the Application User

```bash
psql -h localhost -U taskapp -d taskdb
```

Enter the password `taskpass123`. Try a quick insert and select:

```sql
INSERT INTO tasks (title) VALUES ('Test task from psql');
SELECT * FROM tasks;
```

Confirm the row appears, then clean up:

```sql
DELETE FROM tasks WHERE title = 'Test task from psql';
\q
```

---

## Part 2: Flask API Setup

### Step 4: Install Dependencies

If you haven't already created a virtual environment for the API:

```bash
cd /opt/taskapi 2>/dev/null || sudo mkdir -p /opt/taskapi
sudo chown "$USER":"$USER" /opt/taskapi
cd /opt/taskapi

python3 -m venv venv
source venv/bin/activate
```

Copy the lab files to the working directory:

```bash
cp /path/to/week-13/labs/lab_02_app.py /opt/taskapi/app.py
cp /path/to/week-13/labs/requirements.txt /opt/taskapi/requirements.txt
```

Install the Python packages:

```bash
pip install -r requirements.txt
```

Verify both packages installed:

```bash
pip list | grep -E "flask|psycopg2"
```

```text
Flask              3.x.x
psycopg2-binary    2.9.x
```

### Step 5: Set Environment Variables

The API reads database credentials from environment variables — never hardcoded. Set them:

```bash
export DB_HOST=localhost
export DB_NAME=taskdb
export DB_USER=taskapp
export DB_PASS=taskpass123
export DB_PORT=5432
export PORT=8080
```

### Step 6: Complete the TODO Markers

Open `app.py` in your editor and find the four TODO markers. Each one requires you to replace the placeholder `cur.execute("SELECT 1")` with the correct SQL query.

Here are the hints:

**TODO 1** — `GET /api/tasks` (fetch all tasks):
- You need a SELECT query that returns `id`, `title`, `status`, and `created_at`
- Order results by `created_at` descending (newest first)
- Use the table name `tasks`

**TODO 2** — `POST /api/tasks` (create a task):
- You need an INSERT query with parameterized values (`%s`)
- The variables `title` and `status` are already extracted from the request above
- Use PostgreSQL's `RETURNING` clause to get the new row back
- Return `id`, `title`, `status`, and `created_at`

**TODO 3** — `PUT /api/tasks/<id>` (update a task):
- You need an UPDATE query that sets `title` and `status`
- The variables `title` and `status` are already extracted from the request
- Handle the case where only one of `title` or `status` is provided:
  - If `title` is None, keep the current value: `COALESCE(%s, title)`
  - If `status` is None, keep the current value: `COALESCE(%s, status)`
- Filter by `id = %s` using `task_id`
- Use `RETURNING` to get the updated row

**TODO 4** — `DELETE /api/tasks/<id>` (delete a task):
- You need a DELETE query filtered by `id = %s`
- Pass `(task_id,)` as the parameter tuple
- After executing, check `cur.rowcount` to see if a row was deleted

Take your time with these. The goal is to connect the SQL you practiced in Lab 13.1 to a real application.

### Step 7: Run the API

```bash
cd /opt/taskapi
source venv/bin/activate
python3 app.py
```

You should see:

```text
Starting Task API on port 8080...
Database: localhost:5432/taskdb
 * Serving Flask app 'app'
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8080
```

Leave this running and open a **second terminal** for testing.

---

## Part 3: Test the API with curl

### Step 8: Health Check

```bash
curl -s http://localhost:8080/healthz | python3 -m json.tool
```

Expected output:

```json
{
    "status": "healthy"
}
```

If you see `"status": "unhealthy"`, check that your environment variables are correct and PostgreSQL is running.

### Step 9: Test CRUD Operations

**Create tasks:**

```bash
curl -s -X POST http://localhost:8080/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Install PostgreSQL"}' | python3 -m json.tool
```

```json
{
    "task": {
        "id": 1,
        "title": "Install PostgreSQL",
        "status": "pending",
        "created_at": "2025-01-20T14:00:00"
    }
}
```

Create a few more:

```bash
curl -s -X POST http://localhost:8080/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Configure nginx", "status": "active"}' | python3 -m json.tool

curl -s -X POST http://localhost:8080/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Write backup script"}' | python3 -m json.tool
```

**List all tasks:**

```bash
curl -s http://localhost:8080/api/tasks | python3 -m json.tool
```

You should see all three tasks.

**Update a task:**

```bash
curl -s -X PUT http://localhost:8080/api/tasks/1 \
    -H "Content-Type: application/json" \
    -d '{"status": "complete"}' | python3 -m json.tool
```

Verify the status changed:

```json
{
    "task": {
        "id": 1,
        "title": "Install PostgreSQL",
        "status": "complete",
        "created_at": "2025-01-20T14:00:00"
    }
}
```

**Delete a task:**

```bash
curl -s -X DELETE http://localhost:8080/api/tasks/3 | python3 -m json.tool
```

```json
{
    "message": "Task 3 deleted"
}
```

**Try deleting a nonexistent task:**

```bash
curl -s -X DELETE http://localhost:8080/api/tasks/999 | python3 -m json.tool
```

```json
{
    "error": "Task 999 not found"
}
```

### Step 10: Verify Data Persists

This is the key difference from Week 12. Stop the Flask API (Ctrl+C in the first terminal), then start it again:

```bash
cd /opt/taskapi
source venv/bin/activate
export DB_HOST=localhost DB_NAME=taskdb DB_USER=taskapp DB_PASS=taskpass123
python3 app.py
```

Now list tasks again:

```bash
curl -s http://localhost:8080/api/tasks | python3 -m json.tool
```

The tasks are still there. In Week 12's API, everything would be gone after a restart. The database is what makes this a real application.

---

## Part 4: nginx Reverse Proxy

### Step 11: Verify nginx Configuration

In Week 12, you configured nginx as a reverse proxy to Flask. That configuration should still work. Verify nginx is running:

```bash
sudo systemctl status nginx
```

Check the proxy configuration:

```bash
cat /etc/nginx/sites-enabled/api
```

It should contain a `proxy_pass` directive pointing to `http://127.0.0.1:8080`. If this file doesn't exist or nginx isn't installed, create the configuration:

```bash
sudo tee /etc/nginx/sites-available/api > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/api /etc/nginx/sites-enabled/api
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

### Step 12: Test Through nginx

With both Flask and nginx running, test the full three-tier flow:

```bash
# Through nginx on port 80
curl -s http://localhost/api/tasks | python3 -m json.tool

# Health check through nginx
curl -s http://localhost/healthz | python3 -m json.tool

# Create a task through nginx
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Test through nginx"}' | python3 -m json.tool
```

The results should be identical to calling port 8080 directly. The difference is that the client now talks to nginx (port 80), which proxies to Flask (port 8080), which queries PostgreSQL (port 5432). Three tiers, working together.

### Step 13: Verify in the Database

Confirm the data arrived in PostgreSQL by querying directly:

```bash
psql -h localhost -U taskapp -d taskdb -c "SELECT id, title, status FROM tasks ORDER BY id;"
```

```text
 id |        title         |  status
----+----------------------+----------
  1 | Install PostgreSQL   | complete
  2 | Configure nginx      | active
  4 | Test through nginx   | pending
```

The data flows correctly: client to nginx to Flask to PostgreSQL, and back.

---

## Part 5: Final Validation

### Step 14: Full End-to-End Test

Run this sequence to exercise every endpoint through the full stack:

```bash
echo "=== Root endpoint ==="
curl -s http://localhost/ | python3 -m json.tool

echo "=== Health check ==="
curl -s http://localhost/healthz | python3 -m json.tool

echo "=== Create task ==="
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "End-to-end test"}' | python3 -m json.tool

echo "=== List tasks ==="
curl -s http://localhost/api/tasks | python3 -m json.tool

echo "=== Update task (set id=1 to archived) ==="
curl -s -X PUT http://localhost/api/tasks/1 \
    -H "Content-Type: application/json" \
    -d '{"status": "archived"}' | python3 -m json.tool

echo "=== Delete task ==="
curl -s -X DELETE http://localhost/api/tasks/1 | python3 -m json.tool

echo "=== Verify deletion ==="
curl -s http://localhost/api/tasks | python3 -m json.tool
```

Every request should return a valid JSON response with the appropriate HTTP status code.

### Step 15: Test Error Handling

Good APIs handle errors gracefully:

```bash
# Missing title field
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"status": "active"}' | python3 -m json.tool
```

Expected: `400 Bad Request` with `"error": "Missing 'title' in request body"`

```bash
# Update nonexistent task
curl -s -X PUT http://localhost/api/tasks/9999 \
    -H "Content-Type: application/json" \
    -d '{"status": "complete"}' | python3 -m json.tool
```

Expected: `404 Not Found` with `"error": "Task 9999 not found"`

```bash
# Invalid JSON
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d 'not json' | python3 -m json.tool
```

Expected: `400 Bad Request`

---

## What You've Built

Take a step back and appreciate what's running:

1. **PostgreSQL** stores tasks persistently, enforces data types and constraints, handles concurrent access
2. **Flask API** provides a clean REST interface, validates input, translates between HTTP and SQL
3. **nginx** faces the network, handles HTTP properly, proxies to the application

This is the architecture behind most web applications you use every day — scaled up with more instances, more databases, more services, but the same fundamental pattern.

In Week 16, you'll write a `Dockerfile` for this Flask application. In Week 17, you'll write a `docker-compose.yml` that brings up all three tiers with a single command. The code you wrote today carries forward unchanged.

---

## Verification Checklist

- [ ] PostgreSQL `taskdb` database created with `tasks` table
- [ ] Application user `taskapp` created with limited permissions
- [ ] Flask API starts without errors, connects to database
- [ ] `GET /healthz` returns `{"status": "healthy"}`
- [ ] `POST /api/tasks` creates a task and returns it with an ID
- [ ] `GET /api/tasks` lists all tasks from the database
- [ ] `PUT /api/tasks/<id>` updates a task's title or status
- [ ] `DELETE /api/tasks/<id>` removes a task
- [ ] Data persists across API restarts
- [ ] nginx reverse proxy forwards requests correctly
- [ ] All endpoints work through nginx on port 80
- [ ] Error cases return appropriate HTTP status codes and messages
