# Week 12: Web Servers, DNS & Service Infrastructure

> **Goal:** Configure and run nginx as a web server and reverse proxy, set up local DNS resolution, and serve a backend API through a reverse proxy.

[← Previous Week](../week-11/README.md) · [Next Week →](../week-13/README.md)

---

## Table of Contents

| Section | Topic |
|---------|-------|
| 12.1 | [The Role of Web Servers](#121-the-role-of-web-servers) |
| 12.2 | [nginx Architecture](#122-nginx-architecture) |
| 12.3 | [Installing nginx](#123-installing-nginx) |
| 12.4 | [nginx Configuration Structure](#124-nginx-configuration-structure) |
| 12.5 | [Serving Static Content](#125-serving-static-content) |
| 12.6 | [Virtual Hosts / Server Blocks](#126-virtual-hosts--server-blocks) |
| 12.7 | [Reverse Proxy Configuration](#127-reverse-proxy-configuration) |
| 12.8 | [Running a Simple Backend](#128-running-a-simple-backend) |
| 12.9 | [API Patterns](#129-api-patterns) |
| 12.10 | [Common nginx Directives](#1210-common-nginx-directives) |
| 12.11 | [Testing and Reloading Configuration](#1211-testing-and-reloading-configuration) |
| 12.12 | [DNS Concepts Deep Dive](#1212-dns-concepts-deep-dive) |
| 12.13 | [Setting Up dnsmasq for Local DNS](#1213-setting-up-dnsmasq-for-local-dns) |
| 12.14 | [TLS/HTTPS Concepts](#1214-tlshttps-concepts) |
| 12.15 | [Configuring TLS in nginx](#1215-configuring-tls-in-nginx) |
| 12.16 | [Access Logs and Error Logs](#1216-access-logs-and-error-logs) |
| 12.17 | [HTTP Status Codes](#1217-http-status-codes) |
| 12.18 | [Health Check Endpoints](#1218-health-check-endpoints) |

---

## 12.1 The Role of Web Servers

A **web server** sits between the internet and your application. When someone requests a URL, the web server handles it first. It has four core responsibilities:

**Serving static files.** HTML, CSS, JavaScript, images — anything that doesn't change per request. The web server reads from disk and sends directly to the client, no application code involved.

**Reverse proxying to application backends.** Your Python, Node, or Go application shouldn't face the internet directly. A reverse proxy sits in front, handling concurrent connections, and forwards requests to your application.

**TLS termination.** The web server handles the HTTPS handshake, managing certificates and cipher suites. Your application receives plain HTTP on the backend.

**Load balancing.** When one backend isn't enough, the web server distributes requests across multiple instances, routing around failures automatically.

In this course, we focus on serving static files and reverse proxying — the skills you'll use most often as a Linux administrator.

---

## 12.2 nginx Architecture

**nginx** (pronounced "engine-x") powers roughly a third of all websites on the internet. We focus on it rather than Apache because its configuration model is cleaner and its architecture maps well to modern deployment patterns.

### Master Process and Worker Processes

nginx uses a multi-process architecture:

```text
┌─────────────────────────────────┐
│     Master Process (root)       │
│     - Reads configuration       │
│     - Manages worker processes  │
│     - Binds to privileged ports │
└──────────┬──────────────────────┘
           │ fork
     ┌─────┼──────┐
     ▼     ▼      ▼
┌────────┐ ┌────────┐ ┌────────┐
│Worker 1│ │Worker 2│ │Worker N│
│(nobody)│ │(nobody)│ │(nobody)│
└────────┘ └────────┘ └────────┘
```

The **master process** runs as root, reads configuration, binds to privileged ports (80, 443), and spawns workers. The **worker processes** run as an unprivileged user (`www-data` on Ubuntu, `nginx` on Rocky) and handle all client connections.

### Event-Driven Model

Traditional web servers assigned one thread per connection — 10,000 clients meant 10,000 threads. nginx uses an **event-driven** model instead. Each worker runs a single-threaded event loop using `epoll` on Linux, handling thousands of connections simultaneously. When a connection is waiting for I/O, the worker services other ready connections. This is why a single nginx worker handles thousands of concurrent connections with minimal memory.

### Seeing nginx Processes

```bash
ps aux | grep nginx
```

```text
root      1234  0.0  0.1  4576  1520 ?  Ss  14:00  0:00 nginx: master process /usr/sbin/nginx
www-data  1235  0.0  0.2  5100  2340 ?  S   14:00  0:00 nginx: worker process
www-data  1236  0.0  0.2  5100  2340 ?  S   14:00  0:00 nginx: worker process
```

---

## 12.3 Installing nginx

| Task | Ubuntu | Rocky |
|------|--------|-------|
| Install | `sudo apt update && sudo apt install -y nginx` | `sudo dnf install -y nginx` |
| Enable + start | `sudo systemctl enable --now nginx` | `sudo systemctl enable --now nginx` |
| Open firewall | Not needed (ufw disabled by default) | `sudo firewall-cmd --permanent --add-service=http && sudo firewall-cmd --reload` |

On Ubuntu, nginx is typically started and enabled automatically after installation. On Rocky, you need to be explicit.

### Verify the Installation

```bash
systemctl status nginx
curl -s http://localhost | head -5
```

```text
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
```

If you see "Connection refused," check the service status. If there's no output, check firewall rules (remember from Week 9 how we managed firewall-cmd and ufw).

```bash
nginx -v
```

```text
nginx version: nginx/1.24.0 (Ubuntu)
```

---

## 12.4 nginx Configuration Structure

nginx configuration is a hierarchy of directives organized into contexts (blocks). Every nginx problem you'll ever debug comes down to a directive being in the wrong context or having the wrong value.

### The Main Configuration File

```nginx
# /etc/nginx/nginx.conf — simplified structure
user www-data;
worker_processes auto;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    sendfile on;
    keepalive_timeout 65;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;

    server {
        listen 80;
        server_name example.com;

        location / {
            root /var/www/html;
            index index.html;
        }
    }
}
```

### Context Hierarchy

Directives inherit from parent contexts and can be overridden in child contexts:

```text
Main Context
 └── events { }         — Connection handling settings
 └── http { }           — HTTP protocol settings
      └── server { }    — Virtual host (one per site)
           └── location { }  — URI-specific behavior
```

### Ubuntu vs Rocky Configuration Layout

| Aspect | Ubuntu | Rocky |
|--------|--------|-------|
| Main config | `/etc/nginx/nginx.conf` | `/etc/nginx/nginx.conf` |
| Site configs | `/etc/nginx/sites-available/` + `/etc/nginx/sites-enabled/` | `/etc/nginx/conf.d/` |
| Enable a site | `ln -s sites-available/mysite sites-enabled/` | Place `mysite.conf` in `conf.d/` |
| Disable a site | `rm sites-enabled/mysite` | Rename to `mysite.conf.disabled` |
| Default docroot | `/var/www/html/` | `/usr/share/nginx/html/` |
| Worker user | `www-data` | `nginx` |

On Ubuntu, the `sites-available/sites-enabled` pattern separates "defined" from "active" configurations. On Rocky, `conf.d/` is simpler — every `.conf` file in the directory is automatically included. Both achieve the same result.

---

## 12.5 Serving Static Content

### The Fundamentals: root, index, and try_files

```nginx
server {
    listen 80;
    server_name mysite.local;

    root /var/www/mysite;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

**`root`** defines the base directory. A request for `/about.html` maps to `{root}/about.html`.

**`index`** specifies which file to serve when a directory is requested. A request for `/` tries `/index.html`, then `/index.htm`.

**`try_files`** tries paths in order and uses the first one that exists:
1. `$uri` — the exact path as a file
2. `$uri/` — the path as a directory (triggering the `index` directive)
3. `=404` — return a 404 if nothing matches

### Location Blocks

**Location blocks** match request URIs and apply specific configuration:

```nginx
# Exact match — only /favicon.ico
location = /favicon.ico {
    log_not_found off;
    access_log off;
}

# Prefix match — anything under /images/
location /images/ {
    root /var/www/static;
}

# Case-insensitive regex — image file extensions
location ~* \.(jpg|jpeg|png|gif|ico)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

nginx evaluates locations in this priority order:
1. Exact matches (`=`) — checked first, used immediately if matched
2. Preferential prefix (`^~`) — stops regex evaluation if matched
3. Regular expressions (`~` and `~*`) — checked in order of appearance
4. Standard prefix (no modifier) — longest match wins

### Practical Static Site Configuration

```nginx
server {
    listen 80;
    server_name mysite.local;

    root /var/www/mysite;
    index index.html;

    # Static assets — long cache, no access logging
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public";
        access_log off;
    }

    location / {
        try_files $uri $uri/ =404;
    }
}
```

---

## 12.6 Virtual Hosts / Server Blocks

A single nginx instance can serve dozens of websites. Each gets its own **server block** (what Apache calls a "virtual host"). nginx uses the `Host` header to route requests to the correct block.

### How Server Block Selection Works

1. nginx reads the `Host` header from the request
2. Compares it against `server_name` in each server block
3. Routes to the matching block — or the **default server** if nothing matches

```nginx
# Catch-all default server — rejects unmatched requests
server {
    listen 80 default_server;
    server_name _;
    return 444;  # Close connection without response
}
```

### Hosting Two Sites on One Server

```nginx
server {
    listen 80;
    server_name alpha.example.com;
    root /var/www/alpha;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

server {
    listen 80;
    server_name beta.example.com;
    root /var/www/beta;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

Both listen on port 80 and share the same IP. The `Host` header is the differentiator. This is the foundation of shared hosting.

### Server Name Matching

```nginx
server_name example.com;                    # Exact name
server_name example.com www.example.com;    # Multiple names
server_name *.example.com;                  # Leading wildcard
server_name ~^(?<sub>.+)\.example\.com$;    # Regular expression
```

Exact names are fastest. Use them unless you need wildcards.

---

## 12.7 Reverse Proxy Configuration

A **reverse proxy** sits in front of backend servers, forwarding client requests and returning responses. The client never communicates directly with the backend. Even with a single backend, the proxy provides connection buffering, TLS termination, logging, and access control.

### Basic proxy_pass

```nginx
server {
    listen 80;
    server_name api.example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
```

### Forwarding Client Information

Without explicit headers, the backend sees nginx's IP as the client. Fix this with `proxy_set_header`:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;

    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

| Header | Purpose |
|--------|---------|
| `Host` | The hostname from the original request |
| `X-Real-IP` | The client's actual IP address |
| `X-Forwarded-For` | Appends client IP to the proxy chain |
| `X-Forwarded-Proto` | `http` or `https` — so the backend knows if TLS was used |

Memorize these four headers — you'll configure them on every reverse proxy you build.

### Proxy Timeouts

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_connect_timeout  5s;   # Time to establish connection with backend
    proxy_send_timeout     10s;  # Time to send request to backend
    proxy_read_timeout     30s;  # Time to read response from backend
}
```

If the backend exceeds `proxy_read_timeout`, nginx returns a 504 Gateway Timeout.

### Proxying Specific Paths

A common pattern — serve static files directly, proxy only API requests:

```nginx
server {
    listen 80;
    server_name myapp.example.com;

    location /static/ {
        root /var/www/myapp;
        expires 7d;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        root /var/www/myapp;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## 12.8 Running a Simple Backend

Let's put the reverse proxy into practice with a real application.

### Install Python3

| Task | Ubuntu | Rocky |
|------|--------|-------|
| Install | `sudo apt install -y python3 python3-pip python3-venv` | `sudo dnf install -y python3 python3-pip` |

### The Flask API

The course provides a minimal Flask application in `labs/app.py`. It returns JSON responses, has a health check endpoint, and doesn't touch a database. In Week 13, we'll evolve this app by adding PostgreSQL.

```python
@app.route("/healthz")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/api/hello")
def hello():
    name = request.args.get("name", "World")
    return jsonify({"message": f"Hello, {name}!"})
```

### Set Up and Test

```bash
sudo mkdir -p /opt/myapi
sudo chown "$USER":"$USER" /opt/myapi
cp labs/app.py /opt/myapi/
cp labs/requirements.txt /opt/myapi/

cd /opt/myapi
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python3 app.py
```

In another terminal:

```bash
curl -s http://localhost:8080/ | python3 -m json.tool
```

```json
{
    "application": "Linux Mastery API",
    "version": "1.0",
    "endpoints": ["/", "/healthz", "/api/hello", "/api/echo"]
}
```

### Configure the nginx Proxy

```bash
sudo tee /etc/nginx/sites-available/myapi << 'EOF'
server {
    listen 80;
    server_name myapp.local;

    access_log /var/log/nginx/myapi.access.log;
    error_log  /var/log/nginx/myapi.error.log;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/myapi /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

On Rocky, place the same config in `/etc/nginx/conf.d/myapi.conf` — no symlink needed.

Test through the proxy:

```bash
curl -s -H "Host: myapp.local" http://localhost/api/headers | python3 -m json.tool
```

You should see `X-Real-IP`, `X-Forwarded-For`, and `X-Forwarded-Proto` in the output, proving nginx forwards client information to the backend.

---

## 12.9 API Patterns

### RESTful Endpoints

**REST** (Representational State Transfer) uses HTTP methods to indicate actions and URL paths to identify resources:

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/users` | List all users |
| `GET` | `/api/users/42` | Get user with ID 42 |
| `POST` | `/api/users` | Create a new user |
| `PUT` | `/api/users/42` | Replace user 42 |
| `DELETE` | `/api/users/42` | Delete user 42 |

### JSON Response Conventions

Consistent response structure makes APIs predictable:

```json
{"data": {"id": 42, "name": "Alice"}, "error": null}
```

Error responses include a message and appropriate status code:

```json
{"data": null, "error": "User not found"}
```

### Testing APIs with curl

```bash
# GET request
curl -s http://localhost:8080/api/hello | python3 -m json.tool

# POST with JSON body
curl -s -X POST -H "Content-Type: application/json" \
    -d '{"name": "Alice"}' \
    http://localhost:8080/api/echo | python3 -m json.tool

# Show response headers and status code
curl -si http://localhost:8080/healthz
```

---

## 12.10 Common nginx Directives

### Core Directives

| Directive | Context | Purpose | Example |
|-----------|---------|---------|---------|
| `worker_processes` | main | Number of worker processes | `worker_processes auto;` |
| `worker_connections` | events | Max connections per worker | `worker_connections 1024;` |
| `include` | any | Include another config file | `include /etc/nginx/conf.d/*.conf;` |

### HTTP Directives

| Directive | Context | Purpose | Example |
|-----------|---------|---------|---------|
| `listen` | server | Port and flags | `listen 80;` or `listen 443 ssl;` |
| `server_name` | server | Hostname(s) for this block | `server_name example.com;` |
| `root` | http, server, location | Document root | `root /var/www/html;` |
| `index` | http, server, location | Default file for directories | `index index.html;` |
| `try_files` | server, location | Try paths in order | `try_files $uri $uri/ =404;` |
| `access_log` | http, server, location | Access log path + format | `access_log /var/log/nginx/access.log;` |
| `sendfile` | http, server, location | Efficient file transfer | `sendfile on;` |
| `gzip` | http, server, location | Response compression | `gzip on;` |
| `client_max_body_size` | http, server, location | Max upload size | `client_max_body_size 10m;` |

### Proxy Directives

| Directive | Context | Purpose | Example |
|-----------|---------|---------|---------|
| `proxy_pass` | location | Forward to backend | `proxy_pass http://127.0.0.1:8080;` |
| `proxy_set_header` | http, server, location | Set headers for backend | `proxy_set_header Host $host;` |
| `proxy_connect_timeout` | http, server, location | Backend connection timeout | `proxy_connect_timeout 5s;` |
| `proxy_read_timeout` | http, server, location | Backend response timeout | `proxy_read_timeout 30s;` |
| `proxy_buffering` | http, server, location | Buffer backend responses | `proxy_buffering on;` |

---

## 12.11 Testing and Reloading Configuration

**Never reload nginx without testing first.** This habit will save you in production.

```bash
# Step 1: Test the configuration
sudo nginx -t
```

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

```bash
# Step 2: Reload only if the test passed
sudo systemctl reload nginx
```

If the test fails, read the error — it includes the file, line number, and the problem:

```text
nginx: [emerg] unknown directive "proxypass" in /etc/nginx/sites-enabled/myapi:8
```

### reload vs restart

Remember from Week 11 the difference between reload and restart:

- **`reload`** — Workers finish current requests, then new workers start with the new config. Zero-downtime.
- **`restart`** — All processes stop and restart. Active connections are dropped.

Always reload for config changes. Restart only when upgrading the nginx binary.

### The Production One-Liner

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Make this muscle memory.

---

## 12.12 DNS Concepts Deep Dive

You used DNS in Week 9 with `dig` and `/etc/resolv.conf`. Now let's go deeper.

### How DNS Resolution Works

```text
1. Browser checks its cache
2. OS checks /etc/hosts
3. OS queries the resolver from /etc/resolv.conf
4. Resolver queries root nameservers → "Who handles .com?"
5. .com TLD nameservers → "Who handles example.com?"
6. example.com's authoritative nameservers → returns the IP address
7. IP is cached at each level based on the TTL
```

This is **recursive resolution** — your configured resolver handles the chain of queries for you.

### DNS Record Types

| Type | Name | Purpose | Example |
|------|------|---------|---------|
| `A` | Address | Hostname to IPv4 | `www  A  93.184.216.34` |
| `AAAA` | Quad-A | Hostname to IPv6 | `www  AAAA  2606:2800:220:1:...` |
| `CNAME` | Canonical Name | Alias to another name | `blog  CNAME  www.example.com` |
| `MX` | Mail Exchange | Mail delivery target | `@  MX  10 mail.example.com` |
| `NS` | Nameserver | Authoritative DNS servers | `@  NS  ns1.example.com` |
| `SOA` | Start of Authority | Zone metadata, serial number | Required at zone root |
| `TXT` | Text | SPF, DKIM, domain verification | `@  TXT  "v=spf1 ..."` |
| `SRV` | Service | Service discovery (port, priority) | `_sip._tcp  SRV  ...` |
| `PTR` | Pointer | Reverse DNS (IP to hostname) | `34  PTR  www.example.com` |

### TTL (Time to Live)

Every DNS record has a **TTL** — seconds that resolvers cache the record before re-querying:

| TTL | Duration | Use Case |
|-----|----------|----------|
| 300 | 5 minutes | During migrations |
| 3600 | 1 hour | Standard records |
| 86400 | 1 day | Stable records (MX, NS) |

Before migrating a service, lower the TTL to 300 well in advance (at least 24 hours before). After migration, raise it back.

### Querying DNS Records

```bash
dig example.com A +short           # A record
dig example.com MX +short          # MX records
dig @8.8.8.8 example.com A         # Query a specific nameserver
dig +trace example.com             # Trace the full resolution path
```

---

## 12.13 Setting Up dnsmasq for Local DNS

In development, you often need hostnames to resolve locally. **dnsmasq** is a lightweight DNS server perfect for this.

### Install dnsmasq

| Distro | Command |
|--------|---------|
| Ubuntu | `sudo apt install -y dnsmasq` |
| Rocky | `sudo dnf install -y dnsmasq` |

On Ubuntu, dnsmasq may conflict with systemd-resolved on port 53. See Lab 12.2 for the workaround.

### Configure Local Domains

```bash
sudo tee /etc/dnsmasq.d/local-dev.conf << 'EOF'
address=/myapp.local/127.0.0.1
address=/api.local/127.0.0.1

# Forward everything else to public DNS
server=8.8.8.8
server=8.8.4.4
EOF

sudo systemctl restart dnsmasq
```

### Test It

```bash
dig myapp.local @127.0.0.1 +short
```

```text
127.0.0.1
```

### dnsmasq vs /etc/hosts

| Feature | `/etc/hosts` | dnsmasq |
|---------|-------------|---------|
| Wildcard domains | No | Yes |
| DNS caching | No | Yes |
| Forwarding | No | Yes |
| Serves the network | No | Yes |
| Configuration complexity | One line per hostname | Rich config with zones |

For one or two hostnames, `/etc/hosts` is fine. For a development environment with many services, use dnsmasq.

---

## 12.14 TLS/HTTPS Concepts

Every production web service runs over HTTPS. Let's understand what's happening before we configure it.

### What TLS Provides

**TLS** (Transport Layer Security) delivers three guarantees:

1. **Encryption** — Traffic between client and server is encrypted
2. **Authentication** — The server proves its identity via a certificate
3. **Integrity** — Data cannot be modified in transit without detection

TLS is the successor to **SSL**. You'll hear "SSL" used casually, but the actual protocol is TLS.

### Certificates and Certificate Authorities

A **TLS certificate** binds a domain name to a public key, signed by a **Certificate Authority (CA)**. When your browser connects, it verifies the certificate is valid for that domain, issued by a trusted CA, not expired, and not revoked.

### Let's Encrypt

**Let's Encrypt** is a free, automated CA trusted by all major browsers. The workflow:

1. Install `certbot`
2. Run `certbot --nginx` (modifies your nginx config automatically)
3. Certificates last 90 days with automatic renewal

We won't run certbot in the lab (it requires a public domain), but you should know this is the standard for production TLS.

### The TLS Handshake

```text
Client                                   Server
  │──── ClientHello (supported ciphers) ──►│
  │◄─── ServerHello + Certificate ────────│
  │──── ClientKeyExchange ────────────────►│
  │◄═══ Encrypted HTTP traffic ═══════════►│
```

With TLS 1.3, the handshake completes in a single round trip. After that, all HTTP data is encrypted.

---

## 12.15 Configuring TLS in nginx

In production, use Let's Encrypt. For learning, we'll use a **self-signed certificate**.

### Generate a Self-Signed Certificate

```bash
sudo mkdir -p /etc/nginx/ssl

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/selfsigned.key \
    -out /etc/nginx/ssl/selfsigned.crt \
    -subj "/C=US/ST=State/L=City/O=Lab/CN=myapp.local"
```

### Configure nginx for HTTPS

```nginx
server {
    listen 443 ssl;
    server_name myapp.local;

    ssl_certificate     /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name myapp.local;
    return 301 https://$host$request_uri;
}
```

Test with curl (`-k` skips certificate verification for self-signed certs):

```bash
curl -sk https://myapp.local/healthz | python3 -m json.tool
```

### Key TLS Directives

| Directive | Purpose |
|-----------|---------|
| `ssl_certificate` | Path to the certificate file |
| `ssl_certificate_key` | Path to the private key |
| `ssl_protocols` | Allowed TLS versions (disable TLSv1.0 and 1.1) |
| `ssl_ciphers` | Allowed cipher suites |
| `ssl_prefer_server_ciphers` | Server chooses the cipher, not the client |
| `ssl_session_cache` | Cache TLS sessions for performance |

---

## 12.16 Access Logs and Error Logs

nginx logs are your primary debugging tool. When something goes wrong, the logs tell you what happened.

### Access Log

Every request is written to the access log. The default `combined` format:

```text
192.168.1.50 - - [20/Feb/2026:14:30:22 +0000] "GET /api/hello HTTP/1.1" 200 32 "-" "curl/7.81.0"
```

| Field | Variable | Meaning |
|-------|----------|---------|
| Client IP | `$remote_addr` | `192.168.1.50` |
| Timestamp | `$time_local` | `[20/Feb/2026:14:30:22 +0000]` |
| Request | `$request` | `"GET /api/hello HTTP/1.1"` |
| Status | `$status` | `200` |
| Body size | `$body_bytes_sent` | `32` |
| User agent | `$http_user_agent` | `"curl/7.81.0"` |

### Custom Log Formats

```nginx
log_format proxy '$remote_addr [$time_local] "$request" $status '
                 'upstream=$upstream_addr rt=$request_time '
                 'uct=$upstream_connect_time urt=$upstream_response_time';
```

The `$upstream_response_time` is especially useful — it reveals how long the backend took to respond.

### Error Log

```text
2026/02/20 14:35:10 [error] 1234#1234: *5 connect() failed (111: Connection refused) while connecting to upstream
```

Error log levels (most to least verbose): `debug`, `info`, `notice`, `warn`, `error` (default), `crit`, `alert`, `emerg`.

### Useful Log Analysis

```bash
# Count requests by status code
awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn

# Find the most requested paths
awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10

# Find all 5xx errors
awk '$9 ~ /^5/' /var/log/nginx/access.log

# Monitor logs in real time (remember tail -f from Week 5)
tail -f /var/log/nginx/access.log
```

---

## 12.17 HTTP Status Codes

Every HTTP response includes a status code. When debugging, the status code is your first clue.

| Code | Name | Meaning | Common Cause |
|------|------|---------|--------------|
| **2xx** | **Success** | | |
| 200 | OK | Request succeeded | Normal response |
| 201 | Created | Resource created | Successful POST |
| 204 | No Content | Success, no body | Successful DELETE |
| **3xx** | **Redirection** | | |
| 301 | Moved Permanently | New permanent URL | HTTP-to-HTTPS redirect |
| 302 | Found | Temporary redirect | Login redirects |
| **4xx** | **Client Error** | | |
| 400 | Bad Request | Malformed request | Invalid JSON, missing fields |
| 401 | Unauthorized | Authentication required | Missing credentials |
| 403 | Forbidden | Access denied | File permissions wrong |
| 404 | Not Found | Resource doesn't exist | Wrong URL, typo in path |
| 405 | Method Not Allowed | Wrong HTTP method | POST to a GET-only endpoint |
| 413 | Content Too Large | Body exceeds limit | Exceeds `client_max_body_size` |
| **5xx** | **Server Error** | | |
| 500 | Internal Server Error | Application crashed | Unhandled exception |
| 502 | Bad Gateway | Can't reach backend | Backend is down |
| 503 | Service Unavailable | Overloaded/maintenance | Too many connections |
| 504 | Gateway Timeout | Backend too slow | Slow query, hung process |

### Troubleshooting the Common Ones

**502 Bad Gateway** — nginx can't connect to the backend:

```bash
systemctl status myapi                    # Is the backend running?
ss -tlnp | grep 8080                      # Is anything listening?
curl http://127.0.0.1:8080/               # Can you reach it directly?
tail -20 /var/log/nginx/error.log         # What does nginx say?
```

**403 Forbidden** — nginx found the file but can't read it:

```bash
ls -la /var/www/mysite/                   # Check file permissions
namei -l /var/www/mysite/index.html       # Check every directory in the path
```

**504 Gateway Timeout** — backend connected but didn't respond in time:

```bash
tail -20 /var/log/nginx/error.log         # Confirms "upstream timed out"
# Check application logs for slow queries or hung processes
```

---

## 12.18 Health Check Endpoints

Every service behind a reverse proxy or load balancer needs health check endpoints. This is the mechanism that keeps infrastructure self-healing.

### Why Health Checks Matter

Without health checks, a crashed backend continues to receive traffic. Users see errors, and nobody knows until a human checks. With health checks, the load balancer probes every few seconds and removes failed backends from rotation automatically.

### The Two Endpoints

**`/healthz`** — Liveness check. "Is the process alive?" Returns 200 if the application is responsive. Should not check dependencies.

```python
@app.route("/healthz")
def health():
    return jsonify({"status": "healthy"}), 200
```

**`/ready`** — Readiness check. "Can this service handle traffic?" Checks dependencies like database connections. Returns 503 if not ready.

```python
@app.route("/ready")
def ready():
    try:
        db.session.execute("SELECT 1")
        return jsonify({"status": "ready"}), 200
    except Exception:
        return jsonify({"status": "not ready"}), 503
```

The distinction matters in container orchestration: a failed liveness probe restarts the container; a failed readiness probe stops routing traffic but doesn't restart.

Our Flask API already includes `/healthz`. In Week 13, when we add a database, we'll add `/ready` to verify the database connection.

---

## What's Next

You now have a working web server, a Flask API behind a reverse proxy, and local DNS resolution. This is the foundation of the three-tier application stack:

```text
Week 12 (this week):     nginx (reverse proxy) + Flask API
Week 13 (next week):     + PostgreSQL database
Weeks 14-15:             Scripting and automation
Week 16:                 Containerize the entire stack with Docker
Week 17:                 Deploy with Docker Compose + backups
```

In Week 13, we'll add a PostgreSQL database to this stack — turning our nginx + API setup into a real three-tier application. The Flask app from `labs/app.py` will evolve to include database models, migrations, and CRUD endpoints. The nginx configuration you wrote this week will continue to work without changes.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 12.1: Web Server Setup](labs/lab_01_web_server_setup.md)** — Configure nginx to serve static sites with virtual hosts, custom logs, and troubleshooting
- **[Lab 12.2: Reverse Proxy & DNS](labs/lab_02_reverse_proxy_and_dns.md)** — Run a Flask API behind nginx as a reverse proxy with local DNS via dnsmasq

---

## Checklist

Before moving to Week 13, confirm you can:

- [ ] Install and start nginx on both Ubuntu and Rocky Linux
- [ ] Configure nginx to serve static files from a document root
- [ ] Set up multiple virtual hosts (server blocks) on one nginx instance
- [ ] Configure nginx as a reverse proxy to a backend application
- [ ] Test nginx configuration with nginx -t before reloading
- [ ] Read and interpret nginx access and error logs
- [ ] Explain the most common HTTP status codes and their causes
- [ ] Set up dnsmasq for local DNS resolution
- [ ] Explain TLS/HTTPS concepts: certificates, CAs, and the handshake
- [ ] Implement a /healthz endpoint in a web application
- [ ] Troubleshoot common nginx errors (502, 403, config syntax)

---

[← Previous Week](../week-11/README.md) · [Next Week →](../week-13/README.md)
