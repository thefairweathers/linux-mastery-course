---
title: "Lab 17.2: Capstone Deployment"
sidebar:
  order: 2
---


> **Objective:** Deploy the complete three-tier stack on your Ubuntu VM with production patterns. This lab ties together every week of the course.
>
> **Concepts practiced:** Everything from Weeks 1-17
>
> **Time estimate:** 90-120 minutes
>
> **VM(s) needed:** Ubuntu

---

## Overview

This is the final lab. You will deploy the three-tier application -- nginx, Flask API, PostgreSQL -- as a production-ready Docker Compose stack on a hardened Ubuntu server. Along the way, you'll use skills from every week of the course.

The lab is structured as a sequential walkthrough. Each phase builds on the previous one. By the end, you'll have:

- A properly organized project directory with correct permissions
- Docker and supporting tools installed
- A fully functional Compose stack with health checks and network isolation
- SSH hardening and firewall rules
- Automated database backups with a systemd timer
- A monitoring script that checks the entire stack
- Documentation of the system architecture

Work through each phase in order. Verify your work at each checkpoint before moving on.

---

## Phase 1: Filesystem and Project Layout (Weeks 2, 5)

A well-organized project starts with a clear directory structure. You practiced this in Week 2 (navigation and file operations) and Week 5 (ownership and permissions).

### Step 1: Create the Project Directory

```bash
sudo mkdir -p /opt/taskapp
sudo chown "$USER":"$USER" /opt/taskapp
cd /opt/taskapp
```

### Step 2: Create the Directory Structure

```bash
mkdir -p backups scripts docs
```

The layout:

```text
/opt/taskapp/
├── compose.yml           # Docker Compose configuration
├── compose.override.yml  # Development overrides
├── .env                  # Environment variables (secrets)
├── init.sql              # Database initialization
├── Dockerfile.api        # API container build
├── Dockerfile.nginx      # nginx container build
├── nginx.conf            # nginx reverse proxy config
├── lab_02_app.py         # Flask application
├── requirements.txt      # Python dependencies
├── backups/              # Database backup storage
├── scripts/              # Operational scripts
└── docs/                 # Architecture documentation
```

### Step 3: Copy Project Files

Copy the lab files into the project directory:

```bash
cp ~/week-17/labs/compose.yml /opt/taskapp/
cp ~/week-17/labs/compose.override.yml /opt/taskapp/
cp ~/week-17/labs/.env.example /opt/taskapp/.env
cp ~/week-17/labs/init.sql /opt/taskapp/
cp ~/week-17/labs/Dockerfile.api /opt/taskapp/
cp ~/week-17/labs/requirements.txt /opt/taskapp/
cp ~/week-16/labs/Dockerfile.nginx /opt/taskapp/
cp ~/week-16/labs/nginx.conf /opt/taskapp/
cp ~/week-13/labs/lab_02_app.py /opt/taskapp/
```

> **Note:** Adjust the source paths based on where your course materials are stored. The key files are the compose.yml, Dockerfiles, nginx.conf, the Flask app, and the init.sql.

### Step 4: Secure the Environment File

The `.env` file contains database credentials. Apply restrictive permissions (Week 5):

```bash
chmod 600 /opt/taskapp/.env
ls -la /opt/taskapp/.env
```

```text
-rw------- 1 student student 280 Feb 20 10:00 /opt/taskapp/.env
```

Only the owner can read or write this file. No group or other access.

### Step 5: Set a Real Password

Edit the `.env` file and replace the example password:

```bash
nano /opt/taskapp/.env
```

Change `POSTGRES_PASSWORD` and `DB_PASS` to a strong password. Both variables must match -- they refer to the same credential from different perspectives (PostgreSQL sees `POSTGRES_PASSWORD`; the Flask app sees `DB_PASS`).

### Checkpoint 1

```bash
ls -la /opt/taskapp/
```

