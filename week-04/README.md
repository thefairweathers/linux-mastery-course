# Week 4: Pipes, Redirection & The Unix Philosophy

> **Goal:** Chain commands together using pipes and redirection, understand stdin/stdout/stderr, and write compound one-liners.

[← Previous Week](../week-03/README.md) · [Next Week →](../week-05/README.md)

---

## 4.1 The Unix Philosophy

Before we touch a single command, you need to understand the design principle that makes everything in this week possible.

In 1978, Doug McIlroy summarized the **Unix philosophy** in a few sentences that still govern how Linux tools are built today:

1. Make each program do one thing well.
2. Expect the output of every program to become the input to another.
3. Design and build software to be tried early.

This means `grep` doesn't sort. `sort` doesn't count. `wc` doesn't filter. Each tool does exactly one job, and you combine them. The glue between these tools is **text streams** -- plain text flowing from one program to the next.

This week, you learn to be the plumber.

---

## 4.2 Standard Streams

Every process on a Linux system is born with three open communication channels, called **standard streams**. Each one has a number called a **file descriptor** (fd):

| Stream | File Descriptor | Default Destination | Purpose |
|--------|:-:|---|---|
| **stdin** | 0 | Keyboard | Input to the program |
| **stdout** | 1 | Terminal | Normal output |
| **stderr** | 2 | Terminal | Error messages and diagnostics |

Here is the critical insight: stdout and stderr both print to your terminal by default, so they look the same. But they are separate channels, and you can redirect them independently.

Watch this in action:

```bash
# This command produces both stdout and stderr
ls /etc/hostname /nonexistent
```

```text
ls: cannot access '/nonexistent': No such file or directory
/etc/hostname
```

The error message came from stderr (fd 2). The filename came from stdout (fd 1). They appeared interleaved on your screen, but they traveled through different pipes inside the kernel.

### Everything Is a File (Descriptor)

In Linux, these streams are literally files. You can see them for any running process:

```bash
ls -l /proc/self/fd/
```

```text
lrwx------ 1 user user 64 Feb 20 10:00 0 -> /dev/pts/0
lrwx------ 1 user user 64 Feb 20 10:00 1 -> /dev/pts/0
lrwx------ 1 user user 64 Feb 20 10:00 2 -> /dev/pts/0
```

All three point to your terminal (`/dev/pts/0`). Redirection simply changes where these file descriptors point.

---

## 4.3 Output Redirection

Output redirection lets you send a command's output to a file instead of the terminal.

### Redirect stdout with `>`

The `>` operator redirects stdout (fd 1) to a file. If the file exists, it is **overwritten**.

```bash
echo "Hello, Linux" > greeting.txt
cat greeting.txt
```

```text
Hello, Linux
```

Run it again with different content:

```bash
echo "Goodbye, Linux" > greeting.txt
cat greeting.txt
```

```text
Goodbye, Linux
```

The original content is gone. This is the most common cause of accidental data loss for beginners. Be careful with `>`.

### Append with `>>`

The `>>` operator appends to the file instead of overwriting:

```bash
echo "Line 1" > logfile.txt
echo "Line 2" >> logfile.txt
echo "Line 3" >> logfile.txt
cat logfile.txt
```

```text
Line 1
Line 2
Line 3
```

Use `>>` when you are building up a file over time -- log entries, collected results, accumulated data.

### Redirect stderr with `2>`

To redirect only error messages, prefix the `>` with the file descriptor number `2`:

```bash
ls /etc/hostname /nonexistent 2> errors.txt
```

```text
/etc/hostname
```

The successful output still goes to the terminal. The error went to the file:

```bash
cat errors.txt
```

```text
ls: cannot access '/nonexistent': No such file or directory
```

This pattern is essential for cron jobs and scripts where you want to log errors separately from normal output.

### Redirect stdout and stderr to different files

You can redirect both at once, each to its own file:

```bash
ls /etc/hostname /nonexistent > found.txt 2> errors.txt
cat found.txt
cat errors.txt
```

```text
/etc/hostname
ls: cannot access '/nonexistent': No such file or directory
```

### Combine stdout and stderr with `2>&1`

