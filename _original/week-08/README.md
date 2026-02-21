# Week 8: Bash Scripting Fundamentals

> **Goal:** Write bash scripts that automate common server administration tasks using variables, conditionals, loops, and functions.

[← Previous Week](../week-07/README.md) · [Next Week →](../week-09/README.md)

---

## Table of Contents

| Section | Topic |
|---------|-------|
| 8.1  | [Why Scripting Matters](#81-why-scripting-matters) |
| 8.2  | [Script Structure](#82-script-structure) |
| 8.3  | [Making Scripts Executable](#83-making-scripts-executable) |
| 8.4  | [Variables](#84-variables) |
| 8.5  | [Special Variables](#85-special-variables) |
| 8.6  | [User Input](#86-user-input) |
| 8.7  | [Conditionals](#87-conditionals) |
| 8.8  | [String Comparisons](#88-string-comparisons) |
| 8.9  | [Numeric Comparisons](#89-numeric-comparisons) |
| 8.10 | [File Tests](#810-file-tests) |
| 8.11 | [Compound Conditions](#811-compound-conditions) |
| 8.12 | [Loops](#812-loops) |
| 8.13 | [Case Statements](#813-case-statements) |
| 8.14 | [Functions](#814-functions) |
| 8.15 | [Exit Codes and Error Handling](#815-exit-codes-and-error-handling) |
| 8.16 | [Arithmetic](#816-arithmetic) |
| 8.17 | [String Manipulation](#817-string-manipulation) |

---

## 8.1 Why Scripting Matters

You already know how to run commands one at a time. That's fine for exploration, but production work demands something more: repeatability. If you typed ten commands to deploy a service at 2 PM, can you type the exact same ten commands at 2 AM when the pager goes off? Probably not. A script can.

Here is what bash scripting gives you:

**Automation** — Tasks you do more than once belong in a script. Server provisioning, log rotation, backups, user creation — all of these become one-command operations.

**Reproducibility** — A script produces the same result every time. No forgotten steps, no typos, no "I thought I ran that command." When an auditor asks how you configured the firewall, you hand them a script.

**Incident response** — At 3 AM, your brain is running at half speed. A well-written diagnostic script collects hostname, uptime, memory, disk, recent logs, and network state in seconds. You paste the output into the incident channel and start troubleshooting with real data.

**Deployment** — Before configuration management tools like Ansible existed, bash scripts deployed entire infrastructures. Even today, scripts handle bootstrapping, CI/CD pipelines, container entrypoints, and cloud-init sequences.

The goal is not to write software in bash. If a task needs data structures, error handling across network calls, or anything beyond a few hundred lines, reach for Python or Go. Bash excels at gluing commands together — and that is exactly what server administration demands.

---

## 8.2 Script Structure

Every bash script you write should start with three things: a **shebang**, a comment block, and **strict mode**.

```bash
#!/bin/bash
# =============================================================================
# backup_logs.sh — Archive and compress log files older than 7 days
# Author: ops-team
# Last modified: 2026-02-20
# =============================================================================

set -euo pipefail
```

### The Shebang

The first line, `#!/bin/bash`, is the **shebang** (also called a hashbang). It tells the kernel which interpreter to use when the script is executed directly. Without it, the system guesses — and guesses wrong more often than you would like.

| Shebang | Interpreter |
|---------|-------------|
| `#!/bin/bash` | Bash (most common for admin scripts) |
| `#!/bin/sh` | POSIX shell (more portable, fewer features) |
| `#!/usr/bin/env bash` | Find bash via PATH (useful if bash is not at /bin/bash) |
| `#!/usr/bin/env python3` | Python 3 |

Use `#!/bin/bash` for scripts that use bash-specific features (which we will). Use `#!/bin/sh` only when strict POSIX portability matters.

### Comments

Comments start with `#` and run to the end of the line. Use them to explain *why*, not *what*. The code already says what it does.

```bash
# Bad comment — restates the code
count=0  # Set count to 0

# Good comment — explains intent
count=0  # Reset retry counter before each connection attempt
```

A header block at the top with the script's purpose, author, and date saves future-you twenty minutes of archaeology.

### Strict Mode: set -euo pipefail

This single line prevents an enormous category of bugs. Let's break it down:

| Flag | Behavior | Without It |
|------|----------|------------|
| `-e` | Exit immediately if any command fails (returns non-zero) | Script continues after failures, causing cascading damage |
| `-u` | Treat unset variables as errors | Unset variables silently expand to empty strings |
| `-o pipefail` | A pipeline fails if *any* command in it fails, not just the last one | `curl ... \| grep ...` succeeds even if curl fails |

Here is what happens without strict mode:

```bash
#!/bin/bash
# Dangerous: no strict mode
cd /opt/myapp
rm -rf *
```

If `/opt/myapp` does not exist, `cd` fails but the script continues. The `rm -rf *` runs in whatever directory you happened to be in. With `set -e`, the script exits at the failed `cd`.

Here is what `-u` catches:

```bash
set -u
echo "Deploying to $TAGET_DIR"   # Typo: TAGET instead of TARGET
# bash: TAGET_DIR: unbound variable
```

Without `-u`, `$TAGET_DIR` silently becomes an empty string. You deploy to the wrong place and spend an hour figuring out why.

And `-o pipefail`:

```bash
set -o pipefail
curl -s https://example.com/data.json | jq '.items[]'
# If curl fails, the pipeline returns curl's error code, not jq's success
```

Put all three together. Always.

```bash
set -euo pipefail
```

---

## 8.3 Making Scripts Executable

You have written a script. Now you need to run it. There are two approaches.

### Method 1: Make It Executable

```bash
chmod +x myscript.sh
./myscript.sh
```

The `chmod +x` adds execute permission. The `./` prefix tells the shell to look in the current directory — without it, bash searches `$PATH` and will not find your script.

### Method 2: Pass It to Bash Directly

```bash
bash myscript.sh
```

This works even without execute permission because bash reads the file as input. The shebang is ignored since you are explicitly choosing the interpreter.

### Which to Use

For scripts you will run repeatedly, use Method 1. It is cleaner and the shebang documents the intended interpreter. For quick one-off tests during development, Method 2 is fine.

Verify permissions after `chmod`:

```bash
ls -l myscript.sh
```

Expected output:

```text
-rwxr-xr-x 1 admin admin 1234 Feb 20 14:30 myscript.sh
```

The `x` in positions 4, 7, and 10 confirms execute permission for owner, group, and others.

---

## 8.4 Variables

**Variables** in bash store data for later use. The syntax is straightforward but unforgiving about whitespace.

### Assignment

```bash
# Correct — no spaces around =
hostname="web-server-01"
port=8080
log_dir="/var/log/myapp"

# WRONG — bash interprets this as a command called "hostname" with arguments "=" and "web-server-01"
hostname = "web-server-01"   # Error!
```

No spaces around the `=`. This is the single most common bash syntax mistake for newcomers.

### Accessing Variables

Use `$` to expand a variable. Use `"$VAR"` (with quotes) to prevent word splitting and globbing:

```bash
name="hello world"

# Unquoted — bash splits on spaces, treats as two words
echo $name      # Works here, but fragile

# Quoted — preserves the value exactly
echo "$name"    # Always do this
```

Use `${VAR}` (braces) when you need to disambiguate the variable name from surrounding text:

```bash
prefix="backup"
echo "${prefix}_2026.tar.gz"   # backup_2026.tar.gz
echo "$prefix_2026.tar.gz"     # Tries to expand $prefix_2026 — probably empty
```

### Command Substitution

Capture command output in a variable with `$()`:

```bash
current_date="$(date +%Y-%m-%d)"
cpu_count="$(nproc)"
free_mem="$(free -m | awk '/^Mem:/ {print $4}')"

echo "Date: $current_date, CPUs: $cpu_count, Free RAM: ${free_mem}MB"
```

Always quote command substitutions: `"$(command)"`. The output might contain spaces.

### Environment vs. Local Variables

```bash
# Local to this script
my_var="local"

# Exported to child processes
export MY_VAR="visible to child processes"
```

Convention: local variables use lowercase, environment variables use UPPERCASE.

### Readonly Variables

```bash
readonly CONFIG_FILE="/etc/myapp/config.yaml"
CONFIG_FILE="/other/path"   # Error: CONFIG_FILE: readonly variable
```

---

## 8.5 Special Variables

Bash provides built-in variables that carry information about the script, its arguments, and the last command executed.

| Variable | Meaning | Example Value |
|----------|---------|---------------|
| `$0` | Script name (as invoked) | `./deploy.sh` |
| `$1` .. `$9` | Positional parameters (arguments) | First through ninth argument |
| `${10}` | Tenth argument and beyond (braces required) | Tenth argument |
| `$#` | Number of arguments passed | `3` |
| `$@` | All arguments as separate words | `"arg1" "arg2" "arg3"` |
| `$*` | All arguments as a single string | `"arg1 arg2 arg3"` |
| `$?` | Exit code of the last command | `0` (success) or `1`-`255` (failure) |
| `$$` | PID of the current script | `12345` |
| `$!` | PID of the last background process | `12346` |

The difference between `$@` and `$*` matters when arguments contain spaces:

```bash
#!/bin/bash
# save as test_args.sh

echo "Using \$@:"
for arg in "$@"; do
    echo "  Argument: $arg"
done

echo "Using \$*:"
for arg in "$*"; do
    echo "  Argument: $arg"
done
```

```bash
./test_args.sh "hello world" "foo bar"
```

Expected output:

```text
Using $@:
  Argument: hello world
  Argument: foo bar
Using $*:
  Argument: hello world foo bar
```

`"$@"` preserves argument boundaries. `"$*"` joins everything into one string. Use `"$@"` when iterating over arguments.

---

## 8.6 User Input

Scripts need data from the outside world. There are two primary sources: command-line arguments and interactive input.

### Command-Line Arguments

The most common approach. Arguments land in `$1`, `$2`, and so on:

```bash
#!/bin/bash
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
    echo "Usage: $0 <source_dir> <dest_dir>" >&2
    exit 1
fi

source_dir="$1"
dest_dir="$2"

echo "Copying from $source_dir to $dest_dir"
```

### The shift Command

**`shift`** removes the first positional parameter and shifts the rest down. `$2` becomes `$1`, `$3` becomes `$2`, and so on. This is useful for processing flags before arguments:

```bash
#!/bin/bash
set -euo pipefail

verbose=false

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -v|--verbose) verbose=true; shift ;;
        *)            break ;;
    esac
done

if "$verbose"; then
    echo "Verbose mode enabled"
fi

echo "Remaining arguments: $*"
```

```bash
./myscript.sh -v file1.txt file2.txt
```

Expected output:

```text
Verbose mode enabled
Remaining arguments: file1.txt file2.txt
```

### Interactive Input with read

The **`read`** builtin reads a line from standard input:

```bash
#!/bin/bash
set -euo pipefail

read -rp "Enter your name: " username
echo "Hello, $username"

# -r  prevents backslash interpretation
# -p  displays a prompt
# -s  hides input (useful for passwords)
# -t  sets a timeout in seconds

read -rsp "Enter password: " password
echo    # Add a newline after hidden input
echo "Password is ${#password} characters long"
```

Prefer command-line arguments over interactive input. Scripts that require interactive input cannot be automated — they break in cron jobs, CI pipelines, and remote execution. Use `read` only for scripts that genuinely need human confirmation.

---

## 8.7 Conditionals

**Conditionals** let scripts make decisions. The basic structure:

```bash
if [[ condition ]]; then
    # commands if condition is true
elif [[ other_condition ]]; then
    # commands if other_condition is true
else
    # commands if nothing matched
fi
```

### [[ ]] vs [ ]

Bash provides two test syntaxes:

| Feature | `[ ]` (test) | `[[ ]]` (bash keyword) |
|---------|-------------|----------------------|
| Word splitting | Yes (must quote variables) | No (safer) |
| Glob expansion | Yes (surprising) | No |
| Pattern matching | No | Yes (`==` with globs) |
| Regex matching | No | Yes (`=~`) |
| `&&` and `\|\|` inside | No (use `-a` and `-o`) | Yes |
| Portability | POSIX (works in sh) | Bash/Zsh only |

Use `[[ ]]` in bash scripts. It is safer, more readable, and more powerful. The only reason to use `[ ]` is if you are writing a POSIX `#!/bin/sh` script.

```bash
# Prefer this:
if [[ -f "$config_file" ]]; then
    echo "Config found"
fi

# Over this:
if [ -f "$config_file" ]; then
    echo "Config found"
fi
```

Both work here, but `[[ ]]` will save you from quoting bugs and gives you pattern matching.

---

## 8.8 String Comparisons

| Operator | Meaning | Example |
|----------|---------|---------|
| `==` | Equal | `[[ "$name" == "admin" ]]` |
| `!=` | Not equal | `[[ "$name" != "root" ]]` |
| `-z` | String is empty (zero length) | `[[ -z "$name" ]]` |
| `-n` | String is non-empty | `[[ -n "$name" ]]` |
| `=~` | Regex match | `[[ "$email" =~ ^[a-z]+@[a-z]+\.[a-z]+$ ]]` |
| `<` | Lexicographically less than | `[[ "$a" < "$b" ]]` |
| `>` | Lexicographically greater than | `[[ "$a" > "$b" ]]` |

Examples:

```bash
#!/bin/bash
set -euo pipefail

username="${1:-}"

# Check if argument was provided
if [[ -z "$username" ]]; then
    echo "Usage: $0 <username>" >&2
    exit 1
fi

# Exact match
if [[ "$username" == "root" ]]; then
    echo "Warning: running as root"
fi

# Pattern match (glob — only in [[ ]])
if [[ "$username" == admin* ]]; then
    echo "Admin user detected"
fi

# Regex match
if [[ "$username" =~ ^[a-z][a-z0-9_]{2,15}$ ]]; then
    echo "Username format is valid"
else
    echo "Username must be 3-16 chars, lowercase, starting with a letter" >&2
    exit 1
fi
```

Note the `${1:-}` default value syntax — this prevents `set -u` from complaining when no argument is passed. The `:-` provides an empty string as the default.

---

## 8.9 Numeric Comparisons

For integer comparisons inside `[[ ]]`, use these operators:

| Operator | Meaning | Example |
|----------|---------|---------|
| `-eq` | Equal | `[[ "$count" -eq 0 ]]` |
| `-ne` | Not equal | `[[ "$count" -ne 0 ]]` |
| `-lt` | Less than | `[[ "$load" -lt 80 ]]` |
| `-gt` | Greater than | `[[ "$load" -gt 90 ]]` |
| `-le` | Less than or equal | `[[ "$count" -le 10 ]]` |
| `-ge` | Greater than or equal | `[[ "$count" -ge 1 ]]` |

Do not use `==`, `<`, or `>` for numeric comparisons — those perform string comparison. `"9" > "10"` is true lexicographically but false numerically.

```bash
#!/bin/bash
set -euo pipefail

disk_usage="$(df / | awk 'NR==2 {print $5}' | tr -d '%')"

if [[ "$disk_usage" -ge 90 ]]; then
    echo "CRITICAL: Disk usage at ${disk_usage}%"
elif [[ "$disk_usage" -ge 75 ]]; then
    echo "WARNING: Disk usage at ${disk_usage}%"
else
    echo "OK: Disk usage at ${disk_usage}%"
fi
```

You can also use arithmetic evaluation with `(( ))`, which supports standard math operators:

```bash
count=5
if (( count > 3 )); then
    echo "Count exceeds 3"
fi
```

Inside `(( ))`, you do not need `$` before variable names (though it works with `$` too).

---

## 8.10 File Tests

**File test operators** check properties of files and directories. These are some of the most frequently used tests in system administration scripts.

| Operator | Tests for | Example |
|----------|-----------|---------|
| `-f` | Regular file exists | `[[ -f "/etc/hosts" ]]` |
| `-d` | Directory exists | `[[ -d "/var/log" ]]` |
| `-e` | Anything exists (file, directory, link, etc.) | `[[ -e "$path" ]]` |
| `-r` | Readable by current user | `[[ -r "$config" ]]` |
| `-w` | Writable by current user | `[[ -w "$log_file" ]]` |
| `-x` | Executable by current user | `[[ -x "$script" ]]` |
| `-s` | File exists and has size > 0 | `[[ -s "$log_file" ]]` |
| `-L` | Symbolic link | `[[ -L "$path" ]]` |

Practical example — a script that checks prerequisites before running:

```bash
#!/bin/bash
set -euo pipefail

CONFIG="/etc/myapp/config.yaml"
LOG_DIR="/var/log/myapp"
DATA_DIR="/opt/myapp/data"

# Check config file
if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Config file not found: $CONFIG" >&2
    exit 1
fi

if [[ ! -r "$CONFIG" ]]; then
    echo "ERROR: Config file not readable: $CONFIG" >&2
    exit 1
fi

# Ensure directories exist
for dir in "$LOG_DIR" "$DATA_DIR"; do
    if [[ ! -d "$dir" ]]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
done

# Check if log file is non-empty (has data to process)
if [[ -s "$LOG_DIR/app.log" ]]; then
    echo "Processing existing log data..."
else
    echo "No log data to process yet."
fi
```

---

## 8.11 Compound Conditions

Combine conditions with logical operators:

| Operator | Meaning | Context |
|----------|---------|---------|
| `&&` | AND | Inside `[[ ]]` or between commands |
| `\|\|` | OR | Inside `[[ ]]` or between commands |
| `!` | NOT | Inside `[[ ]]` |

### Inside [[ ]]

```bash
# AND — both must be true
if [[ -f "$file" && -r "$file" ]]; then
    echo "File exists and is readable"
fi

# OR — either can be true
if [[ "$env" == "staging" || "$env" == "production" ]]; then
    echo "Deploying to $env"
fi

# NOT — negate the condition
if [[ ! -d "$backup_dir" ]]; then
    mkdir -p "$backup_dir"
fi

# Combined
if [[ -f "$file" && ! -L "$file" ]]; then
    echo "Regular file (not a symlink)"
fi
```

### Between Commands

`&&` and `||` also work as command connectors:

```bash
# Run second command only if first succeeds
mkdir -p "$dir" && echo "Directory created"

# Run second command only if first fails
cd "$dir" || { echo "Cannot cd to $dir" >&2; exit 1; }
```

The `{ ...; }` grouping is important — without it, only the `echo` runs on failure, and the `exit 1` runs unconditionally.

---

## 8.12 Loops

### For Loop — Iterating Over a List

The **for loop** iterates over a list of items:

```bash
# Iterate over explicit values
for service in sshd cron nginx; do
    echo "Checking $service..."
    systemctl is-active "$service" || true
done

# Iterate over files
for file in /var/log/*.log; do
    if [[ -f "$file" ]]; then
        echo "$file: $(wc -l < "$file") lines"
    fi
done

# Iterate over command output (careful with word splitting)
for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    echo "Regular user: $user"
done
```

### C-Style For Loop

When you need a numeric counter:

```bash
for (( i = 0; i < 10; i++ )); do
    echo "Iteration $i"
done

# Countdown
for (( i = 5; i > 0; i-- )); do
    echo "$i..."
    sleep 1
done
echo "Done!"
```

### While Loop

The **while loop** runs as long as a condition is true:

```bash
# Retry a command up to 5 times
attempt=1
max_attempts=5

while [[ "$attempt" -le "$max_attempts" ]]; do
    echo "Attempt $attempt of $max_attempts..."
    if curl -sf "http://localhost:8080/health" > /dev/null; then
        echo "Service is healthy!"
        break
    fi
    sleep 2
    (( attempt++ ))
done

if [[ "$attempt" -gt "$max_attempts" ]]; then
    echo "Service failed to respond after $max_attempts attempts" >&2
    exit 1
fi
```

### Until Loop

The **until loop** runs until a condition becomes true (the opposite of while):

```bash
# Wait for a file to appear
until [[ -f "/tmp/ready.flag" ]]; do
    echo "Waiting for ready flag..."
    sleep 5
done
echo "Ready flag detected!"
```

### Reading Files Line by Line

This is one of the most common patterns in administration scripts:

```bash
# Read a file line by line
while IFS= read -r line; do
    echo "Processing: $line"
done < "/etc/hosts"

# IFS=    prevents leading/trailing whitespace trimming
# -r      prevents backslash interpretation
# < file  redirects the file into the loop
```

Process a CSV-like file by splitting fields:

```bash
# Read /etc/passwd and extract fields
while IFS=: read -r username _ uid gid _ home shell; do
    if [[ "$uid" -ge 1000 ]]; then
        echo "User: $username, UID: $uid, Home: $home, Shell: $shell"
    fi
done < /etc/passwd
```

Process command output line by line (safer than `for` with command substitution):

```bash
# List listening ports — line by line is safer than word splitting
ss -tlnp | while IFS= read -r line; do
    echo "$line"
done
```

### Loop Control

| Command | Effect |
|---------|--------|
| `break` | Exit the loop immediately |
| `continue` | Skip to the next iteration |
| `break 2` | Break out of two nested loops |

```bash
for file in /var/log/*.log; do
    if [[ ! -r "$file" ]]; then
        echo "Skipping unreadable: $file"
        continue
    fi
    if [[ "$(wc -l < "$file")" -gt 1000000 ]]; then
        echo "Found large log: $file"
        break
    fi
done
```

---

## 8.13 Case Statements

**Case statements** handle multi-branch logic more cleanly than long `if/elif` chains. They are especially common for parsing command-line options and matching patterns.

```bash
#!/bin/bash
set -euo pipefail

action="${1:-}"

case "$action" in
    start)
        echo "Starting service..."
        ;;
    stop)
        echo "Stopping service..."
        ;;
    restart)
        echo "Restarting service..."
        ;;
    status)
        echo "Checking status..."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}" >&2
        exit 1
        ;;
esac
```

Each pattern ends with `)`. Each block ends with `;;`. The `*)` pattern is the default (like `else`).

### Pattern Matching in Case

Case supports glob patterns, making it powerful for string classification:

```bash
read -rp "Continue? (yes/no): " answer

case "$answer" in
    [Yy]|[Yy][Ee][Ss])
        echo "Proceeding..."
        ;;
    [Nn]|[Nn][Oo])
        echo "Aborting."
        exit 0
        ;;
    *)
        echo "Invalid response: $answer" >&2
        exit 1
        ;;
esac
```

### Multiple Patterns

Separate patterns with `|` (OR):

```bash
case "$distro" in
    ubuntu|debian|mint)
        pkg_manager="apt"
        ;;
    rocky|centos|rhel|fedora|almalinux)
        pkg_manager="dnf"
        ;;
    arch|manjaro)
        pkg_manager="pacman"
        ;;
    *)
        echo "Unsupported distro: $distro" >&2
        exit 1
        ;;
esac

echo "Using package manager: $pkg_manager"
```

This is a pattern you will use constantly. Detecting the distribution and branching accordingly is at the heart of writing scripts that work on both Ubuntu and Rocky Linux:

```bash
#!/bin/bash
set -euo pipefail

# Detect distro
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    distro_id="${ID:-unknown}"
else
    distro_id="unknown"
fi

case "$distro_id" in
    ubuntu|debian)
        sudo apt update && sudo apt install -y nginx
        ;;
    rocky|centos|rhel)
        sudo dnf install -y nginx
        ;;
    *)
        echo "Unsupported distribution: $distro_id" >&2
        exit 1
        ;;
esac
```

---

## 8.14 Functions

**Functions** group commands into reusable, named blocks. They make scripts readable, testable, and maintainable.

### Declaration

```bash
# Style 1 (preferred — more portable)
get_hostname() {
    hostname -f
}

# Style 2 (function keyword — bash-specific)
function get_hostname {
    hostname -f
}
```

Both work in bash. Style 1 is more widely compatible.

### Calling Functions

```bash
# Call it like any command
get_hostname

# Capture output
my_host="$(get_hostname)"
echo "Host: $my_host"
```

### Local Variables

By default, variables in functions are global. Use **`local`** to scope them:

```bash
calculate_percentage() {
    local used="$1"
    local total="$2"
    local percent

    if [[ "$total" -eq 0 ]]; then
        echo "0"
        return
    fi

    percent=$(( (used * 100) / total ))
    echo "$percent"
}

result="$(calculate_percentage 750 1000)"
echo "Usage: ${result}%"
```

Without `local`, the variables `used`, `total`, and `percent` would leak into the global scope, potentially overwriting variables in the caller.

### Return Values vs. stdout Capture

Bash functions communicate results in two ways:

**Return codes** (0-255) — for success/failure:

```bash
is_root() {
    [[ "$(id -u)" -eq 0 ]]
}

if is_root; then
    echo "Running as root"
else
    echo "Not root"
fi
```

The `[[ ... ]]` test inside the function sets the return code automatically — 0 (true) if the test passes, 1 (false) if it fails.

**stdout capture** — for returning data:

```bash
get_memory_mb() {
    free -m | awk '/^Mem:/ {print $2}'
}

total_mem="$(get_memory_mb)"
echo "Total memory: ${total_mem}MB"
```

Do not use `return` to pass back data. `return` only handles integers 0-255. Print data to stdout and capture it with `$()`.

### Functions with Arguments

Functions receive arguments the same way scripts do — via `$1`, `$2`, `$#`, and `$@`:

```bash
log_message() {
    local level="$1"
    local message="$2"
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] [$level] $message"
}

log_message "INFO" "Script started"
log_message "WARN" "Disk usage above 80%"
log_message "ERROR" "Service failed to start"
```

Expected output:

```text
[2026-02-20 14:30:00] [INFO] Script started
[2026-02-20 14:30:00] [WARN] Disk usage above 80%
[2026-02-20 14:30:00] [ERROR] Service failed to start
```

---

## 8.15 Exit Codes and Error Handling

Every command returns an **exit code**: 0 for success, 1-255 for failure. Your scripts should both check and set exit codes properly.

### Checking Exit Codes

```bash
# Method 1: Check $? directly
grep -q "error" /var/log/syslog
if [[ "$?" -eq 0 ]]; then
    echo "Errors found in syslog"
fi

# Method 2: Use the command directly in the if (preferred)
if grep -q "error" /var/log/syslog; then
    echo "Errors found in syslog"
fi
```

Method 2 is cleaner. The `if` statement checks the exit code of the command directly.

### Inline Error Handling

```bash
# Exit if a command fails
cd /opt/myapp || exit 1

# Exit with a message
cd /opt/myapp || { echo "Failed to cd to /opt/myapp" >&2; exit 1; }

# Provide a default if a command fails
config_value="$(grep "^port=" config.ini 2>/dev/null || echo "port=8080")"
```

### The trap Command

**`trap`** runs a command when the script exits or receives a signal. It is essential for cleanup:

```bash
#!/bin/bash
set -euo pipefail

TMPDIR=""

cleanup() {
    if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
        echo "Cleaning up temp directory: $TMPDIR"
        rm -rf "$TMPDIR"
    fi
}

trap cleanup EXIT

TMPDIR="$(mktemp -d)"
echo "Working in $TMPDIR"

# ... do work in $TMPDIR ...
# cleanup runs automatically when the script exits, whether by success,
# error (set -e), or signal (Ctrl+C)
```

| Trap Signal | When It Fires |
|-------------|---------------|
| `EXIT` | Script exits (any reason) |
| `ERR` | A command fails (with `set -e`) |
| `INT` | Ctrl+C (SIGINT) |
| `TERM` | kill command (SIGTERM) |

The `EXIT` trap is the most useful — it fires regardless of how the script ends. Use it for cleanup.

### Setting Exit Codes in Your Scripts

```bash
#!/bin/bash
set -euo pipefail

check_disk_space() {
    local usage
    usage="$(df / | awk 'NR==2 {print $5}' | tr -d '%')"

    if [[ "$usage" -gt 95 ]]; then
        echo "CRITICAL: ${usage}% disk usage" >&2
        return 2   # Critical
    elif [[ "$usage" -gt 85 ]]; then
        echo "WARNING: ${usage}% disk usage" >&2
        return 1   # Warning
    fi
    echo "OK: ${usage}% disk usage"
    return 0       # OK
}

# Temporarily disable set -e to capture the return code
set +e
check_disk_space
result="$?"
set -e

case "$result" in
    0) echo "Disk check passed" ;;
    1) echo "Disk check warning" ;;
    2) echo "Disk check critical"; exit 1 ;;
esac
```

---

## 8.16 Arithmetic

Bash handles integer arithmetic natively. For floating-point, you need external tools.

### $(( )) — Arithmetic Expansion

```bash
a=10
b=3

echo "Sum:        $(( a + b ))"      # 13
echo "Difference: $(( a - b ))"      # 7
echo "Product:    $(( a * b ))"      # 30
echo "Division:   $(( a / b ))"      # 3 (integer division!)
echo "Modulo:     $(( a % b ))"      # 1
echo "Power:      $(( a ** 2 ))"     # 100
```

Note that division is integer-only. `10 / 3` gives `3`, not `3.333`.

### Incrementing and Decrementing

```bash
count=0
(( count++ ))   # count is now 1
(( count += 5 ))  # count is now 6
(( count-- ))   # count is now 5
```

### let

The **`let`** command is an alternative syntax:

```bash
let "result = 5 + 3"
let "result += 2"
echo "$result"   # 10
```

`$(( ))` is preferred in modern scripts because it is more readable.

### Floating-Point Arithmetic

Bash cannot do floating-point math. Use `bc` or `awk`:

```bash
# Using bc
result="$(echo "scale=2; 10 / 3" | bc)"
echo "$result"   # 3.33

# Using awk
result="$(awk 'BEGIN {printf "%.2f", 10/3}')"
echo "$result"   # 3.33
```

A practical example — calculating percentage with decimals:

```bash
used=7534
total=16384
percent="$(awk "BEGIN {printf \"%.1f\", ($used / $total) * 100}")"
echo "Memory usage: ${percent}%"   # Memory usage: 46.0%
```

---

## 8.17 String Manipulation

Bash has powerful built-in string manipulation that avoids calling external commands like `sed` or `awk` for simple operations.

### String Length

```bash
path="/var/log/syslog"
echo "${#path}"   # 15
```

### Substrings

```bash
str="Hello, World!"
echo "${str:0:5}"    # Hello   (offset 0, length 5)
echo "${str:7}"      # World!  (offset 7 to end)
echo "${str: -6}"    # orld!   (last 6 chars — note the space before -)
```

### Pattern Removal

| Syntax | Action | Example |
|--------|--------|---------|
| `${var#pattern}` | Remove shortest match from start | `${path#*/}` |
| `${var##pattern}` | Remove longest match from start | `${path##*/}` (filename) |
| `${var%pattern}` | Remove shortest match from end | `${path%/*}` (directory) |
| `${var%%pattern}` | Remove longest match from end | `${path%%/*}` |

```bash
filepath="/var/log/nginx/access.log"

# Extract filename (remove everything up to last /)
echo "${filepath##*/}"    # access.log

# Extract directory (remove everything after last /)
echo "${filepath%/*}"     # /var/log/nginx

# Extract extension (remove everything up to last .)
echo "${filepath##*.}"    # log

# Remove extension (remove everything after last .)
echo "${filepath%.*}"     # /var/log/nginx/access
```

### Search and Replace

```bash
text="Hello World World"

# Replace first occurrence
echo "${text/World/Bash}"       # Hello Bash World

# Replace all occurrences
echo "${text//World/Bash}"      # Hello Bash Bash

# Replace at beginning
echo "${text/#Hello/Goodbye}"   # Goodbye World World

# Replace at end
echo "${text/%World/Bash}"      # Hello World Bash
```

### Case Conversion (Bash 4+)

```bash
name="John Doe"
echo "${name^^}"    # JOHN DOE    (uppercase)
echo "${name,,}"    # john doe    (lowercase)

mixed="hElLo"
echo "${mixed^}"    # HElLo       (capitalize first letter)
```

### Default Values

```bash
# Use default if variable is unset or empty
echo "${EDITOR:-vim}"       # Uses vim if EDITOR is unset/empty

# Use default if variable is unset (but not if empty)
echo "${EDITOR-vim}"        # Uses vim only if EDITOR is unset

# Set variable to default if unset or empty
: "${LOG_DIR:=/var/log/myapp}"   # Sets LOG_DIR if unset/empty
echo "$LOG_DIR"
```

### Putting It Together

Here is a practical example that combines several string operations:

```bash
#!/bin/bash
set -euo pipefail

# Rotate a log file by appending the date
rotate_log() {
    local log_file="$1"
    local dir="${log_file%/*}"
    local filename="${log_file##*/}"
    local base="${filename%.*}"
    local ext="${filename##*.}"
    local date_stamp

    date_stamp="$(date +%Y%m%d)"

    local new_name="${dir}/${base}-${date_stamp}.${ext}"
    echo "Rotating: $log_file -> $new_name"
}

rotate_log "/var/log/nginx/access.log"
# Output: Rotating: /var/log/nginx/access.log -> /var/log/nginx/access-20260220.log
```

---

## What's Next

We have covered the core building blocks of bash scripting: variables, conditionals, loops, functions, error handling, arithmetic, and string manipulation. These are the tools you will reach for every day.

We will build on these fundamentals in Week 14 with argument parsing (`getopts`), arrays, associative arrays, file locking, process substitution, and production-grade patterns for scripts that run in cron jobs and deployment pipelines.

For now, head to the labs and write some real scripts.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 8.1: System Report Script](labs/lab_01_system_report.sh)** — Write a script that generates a system health report with hostname, uptime, CPU, memory, disk, and top processes
- **[Lab 8.2: Service Checker Script](labs/lab_02_service_checker.sh)** — Write a script that checks service status and optionally restarts failed services

---

## Checklist

Before moving to Week 9, confirm you can:

- [ ] Write a bash script with a proper shebang, make it executable, and run it
- [ ] Explain what set -euo pipefail does and why you should use it
- [ ] Declare and use variables with proper quoting
- [ ] Access command-line arguments with $1, $2, $#, and $@
- [ ] Write if/elif/else conditionals with string, numeric, and file tests
- [ ] Write for and while loops including reading files line by line
- [ ] Use case statements for multi-branch logic
- [ ] Define functions with local variables and capture their output
- [ ] Check exit codes and handle errors with trap
- [ ] Perform arithmetic and string manipulation in bash

---

[← Previous Week](../week-07/README.md) · [Next Week →](../week-09/README.md)
