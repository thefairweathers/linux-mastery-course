---
title: "Lab 12.1: Web Server Setup"
sidebar:
  order: 1
---


> **Objective:** Configure nginx to serve a static site with two virtual hosts on Ubuntu. On Rocky, do the same with the conf.d/ pattern. Add custom access log format. Intentionally break the config and diagnose.
>
> **Concepts practiced:** nginx configuration, server blocks, virtual hosts, access logs, nginx -t, journalctl
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Quick Reference

| Task | Ubuntu | Rocky |
|------|--------|-------|
| Install | `sudo apt install nginx` | `sudo dnf install nginx` |
| Config test | `sudo nginx -t` | `sudo nginx -t` |
| Config structure | `sites-available/` + `sites-enabled/` | `conf.d/` |
| Default docroot | `/var/www/html/` | `/usr/share/nginx/html/` |
| Reload | `sudo systemctl reload nginx` | `sudo systemctl reload nginx` |
| Error log | `/var/log/nginx/error.log` | `/var/log/nginx/error.log` |
| Access log | `/var/log/nginx/access.log` | `/var/log/nginx/access.log` |

---

## Part 1: Ubuntu — Two Virtual Hosts

### Step 1: Install nginx and Verify

If nginx is not yet installed from Week 11's lab, install it now:

```bash
sudo apt update && sudo apt install -y nginx
```

Verify the service is running (remember from Week 11 how we checked service status):

```bash
systemctl is-active nginx
```

```text
active
```

Confirm it responds:

```bash
curl -s http://localhost | head -3
```

You should see the opening lines of the default nginx welcome page.

### Step 2: Create Document Roots for Two Sites

We'll serve two separate static sites from the same nginx instance. This is the fundamental pattern behind shared hosting and multi-application servers.

```bash
# Create directories for both sites
sudo mkdir -p /var/www/site-alpha/html
sudo mkdir -p /var/www/site-beta/html
```

Create the index page for the first site:

```bash
sudo tee /var/www/site-alpha/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Site Alpha</title></head>
<body>
<h1>Welcome to Site Alpha</h1>
<p>Served by nginx on Ubuntu.</p>
</body>
</html>
EOF
```

Create the index page for the second site:

```bash
sudo tee /var/www/site-beta/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Site Beta</title></head>
<body>
<h1>Welcome to Site Beta</h1>
<p>A second virtual host on the same server.</p>
</body>
</html>
EOF
```

Set proper ownership (the nginx worker process runs as `www-data` on Ubuntu):

```bash
sudo chown -R www-data:www-data /var/www/site-alpha
sudo chown -R www-data:www-data /var/www/site-beta
```

### Step 3: Create Virtual Host Configurations

On Ubuntu, nginx uses the `sites-available/` and `sites-enabled/` pattern. You define configurations in `sites-available/`, then create a symlink in `sites-enabled/` to activate them. This makes it easy to disable a site without deleting its configuration.

Create the configuration for Site Alpha:

```bash
sudo tee /etc/nginx/sites-available/site-alpha << 'EOF'
server {
    listen 80;
    server_name site-alpha.local;

    root /var/www/site-alpha/html;
    index index.html;

    access_log /var/log/nginx/site-alpha.access.log;
    error_log  /var/log/nginx/site-alpha.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
```

Create the configuration for Site Beta:

```bash
sudo tee /etc/nginx/sites-available/site-beta << 'EOF'
server {
    listen 80;
    server_name site-beta.local;

    root /var/www/site-beta/html;
    index index.html;

    access_log /var/log/nginx/site-beta.access.log;
    error_log  /var/log/nginx/site-beta.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
```

### Step 4: Enable the Sites

Create symlinks in `sites-enabled/`:

```bash
sudo ln -s /etc/nginx/sites-available/site-alpha /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/site-beta /etc/nginx/sites-enabled/
```

Remove the default site to avoid conflicts:

```bash
sudo rm /etc/nginx/sites-enabled/default
```

### Step 5: Test and Reload

Always test before reloading. This habit will save you in production:

```bash
sudo nginx -t
```

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

If the test passes, reload:

```bash
sudo systemctl reload nginx
```

### Step 6: Verify with curl

Since we don't have real DNS set up yet for these hostnames, use the `-H` flag to send the `Host` header manually. nginx uses this header to route requests to the correct server block:

```bash
curl -s -H "Host: site-alpha.local" http://localhost
```

```text
<!DOCTYPE html>
<html>
<head><title>Site Alpha</title></head>
<body>
<h1>Welcome to Site Alpha</h1>
<p>Served by nginx on Ubuntu.</p>
</body>
</html>
```

```bash
curl -s -H "Host: site-beta.local" http://localhost
```

You should see the Site Beta page. Each request is routed to the correct document root based solely on the `Host` header.

### Step 7: Add a Custom Log Format

nginx ships with the `combined` log format, but you can define custom formats. Let's add one that includes request timing — useful for performance analysis.

Edit the main nginx config to add a custom log format inside the `http` block:

```bash
sudo nano /etc/nginx/nginx.conf
```

Find the `http {` block and add this line after the existing `access_log` directive:

```nginx
    log_format timed '$remote_addr - $remote_user [$time_local] '
                     '"$request" $status $body_bytes_sent '
                     '"$http_referer" "$http_user_agent" '
                     'rt=$request_time';
```

Now update Site Alpha to use the custom format:

```bash
sudo tee /etc/nginx/sites-available/site-alpha << 'EOF'
server {
    listen 80;
    server_name site-alpha.local;

    root /var/www/site-alpha/html;
    index index.html;

    access_log /var/log/nginx/site-alpha.access.log timed;
    error_log  /var/log/nginx/site-alpha.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
```