The expression `2>&1` means "redirect file descriptor 2 to wherever file descriptor 1 is currently going." Order matters here:

```bash
# Correct: redirect stdout to file, then stderr to the same place
ls /etc/hostname /nonexistent > all_output.txt 2>&1
cat all_output.txt
```

```text
ls: cannot access '/nonexistent': No such file or directory
/etc/hostname
```

Both streams ended up in the same file. If you reverse the order, it does not work as expected:

```bash
# Wrong order: 2>&1 copies fd1 (still terminal), then > redirects fd1 to file
ls /etc/hostname /nonexistent 2>&1 > output.txt
```

In this case, stderr still goes to the terminal because `2>&1` was evaluated before `>` changed fd 1. The shell processes redirections left to right.

### The shorthand `&>`

Bash provides a shorthand that redirects both stdout and stderr to the same file:

```bash
ls /etc/hostname /nonexistent &> all_output.txt
```

This is equivalent to `> all_output.txt 2>&1` and is the form you will see most often in scripts.

### Discard output with `/dev/null`

**`/dev/null`** is a special file that discards everything written to it. Think of it as a black hole:

```bash
# Suppress error messages, show only successful output
ls /etc/hostname /nonexistent 2>/dev/null
```

```text
/etc/hostname
```

```bash
# Suppress all output entirely
ls /etc/hostname /nonexistent &>/dev/null
```

You will use this constantly in scripts where you only care whether a command succeeded, not what it printed.

---

## 4.4 Input Redirection

### Redirect stdin with `<`

The `<` operator feeds a file into a command's stdin:

```bash
wc -l < /etc/passwd
```

This is subtly different from `wc -l /etc/passwd`. With `<`, the command does not know the filename -- it just reads from stdin. That means `wc` will not print the filename in its output:

```bash
# With filename argument:
wc -l /etc/passwd
```

```text
35 /etc/passwd
```

```bash
# With input redirection:
wc -l < /etc/passwd
```

```text
35
```

The second form is useful when you need just the number without the filename.

### Here Documents with `<<`

A **here document** (heredoc) lets you provide multi-line input inline, without creating a separate file. The syntax is `<< DELIMITER`:

```bash
cat << EOF
Server Report
=============
Date: $(date +%Y-%m-%d)
Hostname: $(hostname)
Uptime: $(uptime -p)
EOF
```

```text
Server Report
=============
Date: 2026-02-20
Hostname: ubuntu-lab
Uptime: up 3 days, 7 hours, 22 minutes
```

The delimiter (commonly `EOF`, but it can be any word) marks the beginning and end of the input block. Everything between the two `EOF` markers is fed to `cat` as stdin.

If you quote the delimiter, variable expansion is suppressed:

```bash
cat << 'EOF'
This will not expand: $HOME
Neither will this: $(whoami)
EOF
```

```text
This will not expand: $HOME
Neither will this: $(whoami)
```

Here documents are enormously useful for creating configuration files in scripts:

```bash
sudo tee /etc/motd << EOF
========================================
  Authorized users only.
  All activity is monitored and logged.
========================================
EOF
```

### Here Strings with `<<<`

A **here string** feeds a single string to a command's stdin:

```bash
wc -w <<< "The quick brown fox"
```

```text
4
```

This avoids the overhead of `echo "..." | command` and is slightly more efficient:

```bash
# Instead of this:
echo "192.168.1.100" | cut -d. -f1

# You can write this:
cut -d. -f1 <<< "192.168.1.100"
```

```text
192
```

---

## 4.5 Pipes

The **pipe** operator `|` connects the stdout of one command to the stdin of the next. This is the single most powerful feature of the Unix shell.

```bash
cat /etc/passwd | head -5
```

```text
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
```

What happened: `cat` wrote the contents of `/etc/passwd` to its stdout. The pipe captured that stdout and fed it to `head` as stdin. `head -5` read the first 5 lines and printed them.

### Building Pipelines

You can chain as many commands as you need. Each `|` adds another stage to the **pipeline**:

```bash
# Count how many users have /bin/bash as their shell
cat /etc/passwd | grep '/bin/bash' | wc -l
```

