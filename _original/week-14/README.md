# Week 14: Advanced Scripting & Automation

> **Goal:** Write production-quality shell scripts using advanced patterns for server automation, deployment, and operational tasks.

[← Previous Week](../week-13/README.md) · [Next Week →](../week-15/README.md)

---

## Table of Contents

| Section | Topic |
|---------|-------|
| 14.1  | [From Fundamentals to Production Scripts](#141-from-fundamentals-to-production-scripts) |
| 14.2  | [Robust Scripting Revisited](#142-robust-scripting-revisited) |
| 14.3  | [Trap for Cleanup](#143-trap-for-cleanup) |
| 14.4  | [Temporary File Handling](#144-temporary-file-handling) |
| 14.5  | [Parsing Arguments](#145-parsing-arguments) |
| 14.6  | [Arrays](#146-arrays) |
| 14.7  | [Here Documents](#147-here-documents) |
| 14.8  | [Process Substitution](#148-process-substitution) |
| 14.9  | [Subshells vs. Current Shell](#149-subshells-vs-current-shell) |
| 14.10 | [File Locking with flock](#1410-file-locking-with-flock) |
| 14.11 | [Logging Patterns](#1411-logging-patterns) |
| 14.12 | [Configuration Files](#1412-configuration-files) |
| 14.13 | [Secrets Handling](#1413-secrets-handling) |
| 14.14 | [Portable Scripting Notes](#1414-portable-scripting-notes) |
| 14.15 | [ShellCheck](#1415-shellcheck) |
| 14.16 | [Script Structure Template](#1416-script-structure-template) |
| 14.17 | [jq for JSON Processing](#1417-jq-for-json-processing) |

---

## 14.1 From Fundamentals to Production Scripts

In Week 8, you learned the building blocks of bash scripting: variables, conditionals, loops, functions, and error handling. Those fundamentals let you automate individual tasks. Now we need scripts that survive the real world.

Production scripts differ from learning exercises in several critical ways:

**Concurrency** — A cron job fires your backup script while the previous run is still going. Without file locking, both instances try to write the same file and you get a corrupted backup. This happens at 2 AM when nobody is watching.

**Failure modes** — Your script creates a temporary directory, writes half a config file, then crashes. Without cleanup traps, those temp files accumulate until the disk fills up. On a server running hundreds of scripts under systemd timers (Week 11), this happens faster than you think.

**Argument handling** — A script that only takes positional arguments (`$1`, `$2`) becomes unreadable the moment it needs five options. You need `--dry-run` to test safely in production, `--verbose` for debugging, and `--config` to override defaults.

**Logging** — `echo` is fine during development. In production, you need timestamps, severity levels, and syslog integration so your monitoring system can catch errors.

**Configuration** — Hardcoded paths and credentials in scripts are a security incident waiting to happen. Proper scripts read configuration from external files and environment variables.

This week builds directly on Week 8. Every concept assumes you are comfortable with variables, conditionals, loops, functions, and `set -euo pipefail`. If any of those feel shaky, review Week 8 before continuing.

---

## 14.2 Robust Scripting Revisited

You already know `set -euo pipefail` from Week 8. Let's revisit it with the nuance that production scripts require.

### When set -e Gets in the Way

`set -e` exits on any non-zero return code. That's usually what you want, but some commands return non-zero for perfectly normal reasons:

```bash
set -euo pipefail

# This kills your script if the pattern isn't found — grep returns 1 for "no match"
count="$(grep -c "ERROR" /var/log/app.log)"
```

There are several clean ways to handle this:

```bash
# Method 1: Use || true to suppress the error
count="$(grep -c "ERROR" /var/log/app.log || true)"

# Method 2: Use an if statement (set -e doesn't apply inside if conditions)
if grep -q "ERROR" /var/log/app.log; then
    echo "Errors found"
fi

# Method 3: Temporarily disable set -e for a block
set +e
count="$(grep -c "ERROR" /var/log/app.log)"
grep_exit="$?"
set -e

if [[ "$grep_exit" -eq 0 ]]; then
    echo "Found $count errors"
elif [[ "$grep_exit" -eq 1 ]]; then
    echo "No errors found"
else
    echo "grep encountered an actual error" >&2
    exit 1
fi
```

Method 3 is the most explicit — it distinguishes between "no matches" (exit 1) and "actual error" (exit 2+). Use it when the distinction matters.

### Pipefail Subtleties

With `set -o pipefail`, a pipeline's exit code is the last non-zero exit code from any command in the pipe:

```bash
set -o pipefail

# If curl fails (exit 7) but jq succeeds (exit 0),
# the pipeline returns 7 — not 0
curl -sf "https://api.example.com/data" | jq '.items[]'
```

This is almost always what you want. But when you genuinely expect a command in the pipeline to "fail," you need to handle it:

```bash
# Count lines that DON'T match — grep returns 1 if no lines match
# Use || true on the specific command that might legitimately fail
result="$(cat /var/log/app.log | grep -v "DEBUG" || true)"
```

### The IFS Variable

The **Internal Field Separator** (`IFS`) controls how bash splits strings into words. The default is space, tab, and newline. In production scripts, you sometimes need to change it:

```bash
# Default IFS splits on spaces — breaks filenames with spaces
for file in $(ls); do
    echo "$file"    # "My Documents" becomes two iterations: "My" and "Documents"
done

# Better: use a glob pattern instead
for file in *; do
    echo "$file"    # Handles "My Documents" correctly
done
```

When you do need to change IFS, always save and restore it:

```bash
old_ifs="$IFS"
IFS=","
read -ra fields <<< "one,two,three"
IFS="$old_ifs"

for field in "${fields[@]}"; do
    echo "Field: $field"
done
```

---

## 14.3 Trap for Cleanup

You saw a basic `trap` example in Week 8 (Section 8.15). Production scripts need more sophisticated cleanup — handling temp files, lock files, PID files, and partial outputs.

### The EXIT Trap Pattern

The `EXIT` trap fires whenever the script exits — success, failure, `set -e` abort, or signal. This is the single most important pattern for writing reliable scripts:

```bash
#!/bin/bash
set -euo pipefail

TMPDIR=""
LOCKFILE=""

cleanup() {
    local exit_code="$?"

    # Remove temp directory if it was created
    if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
        rm -rf "$TMPDIR"
    fi

    # Release lock file if it was acquired
    if [[ -n "$LOCKFILE" && -f "$LOCKFILE" ]]; then
        rm -f "$LOCKFILE"
    fi

    # Log the exit
    if [[ "$exit_code" -eq 0 ]]; then
        echo "[INFO] Script completed successfully"
    else
        echo "[ERROR] Script exited with code $exit_code" >&2
    fi

    exit "$exit_code"
}

trap cleanup EXIT

TMPDIR="$(mktemp -d)"
LOCKFILE="/tmp/myscript.lock"
# ... rest of script ...
```

Key points:

- Capture `$?` as the very first line of the cleanup function — any command you run will overwrite it.
- Check that variables are non-empty before acting on them. The trap can fire before the variable was assigned (if the script fails early).
- Re-exit with the original exit code so the caller sees the correct status.

### Trapping Multiple Signals

You can set separate traps for different signals:

```bash
cleanup() {
    echo "Cleaning up..."
    rm -rf "${TMPDIR:-}"
}

on_interrupt() {
    echo ""
    echo "Interrupted by user (Ctrl+C)" >&2
    exit 130    # Convention: 128 + signal number (SIGINT = 2)
}

trap cleanup EXIT
trap on_interrupt INT
```

The `EXIT` trap still fires after `on_interrupt` calls `exit`, so cleanup happens in both cases. This is why `EXIT` is the right place for cleanup logic — it always runs.

### Trap Pitfalls

Traps in subshells do not inherit from the parent:

```bash
trap 'echo "parent trap"' EXIT

# This subshell has its OWN trap context — the parent trap does not fire inside it
(
    trap 'echo "subshell trap"' EXIT
    echo "inside subshell"
)
# Output: inside subshell
#         subshell trap
#         parent trap
```

Each subshell starts with a clean trap slate. If you spawn background processes, they will not inherit your cleanup traps.

---

## 14.4 Temporary File Handling

Never use hardcoded temp file paths like `/tmp/myscript.tmp`. If two instances run simultaneously, they clobber each other. If the script crashes, the file lingers forever. Use `mktemp`.

### mktemp — Safe Temp Files

**`mktemp`** creates a uniquely named temporary file or directory:

```bash
# Create a temp file — returns a path like /tmp/tmp.Xa3bR9kL2m
tmpfile="$(mktemp)"
echo "Working in: $tmpfile"

# Create a temp file with a meaningful prefix
tmpfile="$(mktemp /tmp/backup-XXXXXX)"
# Result: /tmp/backup-a8K3mN

# Create a temp directory
tmpdir="$(mktemp -d)"
echo "Temp dir: $tmpdir"

# Create a temp directory with a prefix
tmpdir="$(mktemp -d /tmp/deploy-XXXXXX)"
```

The `XXXXXX` pattern is replaced with random characters. More `X`s mean more randomness. Use at least six.

### The Complete Pattern

Every script that uses temp files should follow this pattern:

```bash
#!/bin/bash
set -euo pipefail

TMPDIR=""

cleanup() {
    if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
        rm -rf "$TMPDIR"
    fi
}
trap cleanup EXIT

TMPDIR="$(mktemp -d /tmp/myscript-XXXXXX)"

# Use files inside the temp directory — they all get cleaned up together
config_file="$TMPDIR/config.tmp"
output_file="$TMPDIR/output.tmp"

echo "server=example.com" > "$config_file"
process_data > "$output_file"

# cleanup runs automatically on exit
```

Using a temp *directory* instead of individual temp files is cleaner — one `rm -rf` in the cleanup function handles everything, no matter how many files you created.

### Temp Files in a Shared Environment

On multi-user servers, `/tmp` is world-writable. A malicious user could create a symlink at the path your script expects, tricking it into overwriting arbitrary files. `mktemp` avoids this by using random names and creating the file atomically with restricted permissions:

```bash
ls -la "$(mktemp)"
```

```text
-rw------- 1 admin admin 0 Feb 20 14:30 /tmp/tmp.Xa3bR9kL2m
```

The file is created with `0600` permissions — only the owner can read or write it. This is why `mktemp` exists and hardcoded paths are dangerous.

---

## 14.5 Parsing Arguments

In Week 8, you parsed arguments with simple `$1`/`$2` positional access and a basic `while/case` pattern for flags. Production scripts need more. Let's cover both `getopts` (for short options) and the full `while/case` pattern (for long options).

### getopts — Short Options

**`getopts`** is a bash builtin for parsing short (single-character) options:

```bash
#!/bin/bash
set -euo pipefail

verbose=false
dry_run=false
output_dir=""

while getopts "vno:h" opt; do
    case "$opt" in
        v) verbose=true ;;
        n) dry_run=true ;;
        o) output_dir="$OPTARG" ;;
        h)
            echo "Usage: $0 [-v] [-n] [-o output_dir] file..."
            exit 0
            ;;
        *)
            echo "Usage: $0 [-v] [-n] [-o output_dir] file..." >&2
            exit 1
            ;;
    esac
done
shift $(( OPTIND - 1 ))    # Remove parsed options, leaving positional args

echo "Verbose: $verbose"
echo "Dry run: $dry_run"
echo "Output:  $output_dir"
echo "Files:   $*"
```

The option string `"vno:h"` means:
- `v` — flag (no argument)
- `n` — flag (no argument)
- `o:` — takes an argument (the colon after `o`)
- `h` — flag (no argument)

```bash
./myscript.sh -v -o /tmp/out file1.txt file2.txt
```

```text
Verbose: true
Dry run: false
Output:  /tmp/out
Files:   file1.txt file2.txt
```

`getopts` handles combined flags too: `-vn` is the same as `-v -n`.

### while/case — Long Options

`getopts` does not support long options (`--verbose`, `--output-dir`). For scripts with many options, long options are far more readable. Use the `while/case` pattern:

```bash
#!/bin/bash
set -euo pipefail

verbose=false
dry_run=false
output_dir=""
config_file=""

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <file>...

Options:
    -v, --verbose       Enable verbose output
    -n, --dry-run       Show what would be done without doing it
    -o, --output-dir    Directory for output files
    -c, --config        Path to configuration file
    -h, --help          Show this help message
EOF
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            verbose=true
            shift
            ;;
        -n|--dry-run)
            dry_run=true
            shift
            ;;
        -o|--output-dir)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --output-dir requires an argument" >&2
                exit 1
            fi
            output_dir="$2"
            shift 2
            ;;
        -c|--config)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --config requires an argument" >&2
                exit 1
            fi
            config_file="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break    # Everything after -- is a positional argument
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            break    # First non-option argument — stop parsing
            ;;
    esac
done

# Remaining arguments are in "$@"
if [[ "$#" -eq 0 ]]; then
    echo "Error: At least one file argument is required" >&2
    usage >&2
    exit 1
fi

echo "Verbose: $verbose"
echo "Dry run: $dry_run"
echo "Output:  ${output_dir:-<default>}"
echo "Config:  ${config_file:-<none>}"
echo "Files:   $*"
```

The `--` convention means "everything after this is a positional argument, not an option." This lets you pass filenames that start with a dash.

### Which to Use

| Approach | Pros | Cons |
|----------|------|------|
| `getopts` | Built-in, handles combined flags (`-vn`) | No long options, limited |
| `while/case` | Long options, full control, self-documenting | More code to write |

For any script that will be used by others (including future-you), use `while/case` with long options. The extra twenty lines of argument parsing save hours of "what does `-x` do again?"

---

## 14.6 Arrays

Bash has two kinds of arrays: **indexed arrays** (numbered, like lists) and **associative arrays** (key-value pairs, like dictionaries). You need both for production scripts.

### Indexed Arrays

```bash
# Declare and populate
services=("nginx" "postgresql" "redis" "memcached")

# Access individual elements (0-indexed)
echo "${services[0]}"     # nginx
echo "${services[2]}"     # redis

# Number of elements
echo "${#services[@]}"    # 4

# All elements
echo "${services[@]}"     # nginx postgresql redis memcached

# Append an element
services+=("varnish")

# Iterate
for svc in "${services[@]}"; do
    echo "Checking $svc..."
done
```

Always quote `"${array[@]}"` when iterating — without quotes, elements containing spaces get split.

### Array Slicing and Manipulation

```bash
files=("a.log" "b.log" "c.log" "d.log" "e.log")

# Slice: elements 1-3 (offset 1, length 3)
echo "${files[@]:1:3}"     # b.log c.log d.log

# Last element
echo "${files[-1]}"        # e.log

# Remove an element by index (leaves a gap)
unset 'files[2]'
echo "${files[@]}"         # a.log b.log d.log e.log

# Check if array is empty
if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No files to process"
fi
```

### Associative Arrays

**Associative arrays** (bash 4+) use string keys instead of numbers. You must declare them with `declare -A`:

```bash
# Declare an associative array
declare -A server_roles

# Assign values
server_roles["web-01"]="nginx"
server_roles["db-01"]="postgresql"
server_roles["cache-01"]="redis"

# Access a value
echo "${server_roles["web-01"]}"     # nginx

# Number of entries
echo "${#server_roles[@]}"           # 3

# Iterate over keys
for server in "${!server_roles[@]}"; do
    echo "$server runs ${server_roles[$server]}"
done

# Check if a key exists
if [[ -v server_roles["web-01"] ]]; then
    echo "web-01 is defined"
fi
```

### Practical Example: Service Health Check

Here is a real-world pattern that combines arrays with the service management you learned in Week 11:

```bash
#!/bin/bash
set -euo pipefail

# Services to check with their expected ports
declare -A service_ports
service_ports["nginx"]="80"
service_ports["postgresql"]="5432"
service_ports["redis"]="6379"

errors=()

for service in "${!service_ports[@]}"; do
    port="${service_ports[$service]}"

    if ! systemctl is-active --quiet "$service" 2>/dev/null; then
        errors+=("$service is not running")
        continue
    fi

    if ! ss -tlnp | grep -q ":${port} " 2>/dev/null; then
        errors+=("$service is running but port $port is not listening")
    fi
done

if [[ "${#errors[@]}" -gt 0 ]]; then
    echo "Health check FAILED:" >&2
    for err in "${errors[@]}"; do
        echo "  - $err" >&2
    done
    exit 1
fi

echo "All services healthy"
```

### Building Arrays from Command Output

```bash
# Read lines into an array (bash 4+)
mapfile -t log_files < <(find /var/log -name "*.log" -mtime -1 2>/dev/null)

echo "Found ${#log_files[@]} recent log files"
for f in "${log_files[@]}"; do
    echo "  $f"
done
```

The `mapfile` (also called `readarray`) command reads lines into an array. The `-t` flag strips trailing newlines. The `< <(command)` syntax is process substitution, which we cover in Section 14.8.

---

## 14.7 Here Documents

**Here documents** (heredocs) let you embed multi-line text inside a script. They are invaluable for generating configuration files, SQL queries, email bodies, and anywhere you need a block of templated text.

### Basic Syntax

```bash
cat <<EOF
Hello, this is a here document.
Variables like $USER are expanded.
Commands like $(date) are executed.
EOF
```

The delimiter (`EOF` is conventional, but any word works) marks the start and end of the text block. The closing delimiter must be on a line by itself, with no leading whitespace.

### Suppressing Variable Expansion

Quote the delimiter to prevent variable expansion:

```bash
cat <<'EOF'
This is literal text.
$USER is NOT expanded — it stays as $USER.
$(date) is NOT executed.
EOF
```

This is critical when generating scripts or config files that contain their own variables.

### Indented Here Documents

Use `<<-` (with a dash) to strip leading **tabs** (not spaces):

```bash
generate_config() {
    cat <<-EOF
	server {
	    listen 80;
	    server_name $1;
	    root /var/www/$1;
	}
	EOF
}
```

The tabs before each line are stripped from the output. This keeps your script indented properly without the indentation appearing in the generated file.

### Generating Nginx Configs from a Script

Here is a production pattern — generating server configurations from data:

```bash
#!/bin/bash
set -euo pipefail

generate_nginx_vhost() {
    local domain="$1"
    local root_dir="$2"
    local proxy_port="${3:-}"

    if [[ -n "$proxy_port" ]]; then
        cat <<EOF
server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass http://127.0.0.1:${proxy_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
}
EOF
    else
        cat <<EOF
server {
    listen 80;
    server_name ${domain};
    root ${root_dir};
    index index.html;

    access_log /var/log/nginx/${domain}_access.log;
    error_log /var/log/nginx/${domain}_error.log;
}
EOF
    fi
}

# Generate configs for multiple sites
generate_nginx_vhost "example.com" "/var/www/example" > /tmp/example.conf
generate_nginx_vhost "api.example.com" "" "8080" > /tmp/api.conf
```

Notice the `\$host` and `\$remote_addr` — we escape the dollar signs because those are nginx variables, not bash variables. Without the backslash, bash would try to expand `$host` as a shell variable.

### Generating systemd Units from Scripts

Building on Week 11, here is how you might script the creation of a systemd service:

```bash
create_service_unit() {
    local name="$1"
    local exec_start="$2"
    local user="${3:-root}"
    local description="${4:-$name service}"

    cat <<EOF
[Unit]
Description=${description}
After=network.target

[Service]
Type=simple
User=${user}
ExecStart=${exec_start}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${name}

[Install]
WantedBy=multi-user.target
EOF
}

# Generate a unit file
create_service_unit "myapp" "/usr/local/bin/myapp" "www-data" "My Application" \
    | sudo tee /etc/systemd/system/myapp.service > /dev/null
sudo systemctl daemon-reload
```

### Here Strings

A **here string** (`<<<`) feeds a single string to a command's stdin:

```bash
# Instead of: echo "hello world" | grep "hello"
grep "hello" <<< "hello world"

# Useful for feeding variables to commands that read stdin
while IFS=: read -r user _ uid _; do
    echo "User: $user, UID: $uid"
done <<< "$(getent passwd root)"
```

---

## 14.8 Process Substitution

**Process substitution** lets you use the output of a command as if it were a file. It creates a temporary file descriptor that a command can read from (`<()`) or write to (`>()`).

### Reading with <()

Some commands require filenames as arguments and cannot read from stdin. Process substitution solves this:

```bash
# diff requires two files — use process substitution to compare command outputs
diff <(ssh server1 "cat /etc/nginx/nginx.conf") \
     <(ssh server2 "cat /etc/nginx/nginx.conf")
```

This compares the nginx config on two servers without creating temporary files. The `<(command)` syntax creates a file descriptor (like `/dev/fd/63`) that `diff` reads from.

### Comparing Sorted Output

```bash
# Compare sorted lists to find differences
comm -23 <(sort users_expected.txt) <(sort users_actual.txt)
```

`comm` requires sorted input files. Process substitution lets you sort on the fly.

### Feeding Commands That Need Filenames

```bash
# paste requires files — join two command outputs side by side
paste <(cut -d: -f1 /etc/passwd) <(cut -d: -f3 /etc/passwd)

# source a generated config without writing to disk
source <(generate_env_vars)
```

### Writing with >()

The `>()` form redirects output to a command's stdin:

```bash
# Tee output to both a file and a processing command
some_command | tee >(grep "ERROR" > errors.log) > full_output.log

# Send logs to both a file and syslog simultaneously
./my_script.sh 2>&1 | tee >(logger -t my_script) > /var/log/my_script.log
```

### Process Substitution vs. Pipes

```bash
# Pipe — runs grep in a subshell, variable changes are lost
count=0
echo -e "one\ntwo\nthree" | while read -r line; do
    (( count++ ))
done
echo "$count"    # 0! The while loop ran in a subshell

# Process substitution — while loop runs in the current shell
count=0
while read -r line; do
    (( count++ ))
done < <(echo -e "one\ntwo\nthree")
echo "$count"    # 3 — correct!
```

This is why `mapfile -t arr < <(command)` uses process substitution instead of `command | mapfile -t arr`. The pipe version would fill the array inside a subshell, and the array would be empty in the parent.

---

## 14.9 Subshells vs. Current Shell

Understanding when commands run in a **subshell** versus the **current shell** prevents subtle bugs, especially with variable scope.

### () Creates a Subshell

Parentheses run commands in a child process. Variable changes, directory changes, and traps do not affect the parent:

```bash
var="original"
(
    var="modified"
    cd /tmp
    echo "Inside subshell: $var, pwd: $(pwd)"
)
echo "Outside: $var, pwd: $(pwd)"
```

```text
Inside subshell: modified, pwd: /tmp
Outside: original, pwd: /home/admin
```

This isolation is useful when you *want* to contain side effects:

```bash
# Temporarily change directory without affecting the rest of the script
(
    cd /opt/myapp
    ./deploy.sh
)
# Still in original directory here
```

### {} Runs in the Current Shell

Curly braces group commands **without** creating a subshell:

```bash
var="original"
{
    var="modified"
    echo "Inside braces: $var"
}
echo "Outside: $var"
```

```text
Inside braces: modified
Outside: modified
```

Changes persist because everything runs in the same process.

### When the Distinction Matters

| Operation | `()` Subshell | `{}` Current Shell |
|-----------|---------------|-------------------|
| Variable changes | Lost after `)` | Persist |
| `cd` changes | Lost after `)` | Persist |
| `trap` changes | Isolated | Affect current script |
| `exit` | Exits subshell only | Exits the script |
| Environment changes | Lost after `)` | Persist |

The most common trap is pipes. The right side of a pipe runs in a subshell:

```bash
# BUG: total is modified in a subshell, lost in the parent
total=0
cat /etc/passwd | while IFS=: read -r _ _ uid _; do
    if [[ "$uid" -ge 1000 ]]; then
        (( total++ ))
    fi
done
echo "Found $total regular users"    # Always prints 0!

# FIX: Use process substitution to keep the loop in the current shell
total=0
while IFS=: read -r _ _ uid _; do
    if [[ "$uid" -ge 1000 ]]; then
        (( total++ ))
    fi
done < <(cat /etc/passwd)
echo "Found $total regular users"    # Correct count
```

Or even simpler — redirect the file directly:

```bash
total=0
while IFS=: read -r _ _ uid _; do
    if [[ "$uid" -ge 1000 ]]; then
        (( total++ ))
    fi
done < /etc/passwd
echo "Found $total regular users"
```

---

## 14.10 File Locking with flock

When scripts run from cron jobs or systemd timers (Week 11), there is a real risk of overlapping execution. A backup that takes 45 minutes on a 30-minute timer. A deployment script triggered twice by an impatient engineer. **`flock`** prevents concurrent execution.

### The Problem

```text
Timer fires at 02:00 → backup.sh starts (PID 1234)
Timer fires at 02:30 → backup.sh starts AGAIN (PID 5678)
Both write to /backups/db.sql.gz simultaneously
Corrupted backup. You discover this at 3 AM during a restore.
```

### flock — Advisory File Locking

`flock` uses a lock file to coordinate access. If the lock is already held, the second instance either waits or exits immediately.

**Method 1: Wrap an entire command**

```bash
# Run backup.sh with an exclusive lock — second instance waits
flock /tmp/backup.lock /usr/local/bin/backup.sh

# Non-blocking: exit immediately if lock is held
flock -n /tmp/backup.lock /usr/local/bin/backup.sh
if [[ "$?" -ne 0 ]]; then
    echo "Another instance is already running" >&2
fi
```

**Method 2: Lock inside the script with a file descriptor**

```bash
#!/bin/bash
set -euo pipefail

LOCKFILE="/var/lock/mybackup.lock"

# Open the lock file on file descriptor 9
exec 9>"$LOCKFILE"

# Try to acquire an exclusive lock (non-blocking)
if ! flock -n 9; then
    echo "Another instance is already running. Exiting." >&2
    exit 1
fi

echo "Lock acquired. Starting backup..."
# ... do work ...

echo "Backup complete."
# Lock is released when fd 9 is closed (script exit)
```

The `exec 9>"$LOCKFILE"` opens a file descriptor. `flock -n 9` tries to lock it without blocking. When the script exits, the file descriptor closes and the lock is released automatically.

### flock Options

| Option | Behavior |
|--------|----------|
| `-x` (default) | Exclusive lock — only one holder at a time |
| `-s` | Shared lock — multiple readers, no writers |
| `-n` | Non-blocking — fail immediately if lock is held |
| `-w SECONDS` | Wait up to SECONDS for the lock, then fail |

### Lock File Best Practices

```bash
# Use /var/lock or /run/lock for system scripts
LOCKFILE="/var/lock/myapp-backup.lock"

# Use a descriptive name that identifies the script
LOCKFILE="/var/lock/$(basename "$0").lock"

# Never put lock files in /tmp on systems with tmpwatch/systemd-tmpfiles
# — they might be deleted while the script is running
```

### Combining flock with Cleanup Traps

```bash
#!/bin/bash
set -euo pipefail

LOCKFILE="/var/lock/deploy.lock"
LOCK_FD=9

cleanup() {
    # Lock is released automatically when fd closes,
    # but removing the file keeps the directory clean
    rm -f "$LOCKFILE"
}
trap cleanup EXIT

exec "$LOCK_FD">"$LOCKFILE"
if ! flock -n "$LOCK_FD"; then
    echo "Deployment already in progress. Exiting." >&2
    exit 1
fi

echo "$$" > "$LOCKFILE"    # Write PID for diagnostics
echo "Deploying..."
# ... deployment logic ...
```

Writing the PID to the lock file is a courtesy — if someone needs to debug a stuck deployment, they can `cat /var/lock/deploy.lock` to find the responsible process.

---

## 14.11 Logging Patterns

`echo` is fine for development. Production scripts need structured logging with timestamps, severity levels, and optional syslog integration.

### A Reusable Log Function

```bash
readonly LOG_LEVEL_ERROR=0
readonly LOG_LEVEL_WARN=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_DEBUG=3

LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"
LOG_FILE="${LOG_FILE:-}"

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    local level_name
    case "$level" in
        "$LOG_LEVEL_ERROR") level_name="ERROR" ;;
        "$LOG_LEVEL_WARN")  level_name="WARN"  ;;
        "$LOG_LEVEL_INFO")  level_name="INFO"  ;;
        "$LOG_LEVEL_DEBUG") level_name="DEBUG" ;;
        *)                  level_name="UNKNOWN" ;;
    esac

    # Skip messages below the current log level
    if [[ "$level" -gt "$LOG_LEVEL" ]]; then
        return 0
    fi

    local formatted="[$timestamp] [$level_name] $message"

    # Write to stderr (so stdout remains clean for data output)
    echo "$formatted" >&2

    # Optionally write to a log file
    if [[ -n "$LOG_FILE" ]]; then
        echo "$formatted" >> "$LOG_FILE"
    fi
}

# Convenience wrappers
log_error() { log_message "$LOG_LEVEL_ERROR" "$@"; }
log_warn()  { log_message "$LOG_LEVEL_WARN"  "$@"; }
log_info()  { log_message "$LOG_LEVEL_INFO"  "$@"; }
log_debug() { log_message "$LOG_LEVEL_DEBUG" "$@"; }
```

Usage:

```bash
log_info "Starting backup of database: $db_name"
log_debug "Using connection string: ${conn_string%%@*}@***"
log_warn "Disk usage at ${usage}% — approaching threshold"
log_error "Backup failed with exit code $rc"
```

```text
[2026-02-20 14:30:00] [INFO] Starting backup of database: taskdb
[2026-02-20 14:30:00] [WARN] Disk usage at 87% — approaching threshold
```

Notice the `log_debug` call strips the password from the connection string using parameter expansion before logging it. Never log credentials.

### Logging to syslog with logger

The **`logger`** command writes to the system log (syslog), which is where your monitoring tools (Week 11 journal, centralized logging) are watching:

```bash
# Basic usage
logger "Backup completed successfully"

# With a tag (appears as the program name in logs)
logger -t "backup-script" "Backup completed successfully"

# With a priority
logger -p local0.info -t "backup-script" "Backup completed"
logger -p local0.err  -t "backup-script" "Backup FAILED"

# View in the journal (Week 11)
journalctl -t backup-script --since "1 hour ago"
```

Syslog priorities follow the same levels as journalctl (Section 11.5):

| Priority | Meaning |
|----------|---------|
| `emerg` | System is unusable |
| `alert` | Immediate action required |
| `crit` | Critical |
| `err` | Error |
| `warning` | Warning |
| `notice` | Normal but significant |
| `info` | Informational |
| `debug` | Debug |

### Combining File Logging and Syslog

```bash
log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[$timestamp] [$level] $message" >&2

    # Also send to syslog for centralized monitoring
    local syslog_priority
    case "$level" in
        ERROR) syslog_priority="err" ;;
        WARN)  syslog_priority="warning" ;;
        INFO)  syslog_priority="info" ;;
        DEBUG) syslog_priority="debug" ;;
        *)     syslog_priority="notice" ;;
    esac
    logger -p "local0.${syslog_priority}" -t "${SCRIPT_NAME:-$(basename "$0")}" "$message"
}
```

This dual-logging pattern ensures your script's output is visible both in its own log file and in the centralized journal. When something goes wrong at 3 AM, the on-call engineer sees the error in the monitoring dashboard without needing to find and read your script's log file.

---

## 14.12 Configuration Files

Hardcoding values in scripts is the fast path to a broken production environment. Configuration should live outside the script so you can change behavior without editing code.

### Sourcing Config Files with .

The **`.`** command (or `source`) reads a file and executes it in the current shell. This is the simplest way to load configuration:

```bash
#!/bin/bash
set -euo pipefail

CONFIG_FILE="${CONFIG_FILE:-/etc/myapp/backup.conf}"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
else
    echo "Warning: Config file not found: $CONFIG_FILE" >&2
fi
```

The config file is plain bash variable assignments:

```bash
# /etc/myapp/backup.conf
BACKUP_DIR="/backups/daily"
RETAIN_DAYS=30
COMPRESS=true
DATABASE_HOST="db-01.internal"
DATABASE_NAME="taskdb"
```

The `# shellcheck source=/dev/null` comment tells ShellCheck (Section 14.15) not to warn about sourcing a file it cannot analyze.

### Defaults with ${VAR:-default}

Always provide sensible defaults so the script works even without a config file. Load defaults *before* sourcing the config:

```bash
#!/bin/bash
set -euo pipefail

# Defaults
BACKUP_DIR="/backups/daily"
RETAIN_DAYS=30
COMPRESS=true
DATABASE_HOST="localhost"
DATABASE_NAME="appdb"
LOG_FILE="/var/log/backup.log"

# Override defaults with config file
CONFIG_FILE="${CONFIG_FILE:-/etc/myapp/backup.conf}"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
fi

# Override config with environment variables (highest priority)
BACKUP_DIR="${BACKUP_DIR_OVERRIDE:-$BACKUP_DIR}"
```

This creates a priority chain: **defaults < config file < environment variables**. Any layer can override the one below it.

### Validating Configuration

Never trust configuration blindly:

```bash
validate_config() {
    local errors=()

    if [[ ! -d "$BACKUP_DIR" ]]; then
        errors+=("BACKUP_DIR does not exist: $BACKUP_DIR")
    fi

    if ! [[ "$RETAIN_DAYS" =~ ^[0-9]+$ ]]; then
        errors+=("RETAIN_DAYS must be a positive integer: $RETAIN_DAYS")
    fi

    if [[ "$RETAIN_DAYS" -lt 1 || "$RETAIN_DAYS" -gt 365 ]]; then
        errors+=("RETAIN_DAYS must be between 1 and 365: $RETAIN_DAYS")
    fi

    if [[ "${#errors[@]}" -gt 0 ]]; then
        echo "Configuration errors:" >&2
        for err in "${errors[@]}"; do
            echo "  - $err" >&2
        done
        exit 1
    fi
}
```

### Using ${VAR:?message} for Required Values

The `${VAR:?message}` syntax exits the script with an error if the variable is unset or empty:

```bash
# These MUST be set — script exits with an error if they're missing
: "${DATABASE_NAME:?DATABASE_NAME must be set in config or environment}"
: "${DATABASE_HOST:?DATABASE_HOST must be set}"
```

The `:` command (colon) does nothing — it exists solely to trigger the parameter expansion. If `DATABASE_NAME` is unset or empty, bash prints the error message and exits.

---

## 14.13 Secrets Handling

Putting passwords, API keys, or tokens directly in scripts is a security incident. Here is how to keep secrets out of your code.

### Rule 1: Never Hardcode Secrets

```bash
# NEVER do this
DB_PASSWORD="super_secret_123"
pg_dump -h db-01 -U admin -W "$DB_PASSWORD" mydb

# This password is now in:
# - Your script file (readable by anyone with file access)
# - Your git history (permanently, even if you delete it later)
# - Process listing (ps aux shows command arguments)
```

### Rule 2: Use Environment Variables

```bash
# Set the secret in the environment (not in the script)
export PGPASSWORD="$DB_PASSWORD"
pg_dump -h db-01 -U admin mydb
unset PGPASSWORD
```

For systemd services (Week 11), put secrets in an environment file with restricted permissions:

```bash
# /etc/myapp/secrets.env (chmod 600, owned by the service user)
DB_PASSWORD=super_secret_123
API_KEY=sk-abc123def456
```

```ini
# In the systemd unit file
[Service]
EnvironmentFile=/etc/myapp/secrets.env
```

### Rule 3: Read Secrets from Files

For scripts that need credentials, read them from a protected file:

```bash
#!/bin/bash
set -euo pipefail

SECRET_FILE="/etc/myapp/db_password"

if [[ ! -f "$SECRET_FILE" ]]; then
    echo "Error: Secret file not found: $SECRET_FILE" >&2
    exit 1
fi

# Check permissions — file should only be readable by owner
perms="$(stat -c '%a' "$SECRET_FILE" 2>/dev/null || stat -f '%Lp' "$SECRET_FILE")"
if [[ "$perms" != "600" && "$perms" != "400" ]]; then
    echo "Error: Secret file has insecure permissions ($perms). Expected 600 or 400." >&2
    exit 1
fi

DB_PASSWORD="$(cat "$SECRET_FILE")"
```

### Rule 4: Use .pgpass for PostgreSQL

PostgreSQL supports a dedicated password file (building on Week 13 database concepts):

```bash
# ~/.pgpass format: hostname:port:database:username:password
echo "db-01:5432:taskdb:admin:secret123" > ~/.pgpass
chmod 600 ~/.pgpass

# Now pg_dump reads the password automatically — no PGPASSWORD needed
pg_dump -h db-01 -U admin taskdb
```

### Rule 5: Never Log Secrets

```bash
# BAD — password visible in logs
log_info "Connecting with password: $DB_PASSWORD"

# GOOD — mask the secret
log_info "Connecting to database $DB_NAME as $DB_USER"
log_debug "Password length: ${#DB_PASSWORD} characters"
```

---

## 14.14 Portable Scripting Notes

Not every system has bash, and not every bash is the same version. Understanding the boundaries keeps your scripts working across environments.

### POSIX sh vs. bash

| Feature | POSIX sh | bash |
|---------|----------|------|
| `[[ ]]` | No | Yes |
| Arrays | No | Yes |
| `${var,,}` case conversion | No | Yes (bash 4+) |
| `set -o pipefail` | No | Yes |
| `local` keyword | No (but widely supported) | Yes |
| Process substitution `<()` | No | Yes |
| `=~` regex matching | No | Yes |
| Associative arrays | No | Yes (bash 4+) |

If your script uses any feature in the "bash" column, use `#!/bin/bash` — not `#!/bin/sh`. On Debian and Ubuntu, `/bin/sh` is `dash` (a minimal POSIX shell), which will fail on bash-specific syntax.

### #!/usr/bin/env bash

The `#!/usr/bin/env bash` shebang finds bash through the `PATH` instead of assuming it is at `/bin/bash`:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

This matters on systems where bash is installed in a non-standard location (FreeBSD, NixOS, Homebrew on macOS). For Linux servers where you control the environment, `#!/bin/bash` is fine. For scripts shared across diverse systems, use `env`.

### Checking Bash Version

Some features require specific bash versions:

```bash
# Associative arrays require bash 4+
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: This script requires bash 4 or later" >&2
    echo "Current version: $BASH_VERSION" >&2
    exit 1
fi
```

### Portability Checklist

| Practice | Portable | Bash-specific |
|----------|----------|---------------|
| Shebang | `#!/bin/sh` | `#!/bin/bash` |
| Tests | `[ -f "$file" ]` | `[[ -f "$file" ]]` |
| Functions | `myfunc() { ...; }` | `function myfunc { ...; }` |
| String comparison | `[ "$a" = "$b" ]` | `[[ "$a" == "$b" ]]` |
| Echo with escapes | `printf '%s\n' "$msg"` | `echo -e "$msg"` |

For the scripts in this course, we use bash features freely because we know our target environment. For scripts you distribute to the wider world, consider POSIX compatibility or explicitly document the bash requirement.

---

## 14.15 ShellCheck

**ShellCheck** is a static analysis tool that catches bugs, style issues, and portability problems in shell scripts. If you write shell scripts professionally, ShellCheck is not optional.

### Installing ShellCheck

```bash
# Ubuntu/Debian
sudo apt install shellcheck

# Rocky/RHEL
sudo dnf install ShellCheck

# macOS
brew install shellcheck
```

### Basic Usage

```bash
shellcheck myscript.sh
```

```text
In myscript.sh line 12:
  echo $greeting
       ^--------^ SC2086: Double quote to prevent globbing and word splitting.

Did you mean:
  echo "$greeting"
```

Each warning includes a code (like `SC2086`) that you can look up for a detailed explanation.

### Common Warnings

| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | Use `"$var"` instead of `$var` |
| SC2034 | Variable appears unused | Remove or export the variable |
| SC2155 | Declare and assign separately | Split `local var="$(cmd)"` into two lines |
| SC2164 | Use `cd ... \|\| exit` | Add error handling after `cd` |
| SC2068 | Double-quote array expansions | Use `"${arr[@]}"` not `${arr[@]}` |
| SC1090 | Can't follow sourced file | Add `# shellcheck source=path` directive |

### The SC2155 Pattern

This is worth highlighting because it surprises people:

```bash
# ShellCheck warns about this:
local output="$(some_command)"

# Why? If some_command fails, local's exit code (always 0) masks the failure.
# With set -e, you will NOT catch the error.

# Fix: separate the declaration and assignment
local output
output="$(some_command)"
```

### Integrating ShellCheck into Your Workflow

```bash
# Check all scripts in a directory
find /usr/local/bin -name "*.sh" -exec shellcheck {} +

# Exclude specific warnings
shellcheck --exclude=SC2034 myscript.sh

# Output in different formats (for CI integration)
shellcheck --format=json myscript.sh
shellcheck --format=gcc myscript.sh
```

### In-Script Directives

Suppress specific warnings for specific lines when you have a good reason:

```bash
# shellcheck disable=SC2034
UNUSED_BUT_EXPORTED_VAR="value"    # Used by sourced scripts

# shellcheck source=/dev/null
. "$CONFIG_FILE"                    # Path is dynamic
```

Use these sparingly and always add a comment explaining why the warning is suppressed.

---

## 14.16 Script Structure Template

Here is the structure I recommend for any non-trivial production script. It follows a clear flow: parse arguments, validate inputs, do work, clean up.

```bash
#!/bin/bash
# =============================================================================
# script_name.sh — Brief description of what this script does
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Constants and defaults
# ---------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly VERSION="1.0.0"

VERBOSE=false
DRY_RUN=false
CONFIG_FILE="/etc/myapp/config.conf"
LOG_FILE=""

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" >&2; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" >&2; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }
log_debug() { "$VERBOSE" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >&2 || true; }

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
TMPDIR=""

cleanup() {
    local exit_code="$?"
    if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
        rm -rf "$TMPDIR"
    fi
    if [[ "$exit_code" -ne 0 ]]; then
        log_error "$SCRIPT_NAME exited with code $exit_code"
    fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <arguments>

Options:
    -v, --verbose     Enable verbose output
    -n, --dry-run     Show what would be done without doing it
    -c, --config      Path to configuration file (default: $CONFIG_FILE)
    -h, --help        Show this help message
    --version         Show version
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -v|--verbose)  VERBOSE=true; shift ;;
            -n|--dry-run)  DRY_RUN=true; shift ;;
            -c|--config)   CONFIG_FILE="${2:?--config requires a value}"; shift 2 ;;
            -h|--help)     usage; exit 0 ;;
            --version)     echo "$VERSION"; exit 0 ;;
            --)            shift; break ;;
            -*)            log_error "Unknown option: $1"; usage >&2; exit 1 ;;
            *)             break ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
validate() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        . "$CONFIG_FILE"
    fi

    # Validate required settings, check prerequisites, etc.
}

# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    validate

    TMPDIR="$(mktemp -d "/tmp/${SCRIPT_NAME}-XXXXXX")"
    log_info "Starting $SCRIPT_NAME (PID $$)"

    # ... your logic here ...

    log_info "$SCRIPT_NAME completed successfully"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main "$@"
```

This template gives you:
- Structured argument parsing with both short and long options
- A cleanup trap that handles temp files
- Logging functions with timestamps
- Configuration file support with defaults
- A `--dry-run` flag for safe testing
- A `--verbose` flag for debugging
- Clear separation of concerns (parsing, validation, logic, cleanup)

---

## 14.17 jq for JSON Processing

Modern infrastructure is built on APIs that speak JSON. Monitoring endpoints, cloud APIs, container orchestration — they all return JSON. **`jq`** is the standard command-line tool for parsing and transforming JSON data.

### Installing jq

```bash
# Ubuntu/Debian
sudo apt install jq

# Rocky/RHEL
sudo dnf install jq
```

### Basic Extraction

```bash
# Pretty-print JSON
echo '{"name":"web-01","status":"active"}' | jq '.'
```

```json
{
  "name": "web-01",
  "status": "active"
}
```

```bash
# Extract a single field
echo '{"name":"web-01","status":"active"}' | jq -r '.name'
```

```text
web-01
```

The `-r` flag outputs raw strings (without quotes). Without it, you get `"web-01"` with the surrounding quotes.

### Working with Arrays

```bash
# Sample JSON (imagine this comes from an API)
json='[
    {"name":"web-01","cpu":45,"memory":72},
    {"name":"web-02","cpu":12,"memory":55},
    {"name":"db-01","cpu":89,"memory":91}
]'

# Extract all names
echo "$json" | jq -r '.[].name'
```

```text
web-01
web-02
db-01
```

```bash
# Filter: servers with CPU > 50%
echo "$json" | jq -r '.[] | select(.cpu > 50) | .name'
```

```text
db-01
```

```bash
# Format as "name: cpu% CPU, memory% memory"
echo "$json" | jq -r '.[] | "\(.name): \(.cpu)% CPU, \(.memory)% memory"'
```

```text
web-01: 45% CPU, 72% memory
web-02: 12% CPU, 55% memory
db-01: 89% CPU, 91% memory
```

### Nested Data

```bash
json='{
    "cluster": "production",
    "nodes": [
        {"name": "node-1", "labels": {"role": "web", "zone": "us-east-1a"}},
        {"name": "node-2", "labels": {"role": "db", "zone": "us-east-1b"}}
    ]
}'

# Extract nested fields
echo "$json" | jq -r '.nodes[].labels.role'
```

```text
web
db
```

```bash
# Build a new JSON structure from existing data
echo "$json" | jq '{cluster: .cluster, node_count: (.nodes | length)}'
```

```json
{
  "cluster": "production",
  "node_count": 2
}
```

### Common jq Patterns for Scripts

```bash
# Get the length of an array
echo "$json" | jq '.nodes | length'     # 2

# Check if a field exists
echo "$json" | jq 'has("cluster")'      # true

# Sort an array of objects
echo '[{"n":3},{"n":1},{"n":2}]' | jq 'sort_by(.n)'

# Get unique values
echo '["a","b","a","c","b"]' | jq 'unique'

# Combine with curl to query APIs
curl -sf "https://api.github.com/repos/torvalds/linux" | jq -r '.stargazers_count'
```

### Processing API Responses in Scripts

A practical example that ties jq into the scripting patterns from this week:

```bash
#!/bin/bash
set -euo pipefail

API_URL="${API_URL:-https://api.example.com}"
API_TOKEN="${API_TOKEN:?API_TOKEN must be set}"

log_info() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >&2; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; }

# Fetch server list from API
response="$(curl -sf -H "Authorization: Bearer $API_TOKEN" "$API_URL/servers")" || {
    log_error "Failed to fetch server list from API"
    exit 1
}

# Parse and iterate
mapfile -t servers < <(echo "$response" | jq -r '.[].hostname')

log_info "Found ${#servers[@]} servers"

for server in "${servers[@]}"; do
    status="$(echo "$response" | jq -r --arg name "$server" '.[] | select(.hostname == $name) | .status')"
    log_info "Server $server: $status"
done
```

The `--arg name "$server"` syntax passes a shell variable into jq safely — it handles quoting and escaping automatically. Never embed shell variables directly in jq expressions with string interpolation.

### jq Quick Reference

| Expression | Result |
|------------|--------|
| `.field` | Extract a field |
| `.field.subfield` | Extract nested field |
| `.[0]` | First array element |
| `.[]` | Iterate over array |
| `\| select(.x > 5)` | Filter elements |
| `\| length` | Count elements |
| `\| keys` | Get object keys |
| `\| sort_by(.field)` | Sort array by field |
| `\| map(.field)` | Transform each element |
| `-r` flag | Raw output (no quotes) |
| `--arg name val` | Pass shell variable to jq |

---

## What's Next

You now have the advanced patterns that separate a learning exercise from a production script: argument parsing, file locking, structured logging, temp file management, configuration handling, and JSON processing with jq.

The backup script in Lab 14.2 is the same one you will automate with a systemd timer and eventually run inside a container. The patterns you practice here carry forward directly into infrastructure work.

In Week 15, we move from writing scripts to managing the network layer — understanding how Linux handles IP addresses, routing, DNS, firewalls, and troubleshooting connectivity issues.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 14.1: Log Rotator Script](labs/lab_01_log_rotator.sh)** — Build a log rotation script with argument parsing, file locking, and logging
- **[Lab 14.2: Database Backup Script](labs/lab_02_db_backup_script.sh)** — Build a database backup script tying together Weeks 8, 11, 13, and 14

---

## Checklist

Before moving to Week 15, confirm you can:

- [ ] Use trap to clean up temporary files and lock files on script exit
- [ ] Create and use temporary files safely with mktemp
- [ ] Parse both short (-v) and long (--verbose) command-line options
- [ ] Use indexed and associative arrays in bash
- [ ] Generate configuration files using here documents in scripts
- [ ] Use flock to prevent concurrent script execution
- [ ] Write a logging function with timestamps and severity levels
- [ ] Source configuration from external files with sensible defaults
- [ ] Use jq to parse and filter JSON from the command line
- [ ] Lint scripts with ShellCheck and fix common warnings

---

[← Previous Week](../week-13/README.md) · [Next Week →](../week-15/README.md)