Verify:
- [ ] All project files are present
- [ ] `.env` has permissions `600` (owner read/write only)
- [ ] Directory is owned by your user, not root
- [ ] Password in `.env` is changed from the example

---

## Phase 2: Package Management and Docker (Week 6)

### Step 6: Update the System

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 7: Install Docker (if Not Already Installed)

If Docker isn't installed from Week 15/16:

```bash
# Install prerequisites
sudo apt install -y ca-certificates curl

# Add Docker's GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

### Step 8: Add Your User to the Docker Group

```bash
sudo usermod -aG docker "$USER"
```

Log out and back in for the group change to take effect, then verify:

```bash
docker compose version
```

```text
Docker Compose version v2.27.0
```

### Step 9: Ensure Docker Starts on Boot

```bash
sudo systemctl enable docker
systemctl is-enabled docker
```

```text
enabled
```

This uses the systemd skills from Week 11 -- `enable` creates the symlink so Docker starts at boot.

### Checkpoint 2

```bash
docker --version
docker compose version
systemctl is-active docker
```

Verify:
- [ ] Docker is installed and running
- [ ] Docker Compose V2 is available (`docker compose`, not `docker-compose`)
- [ ] Docker is enabled to start at boot
- [ ] Your user is in the docker group (can run `docker ps` without sudo)

---

## Phase 3: Deploy the Compose Stack (Weeks 15-17)

### Step 10: Build and Start the Stack

```bash
cd /opt/taskapp
docker compose up -d --build
```

This command builds the API and nginx images, creates networks and volumes, and starts all services in dependency order.

### Step 11: Verify Health Checks

```bash
docker compose ps
```

Wait until all three services show `(healthy)`. This may take 30-60 seconds on first start because PostgreSQL needs to initialize the data directory.

If a service shows `(unhealthy)`, check its logs:

```bash
docker compose logs db
docker compose logs api
docker compose logs web
```

### Step 12: Test the Full Request Chain

```bash
# Health check
curl -s http://localhost/healthz | python3 -m json.tool

# List tasks (should show seed data from init.sql)
curl -s http://localhost/api/tasks | python3 -m json.tool

# Create a task
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Capstone deployment complete"}' | python3 -m json.tool

# Verify persistence
curl -s http://localhost/api/tasks | python3 -m json.tool
```

### Step 13: Verify Network Isolation

```bash
# Should succeed: nginx -> API
docker compose exec web wget -qO- http://api:8080/healthz
echo ""

# Should fail: nginx -> database (network isolation)
docker compose exec web sh -c "wget -T 3 -qO- http://db:5432 2>&1 || echo 'Blocked — correct'"
```

### Checkpoint 3

```bash
docker compose ps
curl -s http://localhost/healthz
curl -s http://localhost/api/tasks
```

Verify:
- [ ] All three services show `(healthy)`
- [ ] `/healthz` returns `{"status": "healthy"}`
- [ ] `/api/tasks` returns tasks from the database
- [ ] Creating a task via POST works and persists
- [ ] nginx cannot reach the database directly

---

## Phase 4: Firewall Configuration (Week 9)

### Step 14: Install and Configure ufw

```bash
sudo apt install -y ufw
```

Configure the rules. Order matters -- set defaults first, then allow specific ports:

```bash
# Set default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (so you don't lock yourself out!)
sudo ufw allow ssh

# Allow HTTP (nginx)
sudo ufw allow 80/tcp

# Allow HTTPS (for future TLS)
sudo ufw allow 443/tcp
```

### Step 15: Enable the Firewall

```bash
sudo ufw enable
```

You'll be asked to confirm. Type `y`.

```bash
sudo ufw status verbose
```

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

### Step 16: Verify Access Still Works

```bash
curl -s http://localhost/healthz | python3 -m json.tool
```

If you're SSH'd into the server, verify your SSH session is still alive. If you lose it, you've locked yourself out -- connect via console access and `sudo ufw allow ssh`.

### Important: Docker and ufw

Docker manages its own iptables rules, which can bypass ufw. This is a known issue. Docker publishes container ports by modifying iptables directly, so even with ufw denying incoming traffic, Docker-published ports may still be accessible from the network.

To prevent this, bind ports to localhost in your compose file when you don't want external access:

```yaml
ports:
  - "127.0.0.1:8080:8080"    # Only accessible from the host