Let's trace through a more complex example. Suppose you want a sorted, deduplicated list of all shells used on the system:

```bash
cat /etc/passwd | cut -d: -f7 | sort | uniq
```

```text
/bin/bash
/bin/sync
/sbin/nologin
/usr/sbin/nologin
```

Stage by stage:

1. `cat /etc/passwd` -- reads the file
2. `cut -d: -f7` -- extracts the 7th colon-delimited field (the shell)
3. `sort` -- sorts the lines alphabetically (required for `uniq` to work)
4. `uniq` -- removes adjacent duplicate lines

Add `uniq -c` to count occurrences, then `sort -rn` to rank them:

```bash
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

```text
     27 /usr/sbin/nologin
      1 /bin/sync
      1 /bin/bash
      1 /bin/false
```

Notice I dropped `cat` from the pipeline. Since `cut` can read a file directly, `cat /etc/passwd | cut ...` is a **useless use of cat**. Both forms work, but experienced admins skip the extra process.

### Pipes Only Carry stdout

A common surprise: pipes do **not** carry stderr. Only stdout flows through the pipe:

```bash
ls /etc/hostname /nonexistent | wc -l
```

```text
ls: cannot access '/nonexistent': No such file or directory
1
```

The error message bypassed the pipe and went straight to the terminal. Only the valid output (`/etc/hostname`) was piped to `wc`, which counted 1 line.

To pipe both stdout and stderr, use `2>&1 |` or the Bash shorthand `|&`:

```bash
ls /etc/hostname /nonexistent 2>&1 | wc -l
```

```text
2
```

Now both lines (the error and the filename) were piped to `wc`.

---

## 4.6 tee -- Split Output to File and Screen

**`tee`** reads from stdin and writes to both stdout and one or more files simultaneously. Think of it as a T-junction in a pipe:

```bash
df -h | tee disk_report.txt
```

This displays the disk usage on screen *and* saves it to `disk_report.txt`. Without `tee`, you would have to choose between seeing the output and saving it.

### Append mode

By default, `tee` overwrites. Use `-a` to append:

```bash
echo "Check 1: $(date)" | tee -a health_log.txt
echo "Check 2: $(date)" | tee -a health_log.txt
```

### Writing to protected files

`tee` combined with `sudo` is the standard way to write to files owned by root:

```bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

You might wonder why not `sudo echo "..." > /etc/resolv.conf`. The redirection `>` is handled by your current (non-root) shell before `sudo` runs. The shell tries to open the file as your user, and fails. With `tee`, the redirection happens inside the `sudo`-elevated process.

### Debugging pipelines

`tee` is invaluable for debugging long pipelines. Insert it at any stage to see what data is flowing through:

```bash
cat /etc/passwd | cut -d: -f7 | tee /dev/stderr | sort | uniq -c | sort -rn
```

Here, `tee /dev/stderr` sends a copy of the data to stderr (which prints to the terminal) while the pipeline continues normally. You see the intermediate data without disrupting the flow.

---

## 4.7 Command Substitution

**Command substitution** embeds the output of one command inside another. The syntax is `$(command)`:

```bash
echo "Today is $(date +%A)"
```

```text
Today is Thursday
```

The shell runs `date +%A`, captures its output, and inserts it in place of `$(...)` before executing `echo`.

### Practical examples

Store a value in a variable:

```bash
CURRENT_USER="$(whoami)"
FILE_COUNT="$(ls /etc | wc -l)"
echo "User $CURRENT_USER sees $FILE_COUNT files in /etc"
```

Use in filenames:

```bash
tar czf "backup-$(date +%Y%m%d).tar.gz" /etc/nginx/
```

This creates a file like `backup-20260220.tar.gz`.

Conditional logic:

```bash
if [ "$(systemctl is-active nginx)" = "active" ]; then
    echo "Nginx is running"
else
    echo "Nginx is stopped"
fi
```

### Nesting

Command substitutions can be nested:

```bash
echo "Kernel released on: $(date -d "$(uname -v | grep -oP '#\d+ \K.*')" +%Y-%m-%d 2>/dev/null || echo "unknown")"
```

