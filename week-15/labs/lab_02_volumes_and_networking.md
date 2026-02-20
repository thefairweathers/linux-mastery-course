# Lab 15.2: Volumes & Networking

> **Objective:** Create a named volume, run PostgreSQL with persistent data, verify data survives container replacement. Create a custom network, run Flask API and PostgreSQL containers, verify name-based communication.
>
> **Concepts practiced:** Named volumes, bind mounts, custom networks, container DNS, PostgreSQL container, environment variables
>
> **Time estimate:** 45 minutes
>
> **VM(s) needed:** Both Ubuntu (Docker) and Rocky (Podman)

---

## Quick Reference

| Task | Docker (Ubuntu) | Podman (Rocky) |
|------|----------------|----------------|
| Create volume | `docker volume create data` | `podman volume create data` |
| List volumes | `docker volume ls` | `podman volume ls` |
| Inspect volume | `docker volume inspect data` | `podman volume inspect data` |
| Remove volume | `docker volume rm data` | `podman volume rm data` |
| Create network | `docker network create net` | `podman network create net` |
| List networks | `docker network ls` | `podman network ls` |
| Remove network | `docker network rm net` | `podman network rm net` |

---

## Part 1: Persistent Storage with Named Volumes (Ubuntu)

In this part, you'll prove that named volumes survive container destruction. This is the pattern you'll use for every database container going forward.

### Step 1: Create a Named Volume

```bash
docker volume create pgdata
```

Verify it exists:

```bash
docker volume ls
```

```text
DRIVER    VOLUME NAME
local     pgdata
```

Inspect it to see where it lives on disk:

```bash
docker volume inspect pgdata
```

```text
[
    {
        "CreatedAt": "2026-02-20T15:00:00Z",
        "Driver": "local",
        "Labels": {},
        "Mountpoint": "/var/lib/docker/volumes/pgdata/_data",
        "Name": "pgdata",
        "Options": {},
        "Scope": "local"
    }
]
```

### Step 2: Start PostgreSQL with the Named Volume

```bash
docker run -d --name pg \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16
```

The `-v pgdata:/var/lib/postgresql/data` flag mounts your named volume at the path where PostgreSQL stores its data files. Everything PostgreSQL writes to that directory is actually written to the volume on the host.

Wait for PostgreSQL to finish initializing:

```bash
sleep 5
docker logs pg 2>&1 | tail -3
```

You should see a line containing "database system is ready to accept connections."

### Step 3: Connect and Create Test Data

```bash
docker exec -it pg psql -U labuser -d labdb
```

Inside the `psql` prompt:

```sql
CREATE TABLE lab_test (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO lab_test (message) VALUES ('This data must survive');
INSERT INTO lab_test (message) VALUES ('Container destruction test');
INSERT INTO lab_test (message) VALUES ('Volume persistence proof');

SELECT * FROM lab_test;
```

```text
 id |          message           |         created_at
----+----------------------------+----------------------------
  1 | This data must survive     | 2026-02-20 15:05:00.123456
  2 | Container destruction test | 2026-02-20 15:05:00.234567
  3 | Volume persistence proof   | 2026-02-20 15:05:00.345678
(3 rows)
```

```sql
\q
```

### Step 4: Destroy the Container

```bash
docker rm -f pg
```

The container is gone:

```bash
docker ps -a | grep pg
# Expected: no output
```

But the volume is still there:

```bash
docker volume ls | grep pgdata
```

```text
local     pgdata
```

### Step 5: Start a New Container with the Same Volume

```bash
docker run -d --name pg-new \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16
```

Wait for it to start:

```bash
sleep 3
docker exec pg-new pg_isready -U labuser
```

```text
/var/run/postgresql:5432 - accepting connections
```

### Step 6: Verify the Data Survived

```bash
docker exec -it pg-new psql -U labuser -d labdb -c "SELECT * FROM lab_test;"
```

```text
 id |          message           |         created_at
----+----------------------------+----------------------------
  1 | This data must survive     | 2026-02-20 15:05:00.123456
  2 | Container destruction test | 2026-02-20 15:05:00.234567
  3 | Volume persistence proof   | 2026-02-20 15:05:00.345678
(3 rows)
```

All three rows are intact. The container was destroyed and replaced, but the data persisted because it lived in the named volume, not in the container's writable layer.

This is the fundamental pattern for running databases in containers: **always use a named volume for the data directory.**

