---
title: "Lab 12.2: Reverse Proxy & DNS"
sidebar:
  order: 2
---


> **Objective:** Run the provided Flask API on port 8080, configure nginx as reverse proxy on port 80, set up dnsmasq so myapp.local resolves to the VM, and add a /healthz endpoint.
>
> **Concepts practiced:** reverse proxy, proxy_pass, proxy_set_header, dnsmasq, Flask API, health checks
>
> **Time estimate:** 40 minutes
>
> **VM(s) needed:** Ubuntu

---

## Architecture Overview

Here is what we're building. Every request flows through this chain:

```text
Client (curl)
    │
    ▼
┌──────────────┐
│  dnsmasq     │  myapp.local → 127.0.0.1
│  (DNS)       │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  nginx       │  port 80 (reverse proxy)
│              │  proxy_pass → localhost:8080
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Flask API   │  port 8080 (application)
│  (app.py)    │
└──────────────┘
```

This is the same architecture used in production everywhere. In Week 13, we'll add a database below the Flask API to complete the three-tier stack.

---

## Part 1: Set Up the Flask API

### Step 1: Install Python3 and pip

Python3 is usually pre-installed on Ubuntu, but let's make sure pip is available:

```bash
sudo apt update && sudo apt install -y python3 python3-pip python3-venv
```

Verify:

```bash
python3 --version
```

### Step 2: Create a Project Directory and Virtual Environment

We'll keep the application in a dedicated directory, following the convention from Week 11 where we placed custom services under `/opt/`:

```bash
sudo mkdir -p /opt/myapi
sudo chown "$USER":"$USER" /opt/myapi
```

Copy the provided app files into place:

```bash
cp /path/to/labs/app.py /opt/myapi/
cp /path/to/labs/requirements.txt /opt/myapi/
```

> **Note:** Replace `/path/to/labs/` with the actual path to this lab's directory, or copy the files from wherever you've cloned the course repository.

Create a virtual environment and install dependencies:

```bash
cd /opt/myapi
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Step 3: Test the API Directly

Start the Flask app in the foreground:

```bash
python3 /opt/myapi/app.py
```

```text
 * Serving Flask app 'app'
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8080
 * Running on http://10.0.2.15:8080
```

Open a second terminal (or use `tmux` / another SSH session) and test each endpoint:

```bash
# Root endpoint
curl -s http://localhost:8080/ | python3 -m json.tool
```

```json
{
    "application": "Linux Mastery API",
    "version": "1.0",
    "endpoints": ["/", "/healthz", "/api/hello", "/api/echo"]
}
```

```bash
# Health check
curl -s http://localhost:8080/healthz | python3 -m json.tool
```

```json
{
    "status": "healthy"
}
```

```bash
# Hello with a name parameter
curl -s "http://localhost:8080/api/hello?name=Linux" | python3 -m json.tool
```

```json
{
    "message": "Hello, Linux!"
}
```

```bash
# Echo endpoint (POST with JSON body)
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"course": "Linux Mastery"}' \
    http://localhost:8080/api/echo | python3 -m json.tool