The inner `$(uname -v ...)` runs first, and its result feeds the outer `$(date ...)`. While you can nest them, deep nesting hurts readability. If you go beyond two levels, use intermediate variables instead.

### Legacy syntax: backticks

You may encounter the older backtick syntax in existing scripts:

```bash
echo "User: `whoami`"
```

This is equivalent to `$(whoami)` but harder to nest and easier to confuse with single quotes. Always prefer `$(...)` in new code.

---

## 4.8 xargs -- Build Commands from stdin

**`xargs`** reads items from stdin and executes a command with those items as arguments. It bridges the gap between commands that produce output and commands that expect arguments.

### Basic usage

```bash
echo "file1.txt file2.txt file3.txt" | xargs touch
```

This runs `touch file1.txt file2.txt file3.txt`. Without `xargs`, `touch` would not know what to do with stdin.

### Real-world example: find + xargs

`find` outputs filenames to stdout. Many commands need filenames as arguments. `xargs` connects the two:

```bash
# Find all .log files and count their total lines
find /var/log -name "*.log" -type f 2>/dev/null | xargs wc -l
```

### The `-I{}` placeholder

When you need to control where the argument is placed, use `-I{}`:

```bash
# Rename every .txt file to .bak
ls *.txt | xargs -I{} mv {} {}.bak
```

`-I{}` processes one item at a time and places it wherever `{}` appears in the command.

### Handling filenames with spaces

Filenames with spaces break `xargs` because it splits on whitespace by default. Use null-delimited input:

```bash
find /home -name "*.conf" -print0 | xargs -0 grep "setting"
```

`find -print0` separates filenames with null bytes instead of newlines. `xargs -0` reads null-delimited input. This combination is bulletproof.

### Parallel execution with `-P`

Run multiple jobs in parallel with `-P`:

```bash
# Compress 4 files at a time
find /var/log -name "*.log" -type f | xargs -P 4 -I{} gzip {}
```

`-P 4` runs up to 4 `gzip` processes simultaneously. On a multi-core system, this can dramatically speed up bulk operations.

### Confirmation with `-p`

When running destructive commands, add `-p` to confirm each execution:

```bash
find /tmp -name "*.tmp" -mtime +7 | xargs -p rm
```

```text
rm /tmp/old1.tmp /tmp/old2.tmp?...y
```

---

## 4.9 Process Substitution

**Process substitution** lets you treat the output of a command as if it were a file. The syntax is `<(command)`:

```bash
diff <(ls /etc/nginx/sites-available/) <(ls /etc/nginx/sites-enabled/)
```

This compares two directory listings without creating temporary files. The shell runs both `ls` commands, creates temporary file descriptors for their output, and passes those file descriptors to `diff`.

### How it works

```bash
echo <(echo "hello")
```

```text
/dev/fd/63
```

Process substitution creates a special file descriptor. The command inside runs concurrently, and the file descriptor streams its output.

### Practical examples

Compare sorted vs. unsorted data without intermediate files:

```bash
# Compare packages installed on two systems (run on one, SSH to the other)
diff <(rpm -qa | sort) <(ssh rocky-server 'rpm -qa | sort')
```

Feed multiple inputs to a command that expects files:

```bash
# Paste columns from different commands side by side
paste <(cut -d: -f1 /etc/passwd) <(cut -d: -f7 /etc/passwd)
```

```text
root    /bin/bash
daemon  /usr/sbin/nologin
bin     /usr/sbin/nologin
...
```

Process substitution is a Bash feature (not POSIX sh). It works in Bash on both Ubuntu and Rocky Linux.

---

## 4.10 Command Chaining

You often need to run multiple commands in sequence. Linux offers three chaining operators, each with different behavior on failure.

### Sequential with `;`

The semicolon runs commands one after another, regardless of success or failure:

```bash
echo "Starting"; sleep 1; echo "Done"
```

Each command runs no matter what happened to the previous one. Use `;` when the commands are independent.

### On-success with `&&`

The `&&` operator runs the next command **only if the previous one succeeded** (exit code 0):

```bash
mkdir /tmp/workdir && cd /tmp/workdir && echo "Ready to work"
```