### Step 7: Clean Up Part 1

```bash
docker rm -f pg-new
# Keep the volume for now — we'll use it in Part 2
```

---

## Part 2: Bind Mount Quick Exercise (Ubuntu)

Before moving to networking, let's quickly demonstrate bind mounts as a contrast to named volumes.

### Step 1: Create a Host Directory with Content

```bash
mkdir -p ~/lab-html
echo '<html><body><h1>Served from a bind mount</h1></body></html>' > ~/lab-html/index.html
```

### Step 2: Run nginx with a Bind Mount

```bash
docker run -d --name bind-web \
  -p 8080:80 \
  -v ~/lab-html:/usr/share/nginx/html:ro \
  nginx
```

### Step 3: Verify

```bash
curl -s http://localhost:8080
```

```text
<html><body><h1>Served from a bind mount</h1></body></html>
```

### Step 4: Modify on the Host, See It in the Container

```bash
echo '<html><body><h1>Updated on the host!</h1></body></html>' > ~/lab-html/index.html
curl -s http://localhost:8080
```

```text
<html><body><h1>Updated on the host!</h1></body></html>
```

The change was instant. Bind mounts are a direct link between host and container filesystems. This is ideal for development — edit code on your host, and the container sees the changes immediately.

### Step 5: Clean Up

```bash
docker rm -f bind-web
rm -rf ~/lab-html
```

---

## Part 3: Custom Networks and Container DNS (Ubuntu)

Now let's connect containers by name using a custom network. This is how real containerized applications find each other.

### Step 1: Create a Custom Network

```bash
docker network create lab-net
```

Verify:

```bash
docker network ls
```

```text
NETWORK ID     NAME      DRIVER    SCOPE
...
f1e2d3c4b5a6   lab-net   bridge    local
```

### Step 2: Start PostgreSQL on the Custom Network

```bash
docker run -d --name db \
  --network lab-net \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

Notice: no `-p` flag. We don't need to expose PostgreSQL to the host because only other containers on the same network need to reach it. This is a security best practice — don't expose database ports to the host unless you have a reason.

Wait for PostgreSQL to be ready:

```bash
sleep 3
docker exec db pg_isready -U labuser
```

### Step 3: Start a Python/Flask Container on the Same Network

We'll use a simple Python container to prove we can reach the database by name. First, create a small test script:

```bash
cat > /tmp/test_connection.py << 'PYEOF'
import subprocess
import socket
import sys

# Test 1: DNS resolution
try:
    addr = socket.gethostbyname("db")
    print(f"[PASS] DNS resolved 'db' to {addr}")
except socket.gaierror:
    print("[FAIL] Could not resolve 'db'")
    sys.exit(1)

# Test 2: TCP connection to PostgreSQL port
try:
    sock = socket.create_connection(("db", 5432), timeout=5)
    sock.close()
    print("[PASS] TCP connection to db:5432 succeeded")
except (socket.timeout, ConnectionRefusedError) as e:
    print(f"[FAIL] TCP connection to db:5432 failed: {e}")
    sys.exit(1)

print("\nAll connectivity tests passed.")
print("The Flask API would use: postgresql://labuser:labsecret@db:5432/labdb")
PYEOF
```

Run the test inside a Python container on the same network:

```bash
docker run --rm \
  --network lab-net \
  -v /tmp/test_connection.py:/app/test_connection.py:ro \
  python:3.12-slim \
  python3 /app/test_connection.py
```

```text
[PASS] DNS resolved 'db' to 172.18.0.2
[PASS] TCP connection to db:5432 succeeded

All connectivity tests passed.
The Flask API would use: postgresql://labuser:labsecret@db:5432/labdb
```

The Python container resolved the hostname `db` to the PostgreSQL container's IP address on the custom network. This is exactly how the Flask API will connect to PostgreSQL in our three-tier application (Weeks 16 and 17).

### Step 4: Verify with psql from Another Container

Let's use a PostgreSQL client container to actually query the database across the network:

```bash
docker run -it --rm \
  --network lab-net \
  postgres:16 \
  psql -h db -U labuser -d labdb -c "SELECT * FROM lab_test;"
```

When prompted for the password, enter `labsecret`.

```text
 id |          message           |         created_at
----+----------------------------+----------------------------
  1 | This data must survive     | 2026-02-20 15:05:00.123456
  2 | Container destruction test | 2026-02-20 15:05:00.234567
  3 | Volume persistence proof   | 2026-02-20 15:05:00.345678
