---
title: "Lab 11.1: Service Management"
sidebar:
  order: 1
---


> **Objective:** Install and manage a web server: nginx on Ubuntu, httpd on Rocky. Start, stop, enable, intentionally break the config, read error logs with journalctl, and fix it.
>
> **Concepts practiced:** systemctl, journalctl, nginx/httpd configuration, service troubleshooting
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Quick Reference

| Task | Ubuntu (nginx) | Rocky (httpd) |
|------|---------------|---------------|
| Install | `sudo apt install nginx` | `sudo dnf install httpd` |
| Service name | `nginx.service` | `httpd.service` |
| Config file | `/etc/nginx/nginx.conf` | `/etc/httpd/conf/httpd.conf` |
| Config test | `sudo nginx -t` | `sudo httpd -t` |
| Default page | `/var/www/html/` | `/var/www/html/` |
| Error log | `journalctl -u nginx` | `journalctl -u httpd` |

---

## Part 1: Ubuntu (nginx)

### Step 1: Install nginx

```bash
sudo apt update && sudo apt install -y nginx
```

Verify the package installed:

```bash
dpkg -l nginx | grep nginx
```

### Step 2: Start and Enable the Service

On Ubuntu, nginx is usually started and enabled automatically after installation. Let's verify and be explicit:

```bash
# Check the current state
systemctl status nginx
```

If it's not running:

```bash
sudo systemctl enable --now nginx
```

Verify both the runtime state and the boot configuration:

```bash
systemctl is-active nginx
```

```text
active
```

```bash
systemctl is-enabled nginx
```

```text
enabled
```

### Step 3: Verify It Works

```bash
curl -s http://localhost | head -5
```

You should see HTML output from the default nginx welcome page.

### Step 4: Explore the Status Output

```bash
systemctl status nginx
```

Take a moment to identify each piece of information from Section 11.4 of the README:

- The loaded path and enabled state
- The active state and uptime
- The main PID and process tree
- The memory usage
- The recent log lines at the bottom

### Step 5: Practice Stop, Start, Restart, Reload

```bash
# Stop nginx
sudo systemctl stop nginx

# Verify it's stopped
systemctl is-active nginx
# Expected: inactive

# Verify the page is unreachable
curl -s http://localhost
# Expected: Connection refused

# Start it again
sudo systemctl start nginx

# Reload configuration (no downtime)
sudo systemctl reload nginx

# Restart (brief downtime)
sudo systemctl restart nginx
```

### Step 6: Intentionally Break the Configuration

Now let's introduce a syntax error and practice diagnosing it with journalctl.

First, back up the config:

```bash
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
```

Introduce a deliberate error — remove the semicolon from a directive:

```bash
sudo sed -i 's/worker_connections 768;/worker_connections 768/' /etc/nginx/nginx.conf
```

Verify the config is broken:

```bash
sudo nginx -t
```

```text
nginx: [emerg] directive "worker_connections" is not terminated by ";" in /etc/nginx/nginx.conf:14
nginx: configuration file /etc/nginx/nginx.conf test failed
```

### Step 7: Try to Reload — Watch It Fail

```bash
sudo systemctl reload nginx
```

Check the status:

```bash
systemctl status nginx
```

Note: `reload` may succeed or fail depending on how nginx handles the signal. Let's try a full restart to see a clear failure:

```bash
sudo systemctl restart nginx
```

```bash
systemctl status nginx
```

You should see the service in a **failed** state with error details.

### Step 8: Diagnose with journalctl

```bash
# View recent nginx logs
journalctl -u nginx -n 20 --no-pager
```

```bash
# View only error-level messages
journalctl -u nginx -p err -n 10 --no-pager
```

You should see the configuration error message pointing to the exact file and line number.

### Step 9: Fix and Recover

Restore the backup:

```bash
sudo cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
```

Verify the config is valid:

```bash
sudo nginx -t
```

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Start the service:

```bash
sudo systemctl start nginx
systemctl status nginx
```

Verify the web page works:

```bash
curl -s http://localhost | head -5
```

---

## Part 2: Rocky (httpd)

### Step 1: Install httpd

```bash
sudo dnf install -y httpd
```

Unlike Ubuntu's nginx, httpd on Rocky is **not** started or enabled after installation.

```bash
systemctl is-active httpd
```

```text
inactive
```

```bash
systemctl is-enabled httpd
```

```text
disabled
```

### Step 2: Start and Enable the Service

```bash
sudo systemctl enable --now httpd
```

```bash
systemctl is-active httpd
```

```text
active
```

```bash
systemctl is-enabled httpd
```

```text
enabled
```

### Step 3: Open the Firewall (if needed)

Rocky Linux has `firewalld` enabled by default, which may block port 80:

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

### Step 4: Verify It Works

```bash
curl -s http://localhost | head -5
```

You should see the default Rocky/CentOS test page HTML.

### Step 5: Explore the Status Output

```bash
systemctl status httpd
```

Compare the output with what you saw for nginx on Ubuntu. The format is identical because both use systemctl — only the service name and details differ.

### Step 6: Intentionally Break the Configuration

Back up the config:

```bash
sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
```

Add a bad directive:

```bash
echo "InvalidDirective broken" | sudo tee -a /etc/httpd/conf/httpd.conf
```

Test the config:

```bash
sudo httpd -t
```

```text
AH00526: Syntax error on line 358 of /etc/httpd/conf/httpd.conf:
Invalid command 'InvalidDirective', perhaps misspelled or defined by a module not included in the server configuration
```

### Step 7: Try to Restart — Watch It Fail

```bash
sudo systemctl restart httpd
```

```bash
systemctl status httpd
```

The service should be in a failed state.

### Step 8: Diagnose with journalctl

```bash
journalctl -u httpd -n 20 --no-pager
```

```bash
journalctl -u httpd -p err -n 10 --no-pager
```

The error message will point to the exact line with the invalid directive.

### Step 9: Fix and Recover

Restore the backup:

```bash
sudo cp /etc/httpd/conf/httpd.conf.bak /etc/httpd/conf/httpd.conf
```

Verify:

```bash
sudo httpd -t
```

```text
Syntax OK
```

Start the service:

```bash
sudo systemctl start httpd
systemctl status httpd
```

Verify:

```bash
curl -s http://localhost | head -5
```

---

## Part 3: Compare Both Distros

Fill in this comparison from your experience in this lab:

| Feature | Ubuntu (nginx) | Rocky (httpd) |
|---------|---------------|---------------|
| Auto-started after install? | ______ | ______ |
| Auto-enabled after install? | ______ | ______ |
| Config test command | ______ | ______ |
| Main config path | ______ | ______ |
| Error log command | ______ | ______ |
| Firewall needed? | ______ | ______ |

---

## Verification Checklist

On **both** VMs, confirm:

- [ ] The web server service is active and enabled
- [ ] `curl http://localhost` returns a web page
- [ ] You can identify the PID, memory usage, and uptime from `systemctl status`
- [ ] You successfully diagnosed a config error using `journalctl -u <service>`
- [ ] The broken config was fixed and the service recovered
- [ ] You understand the difference between `reload` and `restart`
