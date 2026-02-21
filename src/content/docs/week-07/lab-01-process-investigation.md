---
title: "Lab 7.1: Process Investigation"
sidebar:
  order: 1
---


> **Objective:** Use ps, top, /proc to investigate running processes: find memory-heavy processes, trace parent-child relationships, identify zombie processes, and find which process listens on port 22.
>
> **Concepts practiced:** ps, top, pstree, /proc filesystem, kill, pgrep, ss
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Part 1: Listing and Understanding Processes

### Step 1: List All Running Processes

Run the BSD-style process listing:

```bash
ps aux
```

Count how many processes are running:

```bash
ps aux | wc -l
```

**Expected output:** A number between 80 and 200 on a minimal install. Subtract 1 for the header line.

Now run the POSIX-style listing:

```bash
ps -ef
```

**Before you continue, predict:** What column does `ps -ef` show that `ps aux` does not? Why would you need that column?

### Step 2: Find the Most Memory-Hungry Process

Sort processes by memory usage (highest first):

```bash
ps aux --sort=-%mem | head -10
```

**Expected output:** The header line plus the 9 processes using the most memory. On a minimal server, `systemd`, `sshd`, and your bash session are likely near the top.

Now sort by CPU usage:

```bash
ps aux --sort=-%cpu | head -10
```

### Step 3: Find Specific Processes

Use `pgrep` to find the SSH daemon:

```bash
pgrep -a sshd
```

**Expected output:** At least two lines — the main sshd listener and the process handling your SSH connection. Your PIDs will differ from anyone else's.

Now try the `ps | grep` approach and notice the gotcha:

```bash
ps aux | grep sshd
```

Notice the extra line where `grep` matches itself. Use the bracket trick to avoid it:

```bash
ps aux | grep '[s]shd'
```

---

## Part 2: Tracing Parent-Child Relationships

### Step 4: View the Process Tree

```bash
pstree -p
```

Find your own session in the tree. You should see a chain like:

```text
systemd(1)───sshd(...)───sshd(...)───sshd(...)───bash(...)───pstree(...)
```

Show the tree for just your user:

```bash
pstree -p student
```

### Step 5: Trace a Process Manually

Find your shell's PID and trace it back to PID 1:

```bash
echo "$$"
```

Record that number. Look up its parent using the PPID column:

```bash
ps -ef | grep "$$"
```

Find the PPID for your bash process, then look up that PID. Keep following the chain until you reach PID 1 (systemd).

### Step 6: Explore /proc for Your Shell

```bash
cat /proc/$$/status | head -15
```

**Expected output (first few lines):**

```text
Name:   bash
State:  S (sleeping)
Pid:    1423
PPid:   1422
...
```

Check what files your shell has open:

```bash
ls -l /proc/$$/fd/
```

**Expected output:** File descriptors 0, 1, 2 (stdin, stdout, stderr) pointing to your terminal device.

Now look at PID 1:

```bash
sudo cat /proc/1/status | head -10
```

**Expected output:** `Name: systemd` and `PPid: 0` — systemd has no parent. It's the root of the process tree.

---

## Part 3: Finding Port Listeners

### Step 7: Find What's Listening on Port 22

```bash
ss -tlnp
```

**Expected output:**

```text
State   Recv-Q  Send-Q  Local Address:Port   Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22            0.0.0.0:*          users:(("sshd",pid=1100,fd=3))
```

The flags: `-t` for TCP, `-l` for listening, `-n` for numeric, `-p` for process info.

Now use `lsof` for the same information:

```bash
sudo lsof -i :22
```

### Step 8: Check Established Connections

```bash
ss -tn
```

**Expected output:** At least one ESTABLISHED connection — your current SSH session. The peer address is your Mac (the Parallels gateway).

---

## Part 4: Creating and Killing Processes

### Step 9: Create and Kill a Background Process

Start a long-running process:

```bash
sleep 600 &
```

Verify it's running:

```bash
jobs
```

Find it in /proc:

```bash
cat /proc/$(pgrep -f "sleep 600")/status | head -6
```

Send SIGTERM (the polite way):

```bash
kill "$(pgrep -f 'sleep 600')"
jobs
```

**Expected output:** `[1]+ Terminated sleep 600`

Now start another and force-kill it:

```bash
sleep 600 &
kill -9 "$(pgrep -f 'sleep 600')"
jobs
```

**Expected output:** `[1]+ Killed sleep 600`

Notice the difference: "Terminated" (SIGTERM) vs "Killed" (SIGKILL).

### Step 10: Practice Job Control

Start a foreground process and suspend it:

```bash
sleep 300
# Press Ctrl+Z
```

Send it to the background, start another, and list all jobs:

```bash
bg
sleep 400 &
jobs -l
```

**Expected output:** Two running jobs with their PIDs.

Bring job 1 to the foreground and press Ctrl+C. Kill the other:

```bash
fg %1
# Press Ctrl+C
kill %2
jobs
```

---

## Part 5: Repeat on the Other VM

### Step 11: Verify on Rocky (or Ubuntu)

Connect to your other VM and run these commands:

```bash
ps aux | head -5
pstree -p | head -10
ss -tlnp
cat /proc/1/status | head -5
```

The commands are identical. You may see different services running, but the tools and output format are the same on both distributions.

---

## Verify Your Work

```bash
# Can you list processes?
ps aux | wc -l
```

Expected: A number greater than 50

```bash
# Can you find a specific process?
pgrep -c sshd
```

Expected: 1 or more

```bash
# Can you read /proc?
cat /proc/1/comm
```

Expected: `systemd`

```bash
# Can you find port listeners?
ss -tlnp | grep ":22"
```

Expected: At least one line showing sshd listening on port 22

```bash
# Can you use job control?
sleep 10 & kill %1 && echo "Job control works"
```

Expected: `Job control works` (with a Terminated notice)

If all checks pass, you have a solid working knowledge of process investigation. Move on to Lab 7.2.