If `mkdir` fails (directory already exists), `cd` never runs, and neither does `echo`. This prevents cascading errors.

This is the operator you should reach for most often. It is the safe default.

### On-failure with `||`

The `||` operator runs the next command **only if the previous one failed** (non-zero exit code):

```bash
ping -c 1 -W 2 8.8.8.8 &>/dev/null || echo "No internet connectivity"
```

If `ping` succeeds, the `echo` is skipped. If `ping` fails, you see the message.

### Combining `&&` and `||`

You can build simple conditional logic:

```bash
systemctl is-active --quiet nginx && echo "Nginx: running" || echo "Nginx: stopped"
```

This is readable for simple cases but be cautious: if the `&&` command itself fails, the `||` command will also run. For real conditional logic, use `if` statements.

### Grouping with `{}`

Braces group commands together so chaining operators apply to the group:

```bash
{ echo "=== Disk Report ==="; df -h; echo "=== Memory Report ==="; free -h; } > system_report.txt
```

Note the required semicolon before `}` and the spaces inside the braces.

Subshells with `()` are similar but run in a child process:

```bash
(cd /var/log && tar czf /tmp/logs.tar.gz *.log)
# You are still in your original directory here
```

The `cd` only affects the subshell. Your current directory is unchanged.

---

## 4.11 Putting It All Together

Now let's combine these tools into real-world pipelines that you would actually use on a server.

### Example 1: Top 10 IP addresses hitting your web server

```bash
cat /var/log/nginx/access.log \
  | awk '{print $1}' \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -10
```

```text
   1423 203.0.113.50
    892 198.51.100.14
    567 192.0.2.33
    ...
```

Breaking it down: extract the first field (IP address), sort them, count duplicates, sort by count descending, take the top 10.

### Example 2: Find large files eating disk space

```bash
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null \
  | awk '{print $5, $9}' \
  | sort -rh \
  | head -20
```

This finds files larger than 100MB, formats them with human-readable sizes, sorts by size descending, and shows the top 20.

### Example 3: Monitor a log file for errors in real time

```bash
tail -f /var/log/syslog | grep --line-buffered -i "error" | tee errors_found.txt
```

`tail -f` follows the file as it grows. `grep` filters for lines containing "error". `tee` saves matches to a file while also displaying them. The `--line-buffered` flag ensures `grep` outputs each match immediately instead of buffering.

### Example 4: Generate a system health snapshot

```bash
{
  echo "=== System Health Report ==="
  echo "Generated: $(date)"
  echo ""
  echo "--- Uptime ---"
  uptime
  echo ""
  echo "--- Disk Usage ---"
  df -h | grep -v tmpfs
  echo ""
  echo "--- Memory ---"
  free -h
  echo ""
  echo "--- Top 5 CPU Processes ---"
  ps aux --sort=-%cpu | head -6
  echo ""
  echo "--- Listening Ports ---"
  ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null
} | tee "/tmp/health-$(hostname)-$(date +%Y%m%d).txt"
```

This generates a health report, displays it on screen, and saves it to a timestamped file.

### Example 5: Bulk operations with xargs

```bash
# Find config files modified in the last 24 hours and back them up
find /etc -name "*.conf" -mtime -1 -type f 2>/dev/null \
  | xargs -I{} cp {} /tmp/config-backup/
```

### Example 6: Compare configurations across servers

```bash
diff <(ssh ubuntu-server 'cat /etc/ssh/sshd_config') \
     <(ssh rocky-server 'cat /etc/ssh/sshd_config')
```

This shows differences in SSH configuration between two servers without copying files around.

### Example 7: Extract and summarize data

```bash
# Who logged in most recently from each unique IP?
last -i | grep -v "^$" | grep -v "^wtmp" \
  | awk '{print $3}' \
  | sort -u \
  | while read -r ip; do
      last -i | grep "$ip" | head -1
    done
```

### Distro differences

Most of the tools in this chapter work identically on Ubuntu and Rocky Linux. The few differences to be aware of:

