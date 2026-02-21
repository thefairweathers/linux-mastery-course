# Lab 2.1: Filesystem Exploration

> **Objective:** Navigate the Linux filesystem, predict what's in key directories, verify, and compare between Ubuntu and Rocky.
>
> **Concepts practiced:** cd, ls, pwd, absolute/relative paths, filesystem hierarchy
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Setup

Open two terminal windows (or tabs) on your Mac — one SSH'd into Ubuntu, one into Rocky:

```bash
# Terminal 1
ssh student@<ubuntu-ip>

# Terminal 2
ssh student@<rocky-ip>
```

Run each exercise on **both VMs** unless noted otherwise. Watch for differences.

---

## Part 1: Know Where You Are

### Step 1: Confirm your starting location

```bash
pwd
```

**Expected output:** `/home/student` — your home directory. Every time you log in, you start here.

### Step 2: Try three ways to get home

Start somewhere else, then get home using each method:

```bash
cd /tmp        # go somewhere else first
cd ~           # way 1: tilde
pwd

cd /tmp
cd             # way 2: bare cd
pwd

cd /tmp
cd "$HOME"     # way 3: HOME variable
pwd
```

All three should print `/home/student`. The `HOME` environment variable always contains the path to your home directory.

---

## Part 2: Explore Key Directories

For each directory below, **predict** what you'll find before you look. Then verify.

### Step 3: The /etc directory — system configuration

**Predict:** This directory holds configuration files. What configuration files might a freshly installed Linux server have?

```bash
cd /etc
ls | head -20
```

Now look for specific configuration areas:

```bash
ls -la ssh/
ls -la hostname
cat hostname
```

**Question:** What is the hostname set to? Does it match your shell prompt?

### Step 4: The /var/log directory — system logs

**Predict:** What log files would a fresh installation have?

```bash
cd /var/log
ls -lt | head -15
```

The `-t` flag sorts by modification time, newest first. The most recently written logs appear at the top.

**Distro comparison — run on both VMs:**

```bash
# On Ubuntu:
ls /var/log/syslog 2>/dev/null && echo "syslog exists" || echo "syslog not found"

# On Rocky:
ls /var/log/messages 2>/dev/null && echo "messages exists" || echo "messages not found"
```

**Expected result:** Ubuntu has `syslog`, Rocky has `messages`. These are the main system log files for each distribution. Same purpose, different name.

### Step 5: The /usr/bin directory — user commands

```bash
ls /usr/bin | wc -l
```

**Question:** How many commands are available? Is the number different between Ubuntu and Rocky?

Look for commands you already know:

```bash
ls -l /usr/bin/ls
ls -l /usr/bin/cat
ls -l /usr/bin/pwd
```

### Step 6: Verify the usrmerge

```bash
ls -ld /bin
ls -ld /sbin
```

**Expected output:** Both are symbolic links to `/usr/bin` and `/usr/sbin` respectively. This confirms the usrmerge is in place on your system.

### Step 7: The /tmp directory — temporary files

```bash
ls -la /tmp
```

Check the permissions on `/tmp` itself:

```bash
ls -ld /tmp
```

**Expected output (similar to):**

```text
drwxrwxrwt 10 root root 4096 Feb 20 10:00 /tmp
```

Notice the `t` at the end of the permissions — that's the **sticky bit**. It means anyone can create files in `/tmp`, but you can only delete your own files. We'll cover this in Week 5.

### Step 8: The /home directory

```bash
ls -la /home
```

**Question:** How many user directories exist? Just `student`?

Now check the root user's home:

```bash
ls -la /root
```

**Expected output:**

```text
ls: cannot open directory '/root': Permission denied
```

You can't look in root's home directory as a regular user. That's by design.

### Step 9: The /dev directory — device files

```bash
ls /dev | head -20
```

These aren't real files — they're interfaces to hardware. You'll see entries like `sda` (disk), `tty` (terminals), and `null` (a data sink).

Test the special `/dev/null` device:

```bash
echo "This goes nowhere" > /dev/null
cat /dev/null
```