```

For the nginx port (80), external access is intentional, so the default binding is correct.

### Checkpoint 4

```bash
sudo ufw status
curl -s http://localhost/healthz
```

Verify:
- [ ] ufw is active with default deny incoming
- [ ] SSH (22), HTTP (80), and HTTPS (443) are allowed
- [ ] The application still responds on port 80

---

## Phase 5: SSH Hardening and Intrusion Prevention (Week 10)

### Step 17: Harden SSH

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

Edit the SSH configuration:

```bash
sudo nano /etc/ssh/sshd_config
```

Set these directives (uncomment and change as needed):

```text
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
```

> **Warning:** Before disabling password authentication, confirm you have a working SSH key. If you disable passwords without a key, you'll lock yourself out.

Test the configuration and restart:

```bash
sudo sshd -t && sudo systemctl restart sshd
```

### Step 18: Install fail2ban

```bash
sudo apt install -y fail2ban
```

Create a local configuration:

```bash
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
```

```bash
sudo systemctl enable --now fail2ban
sudo systemctl status fail2ban
```

Check the jail status:

```bash
sudo fail2ban-client status sshd
```

```text
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

### Checkpoint 5

```bash
sudo sshd -t
sudo fail2ban-client status sshd
```

Verify:
- [ ] Root login is disabled
- [ ] Password authentication is disabled (SSH key only)
- [ ] fail2ban is running and monitoring SSH
- [ ] You can still log in via SSH (test in a new terminal before closing your current session!)

---

## Phase 6: Automated Backups (Weeks 8, 11, 14)

### Step 19: Create the Backup Script

This script combines skills from Weeks 8 (scripting basics), 14 (production scripting patterns), and 13 (database backups):

```bash
sudo tee /opt/taskapp/scripts/backup-db.sh << 'SCRIPT'
#!/bin/bash
# =============================================================================
# TaskApp Database Backup Script
# =============================================================================
# Creates compressed PostgreSQL backups with rotation.
# Designed to run via systemd timer (see Phase 6).
#
# Usage:
#   /opt/taskapp/scripts/backup-db.sh
# =============================================================================
set -euo pipefail

# Configuration
BACKUP_DIR="/opt/taskapp/backups"
COMPOSE_DIR="/opt/taskapp"
RETENTION_DAYS=7
DATE="$(date +%Y%m%d_%H%M%S)"

# Logging function (Week 14 pattern)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Verify the database container is running
if ! docker compose -f "$COMPOSE_DIR/compose.yml" ps db --format json 2>/dev/null | grep -q "running"; then
    log "ERROR: Database container is not running"
    exit 1
fi

# Create the backup
log "Starting backup of taskdb..."
docker compose -f "$COMPOSE_DIR/compose.yml" exec -T db \
    pg_dump -Fc -U taskapp taskdb > "${BACKUP_DIR}/taskdb_${DATE}.dump"

# Verify the backup is not empty
if [ ! -s "${BACKUP_DIR}/taskdb_${DATE}.dump" ]; then
    log "ERROR: Backup file is empty"
    rm -f "${BACKUP_DIR}/taskdb_${DATE}.dump"
    exit 1
fi

BACKUP_SIZE="$(du -h "${BACKUP_DIR}/taskdb_${DATE}.dump" | cut -f1)"
log "Backup created: taskdb_${DATE}.dump ($BACKUP_SIZE)"

# Rotate old backups
DELETED="$(find "$BACKUP_DIR" -name "*.dump" -mtime +"$RETENTION_DAYS" -print -delete | wc -l)"
if [ "$DELETED" -gt 0 ]; then
    log "Rotated $DELETED backup(s) older than $RETENTION_DAYS days"
fi

# Summary
TOTAL="$(find "$BACKUP_DIR" -name "*.dump" | wc -l)"
log "Backup complete. $TOTAL backup(s) on disk."
SCRIPT
```

