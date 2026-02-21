# Lab 4.2: Pipeline Challenges

> **Objective:** Solve 10 progressively harder problems using pipes, redirection, and command chaining.
>
> **Concepts practiced:** pipes, grep, sort, uniq, cut, awk, wc, head, tail, xargs, command substitution
>
> **Time estimate:** 40 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Instructions

Each challenge gives you a problem to solve with a single pipeline (one line, possibly using `\` for readability). Try to solve it yourself before expanding the solution.

---

## Setup

Run this on both VMs to create sample data:

```bash
mkdir -p ~/labs/week04/lab02 && cd ~/labs/week04/lab02
```

Generate sample log files (access log and auth log):

```bash
cat << 'EOF' > access.log
203.0.113.50 - - [20/Feb/2026:10:15:01 +0000] "GET /index.html HTTP/1.1" 200 1024
198.51.100.14 - - [20/Feb/2026:10:15:02 +0000] "GET /about.html HTTP/1.1" 200 2048
203.0.113.50 - - [20/Feb/2026:10:15:03 +0000] "POST /login HTTP/1.1" 401 128
192.0.2.33 - - [20/Feb/2026:10:15:04 +0000] "GET /index.html HTTP/1.1" 200 1024
203.0.113.50 - - [20/Feb/2026:10:15:05 +0000] "POST /login HTTP/1.1" 401 128
198.51.100.14 - - [20/Feb/2026:10:15:06 +0000] "GET /products HTTP/1.1" 200 4096
10.0.0.1 - - [20/Feb/2026:10:15:07 +0000] "GET /admin HTTP/1.1" 403 256
203.0.113.50 - - [20/Feb/2026:10:15:08 +0000] "POST /login HTTP/1.1" 200 512
192.0.2.33 - - [20/Feb/2026:10:15:09 +0000] "GET /products HTTP/1.1" 200 4096
198.51.100.14 - - [20/Feb/2026:10:15:10 +0000] "GET /index.html HTTP/1.1" 200 1024
10.0.0.1 - - [20/Feb/2026:10:15:11 +0000] "GET /admin HTTP/1.1" 403 256
203.0.113.50 - - [20/Feb/2026:10:15:12 +0000] "GET /dashboard HTTP/1.1" 200 8192
192.0.2.33 - - [20/Feb/2026:10:15:13 +0000] "GET /about.html HTTP/1.1" 200 2048
198.51.100.14 - - [20/Feb/2026:10:15:14 +0000] "GET /products HTTP/1.1" 200 4096
10.0.0.1 - - [20/Feb/2026:10:15:15 +0000] "DELETE /admin/users HTTP/1.1" 403 256
EOF

cat << 'EOF' > auth.log
Feb 20 10:01:15 server sshd[1234]: Failed password for root from 203.0.113.50 port 22 ssh2
Feb 20 10:01:18 server sshd[1235]: Failed password for root from 203.0.113.50 port 22 ssh2
Feb 20 10:01:22 server sshd[1236]: Accepted password for admin from 192.168.1.10 port 22 ssh2
Feb 20 10:01:25 server sshd[1237]: Failed password for invalid user test from 198.51.100.14 port 22 ssh2
Feb 20 10:01:30 server sshd[1238]: Failed password for root from 203.0.113.50 port 22 ssh2
Feb 20 10:01:33 server sshd[1239]: Failed password for admin from 198.51.100.14 port 22 ssh2
Feb 20 10:01:36 server sshd[1240]: Accepted password for deploy from 10.0.0.5 port 22 ssh2
Feb 20 10:01:40 server sshd[1241]: Failed password for root from 203.0.113.50 port 22 ssh2
Feb 20 10:01:43 server sshd[1242]: Failed password for invalid user guest from 192.0.2.33 port 22 ssh2
Feb 20 10:01:47 server sshd[1243]: Accepted password for admin from 192.168.1.10 port 22 ssh2
EOF
```

---

## Challenge 1: Count Unique Shells

**Problem:** List all unique login shells from `/etc/passwd`, along with how many users use each, sorted most-to-least common.

**Hint:** You need `cut`, `sort`, `uniq -c`, and `sort -rn`.

<details>
<summary>Solution</summary>

```bash
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

</details>

**Expected output** (numbers will vary):

```text
     27 /usr/sbin/nologin
      1 /bin/sync
      1 /bin/bash
      1 /bin/false
```

---

## Challenge 2: Top IP Addresses in Access Log

**Problem:** Using `access.log`, find the top 3 IP addresses by request count.

**Hint:** The IP address is the first field.

<details>
<summary>Solution</summary>

```bash
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -3
```

</details>

**Expected output:**

```text
      5 203.0.113.50
      4 198.51.100.14
      3 192.0.2.33
```

---

## Challenge 3: Find Failed SSH Logins

**Problem:** Using `auth.log`, extract the IP addresses from which failed login attempts originated, count them, and show the worst offenders first.

**Hint:** Filter for "Failed password", then extract the IP that follows the word "from".

<details>
<summary>Solution</summary>

```bash
grep "Failed password" auth.log \
  | grep -oP 'from \K[0-9.]+' \
  | sort | uniq -c | sort -rn
```

If `grep -P` is not available, use `awk`:

```bash
grep "Failed password" auth.log \
  | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' \
  | sort | uniq -c | sort -rn
```

</details>

**Expected output:**

```text
      4 203.0.113.50
      2 198.51.100.14
      1 192.0.2.33
```

---

## Challenge 4: HTTP Error Summary

**Problem:** From `access.log`, list all requests with a non-200 status code. Show the status code, HTTP method, and URL path.

**Hint:** The status code is field 9 in the combined log format.

<details>
<summary>Solution</summary>

```bash
awk '$9 != 200 {print $9, $6, $7}' access.log | sed 's/"//g' | sort
```

</details>

**Expected output:**

```text
401 POST /login
401 POST /login
403 DELETE /admin/users
403 GET /admin
403 GET /admin
```

---

## Challenge 5: Disk Usage Report for /var

**Problem:** Show the 5 largest subdirectories under `/var`, sorted by size descending, with human-readable sizes. Suppress permission errors.

<details>
<summary>Solution</summary>

```bash
sudo du -sh /var/*/ 2>/dev/null | sort -rh | head -5
```

</details>

Output will vary by system. You should see `/var/cache/` and `/var/lib/` near the top.

---

## Challenge 6: Find Large Log Files

**Problem:** Find all files under `/var/log` larger than 1KB, show their sizes in human-readable format, sorted by size descending. Top 10 only.

<details>
<summary>Solution</summary>

```bash
find /var/log -type f -size +1k -exec ls -lh {} \; 2>/dev/null \
  | awk '{print $5, $NF}' | sort -rh | head -10
```

</details>

---

## Challenge 7: Users with Real Login Shells

**Problem:** List usernames of all accounts in `/etc/passwd` that have a real login shell (ending in `bash`, `sh`, `zsh`, or `fish`), sorted alphabetically.

<details>
<summary>Solution</summary>

```bash
grep -E '/(bash|sh|zsh|fish)$' /etc/passwd | cut -d: -f1 | sort
```

</details>

**Expected output** (will vary):

```text
root
tim
```

---

## Challenge 8: Bandwidth by IP Address

**Problem:** From `access.log`, calculate total bytes transferred per IP address, sorted by total bytes descending.

**Hint:** The bytes transferred is the last field. Use `awk` to sum by IP.

<details>
<summary>Solution</summary>

```bash
awk '{bytes[$1] += $NF} END {for (ip in bytes) print bytes[ip], ip}' access.log \
  | sort -rn
```

</details>

**Expected output:**

```text
11264 198.51.100.14
11084 203.0.113.50
7168 192.0.2.33
768 10.0.0.1
```

---

## Challenge 9: Compare System Users Across VMs

**Problem:** Compare the list of system users (UID < 1000) between Ubuntu and Rocky Linux. Show which users exist on one but not the other.

If you cannot SSH between VMs, simulate by creating two files:

```bash
awk -F: '$3 < 1000 {print $1}' /etc/passwd | sort > ubuntu_system_users.txt
awk -F: '$3 < 1000 {print $1}' /etc/passwd | sort | sed '3d' > rocky_system_users.txt
echo "chrony" >> rocky_system_users.txt && sort -o rocky_system_users.txt rocky_system_users.txt
```

<details>
<summary>Solution</summary>

Using `comm` (requires sorted input):

```bash
echo "=== Only on Ubuntu ===" && comm -23 ubuntu_system_users.txt rocky_system_users.txt
echo "=== Only on Rocky ===" && comm -13 ubuntu_system_users.txt rocky_system_users.txt
```

Using `diff` with process substitution (for live SSH comparison):

```bash
diff <(awk -F: '$3 < 1000 {print $1}' /etc/passwd | sort) \
     <(ssh rocky-server 'awk -F: '\''$3 < 1000 {print $1}'\'' /etc/passwd' | sort)
```

</details>

---

## Challenge 10: Full Server Health Pipeline

**Problem:** Build a single pipeline that generates a server health report and saves it to `/tmp/health_report.txt` while displaying it on screen. Include:

1. Hostname and current date
2. Uptime
3. Top 3 directories by disk usage under `/var`
4. Number of running processes
5. Number of established network connections
6. Number of users with real login shells

This is the capstone challenge. Combine command substitution, grouping, redirection, pipes, and `tee`.

<details>
<summary>Solution</summary>

```bash
{
    echo "========================================"
    echo "  SERVER HEALTH REPORT"
    echo "  Host: $(hostname)"
    echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    echo ""
    echo "--- Uptime ---"
    uptime
    echo ""
    echo "--- Top 3 Directories in /var ---"
    sudo du -sh /var/*/ 2>/dev/null | sort -rh | head -3
    echo ""
    echo "--- Process Count ---"
    echo "Running processes: $(ps aux | wc -l)"
    echo ""
    echo "--- Network Connections ---"
    echo "Established: $(ss -t state established 2>/dev/null | tail -n +2 | wc -l)"
    echo ""
    echo "--- Login Shell Users ---"
    echo "Users with login shells: $(grep -cE '/(bash|sh|zsh|fish)$' /etc/passwd)"
} | tee /tmp/health_report.txt
```

</details>

You should see a neatly formatted report with all six sections, both on screen and saved in the file. Verify with `cat /tmp/health_report.txt`.

---

## Cleanup

```bash
cd ~
rm -rf ~/labs/week04/lab02
rm -f /tmp/health_report.txt
```

---

## Scoring Yourself

| Challenge | Solved without hints | Solved with hints | Needed solution |
|:-:|:-:|:-:|:-:|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |
| 6 | | | |
| 7 | | | |
| 8 | | | |
| 9 | | | |
| 10 | | | |

- **8-10 without hints:** You have strong pipeline instincts. Move on to Week 5.
- **5-7 without hints:** Solid foundation. Review the challenges you missed, then proceed.
- **Under 5 without hints:** Re-read sections 4.5 through 4.10 in the README, then try these challenges again before moving on.