(3 rows)
```

The data you created in Part 1 is still there — accessed from a completely different container over the custom network. This is the power of combining named volumes with custom networks.

### Step 5: Inspect the Network

```bash
docker network inspect lab-net --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
```

```text
db: 172.18.0.2/16
```

### Step 6: Prove the Default Bridge Does NOT Have DNS

For comparison, start a container on the default bridge and try to resolve the `db` name:

```bash
docker run --rm alpine ping -c 1 db 2>&1 || true
```

```text
ping: bad address 'db'
```

This fails because the default bridge network does not provide DNS resolution. Only custom networks have the embedded DNS server. This is why you should always create a custom network for containers that need to communicate.

### Step 7: Clean Up Part 3

```bash
docker rm -f db
docker network rm lab-net
docker volume rm pgdata
rm -f /tmp/test_connection.py
```

---

## Part 4: Repeat on Rocky (Podman)

Switch to your Rocky VM and run through the essential exercises with Podman.

### Volume Persistence

```bash
# Create volume and run PostgreSQL
podman volume create pgdata
podman run -d --name pg \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16

# Wait for initialization
sleep 5

# Create test data
podman exec -it pg psql -U labuser -d labdb -c "
  CREATE TABLE rocky_test (id SERIAL PRIMARY KEY, msg TEXT);
  INSERT INTO rocky_test (msg) VALUES ('Podman volume test');
"

# Destroy and recreate
podman rm -f pg
podman run -d --name pg-new \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16

sleep 3

# Verify data survived
podman exec pg-new psql -U labuser -d labdb -c "SELECT * FROM rocky_test;"
```

```text
 id |        msg
----+--------------------
  1 | Podman volume test
(1 row)
```

### Custom Network and DNS

```bash
# Create network
podman network create lab-net

# Start PostgreSQL on the custom network
podman rm -f pg-new
podman run -d --name db \
  --network lab-net \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

sleep 3

# Verify DNS resolution from another container
podman run --rm --network lab-net alpine ping -c 2 db
```

```text
PING db (10.89.0.2): 56 data bytes
64 bytes from 10.89.0.2: seq=0 ttl=42 time=0.065 ms
64 bytes from 10.89.0.2: seq=1 ttl=42 time=0.058 ms
```

```bash
# Query the database from a client container
podman run -it --rm \
  --network lab-net \
  postgres:16 \
  psql -h db -U labuser -d labdb -c "SELECT * FROM rocky_test;"
```

### Podman-Specific: Inspect Volume Location

```bash
podman volume inspect pgdata
```

Note that Podman stores volumes in a different location than Docker. With rootless Podman, volumes are typically stored under `~/.local/share/containers/storage/volumes/`.

### Clean Up

```bash
podman rm -f db
podman network rm lab-net
podman volume rm pgdata
podman system prune -f
```

---

## Part 5: Architecture Review

Before finishing, take a moment to map what you did in this lab to the three-tier architecture from Week 13 and where we're headed:

```text
What you did in Week 13 (native):
  Host → apt/dnf install postgresql → systemctl start → psql

What you did in this lab (containerized):
  Host → docker run postgres:16 -v pgdata:/var/lib/postgresql/data → psql via exec

What's coming in Weeks 16-17:
  Host → docker compose up → nginx + Flask + PostgreSQL (all containers, one command)
```

The core concepts carry forward:
- PostgreSQL still needs persistent storage (now a named volume instead of a filesystem path)
- Services still need to find each other (now DNS on a custom network instead of IP/localhost)
- Configuration still uses environment variables (now `-e` flags instead of editing config files)

---

## Verification Checklist

On **both** VMs, confirm:

- [ ] You created a named volume and verified it with `volume ls` and `volume inspect`
- [ ] You ran PostgreSQL with data stored in the named volume
- [ ] You inserted data, destroyed the container, created a new one with the same volume, and verified the data survived
- [ ] You used a bind mount to serve custom HTML from the host filesystem
- [ ] You created a custom network with `network create`
- [ ] You ran PostgreSQL and a client container on the same custom network
- [ ] You verified DNS resolution — containers could reach each other by name
- [ ] You proved that the default bridge does NOT support DNS resolution
- [ ] You queried the database from a separate container using the container name as hostname
- [ ] You cleaned up all containers, volumes, and networks