```bash
sudo chmod +x /opt/taskapp/scripts/backup-db.sh
```

### Step 20: Test the Backup Script

```bash
sudo /opt/taskapp/scripts/backup-db.sh
```

```text
[2026-02-20 10:30:00] Starting backup of taskdb...
[2026-02-20 10:30:02] Backup created: taskdb_20260220_103000.dump (4.0K)
[2026-02-20 10:30:02] Backup complete. 1 backup(s) on disk.
```

Verify the backup file exists:

```bash
ls -lh /opt/taskapp/backups/
```

### Step 21: Create a systemd Timer (Week 11)

Create the service unit (what to run):

```bash
sudo tee /etc/systemd/system/taskapp-backup.service << 'EOF'
[Unit]
Description=TaskApp database backup

[Service]
Type=oneshot
ExecStart=/opt/taskapp/scripts/backup-db.sh
User=root
StandardOutput=journal
StandardError=journal
SyslogIdentifier=taskapp-backup
EOF
```

Create the timer unit (when to run):

```bash
sudo tee /etc/systemd/system/taskapp-backup.timer << 'EOF'
[Unit]
Description=Daily TaskApp database backup at 2 AM

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
EOF
```

Enable the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now taskapp-backup.timer
```

Verify:

```bash
systemctl list-timers taskapp-backup.timer
```

```text
NEXT                         LEFT     LAST  PASSED  UNIT                   ACTIVATES
Sat 2026-02-21 02:00:00 UTC  15h left n/a   n/a     taskapp-backup.timer   taskapp-backup.service
```

### Step 22: Test the Timer Manually

```bash
sudo systemctl start taskapp-backup.service
journalctl -u taskapp-backup.service --no-pager
```

### Step 23: Test Restore

Verify your backup actually works by restoring it:

```bash
# Remember the current task count
curl -s http://localhost/api/tasks | python3 -c "import sys,json; data=json.load(sys.stdin); print(f'Tasks before: {len(data.get(\"tasks\", []))}')"

# Find the most recent backup
LATEST_BACKUP="$(ls -t /opt/taskapp/backups/*.dump | head -1)"
echo "Restoring from: $LATEST_BACKUP"

# Restore (--clean drops existing objects first)
docker compose -f /opt/taskapp/compose.yml exec -T db \
    pg_restore -U taskapp -d taskdb --clean < "$LATEST_BACKUP"

# Verify
curl -s http://localhost/api/tasks | python3 -c "import sys,json; data=json.load(sys.stdin); print(f'Tasks after: {len(data.get(\"tasks\", []))}')"
```

### Checkpoint 6

```bash
ls -lh /opt/taskapp/backups/
systemctl list-timers taskapp-backup.timer
```

Verify:
- [ ] Backup script runs successfully and creates a `.dump` file
- [ ] Systemd timer is enabled and shows the next scheduled run
- [ ] Restore from the backup works correctly
- [ ] Journal logs show backup activity (`journalctl -u taskapp-backup`)

---

## Phase 7: Monitoring Script (Weeks 8, 14)

### Step 24: Create the Health Check Script

```bash
tee /opt/taskapp/scripts/check-health.sh << 'SCRIPT'
#!/bin/bash
# =============================================================================
# TaskApp Health Check Script
# =============================================================================
# Checks all components of the three-tier stack.
# Exit code 0 = all healthy, non-zero = one or more failures.
# =============================================================================
set -euo pipefail

FAILURES=0
COMPOSE_DIR="/opt/taskapp"