```

```json
{
    "echoed": {
        "course": "Linux Mastery"
    }
}
```

```bash
# Headers endpoint — shows what the API sees
curl -s http://localhost:8080/api/headers | python3 -m json.tool
```

Every endpoint works. Stop the Flask app with `Ctrl+C` for now.

### Step 4: Run the API in the Background

For this lab, we'll run the API in the background. In a production environment, you'd use a systemd service unit (as we learned in Week 11), but for learning the reverse proxy pattern, a background process is sufficient:

```bash
cd /opt/myapi
source venv/bin/activate
nohup python3 app.py > /tmp/myapi.log 2>&1 &
echo $!
```

Note the PID so you can stop it later. Verify it's running:

```bash
curl -s http://localhost:8080/healthz
```

```json
{"status":"healthy"}
```

---

## Part 2: Configure nginx as a Reverse Proxy

### Step 1: Create the Reverse Proxy Configuration

```bash
sudo tee /etc/nginx/sites-available/myapi << 'EOF'
server {
    listen 80;
    server_name myapp.local;

    access_log /var/log/nginx/myapi.access.log;
    error_log  /var/log/nginx/myapi.error.log;

    location / {
        proxy_pass http://127.0.0.1:8080;

        # Forward the original client information to the backend
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

Let's break down the `proxy_set_header` directives:

| Header | Purpose |
|--------|---------|
| `Host` | Tells the backend which hostname the client requested |
| `X-Real-IP` | The actual client IP address (not the proxy's address) |
| `X-Forwarded-For` | Chain of all proxies the request passed through |
| `X-Forwarded-Proto` | Whether the client connected via `http` or `https` |

Without these headers, the Flask API would see every request as coming from `127.0.0.1` (the proxy itself), and it wouldn't know the original hostname or protocol.

### Step 2: Enable the Site and Reload

```bash
sudo ln -s /etc/nginx/sites-available/myapi /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Step 3: Test Through the Proxy

Since we haven't set up DNS yet, use the `Host` header to route the request:

```bash
curl -s -H "Host: myapp.local" http://localhost/ | python3 -m json.tool
```

```json
{
    "application": "Linux Mastery API",
    "version": "1.0",
    "endpoints": ["/", "/healthz", "/api/hello", "/api/echo"]
}
```

The request went: `curl` --> `nginx:80` --> `Flask:8080` --> response back up the chain.

### Step 4: Verify Headers Are Forwarded

This is the critical test. The `/api/headers` endpoint shows exactly what the Flask app receives:

```bash
curl -s -H "Host: myapp.local" http://localhost/api/headers | python3 -m json.tool
```

```json
{
    "headers": {
        "Host": "myapp.local",
        "X-Real-Ip": "127.0.0.1",
        "X-Forwarded-For": "127.0.0.1",
        "X-Forwarded-Proto": "http",
        "Connection": "close",
        "User-Agent": "curl/7.81.0",
        "Accept": "*/*"
    }
}
```

Confirm these headers are present:

- `Host: myapp.local` -- the original requested hostname, not `127.0.0.1`
- `X-Real-Ip` -- the client's actual IP
- `X-Forwarded-For` -- the proxy chain
- `X-Forwarded-Proto` -- the original protocol

If any of these are missing, your `proxy_set_header` directives need attention.

---

## Part 3: Set Up Local DNS with dnsmasq

Right now, we have to pass `-H "Host: myapp.local"` with every curl request. Let's set up local DNS so that `myapp.local` actually resolves to our machine.

### Step 1: Install dnsmasq

```bash
sudo apt install -y dnsmasq
```

On Ubuntu with systemd-resolved running, dnsmasq may fail to start because port 53 is already in use. Check:

```bash
sudo systemctl status dnsmasq
```

If it failed, we need to adjust systemd-resolved to stop listening on port 53:

```bash
# Tell systemd-resolved to stop binding to port 53
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/no-stub.conf << 'EOF'
[Resolve]
DNSStubListener=no
EOF

sudo systemctl restart systemd-resolved
```

Then restart dnsmasq:

```bash
sudo systemctl restart dnsmasq
```

Verify it's running:

```bash
systemctl is-active dnsmasq
```

```text
active
```

### Step 2: Configure dnsmasq

Add a local DNS entry that maps `myapp.local` to `127.0.0.1`:

```bash
sudo tee /etc/dnsmasq.d/myapp.conf << 'EOF'
# Local DNS for our application
address=/myapp.local/127.0.0.1
EOF
```

Restart dnsmasq to pick up the new configuration:

```bash
sudo systemctl restart dnsmasq
```

### Step 3: Point the System Resolver at dnsmasq

Ensure the system uses dnsmasq for DNS resolution. Update `/etc/resolv.conf` to point to localhost:

```bash
# Check the current resolver
cat /etc/resolv.conf
```

If it's a symlink managed by systemd-resolved, replace it:

```bash
sudo rm /etc/resolv.conf
sudo tee /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
EOF
```

> **Note:** On a VM, you may also want a fallback DNS server so you don't lose internet access. Add your original nameserver as a second line (e.g., `nameserver 8.8.8.8`). dnsmasq will handle `.local` domains and forward everything else upstream.

Configure dnsmasq to forward non-local queries:

```bash
sudo tee -a /etc/dnsmasq.d/myapp.conf << 'EOF'

# Forward all other queries to Google DNS
server=8.8.8.8
server=8.8.4.4
EOF

sudo systemctl restart dnsmasq
```

### Step 4: Test DNS Resolution

```bash
# Test that our local domain resolves
dig myapp.local @127.0.0.1 +short
```

```text
127.0.0.1
```

```bash
# Verify the system resolver works too
getent hosts myapp.local
```

```text
127.0.0.1       myapp.local
```

### Step 5: Test the Full Chain

Now we can use the hostname directly, no `-H` header needed:

```bash
curl -s http://myapp.local/ | python3 -m json.tool
```

```json
{
    "application": "Linux Mastery API",
    "version": "1.0",
    "endpoints": ["/", "/healthz", "/api/hello", "/api/echo"]
}
```

```bash
curl -s http://myapp.local/healthz | python3 -m json.tool
```

```json
{
    "status": "healthy"
}
```

```bash
curl -s "http://myapp.local/api/hello?name=DevOps" | python3 -m json.tool
```

```json
{
    "message": "Hello, DevOps!"
}
```

The full chain works: `curl` resolves `myapp.local` to `127.0.0.1` via dnsmasq, connects to nginx on port 80, nginx proxies to Flask on port 8080, and the response flows back.

---

## Part 4: Verify Health Checks

Health check endpoints are critical infrastructure. Let's verify ours works the way a load balancer would use it.

### Step 1: Test the Health Endpoint

```bash
# Check status code (-o /dev/null discards body, -w prints the code)
curl -s -o /dev/null -w "%{http_code}" http://myapp.local/healthz
```

```text
200
```

A 200 response means the service is healthy. Load balancers typically check this endpoint every few seconds. If it returns anything other than 200, the service is pulled from rotation.

### Step 2: Simulate an Unhealthy Backend

Stop the Flask API:

```bash
# Find and kill the Flask process
pkill -f "python3 app.py"
```

Now test through the proxy:

```bash
curl -s http://myapp.local/healthz
```

```text
<html>
<head><title>502 Bad Gateway</title></head>
...
```

A **502 Bad Gateway** means nginx couldn't connect to the backend. Check the nginx error log:

```bash
tail -3 /var/log/nginx/myapi.error.log
```

```text
2026/02/20 15:10:00 [error] 1234#1234: *15 connect() failed (111: Connection refused) while connecting to upstream, client: 127.0.0.1, server: myapp.local, request: "GET /healthz HTTP/1.1", upstream: "http://127.0.0.1:8080/healthz"
```

The error is clear: "Connection refused" to the upstream at port 8080. The backend is down.

### Step 3: Restart the Backend

```bash
cd /opt/myapi
source venv/bin/activate
nohup python3 app.py > /tmp/myapi.log 2>&1 &
```

Verify recovery:

```bash
curl -s -o /dev/null -w "%{http_code}" http://myapp.local/healthz
```

```text
200
```

The service is healthy again.

---

## Cleanup

When you're done with the lab:

```bash
# Stop the Flask API
pkill -f "python3 app.py"

# If you want to restore the original DNS configuration
# (important on VMs you'll reuse)
sudo systemctl stop dnsmasq
sudo systemctl disable dnsmasq
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo rm -f /etc/systemd/resolved.conf.d/no-stub.conf
sudo systemctl restart systemd-resolved
```

---

## Verification Checklist

After completing this lab, confirm:

- [ ] The Flask API runs and responds on port 8080
- [ ] nginx proxies requests from port 80 to the Flask backend on port 8080
- [ ] The `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto` headers are forwarded to the backend
- [ ] dnsmasq resolves `myapp.local` to `127.0.0.1`
- [ ] `curl http://myapp.local/healthz` returns `{"status": "healthy"}` with HTTP 200
- [ ] Stopping the backend causes nginx to return 502 Bad Gateway
- [ ] You can read nginx error logs to identify a down backend

---

