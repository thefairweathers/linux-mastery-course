# Lab 4.1: Redirection Mastery

> **Objective:** Practice redirecting stdout and stderr separately, appending to files, combining streams, and using here documents for multi-line input.
>
> **Concepts practiced:** >, >>, 2>, 2>&1, &>, <, <<EOF, tee
>
> **Time estimate:** 25 minutes
>
> **VM(s) needed:** Ubuntu (works identically on Rocky)

---

## Setup

Create a working directory for this lab:

```bash
mkdir -p ~/labs/week04/lab01 && cd ~/labs/week04/lab01
```

---

## Exercise 1: Basic stdout Redirection

Write the output of `hostname` to a file called `server_info.txt`:

```bash
hostname > server_info.txt
```

Now append the current date and kernel version to the same file:

```bash
date >> server_info.txt
uname -r >> server_info.txt
```

**Verify** with `cat server_info.txt`. You should see exactly three lines. If you used `>` instead of `>>` for the second and third commands, you would only see the kernel version.

---

## Exercise 2: Redirecting stderr

Run a command that produces both stdout and stderr:

```bash
find /etc -name "*.conf" -type f > found_configs.txt 2> find_errors.txt
```

**Verify:**

```bash
echo "Configs found: $(wc -l < found_configs.txt)"
echo "Errors encountered: $(wc -l < find_errors.txt)"
head -3 find_errors.txt
```

You should see config file paths in `found_configs.txt` and "Permission denied" errors in `find_errors.txt`. The two streams were cleanly separated.

---

## Exercise 3: Combining stdout and stderr

Run the same `find` command but send both streams to a single file using two different methods:

```bash
find /etc -name "*.conf" -type f > all_output.txt 2>&1
find /etc -name "*.conf" -type f &> all_output_v2.txt
```

**Verify both files are identical in line count:**

```bash
echo "Version 1 (2>&1):  $(wc -l < all_output.txt) lines"
echo "Version 2 (&>):    $(wc -l < all_output_v2.txt) lines"
```

The line count should equal the sum of `found_configs.txt` and `find_errors.txt` from Exercise 2.

---

## Exercise 4: Discarding Output

Sometimes you only care whether a command succeeds, not what it prints:

```bash
# Check if a user exists (silently)
grep -q "^root:" /etc/passwd 2>/dev/null && echo "root user exists"

# Suppress all output from a noisy command
find / -name "shadow" &>/dev/null
echo "Exit code: $?"
```

**Task:** Write a one-liner that checks if `/etc/nginx/nginx.conf` exists, prints "Nginx is configured" if it does, or "Nginx not found" if it doesn't. Suppress any errors.

<details>
<summary>Solution</summary>

```bash
ls /etc/nginx/nginx.conf &>/dev/null && echo "Nginx is configured" || echo "Nginx not found"
```

</details>

---

## Exercise 5: Separating stdout and stderr into Labeled Files

Run a group of commands and split the two streams into separate files:

```bash
{
    echo "=== Starting checks ==="
    ls /etc/hostname
    ls /nonexistent/path
    cat /etc/os-release | head -1
    cat /no/such/file
    echo "=== Checks complete ==="
} > checks_stdout.txt 2> checks_stderr.txt
```

**Verify:**

```bash
echo "--- STDOUT ---"
cat checks_stdout.txt
echo ""
echo "--- STDERR ---"
cat checks_stderr.txt
```

Expected stdout:

```text
=== Starting checks ===
/etc/hostname
PRETTY_NAME="Ubuntu 22.04.3 LTS"
=== Checks complete ===
```

Expected stderr:

```text
ls: cannot access '/nonexistent/path': No such file or directory
cat: /no/such/file: No such file or directory
```

The `echo` commands and successful output went to stdout. The error messages went to stderr.

---

## Exercise 6: Here Documents

Use a here document to create a configuration file:

```bash
cat << EOF > app.conf
# Application Configuration
# Generated on $(date +%Y-%m-%d) by $(whoami)

[server]
host = 0.0.0.0
port = 8080
workers = 4

[database]
host = localhost
port = 5432
name = myapp_production
EOF
```

**Verify** that `$(date ...)` and `$(whoami)` were expanded:

```bash
head -3 app.conf
```