# Color output (if terminal supports it)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m'
else
    GREEN=""
    RED=""
    NC=""
fi

pass() { echo -e "  ${GREEN}[OK]${NC}   $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; FAILURES=$((FAILURES + 1)); }

echo "========================================"
echo " TaskApp Health Check"
echo " $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# --- Container Health ---
echo "Container Status:"
for svc in db api web; do
    if docker compose -f "$COMPOSE_DIR/compose.yml" ps "$svc" 2>/dev/null | grep -q "(healthy)"; then
        pass "$svc container is healthy"
    else
        fail "$svc container is NOT healthy"
    fi
done

echo ""

# --- Endpoint Checks ---
echo "Endpoint Checks:"

if curl -sf http://localhost/nginx-health > /dev/null 2>&1; then
    pass "nginx health endpoint"
else
    fail "nginx health endpoint unreachable"
fi

if curl -sf http://localhost/healthz > /dev/null 2>&1; then
    pass "API health endpoint"
else
    fail "API health endpoint unreachable"
fi

if curl -sf http://localhost/api/tasks > /dev/null 2>&1; then
    pass "API tasks endpoint (database connected)"
else
    fail "API tasks endpoint unreachable"
fi

echo ""

# --- System Checks ---
echo "System Checks:"

if systemctl is-active --quiet docker; then
    pass "Docker daemon running"
else
    fail "Docker daemon not running"
fi

if systemctl is-active --quiet ufw; then
    pass "Firewall (ufw) active"
else
    fail "Firewall (ufw) not active"
fi

if systemctl is-active --quiet fail2ban; then
    pass "fail2ban running"
else
    fail "fail2ban not running"
fi

if systemctl is-enabled --quiet taskapp-backup.timer 2>/dev/null; then
    pass "Backup timer enabled"
else
    fail "Backup timer not enabled"
fi

# Check disk space (warn if > 80% used on /)
DISK_USAGE="$(df / --output=pcent | tail -1 | tr -d ' %')"
if [ "$DISK_USAGE" -lt 80 ]; then
    pass "Disk usage at ${DISK_USAGE}%"
else
    fail "Disk usage at ${DISK_USAGE}% (above 80% threshold)"
fi

echo ""
echo "========================================"
if [ "$FAILURES" -eq 0 ]; then
    echo " All checks passed."
else
    echo " WARNING: $FAILURES check(s) failed!"
fi
echo "========================================"

exit "$FAILURES"
SCRIPT
```

```bash
chmod +x /opt/taskapp/scripts/check-health.sh
```

### Step 25: Run the Health Check

```bash
/opt/taskapp/scripts/check-health.sh
```

Expected output (all checks passing):

```text
========================================
 TaskApp Health Check
 2026-02-20 10:45:00
========================================

Container Status:
  [OK]   db container is healthy
  [OK]   api container is healthy
  [OK]   web container is healthy

Endpoint Checks:
  [OK]   nginx health endpoint
  [OK]   API health endpoint
  [OK]   API tasks endpoint (database connected)

System Checks:
  [OK]   Docker daemon running
  [OK]   Firewall (ufw) active
  [OK]   fail2ban running
  [OK]   Backup timer enabled
  [OK]   Disk usage at 23%

========================================
 All checks passed.
========================================
```

### Checkpoint 7

```bash
/opt/taskapp/scripts/check-health.sh
echo "Exit code: $?"
```

Verify:
- [ ] All container checks pass
- [ ] All endpoint checks pass
- [ ] All system checks pass
- [ ] Exit code is 0

---

## Phase 8: Optional TLS with Self-Signed Certificate (Week 12)

This phase is optional. It adds HTTPS using a self-signed certificate and a host-level nginx instance. Skip this if you want to keep things simpler.

### Step 26: Generate a Self-Signed Certificate

```bash
sudo mkdir -p /etc/nginx/ssl

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/taskapp.key \
    -out /etc/nginx/ssl/taskapp.crt \
    -subj "/C=US/ST=Lab/L=Lab/O=LinuxMastery/CN=taskapp.local"
```

### Step 27: Install Host nginx (TLS Termination)

If you want to add TLS termination in front of the containerized stack, install nginx on the host and proxy to the Docker-published port:

```bash
sudo apt install -y nginx
```

```bash
sudo tee /etc/nginx/sites-available/taskapp << 'EOF'
server {
    listen 443 ssl;
    server_name taskapp.local;

    ssl_certificate     /etc/nginx/ssl/taskapp.crt;
    ssl_certificate_key /etc/nginx/ssl/taskapp.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name taskapp.local;
    return 301 https://$host$request_uri;
}
EOF
```

```bash
sudo ln -sf /etc/nginx/sites-available/taskapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

Note: If port 80 conflicts with the containerized nginx, update the Compose port mapping to use a different host port (e.g., `"8080:80"`) and update the proxy_pass accordingly.

### Step 28: Test TLS

```bash
curl -sk https://localhost/healthz | python3 -m json.tool
```

---

## Phase 9: Architecture Documentation

### Step 29: Document Your Stack

Create a documentation file describing the system:

```bash
tee /opt/taskapp/docs/ARCHITECTURE.md << 'DOCEOF'
# TaskApp Architecture

## Overview

TaskApp is a three-tier web application deployed with Docker Compose on Ubuntu.

## Stack Components

| Tier | Service | Technology | Container Image |
|------|---------|------------|-----------------|
| Frontend | Reverse Proxy | nginx | nginx:alpine (custom) |
| Middleware | REST API | Flask (Python) | python:3.12-slim (custom) |
| Backend | Database | PostgreSQL 16 | postgres:16-alpine |

## Network Architecture

- **frontend network**: nginx <-> Flask API
- **backend network**: Flask API <-> PostgreSQL
- nginx cannot reach PostgreSQL directly (defense in depth)

## Data Persistence

- PostgreSQL data: Docker named volume (`pgdata`)
- Backups: `/opt/taskapp/backups/` (daily, 7-day retention)

## Security

- SSH: key-only authentication, no root login
- Firewall: ufw with default deny, ports 22/80/443 only
- Intrusion prevention: fail2ban on SSH
- Container isolation: non-root users, network segmentation
- Secrets: `.env` file with 600 permissions

## Backup & Restore

### Automated Backups
- Schedule: Daily at 2:00 AM via systemd timer
- Script: `/opt/taskapp/scripts/backup-db.sh`
- Storage: `/opt/taskapp/backups/`
- Retention: 7 days

### Manual Backup
```
docker compose -f /opt/taskapp/compose.yml exec -T db \
    pg_dump -Fc -U taskapp taskdb > /opt/taskapp/backups/manual_backup.dump
```

### Restore
```
docker compose -f /opt/taskapp/compose.yml exec -T db \
    pg_restore -U taskapp -d taskdb --clean < /opt/taskapp/backups/BACKUP_FILE.dump
```

## Monitoring

- Health check script: `/opt/taskapp/scripts/check-health.sh`
- Container health: `docker compose -f /opt/taskapp/compose.yml ps`
- Logs: `docker compose -f /opt/taskapp/compose.yml logs -f`

## Common Operations

| Task | Command |
|------|---------|
| Start stack | `cd /opt/taskapp && docker compose up -d` |
| Stop stack | `cd /opt/taskapp && docker compose down` |
| Rebuild after code change | `cd /opt/taskapp && docker compose up -d --build` |
| View logs | `cd /opt/taskapp && docker compose logs -f` |
| Database shell | `docker compose -f /opt/taskapp/compose.yml exec db psql -U taskapp taskdb` |
| Run health check | `/opt/taskapp/scripts/check-health.sh` |
| Manual backup | `/opt/taskapp/scripts/backup-db.sh` |

## Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| 502 Bad Gateway | `docker compose ps` | Restart unhealthy service |
| API unhealthy | `docker compose logs api` | Check database connectivity |
| Database unhealthy | `docker compose logs db` | Check volume, credentials |
| Can't SSH | `sudo ufw status` | Ensure port 22 is allowed |
| Disk full | `df -h` | Rotate logs, remove old backups |
DOCEOF
```

### Checkpoint 8

```bash
cat /opt/taskapp/docs/ARCHITECTURE.md
```

Verify:
- [ ] Documentation covers all stack components
- [ ] Backup and restore procedures are documented
- [ ] Common operations are listed with commands
- [ ] Troubleshooting guide covers common failure modes

---

## Phase 10: Final Verification

### Step 30: Run the Complete Health Check

```bash
/opt/taskapp/scripts/check-health.sh
```

Every check should pass.

### Step 31: Process Verification (Week 7)

Use the process monitoring skills from Week 7:

```bash
# Check Docker containers
docker compose -f /opt/taskapp/compose.yml ps

# Check resource usage
docker stats --no-stream

# Check listening ports
sudo ss -tlnp | grep -E ':(22|80|443|5432|8080)\s'
```

### Step 32: Full Request Chain Test

```bash
echo "=== Full Request Chain Test ==="

echo ""
echo "1. Health check (nginx -> API):"
curl -s http://localhost/healthz | python3 -m json.tool

echo ""
echo "2. List tasks (nginx -> API -> PostgreSQL):"
curl -s http://localhost/api/tasks | python3 -m json.tool

echo ""
echo "3. Create a task:"
curl -s -X POST http://localhost/api/tasks \
    -H "Content-Type: application/json" \
    -d '{"title": "Capstone complete - all 17 weeks done"}' | python3 -m json.tool

echo ""
echo "4. Verify persistence:"
curl -s http://localhost/api/tasks | python3 -m json.tool
```

### Step 33: Reboot Test

The ultimate test -- does everything come back after a reboot?

```bash
sudo reboot
```

After the server comes back up, SSH in and verify:

```bash
# Docker should auto-start
systemctl is-active docker

# Containers should auto-restart (unless-stopped policy)
docker compose -f /opt/taskapp/compose.yml ps

# Data should persist
curl -s http://localhost/api/tasks | python3 -m json.tool

# Run the health check
/opt/taskapp/scripts/check-health.sh
```

If everything comes back cleanly, your deployment is production-ready.

---

## Final Checklist

This checklist maps every skill to the week where you learned it:

| Week | Skill | Verified? |
|------|-------|-----------|
| 2 | Project directory organized with clear structure | [ ] |
| 5 | `.env` file has restrictive permissions (600) | [ ] |
| 6 | Docker installed from official repository | [ ] |
| 7 | Process monitoring: `docker stats`, `ss -tlnp` | [ ] |
| 8, 14 | Backup script with error handling and rotation | [ ] |
| 9 | Firewall configured: default deny, allow 22/80/443 | [ ] |
| 10 | SSH hardened: no root, no passwords, fail2ban | [ ] |
| 11 | Systemd timer for automated backups | [ ] |
| 12 | nginx reverse proxy (containerized) | [ ] |
| 13 | PostgreSQL with init scripts, backup/restore | [ ] |
| 15 | Container concepts: images, layers, registries | [ ] |
| 16 | Dockerfiles: multi-stage builds, non-root users | [ ] |
| 17 | Docker Compose: services, networks, volumes, health checks | [ ] |
| -- | Architecture documentation written | [ ] |
| -- | Health check script runs with all checks passing | [ ] |
| -- | Stack survives a reboot | [ ] |

---

Congratulations. You've deployed a complete three-tier application stack from scratch, secured the host, automated backups, and documented everything. Every layer of this system -- from the firewall rules to the database queries to the container health checks -- you built by hand. You understand how it works because you made it work.

That's the foundation. Now go build something.

---