Nothing comes back. `/dev/null` discards everything written to it. It's commonly used to suppress output you don't want to see.

---

## Part 3: Practice Paths

### Step 10: Absolute paths

Navigate using only absolute paths:

```bash
cd /var/log
pwd
cd /etc/ssh
pwd
cd /home/student
pwd
```

### Step 11: Relative paths

Now navigate the same route using relative paths. Start from home:

```bash
cd ~
cd ../../var/log
pwd
cd ../../etc/ssh
pwd
cd /home/student       # go home to reset
```

**Question:** From `/var/log`, the relative path to `/etc/ssh` is `../../etc/ssh`. How many `..` do you need? Trace the path: `/var/log` -> `/var` -> `/` -> `/etc` -> `/etc/ssh`. Two levels up to reach `/`, then down into `etc/ssh`.

### Step 12: The cd - shortcut

```bash
cd /etc/ssh
cd /var/log
cd -
pwd
cd -
pwd
```

You should bounce between `/etc/ssh` and `/var/log` with each `cd -`.

---

## Part 4: Listing Flags Deep Dive

### Step 13: Compare ls output formats

Run all of these from `/etc` and observe how the output changes:

```bash
cd /etc
ls                    # basic listing
ls -l | head -10      # long format
ls -la | head -10     # include hidden files
ls -lah | head -10    # human-readable sizes
ls -lt | head -10     # sort by modification time (newest first)
ls -lS | head -10     # sort by size (largest first)
ls -ltr | head -10    # reverse time sort (oldest first)
```

### Step 14: List a directory without entering it

```bash
cd ~
ls /var/log | head -5     # lists the CONTENTS of /var/log
ls -ld /var/log           # lists /var/log ITSELF (permissions, owner, etc.)
```

The `-d` flag is essential when you want to check properties of a directory rather than its contents.

---

## Part 5: Distro Comparison

### Step 15: Side-by-side comparison

Run these commands on **both VMs** and note the differences:

| Command | Ubuntu Result | Rocky Result |
|---------|--------------|--------------|
| `echo "$SHELL"` | | |
| `cat /etc/hostname` | | |
| `ls /usr/bin \| wc -l` | | |
| `ls /var/log/syslog 2>/dev/null` | | |
| `ls /var/log/messages 2>/dev/null` | | |
| `cat /etc/os-release \| head -2` | | |

Fill in the table as you go. Most results will be identical or very similar. The log file names and the OS identification are the most visible differences.

---

## Try Breaking It

These exercises intentionally produce errors. Run them and understand the error messages.

```bash
# Try to cd into a file (not a directory)
cd /etc/hostname
```

**Expected:** `bash: cd: /etc/hostname: Not a directory`

```bash
# Try to list a directory that doesn't exist
ls /nonexistent
```

**Expected:** `ls: cannot access '/nonexistent': No such file or directory`

```bash
# Try to cd into a directory you don't have permission for
cd /root
```

**Expected:** `bash: cd: /root: Permission denied`

Understanding error messages is a skill. These three — "not a directory," "no such file," and "permission denied" — are the most common navigation errors you'll see. Each tells you exactly what went wrong.

---

## Verify Your Work

Run through this checklist. Each command should succeed without error:

```bash
# 1. You can navigate with absolute paths
cd /var/log && pwd
# Expected: /var/log

# 2. You can navigate with relative paths
cd /home/student && cd ../../etc && pwd
# Expected: /etc

# 3. You can get home three different ways
cd ~ && pwd
cd && pwd
cd "$HOME" && pwd
# Expected: /home/student (all three times)

# 4. You can use cd -
cd /tmp && cd /var && cd - && pwd
# Expected: /tmp

# 5. You know your important directories
ls -ld /etc /var/log /home /tmp /usr/bin
# Expected: details for all five directories, no errors

# 6. You can read ls -l output
ls -l /etc/hostname
# Look at the output: can you identify the permissions, owner, group, size, and date?
```

If all of these work, you've mastered filesystem navigation. Move on to Lab 2.2.