Note the `timed` at the end of the `access_log` line — that references the custom log format.

Test and reload:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

Make a request and check the log:

```bash
curl -s -H "Host: site-alpha.local" http://localhost > /dev/null
tail -1 /var/log/nginx/site-alpha.access.log
```

```text
127.0.0.1 - - [20/Feb/2026:14:30:22 +0000] "GET / HTTP/1.1" 200 153 "-" "curl/7.81.0" rt=0.000
```

The `rt=0.000` at the end is the request time in seconds. For static files it will be near zero. When you proxy to a backend, this number reveals how long the backend took to respond.

---

## Part 2: Rocky Linux — conf.d/ Pattern

Rocky Linux uses `conf.d/` instead of the `sites-available/sites-enabled` pattern. The concept is the same — each `.conf` file in `/etc/nginx/conf.d/` defines a server block — but there's no enable/disable symlink mechanism. You add a file to activate it, rename or remove it to deactivate.

### Step 1: Install and Start nginx

```bash
sudo dnf install -y nginx
sudo systemctl enable --now nginx
```

If the firewall is active (remember from Week 9), open HTTP:

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

Verify:

```bash
curl -s http://localhost | head -3
```

### Step 2: Create the Document Root and Content

```bash
sudo mkdir -p /var/www/site-alpha/html

sudo tee /var/www/site-alpha/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Site Alpha (Rocky)</title></head>
<body>
<h1>Welcome to Site Alpha</h1>
<p>Served by nginx on Rocky Linux.</p>
</body>
</html>
EOF

sudo chown -R nginx:nginx /var/www/site-alpha
```

Note: On Rocky, the nginx worker runs as the `nginx` user, not `www-data`.

### Step 3: Create the Virtual Host Configuration

```bash
sudo tee /etc/nginx/conf.d/site-alpha.conf << 'EOF'
server {
    listen 80;
    server_name site-alpha.local;

    root /var/www/site-alpha/html;
    index index.html;

    access_log /var/log/nginx/site-alpha.access.log;
    error_log  /var/log/nginx/site-alpha.error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF
```

You may also want to remove the default server block to avoid conflicts. On Rocky, the default server is defined inside `/etc/nginx/nginx.conf` itself. Comment it out or rename it:

```bash
# Back up the original config first
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
```

### Step 4: Test and Reload

```bash
sudo nginx -t && sudo systemctl reload nginx
```

### Step 5: Verify

```bash
curl -s -H "Host: site-alpha.local" http://localhost
```

You should see the Rocky version of Site Alpha.

---

## Part 3: Break It and Fix It

The best way to learn nginx troubleshooting is to intentionally cause failures you'll encounter in real life.

### Scenario 1: Syntax Error

On Ubuntu, introduce a typo in the config:

```bash
sudo nano /etc/nginx/sites-available/site-alpha
```

Remove the semicolon after `index index.html` so the line reads:

```nginx
    index index.html
```

Now test:

```bash
sudo nginx -t
```

```text
nginx: [emerg] directive "location" is not terminated by ";" in /etc/nginx/sites-available/site-alpha:7
nginx: configuration file /etc/nginx/nginx.conf test is failed
```

The error message tells you the file and line number. Fix the semicolon and re-test:

```bash
sudo nginx -t
```

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

### Scenario 2: Wrong Document Root

Point the root to a directory that doesn't exist:

```bash
sudo sed -i 's|root /var/www/site-alpha/html;|root /var/www/nonexistent;|' /etc/nginx/sites-available/site-alpha
sudo nginx -t && sudo systemctl reload nginx
```

Note that `nginx -t` passes — nginx doesn't verify that document roots exist. But when you request the page:

```bash
curl -s -H "Host: site-alpha.local" http://localhost
```

```text
<html>
<head><title>404 Not Found</title></head>
...
```

Check the error log:

```bash
tail -5 /var/log/nginx/site-alpha.error.log
```

```text
2026/02/20 14:35:10 [error] 1234#1234: *5 "/var/www/nonexistent/index.html" is not found (2: No such file or directory)
```

The log clearly shows the missing path. Fix it by restoring the correct root path and reloading.

### Scenario 3: Permission Denied

```bash
# Restore the correct root first
sudo sed -i 's|root /var/www/nonexistent;|root /var/www/site-alpha/html;|' /etc/nginx/sites-available/site-alpha
sudo systemctl reload nginx

# Now remove read permissions
sudo chmod 000 /var/www/site-alpha/html/index.html

curl -s -H "Host: site-alpha.local" http://localhost
```

```text
<html>
<head><title>403 Forbidden</title></head>
...
```

Check the error log:

```bash
tail -3 /var/log/nginx/site-alpha.error.log
```

```text
2026/02/20 14:36:00 [error] 1234#1234: *7 open() "/var/www/site-alpha/html/index.html" failed (13: Permission denied)
```

Fix it (remember from Week 5 how we set permissions):

```bash
sudo chmod 644 /var/www/site-alpha/html/index.html
```

Verify:

```bash
curl -s -H "Host: site-alpha.local" http://localhost | head -3
```

---

## Verification Checklist

After completing this lab, confirm:

- [ ] You can serve two different sites from one nginx instance using virtual hosts
- [ ] You understand the difference between Ubuntu's `sites-available/sites-enabled` and Rocky's `conf.d/`
- [ ] You always run `nginx -t` before reloading
- [ ] You can read nginx error logs to diagnose 403 and 404 errors
- [ ] You can define and use a custom log format
- [ ] You know where to look when nginx returns an unexpected error

---