Now create a file where variables are NOT expanded by quoting the delimiter:

```bash
cat << 'EOF' > template.conf
# Template -- variables are NOT expanded
DB_HOST=$DATABASE_HOST
DB_PORT=$DATABASE_PORT
APP_HOME=$(dirname $0)
EOF
```

**Verify:**

```bash
cat template.conf
```

```text
# Template -- variables are NOT expanded
DB_HOST=$DATABASE_HOST
DB_PORT=$DATABASE_PORT
APP_HOME=$(dirname $0)
```

The dollar signs are literal -- exactly what you want when creating script templates.

---

## Exercise 7: Here Document with sudo and tee

Create a file in a root-owned directory using `tee` and a here document:

```bash
sudo tee /etc/profile.d/lab_greeting.sh << 'EOF' > /dev/null
#!/bin/bash
# Custom greeting for lab environment
echo "Welcome to the lab environment. Today is $(date +%A)."
EOF
```

The `> /dev/null` suppresses `tee`'s stdout echo. The quoted `'EOF'` means `$(date +%A)` is written literally -- it will expand when the script runs, not when it was created.

**Verify:**

```bash
cat /etc/profile.d/lab_greeting.sh
```

**Cleanup:**

```bash
sudo rm /etc/profile.d/lab_greeting.sh
```

---

## Exercise 8: Using tee for Dual Output

Save a disk usage report to a file while also viewing it on screen:

```bash
df -h | grep -v tmpfs | tee disk_report.txt
```

Now use `tee` at two stages of a pipeline to capture intermediate data:

```bash
cat /etc/passwd \
  | cut -d: -f7 \
  | tee all_shells.txt \
  | sort \
  | uniq -c \
  | sort -rn \
  | tee shell_summary.txt
```

**Verify both files:**

```bash
echo "--- Raw shells (first 5 lines) ---"
head -5 all_shells.txt
echo ""
echo "--- Shell summary ---"
cat shell_summary.txt
```

`all_shells.txt` contains every shell from `/etc/passwd` (unsorted). `shell_summary.txt` contains the counted, sorted summary. Each `tee` captured data at a different pipeline stage.

---

## Exercise 9: Input Redirection

Compare the difference between a filename argument and stdin redirection:

```bash
wc -l /etc/passwd
wc -l < /etc/passwd
```

```text
35 /etc/passwd
35
```

The second form omits the filename -- useful when you need a clean numeric value.

**Task:** Sort `/etc/passwd` by UID (third field) numerically using input redirection, saving to `sorted_users.txt`.

<details>
<summary>Solution</summary>

```bash
sort -t: -k3 -n < /etc/passwd > sorted_users.txt
```

</details>

**Verify:**

```bash
head -3 sorted_users.txt
```

You should see `root` first (UID 0), followed by other system users with low UIDs.

---

## Exercise 10: Combine Everything

Build a system snapshot using here documents, command substitution, grouping, and redirection:

```bash
cat << 'HEADER' > system_snapshot.txt
=========================================
  SYSTEM SNAPSHOT
=========================================
HEADER

{
    echo "Generated: $(date)"
    echo "Hostname:  $(hostname)"
    echo "Kernel:    $(uname -r)"
    echo ""
    echo "--- Disk Usage ---"
    df -h | grep -v tmpfs
    echo ""
    echo "--- Memory ---"
    free -h
    echo ""
    echo "--- Users Currently Logged In ---"
    who
} >> system_snapshot.txt 2>&1

echo "Snapshot saved:"
cat system_snapshot.txt
```

**Verify** the file contains the header, system data, and no stray error messages.

---

## Cleanup

```bash
cd ~
rm -rf ~/labs/week04/lab01
```

---

## Summary

In this lab you practiced:

- ✓ Redirecting stdout to files with `>` and `>>`
- ✓ Redirecting stderr with `2>`
- ✓ Combining streams with `2>&1` and `&>`
- ✓ Discarding output with `/dev/null`
- ✓ Creating files with here documents (`<<EOF`)
- ✓ Preventing variable expansion with quoted delimiters (`<<'EOF'`)
- ✓ Writing to root-owned files with `sudo tee`
- ✓ Capturing intermediate pipeline data with `tee`
- ✓ Using input redirection with `<`
