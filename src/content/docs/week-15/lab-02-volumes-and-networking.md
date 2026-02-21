---
title: "Lab 15.2: Volumes & Networking"
sidebar:
  order: 2
---


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
| Create network | `docker network create net` | `podman network create net` |
| Remove network | `docker network rm net` | `podman network rm net` |

---

## Part 1: Persistent Storage with Named Volumes (Ubuntu)

### Step 1: Create a Named Volume

```bash
docker volume create pgdata
docker volume ls
```

```text
DRIVER    VOLUME NAME
local     pgdata
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

The `-v pgdata:/var/lib/postgresql/data` mounts your named volume at the path where PostgreSQL stores its data files. Wait for initialization:

```bash
sleep 5
docker logs pg 2>&1 | tail -3
```

You should see "database system is ready to accept connections."

### Step 3: Create Test Data

```bash
docker exec -it pg psql -U labuser -d labdb
```

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
\q
```

### Step 4: Destroy the Container

```bash
docker rm -f pg
docker ps -a | grep pg
# Expected: no output — container is gone
docker volume ls | grep pgdata
# Expected: pgdata still exists
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

sleep 3
```

### Step 6: Verify the Data Survived

```bash
docker exec pg-new psql -U labuser -d labdb -c "SELECT * FROM lab_test;"
```

```text
 id |          message           |         created_at
----+----------------------------+----------------------------
  1 | This data must survive     | 2026-02-20 15:05:00.123456
  2 | Container destruction test | 2026-02-20 15:05:00.234567
  3 | Volume persistence proof   | 2026-02-20 15:05:00.345678
(3 rows)
```

All three rows intact. The container was destroyed and replaced, but the data persisted in the named volume. This is the fundamental pattern for databases in containers.

```bash
docker rm -f pg-new
```

---

## Part 2: Bind Mount Quick Exercise (Ubuntu)

```bash
# Create host content
mkdir -p ~/lab-html
echo '<h1>Served from a bind mount</h1>' > ~/lab-html/index.html

# Run nginx with a bind mount
docker run -d --name bind-web -p 8080:80 \
  -v ~/lab-html:/usr/share/nginx/html:ro nginx

curl -s http://localhost:8080
```

```text
<h1>Served from a bind mount</h1>
```

Now modify the file on the host and verify the change is instant:

```bash
echo '<h1>Updated on the host!</h1>' > ~/lab-html/index.html
curl -s http://localhost:8080
```

```text
<h1>Updated on the host!</h1>
```

Bind mounts are a direct link — ideal for development where you edit code on the host and the container sees changes immediately.

```bash
docker rm -f bind-web
rm -rf ~/lab-html
```

---

## Part 3: Custom Networks and Container DNS (Ubuntu)

### Step 1: Create a Custom Network

```bash
docker network create lab-net
docker network ls | grep lab-net
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

sleep 3
docker exec db pg_isready -U labuser
```

Notice: no `-p` flag. We don't expose the database to the host — only containers on the same network need to reach it. This is a security best practice.

### Step 3: Test DNS Resolution from a Python Container

Create a test script:

```bash
cat > /tmp/test_connection.py << 'PYEOF'
import socket, sys

try:
    addr = socket.gethostbyname("db")
    print(f"[PASS] DNS resolved 'db' to {addr}")
except socket.gaierror:
    print("[FAIL] Could not resolve 'db'"); sys.exit(1)

try:
    sock = socket.create_connection(("db", 5432), timeout=5)
    sock.close()
    print("[PASS] TCP connection to db:5432 succeeded")
except Exception as e:
    print(f"[FAIL] TCP connection failed: {e}"); sys.exit(1)

print("\nAll tests passed.")
print("Connection string: postgresql://labuser:labsecret@db:5432/labdb")
PYEOF
```

```bash
docker run --rm --network lab-net \
  -v /tmp/test_connection.py:/app/test.py:ro \
  python:3.12-slim python3 /app/test.py
```

```text
[PASS] DNS resolved 'db' to 172.18.0.2
[PASS] TCP connection to db:5432 succeeded

All tests passed.
Connection string: postgresql://labuser:labsecret@db:5432/labdb
```

### Step 4: Query the Database from Another Container

```bash
docker run -it --rm --network lab-net \
  postgres:16 psql -h db -U labuser -d labdb -c "SELECT * FROM lab_test;"
```

Enter `labsecret` when prompted. You should see the three rows from Part 1 — accessed from a different container over the custom network.

### Step 5: Prove Default Bridge Has No DNS

```bash
docker run --rm alpine ping -c 1 db 2>&1 || true
```

```text
ping: bad address 'db'
```

Only custom networks have the embedded DNS server. Always create a custom network for containers that need to communicate by name.

### Step 6: Clean Up

```bash
docker rm -f db
docker network rm lab-net
docker volume rm pgdata
rm -f /tmp/test_connection.py
```

---

## Part 4: Repeat on Rocky (Podman)

### Volume Persistence

```bash
podman volume create pgdata
podman run -d --name pg \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16

sleep 5
podman exec -it pg psql -U labuser -d labdb -c "
  CREATE TABLE rocky_test (id SERIAL PRIMARY KEY, msg TEXT);
  INSERT INTO rocky_test (msg) VALUES ('Podman volume test');
"

podman rm -f pg
podman run -d --name pg-new \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16

sleep 3
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
podman rm -f pg-new
podman network create lab-net

podman run -d --name db --network lab-net \
  -e POSTGRES_PASSWORD=labsecret \
  -e POSTGRES_USER=labuser \
  -e POSTGRES_DB=labdb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

sleep 3
podman run --rm --network lab-net alpine ping -c 2 db
```

```text
PING db (10.89.0.2): 56 data bytes
64 bytes from 10.89.0.2: seq=0 ttl=42 time=0.065 ms
```

Note: Podman stores rootless volumes under `~/.local/share/containers/storage/volumes/` instead of Docker's `/var/lib/docker/volumes/`.

### Clean Up

```bash
podman rm -f db
podman network rm lab-net
podman volume rm pgdata
podman system prune -f
```

---

## Verification Checklist

On **both** VMs, confirm:

- [ ] You created a named volume and ran PostgreSQL with data stored in it
- [ ] You inserted data, destroyed the container, recreated it with the same volume, and verified data survived
- [ ] You used a bind mount to serve custom HTML and saw live host-side edits
- [ ] You created a custom network and ran containers on it
- [ ] You verified DNS resolution — containers reached each other by name
- [ ] You proved that the default bridge does NOT support name resolution
- [ ] You queried the database from a separate container using the container name as hostname
- [ ] You cleaned up all containers, volumes, and networks
