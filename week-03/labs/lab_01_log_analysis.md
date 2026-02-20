# Lab 3.1: Log Analysis

> **Objective:** Analyze a sample web server access log to find 404 errors, count hits per endpoint, extract unique IPs, find top clients, and identify suspicious patterns.
>
> **Concepts practiced:** grep, cut, sort, uniq, awk, wc, head, tail
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Ubuntu (works identically on Rocky)

---

## Step 1: Create the Sample Access Log

We will work with a realistic Apache combined log format file. Create it using a heredoc:

```bash
mkdir -p ~/labs/week03
cat << 'EOF' > ~/labs/week03/access.log
192.168.1.10 - - [15/Feb/2026:08:12:34 +0000] "GET / HTTP/1.1" 200 5432 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
192.168.1.10 - - [15/Feb/2026:08:12:35 +0000] "GET /css/style.css HTTP/1.1" 200 1234 "http://example.com/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
10.0.0.55 - - [15/Feb/2026:08:14:02 +0000] "GET /about HTTP/1.1" 200 3456 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
172.16.0.23 - - [15/Feb/2026:08:15:10 +0000] "GET /login HTTP/1.1" 200 2345 "-" "Mozilla/5.0 (X11; Linux x86_64)"
172.16.0.23 - - [15/Feb/2026:08:15:12 +0000] "POST /login HTTP/1.1" 302 0 "http://example.com/login" "Mozilla/5.0 (X11; Linux x86_64)"
192.168.1.10 - - [15/Feb/2026:08:16:45 +0000] "GET /dashboard HTTP/1.1" 200 8765 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
10.0.0.55 - - [15/Feb/2026:08:18:03 +0000] "GET /api/users HTTP/1.1" 200 567 "-" "curl/7.81.0"
10.0.0.55 - - [15/Feb/2026:08:18:04 +0000] "GET /api/orders HTTP/1.1" 200 890 "-" "curl/7.81.0"
192.168.1.42 - - [15/Feb/2026:08:20:15 +0000] "GET /products HTTP/1.1" 200 4567 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)"
192.168.1.42 - - [15/Feb/2026:08:20:18 +0000] "GET /products/widget HTTP/1.1" 200 2345 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)"
203.0.113.7 - - [15/Feb/2026:08:22:30 +0000] "GET /admin HTTP/1.1" 403 187 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
203.0.113.7 - - [15/Feb/2026:08:22:31 +0000] "GET /admin/config HTTP/1.1" 403 187 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
203.0.113.7 - - [15/Feb/2026:08:22:32 +0000] "GET /.env HTTP/1.1" 404 196 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
203.0.113.7 - - [15/Feb/2026:08:22:33 +0000] "GET /wp-admin HTTP/1.1" 404 196 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
203.0.113.7 - - [15/Feb/2026:08:22:34 +0000] "GET /phpmyadmin HTTP/1.1" 404 196 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
10.0.0.55 - - [15/Feb/2026:08:25:00 +0000] "GET /api/users HTTP/1.1" 200 567 "-" "curl/7.81.0"
192.168.1.10 - - [15/Feb/2026:08:30:22 +0000] "GET / HTTP/1.1" 200 5432 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
172.16.0.23 - - [15/Feb/2026:08:31:05 +0000] "GET /dashboard HTTP/1.1" 200 8765 "-" "Mozilla/5.0 (X11; Linux x86_64)"
192.168.1.42 - - [15/Feb/2026:08:32:10 +0000] "GET /products HTTP/1.1" 200 4567 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)"
10.0.0.88 - - [15/Feb/2026:08:33:45 +0000] "GET /nonexistent HTTP/1.1" 404 196 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
192.168.1.10 - - [15/Feb/2026:08:35:00 +0000] "GET /about HTTP/1.1" 200 3456 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
10.0.0.55 - - [15/Feb/2026:08:36:12 +0000] "DELETE /api/users/5 HTTP/1.1" 204 0 "-" "curl/7.81.0"
172.16.0.23 - - [15/Feb/2026:08:37:20 +0000] "GET /settings HTTP/1.1" 200 3456 "-" "Mozilla/5.0 (X11; Linux x86_64)"
192.168.1.10 - - [15/Feb/2026:08:40:01 +0000] "GET /dashboard HTTP/1.1" 200 8765 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
10.0.0.55 - - [15/Feb/2026:08:42:30 +0000] "GET /api/orders HTTP/1.1" 500 234 "-" "curl/7.81.0"
EOF
```

Verify the file was created:

```bash
wc -l ~/labs/week03/access.log
```

Expected output:

```text
25 /home/<user>/labs/week03/access.log
```

---

## Step 2: Count Total Requests

```bash
wc -l ~/labs/week03/access.log
```

This tells you there were 25 requests in this log excerpt. On a production server, you might have millions of lines, which is exactly why these command-line tools exist -- they process large files efficiently.

---

## Step 3: Find All 404 Errors

Use `grep` to find lines containing the 404 status code. In the combined log format, the status code appears after the closing quote of the request line:

```bash
grep '" 404 ' ~/labs/week03/access.log
```

Expected output:

```text
203.0.113.7 - - [15/Feb/2026:08:22:32 +0000] "GET /.env HTTP/1.1" 404 196 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
203.0.113.7 - - [15/Feb/2026:08:22:33 +0000] "GET /wp-admin HTTP/1.1" 404 196 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
203.0.113.7 - - [15/Feb/2026:08:22:34 +0000] "GET /phpmyadmin HTTP/1.1" 404 196 "-" "Mozilla/5.0 (compatible; Googlebot/2.1)"
10.0.0.88 - - [15/Feb/2026:08:33:45 +0000] "GET /nonexistent HTTP/1.1" 404 196 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
```

Count them:

```bash
grep -c '" 404 ' ~/labs/week03/access.log
```

Expected output: `4`

---

## Step 4: Extract and Count Status Codes

Use `awk` to pull out the status code field. In the combined log format, the status code is field 9 (space-delimited):

```bash
awk '{ print $9 }' ~/labs/week03/access.log | sort | uniq -c | sort -rn
```

Expected output:

```text
     17 200
      4 404
      2 403
      1 500
      1 302
      1 204
```

This gives you a quick health overview of the server. Most requests returned 200 (success), but there are some 404s, 403s, and a 500 (server error) that warrant investigation.

---

## Step 5: Find Unique Client IP Addresses

Extract the IP address (field 1) and deduplicate:

```bash
awk '{ print $1 }' ~/labs/week03/access.log | sort -u
```

Expected output:

```text
10.0.0.55
10.0.0.88
172.16.0.23
192.168.1.10
192.168.1.42
203.0.113.7
```

Count them:

```bash
awk '{ print $1 }' ~/labs/week03/access.log | sort -u | wc -l
```

Expected output: `6`

---

## Step 6: Find the Top Clients by Request Count

```bash
awk '{ print $1 }' ~/labs/week03/access.log | sort | uniq -c | sort -rn
```

Expected output:

```text
      7 192.168.1.10
      5 10.0.0.55
      5 203.0.113.7
      4 172.16.0.23
      3 192.168.1.42
      1 10.0.0.88
```

The IP `192.168.1.10` is the most active client with 7 requests.

---

## Step 7: Find the Most Requested Endpoints

Extract the request path. The URL is field 7 in the combined format:

```bash
awk '{ print $7 }' ~/labs/week03/access.log | sort | uniq -c | sort -rn | head -10
```

Expected output:

```text
      3 /dashboard
      3 /products
      2 /api/users
      2 /api/orders
      2 /about
      2 /
      1 /wp-admin
      1 /settings
      1 /products/widget
      1 /phpmyadmin
```

---

## Step 8: Identify Suspicious Activity

Look at the IP that generated all the 404s and 403s -- this could be a scanner probing for vulnerabilities:

```bash
grep "203.0.113.7" ~/labs/week03/access.log
```

Notice the pattern: this IP tried `/admin`, `/admin/config`, `/.env`, `/wp-admin`, and `/phpmyadmin` in rapid succession. This is a classic reconnaissance scan looking for common attack vectors.

Extract just the paths and status codes for this IP:

```bash
grep "203.0.113.7" ~/labs/week03/access.log | awk '{ print $9, $7 }'
```

Expected output:

```text
403 /admin
403 /admin/config
404 /.env
404 /wp-admin
404 /phpmyadmin
```

---

## Step 9: Find the 500 Error

A 500 status code means the server encountered an internal error. Find it:

```bash
grep '" 500 ' ~/labs/week03/access.log
```

Expected output:

```text
10.0.0.55 - - [15/Feb/2026:08:42:30 +0000] "GET /api/orders HTTP/1.1" 500 234 "-" "curl/7.81.0"
```

Now you know the endpoint (`/api/orders`), the time (08:42:30), and the client (10.0.0.55 using curl). On a real server, you would cross-reference this timestamp with the application logs to find the root cause.

---

## Step 10: Calculate Total Bytes Transferred

The response size in bytes is field 10 in the combined log format:

```bash
awk '{ total += $10 } END { print "Total bytes:", total }' ~/labs/week03/access.log
```

Expected output:

```text
Total bytes: 64988
```

For a human-readable version:

```bash
awk '{ total += $10 } END { printf "Total transferred: %.2f KB\n", total/1024 }' ~/labs/week03/access.log
```

---

## Verification

Run these commands and confirm your results match:

```bash
echo "=== Verification ==="
echo -n "Total requests: "
wc -l < ~/labs/week03/access.log
echo -n "404 errors: "
grep -c '" 404 ' ~/labs/week03/access.log
echo -n "Unique IPs: "
awk '{ print $1 }' ~/labs/week03/access.log | sort -u | wc -l
echo -n "500 errors: "
grep -c '" 500 ' ~/labs/week03/access.log
echo -n "Top client: "
awk '{ print $1 }' ~/labs/week03/access.log | sort | uniq -c | sort -rn | head -1
```

Expected output:

```text
=== Verification ===
Total requests: 25
404 errors: 4
Unique IPs: 6
500 errors: 1
Top client:       7 192.168.1.10
```

---

## Bonus Challenge

If you finish early, try these:

1. Find all requests that used the `curl` user agent.
2. Count how many requests each user agent made.
3. Find the time range of the log (earliest and latest timestamps).
4. List all unique HTTP methods (GET, POST, DELETE, etc.) used in the log.

---

## Cleanup

```bash
# Keep the file for reference, or remove it:
# rm -rf ~/labs/week03
```