| Feature | Ubuntu (Debian-based) | Rocky (RHEL-based) |
|---|---|---|
| Default shell | Bash (dash for /bin/sh) | Bash |
| `netstat` | Install `net-tools` | Install `net-tools` |
| `ss` | Pre-installed | Pre-installed |
| Process substitution | Bash only (not dash) | Bash (default) |
| Log locations | `/var/log/syslog` | `/var/log/messages` |

When writing portable scripts, use `ss` instead of `netstat` (it is newer and always available), and check for log file locations.

---

## 4.12 Common Pitfalls

### Pitfall 1: Redirecting to the same file you are reading

```bash
# DANGER: This will empty the file!
sort < data.txt > data.txt
```

The shell opens `data.txt` for writing (truncating it) *before* `sort` reads it. Use a temporary file or `sponge` from `moreutils`:

```bash
sort < data.txt > /tmp/sorted.txt && mv /tmp/sorted.txt data.txt
```

### Pitfall 2: Forgetting that pipes create subshells

Variables set inside a pipeline are lost when the pipeline finishes:

```bash
count=0
cat /etc/passwd | while read -r line; do
    count=$((count + 1))
done
echo "$count"  # Prints 0, not the number of lines
```

The `while` loop runs in a subshell (because it is on the right side of a pipe). The `count` variable in the subshell is a copy. Fix this with process substitution:

```bash
count=0
while read -r line; do
    count=$((count + 1))
done < /etc/passwd
echo "$count"  # Prints the correct count
```

### Pitfall 3: Unquoted variables in redirections

```bash
FILE="my report.txt"
echo "data" > $FILE     # Creates two files: "my" and "report.txt"
echo "data" > "$FILE"   # Creates one file: "my report.txt"
```

Always quote your variables.

### Pitfall 4: Using `echo` to pipe passwords

```bash
# Insecure: password visible in process list
echo "mypassword" | sudo -S some_command
```

The password appears in `ps` output. Use `read -s` or a dedicated credential mechanism instead.

---

## Quick Reference

| Operation | Syntax | Example |
|---|---|---|
| Redirect stdout | `>` | `ls > files.txt` |
| Append stdout | `>>` | `echo "line" >> log.txt` |
| Redirect stderr | `2>` | `cmd 2> errors.txt` |
| Redirect both | `&>` | `cmd &> all.txt` |
| Combine stderr into stdout | `2>&1` | `cmd > out.txt 2>&1` |
| Discard output | `>/dev/null` | `cmd 2>/dev/null` |
| Input from file | `<` | `wc -l < file.txt` |
| Here document | `<<EOF` | `cat <<EOF ... EOF` |
| Here string | `<<<` | `grep x <<< "text"` |
| Pipe | `\|` | `cmd1 \| cmd2` |
| Tee | `tee` | `cmd \| tee file.txt` |
| Command substitution | `$(cmd)` | `echo "$(date)"` |
| Process substitution | `<(cmd)` | `diff <(cmd1) <(cmd2)` |
| xargs | `xargs` | `find . \| xargs rm` |
| Sequential | `;` | `cmd1; cmd2` |
| On success | `&&` | `cmd1 && cmd2` |
| On failure | `\|\|` | `cmd1 \|\| cmd2` |

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 4.1: Redirection Mastery](labs/lab_01_redirection_mastery.md)** — Exercises on redirecting stdout/stderr, appending, combining streams, and here documents
- **[Lab 4.2: Pipeline Challenges](labs/lab_02_pipeline_challenges.md)** — Solve 10 progressively harder problems using pipes and command chaining

---

## Checklist

Before moving to Week 5, confirm you can:

- [ ] Explain the three standard streams (stdin, stdout, stderr) and their file descriptor numbers
- [ ] Redirect stdout and stderr to files independently
- [ ] Combine stdout and stderr into a single stream with 2>&1
- [ ] Use here documents to provide multi-line input to a command
- [ ] Pipe the output of one command into the input of another
- [ ] Use tee to save output while also displaying it
- [ ] Embed command output in another command with $(command)
- [ ] Use xargs to convert stdin into command arguments
- [ ] Chain commands with ;, &&, and || and explain when each is appropriate
- [ ] Build multi-step pipelines to extract and transform data

---

[← Previous Week](../week-03/README.md) · [Next Week →](../week-05/README.md)
