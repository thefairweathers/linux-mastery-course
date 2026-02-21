# Week 7: Processes, Jobs & System Monitoring

> **Goal:** Understand how Linux manages processes, monitor system resources, and control running programs.

[← Previous Week](../week-06/README.md) · [Next Week →](../week-08/README.md)

---

## 7.1 What Is a Process?

Every running program on a Linux system is a **process**. When you type `ls` and press Enter, the shell creates a new process, that process runs the `ls` program, produces output, and then exits. When you start a web server, it creates a process that stays running indefinitely, waiting for connections.

This is fundamental to how Linux works: everything that executes is a process, and every process is tracked by the kernel. Understanding processes is what separates someone who uses Linux from someone who administers it.

Each process has several key attributes:

| Attribute | Meaning |
|-----------|---------|
| **PID** | Process ID — a unique number assigned by the kernel |
| **PPID** | Parent Process ID — the PID of the process that started this one |
| **UID** | User ID — which user owns the process |
| **State** | What the process is currently doing |
| **Priority** | How much CPU time the scheduler gives it |

Every process has a parent. When you run a command in bash, bash is the parent and the command is the child. This creates a tree structure rooted at PID 1, which is the **init** process (on modern systems, `systemd`). If you remember from Week 1, systemd is the first process the kernel starts after booting. Everything else descends from it.

### Process States

A process is always in one of several states. You'll see these as single-letter codes in `ps` output:

| State | Code | Meaning |
|-------|------|---------|
| Running | `R` | Actively executing on a CPU or waiting in the run queue |
| Sleeping | `S` | Waiting for something (I/O, a signal, a timer) — interruptible |
| Uninterruptible Sleep | `D` | Waiting for I/O that can't be interrupted (usually disk) |
| Zombie | `Z` | Finished executing but parent hasn't collected its exit status |
| Stopped | `T` | Paused (by a signal like Ctrl+Z or a debugger) |

The ones you'll encounter most are `S` (sleeping — the normal state for a process waiting for work), `R` (running), and occasionally `Z` (zombie — which indicates a bug in the parent process). If you see many processes in `D` state, your system is likely waiting on slow disk I/O — a critical diagnostic clue.

---

## 7.2 Viewing Processes

### ps — Process Snapshot

The `ps` command takes a snapshot of current processes. It has two major syntax styles (a legacy of Unix history), and you'll encounter both in the wild.

**BSD-style (no dashes):**

```bash
ps aux
```

```text
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.3 168640 12288 ?        Ss   09:15   0:01 /usr/lib/systemd/systemd
root           2  0.0  0.0      0     0 ?        S    09:15   0:00 [kthreadd]
student     1423  0.0  0.1  10280  5120 pts/0    Ss   09:30   0:00 -bash
student     1456  0.0  0.0  10776  3328 pts/0    R+   09:45   0:00 ps aux
```

Breaking down what each column means:

| Column | Meaning |
|--------|---------|
| `USER` | Process owner |
| `PID` | Process ID |
| `%CPU` | CPU usage percentage |
| `%MEM` | Memory usage percentage |
| `VSZ` | Virtual memory size (KB) — total memory the process *could* access |
| `RSS` | Resident Set Size (KB) — physical memory actually in use |
| `TTY` | Terminal associated with the process (`?` means no terminal — a daemon) |
| `STAT` | Process state (the codes from Section 7.1, plus modifiers) |
| `START` | When the process started |
| `TIME` | Total CPU time consumed |
| `COMMAND` | The command that started the process |

The `STAT` column often has extra characters: `Ss` means sleeping + session leader, `R+` means running + foreground process, `Sl` means sleeping + multithreaded.

**POSIX-style (with dashes):**

```bash
ps -ef
```

```text
UID          PID    PPID  C STIME TTY          TIME CMD
root           1       0  0 09:15 ?        00:00:01 /usr/lib/systemd/systemd
root           2       0  0 09:15 ?        00:00:00 [kthreadd]
student     1423    1400  0 09:30 pts/0    00:00:00 -bash
```

The key difference: `ps -ef` shows the PPID column, which `ps aux` does not. When you need to trace parent-child relationships, use `ps -ef`.

### Filtering Process Output

You'll often pipe `ps` through `grep` to find specific processes:

```bash
ps aux | grep sshd
```

```text
root        1100  0.0  0.1  15420  7168 ?        Ss   09:15   0:00 sshd: /usr/sbin/sshd -D
root        1400  0.0  0.1  17388  8448 ?        Ss   09:30   0:00 sshd: student [priv]
student     1422  0.0  0.1  17388  6400 ?        S    09:30   0:00 sshd: student@pts/0
student     1460  0.0  0.0   6480  2176 pts/0    S+   09:46   0:00 grep --color=auto sshd
```

Notice the last line — `grep` found itself. A classic trick to avoid this:

```bash
ps aux | grep '[s]shd'
```

The bracket around the first character makes the grep pattern not match its own process listing. But for most day-to-day work, just use `pgrep`.

### pgrep and pidof — Finding Process IDs

```bash
pgrep sshd
```

```text
1100
1400
1422
```

`pgrep` returns just the PIDs. Add `-l` for names, or `-a` for the full command line:

```bash
pgrep -a sshd
```

```text
1100 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups
1400 sshd: student [priv]
1422 sshd: student@pts/0
```

`pidof` is simpler — it finds PIDs by exact program name:

```bash
pidof sshd
```

```text
1422 1400 1100
```

### pstree — Visualizing the Process Tree

```bash
pstree -p
```

This shows the parent-child hierarchy with PIDs:

```text
systemd(1)─┬─sshd(1100)───sshd(1400)───sshd(1422)───bash(1423)───pstree(1470)
            ├─systemd-journal(350)
            ├─systemd-udevd(385)
            ├─cron(980)
            ├─dbus-daemon(985)
            └─...
```

You can see the complete chain: `systemd` started `sshd`, which forked to handle your SSH connection, which spawned `bash`, which is running `pstree`. This tree view is invaluable when debugging process relationships.

To show the tree for a specific user:

```bash
pstree -p student
```

---

## 7.3 Real-Time Monitoring with top and htop

### top — Built-In Process Monitor

`top` shows a live, updating view of processes sorted by resource usage:

```bash
top
```

The header area (first 5 lines) is dense with information. Here's what each line means:

```text
top - 09:50:23 up 35 min,  1 user,  load average: 0.08, 0.03, 0.01
Tasks: 112 total,   1 running, 111 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.3 us,  0.2 sy,  0.0 ni, 99.5 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   3936.0 total,   3200.5 free,    412.3 used,    502.8 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   3524.0 avail Mem
```

| Field | Meaning |
|-------|---------|
| `load average: 0.08, 0.03, 0.01` | CPU demand over the last 1, 5, and 15 minutes |
| `us` | User-space CPU (your programs) |
| `sy` | Kernel-space CPU (system calls, drivers) |
| `ni` | Nice — CPU used by low-priority processes |
| `id` | Idle — CPU doing nothing |
| `wa` | I/O Wait — CPU waiting for disk (high values = disk bottleneck) |
| `hi/si` | Hardware/software interrupts |
| `st` | Steal — CPU stolen by hypervisor (relevant in VMs and cloud instances) |
| `buff/cache` | Memory used for disk caching (reclaimable if needed) |
| `avail Mem` | Memory available without swapping (the number that actually matters) |

**Key commands while in top:**

| Key | Action |
|-----|--------|
| `M` | Sort by memory usage |
| `P` | Sort by CPU usage |
| `k` | Kill a process (prompts for PID and signal) |
| `u` | Filter by user |
| `c` | Toggle full command line display |
| `1` | Toggle per-CPU view |
| `q` | Quit |

**Load average** deserves special attention. On a system with 2 CPUs, a load average of 2.0 means the CPUs are fully utilized. A load average of 4.0 means processes are queuing up — the system can't keep up. As a rule of thumb, sustained load average above your CPU count means the system is overloaded. We discussed CPU allocation back in Week 1 when setting up VMs; this is where it becomes practically relevant.

### htop — The Better top

`htop` is an improved version of `top` with color coding, mouse support, scrolling, and interactive filtering. It's not installed by default on minimal systems.

Install it:

| Distro | Command |
|--------|---------|
| Ubuntu | `sudo apt install htop` |
| Rocky | `sudo dnf install htop` |

Then run it:

```bash
htop
```

`htop` advantages over `top`:

- Color-coded CPU and memory bars give an instant visual read
- You can scroll through the process list (top only shows what fits on screen)
- Press `F4` to filter processes by name (type a search term)
- Press `F5` to toggle tree view (like `pstree` but live)
- Press `F6` to choose the sort column
- Press `F9` to send a signal to the selected process
- Mouse support — you can click column headers to sort

Use `htop` as your default process monitor. Use `top` when `htop` isn't installed (minimal servers, containers, recovery environments).

---

## 7.4 Process Signals

Processes don't just run and exit on their own — the kernel and other processes can send them **signals** to request specific behavior. Signals are how Linux communicates with running processes.

### Common Signals

| Signal | Number | Default Action | Typical Use |
|--------|--------|---------------|-------------|
| `SIGHUP` | 1 | Terminate | Reload configuration (many daemons catch this) |
| `SIGINT` | 2 | Terminate | Interrupt — what Ctrl+C sends |
| `SIGKILL` | 9 | Terminate (forced) | Unconditional kill — process cannot catch or ignore |
| `SIGUSR1` | 10 | Terminate | User-defined — applications use this for custom actions |
| `SIGTERM` | 15 | Terminate | Polite shutdown request — the default signal |
| `SIGSTOP` | 19 | Stop | Pause process — cannot be caught (like SIGKILL for stopping) |
| `SIGCONT` | 18 | Continue | Resume a stopped process |
| `SIGTSTP` | 20 | Stop | What Ctrl+Z sends — can be caught unlike SIGSTOP |

### Sending Signals with kill, killall, and pkill

Despite its name, `kill` doesn't necessarily kill — it sends a signal. The default signal is SIGTERM (15).

```bash
# Send SIGTERM (default) to PID 1456
kill 1456

# Send SIGKILL to PID 1456
kill -9 1456

# Equivalent — use signal name
kill -SIGKILL 1456
```

`killall` sends a signal to all processes matching a name:

```bash
# Terminate all processes named "python3"
killall python3

# Force-kill all processes named "python3"
killall -9 python3
```

`pkill` is like `killall` but matches patterns (like `pgrep`):

```bash
# Kill any process whose name contains "python"
pkill python

# Kill processes owned by user "student" whose name matches "sleep"
pkill -u student sleep
```

### Graceful vs Forceful Termination

This matters more than most beginners realize. Always try SIGTERM before SIGKILL:

**SIGTERM (15)** — the polite request. The process receives the signal and can:
- Save its state to disk
- Close database connections cleanly
- Flush write buffers
- Remove temporary files
- Notify child processes to shut down

**SIGKILL (9)** — the sledgehammer. The kernel terminates the process immediately. The process:
- Cannot catch, handle, or ignore this signal
- Gets no chance to clean up
- May leave corrupted files, stale lock files, or half-written data
- May leave child processes orphaned

The correct sequence when a process won't stop:

```bash
# Step 1: Ask nicely
kill "$PID"

# Step 2: Wait a few seconds
sleep 5

# Step 3: Check if it's gone
kill -0 "$PID" 2>/dev/null && echo "still running" || echo "terminated"

# Step 4: Only if still running, force it
kill -9 "$PID"
```

The `kill -0` trick sends signal 0, which doesn't do anything to the process but returns an error if the process doesn't exist. It's a clean way to check whether a process is still alive.

In production, reaching for `kill -9` first is a red flag. It means you're accepting data loss as a default. Get in the habit of SIGTERM first.

---

## 7.5 Job Control

When you run a command in the terminal, it normally runs in the **foreground** — it takes over your terminal until it finishes. But you often need to run something in the background while you continue working.

### Running a Command in the Background

Append `&` to run a command in the background:

```bash
sleep 300 &
```

```text
[1] 1502
```

The shell reports the **job number** (`[1]`) and the **PID** (`1502`). You get your prompt back immediately.

### Suspending and Resuming

If a command is already running in the foreground and you want your prompt back, press **Ctrl+Z**:

```bash
sleep 300
# (press Ctrl+Z)
```

```text
[1]+  Stopped                 sleep 300
```

The process is now **stopped** (state `T`). It's not running — it's paused in memory.

Resume it in the background:

```bash
bg
```

```text
[1]+ sleep 300 &
```

Or bring it back to the foreground:

```bash
fg
```

### Listing Jobs

The `jobs` command shows all background and stopped jobs in the current shell:

```bash
sleep 100 &
sleep 200 &
sleep 300 &
jobs
```

```text
[1]   Running                 sleep 100 &
[2]-  Running                 sleep 200 &
[3]+  Running                 sleep 300 &
```

The `+` marks the current default job (what `fg` and `bg` will act on). The `-` marks the previous job.

To bring a specific job to the foreground:

```bash
fg %2
```

To kill a specific job:

```bash
kill %1
```

### disown — Detaching a Job from the Shell

If you start a long-running process and then realize you need to log out, `disown` removes it from the shell's job table so it won't receive SIGHUP when the shell exits:

```bash
./long_running_script.sh &
disown
```

Or disown a specific job:

```bash
disown %1
```

After `disown`, the process continues running but `jobs` won't show it anymore. You'd need `ps` to find it.

---

## 7.6 nohup — Surviving Logout

**nohup** (no hangup) runs a command immune to SIGHUP signals. When you log out, the shell sends SIGHUP to all its child processes. `nohup` prevents that from killing your process.

```bash
nohup ./long_backup.sh &
```

```text
nohup: ignoring input and appending output to 'nohup.out'
[1] 1550
```

By default, `nohup` redirects output to `nohup.out` in the current directory. You can redirect it yourself:

```bash
nohup ./long_backup.sh > /tmp/backup.log 2>&1 &
```

The `2>&1` redirects stderr to the same file as stdout (we covered redirection in Week 4). This gives you a complete log of everything the script produced.

**nohup vs disown:**

| Feature | nohup | disown |
|---------|-------|--------|
| When to use | Before starting the command | After the command is already running |
| SIGHUP protection | Yes | Yes |
| Output handling | Redirects to nohup.out by default | No output redirection |
| Still in job table | Yes | No |

In practice: if you know in advance the process should survive logout, use `nohup`. If you already started it and realized too late, use `disown`.

---

## 7.7 System Resource Monitoring

Understanding process management is only half the picture. You also need to know what's happening with the system's resources — memory, disk, CPU, and I/O. This section covers the tools you'll use every day when managing Linux systems.

### Memory: free

```bash
free -h
```

```text
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       412Mi       3.1Gi        12Mi       502Mi       3.4Gi
Swap:          2.0Gi          0B       2.0Gi
```

The critical column is **available**, not free. Linux aggressively uses "free" memory for disk caching (`buff/cache`), which dramatically improves performance. This cached memory is immediately reclaimable when applications need it. So `available` = `free` + reclaimable `buff/cache`.

If you see `available` dropping close to zero and `Swap` being used, the system is under memory pressure. If swap usage is climbing, you either need more RAM or you need to find the process eating all the memory.

### Disk Space: df

```bash
df -h
```

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda2        39G  4.2G   33G  12% /
tmpfs           1.9G     0  1.9G   0% /dev/shm
/dev/sda1       512M  6.1M  506M   2% /boot/efi
```

Key things to watch:
- Any filesystem above 90% usage needs attention
- The root filesystem (`/`) running full can crash the system — logs can't be written, databases can't create temp files, and applications fail in unpredictable ways
- `tmpfs` is a RAM-based filesystem; it doesn't use disk

### Finding Large Directories: du

When `df` tells you the disk is filling up, `du` helps you find where:

```bash
# Summarize sizes of top-level directories
sudo du -sh /* 2>/dev/null | sort -rh | head -10
```

```text
5.1G    /usr
1.2G    /var
380M    /lib
150M    /boot
42M     /etc
...
```

Then drill down:

```bash
sudo du -sh /var/* 2>/dev/null | sort -rh | head -10
```

Common disk space culprits: `/var/log` (log files), `/var/cache` (package caches), `/tmp` (temp files that nobody cleaned up), and `/home` (user data).

The flags: `-s` summarizes (one line per argument instead of listing every subdirectory), `-h` is human-readable, and `sort -rh` sorts by size in reverse (largest first). We covered pipes and sort in Week 4.

### System Uptime and Load

```bash
uptime
```

```text
 10:15:03 up 1:00,  1 user,  load average: 0.12, 0.08, 0.03
```

This tells you the current time, how long the system has been running, how many users are logged in, and the load averages (1, 5, and 15 minutes). We discussed load average in Section 7.3 — the same numbers appear here.

### CPU Information

```bash
lscpu
```

```text
Architecture:           aarch64
CPU(s):                 2
Model name:             Cortex-A76
Thread(s) per core:     1
Core(s) per socket:     2
Socket(s):              1
...
```

This tells you how many CPUs the system has, the architecture, and the core/thread layout. On your Parallels VMs, you'll see the 2 CPUs you allocated.

### Block Devices: lsblk

```bash
lsblk
```

```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   40G  0 disk
├─sda1   8:1    0  512M  0 part /boot/efi
└─sda2   8:2    0 39.5G  0 part /
```

This shows your disk layout — the physical disk and how it's partitioned. We covered partitions in the installation process (Week 1), and this is how you verify that layout after the fact.

### vmstat — Virtual Memory Statistics

```bash
vmstat 2 5
```

This runs vmstat every 2 seconds, 5 times:

```text
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 3276800  51200 463872    0    0    12     8   50  100  0  0 99  0  0
 0  0      0 3276544  51200 463872    0    0     0     4   42   88  0  0 100 0  0
 0  0      0 3276544  51200 463872    0    0     0     0   38   82  0  0 100 0  0
```

Key columns:

| Column | Meaning | Red Flag |
|--------|---------|----------|
| `r` | Processes waiting for CPU | Consistently > CPU count |
| `b` | Processes in uninterruptible sleep (blocked on I/O) | Any value > 0 sustained |
| `si/so` | Swap in/out (KB/s) | Any sustained swap activity |
| `wa` | CPU % waiting on I/O | Above 10-20% sustained |

`vmstat` is one of the first tools you run when troubleshooting a slow system. The first line is always an average since boot — ignore it and look at subsequent lines for current behavior.

### iostat — I/O Statistics

`iostat` may need to be installed:

| Distro | Package |
|--------|---------|
| Ubuntu | `sudo apt install sysstat` |
| Rocky | `sudo dnf install sysstat` |

```bash
iostat -xz 2 3
```

```text
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.15    0.00    0.10    0.02    0.00   99.73

Device            r/s     w/s     rkB/s     wkB/s   await  %util
sda              0.50    1.20     12.00     48.00    1.50   0.20
```

The columns to watch:

| Column | Meaning | Red Flag |
|--------|---------|----------|
| `await` | Average I/O wait time (ms) | Above 10-20ms on SSDs |
| `%util` | How busy the device is | Above 80% sustained |
| `r/s`, `w/s` | Reads/writes per second | Context-dependent |

High `%util` combined with high `await` means the disk is a bottleneck. This is a common cause of slow systems that show low CPU usage — the CPU is idle because it's waiting for the disk.

---

## 7.8 The /proc Filesystem

Linux exposes an enormous amount of kernel and process information through the **/proc** filesystem. It looks like a directory tree full of files, but nothing actually exists on disk — the kernel generates this information on the fly when you read it.

### System Information

```bash
# CPU information (same data as lscpu, more detail)
cat /proc/cpuinfo

# Memory information
cat /proc/meminfo

# Kernel version
cat /proc/version

# Current load average
cat /proc/loadavg
```

`/proc/meminfo` is where `free` gets its data. `/proc/loadavg` is where `uptime` gets the load average.

### Per-Process Information

Every running process has a directory at `/proc/[pid]/`:

```bash
# Find your shell's PID
echo "$$"
```

```text
1423
```

Now explore that process:

```bash
# Process status (state, memory, threads, etc.)
cat /proc/1423/status
```

```text
Name:   bash
State:  S (sleeping)
Tgid:   1423
Pid:    1423
PPid:   1422
Uid:    1000    1000    1000    1000
VmRSS:      5120 kB
Threads:    1
...
```

```bash
# The command that started this process
cat /proc/1423/cmdline | tr '\0' ' '
```

```text
-bash
```

The `cmdline` file uses null bytes as separators (not spaces), so `tr '\0' ' '` makes it readable.

```bash
# Open file descriptors
ls -l /proc/1423/fd/
```

```text
lrwx------ 1 student student 64 ... 0 -> /dev/pts/0
lrwx------ 1 student student 64 ... 1 -> /dev/pts/0
lrwx------ 1 student student 64 ... 2 -> /dev/pts/0
lr-x------ 1 student student 64 ... 255 -> /dev/pts/0
```

File descriptors 0, 1, and 2 are stdin, stdout, and stderr — all pointing to your terminal (`/dev/pts/0`). We covered file descriptors and redirection in Week 4; this is where you can see them in action at the kernel level.

```bash
# Working directory of the process
ls -l /proc/1423/cwd
```

```text
lrwx------ 1 student student 0 ... /proc/1423/cwd -> /home/student
```

This is incredibly useful for debugging: when a process complains it can't find a file, checking its `/proc/[pid]/cwd` tells you what directory it thinks it's running in.

---

## 7.9 lsof — List Open Files

In Linux, everything is a file: regular files, directories, network sockets, pipes, devices. `lsof` lists all open files, making it one of the most versatile debugging tools available.

### Finding What's Using a Port

This is the single most common use of `lsof`. You try to start a web server and get "Address already in use." Who's holding the port?

```bash
sudo lsof -i :22
```

```text
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
sshd     1100 root    3u  IPv4  25432      0t0  TCP *:ssh (LISTEN)
sshd     1100 root    4u  IPv6  25434      0t0  TCP *:ssh (LISTEN)
sshd     1400 root    4u  IPv4  27890      0t0  TCP 10.211.55.3:ssh->10.211.55.2:52431 (ESTABLISHED)
```

Now you know: PID 1100 is the SSH daemon listening on port 22, and there's one active connection.

For a broader view of all listening ports:

```bash
sudo lsof -i -P -n | grep LISTEN
```

The `-P` prevents port-to-service name conversion (shows `22` instead of `ssh`), and `-n` prevents DNS lookups (shows IPs instead of hostnames). Both speed up the output considerably.

You can also use `ss` (the modern replacement for `netstat`, which we'll cover more in the networking weeks):

```bash
ss -tlnp
```

```text
State   Recv-Q  Send-Q  Local Address:Port   Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22            0.0.0.0:*          users:(("sshd",pid=1100,fd=3))
LISTEN  0       128     [::]:22               [::]:*             users:(("sshd",pid=1100,fd=4))
```

### Finding What Files a Process Has Open

```bash
lsof -p 1100
```

This shows every file the SSH daemon has open — its binary, shared libraries, configuration files, log files, network sockets, and more. Useful when you need to understand what a process is doing.

### Finding Who's Using a File

```bash
lsof /var/log/syslog
```

This shows which processes have `/var/log/syslog` open. Useful when you can't unmount a filesystem ("device is busy") or can't delete a file that something is using.

---

## 7.10 nice and renice — Process Priority

Every process has a **nice value** that influences how much CPU time the scheduler gives it. The nice value ranges from -20 (highest priority) to 19 (lowest priority). The default is 0.

The name comes from being "nice" to other processes — a higher nice value means you're being nicer by taking less CPU time.

### Starting a Process with a Specific Priority

```bash
# Run a CPU-intensive task at low priority
nice -n 10 ./heavy_computation.sh
```

This starts the process with nice value 10 — it'll run, but it won't compete aggressively with normal-priority processes for CPU time.

### Changing Priority of a Running Process

```bash
# Lower the priority of PID 1502
renice 10 -p 1502
```

```text
1502 (process ID) old priority 0, new priority 10
```

Only root can increase priority (lower nice values). Regular users can only decrease priority (higher nice values — being nicer):

```bash
# This requires root
sudo renice -5 -p 1502
```

In practice, you'll use `nice` when running backups, batch jobs, or compilations that shouldn't interfere with production services. If a runaway process is eating CPU and degrading service, `renice` it to 19 to give everything else breathing room while you figure out what's wrong.

---

## 7.11 strace — Tracing System Calls

Every time a process reads a file, opens a network connection, allocates memory, or does almost anything useful, it makes a **system call** to the kernel. `strace` intercepts and records these calls.

This is an advanced debugging tool, but even a basic understanding is tremendously valuable. If a program fails with a vague error, strace often reveals exactly what went wrong.

Install if needed:

| Distro | Package |
|--------|---------|
| Ubuntu | `sudo apt install strace` |
| Rocky | `sudo dnf install strace` |

```bash
# Trace a simple command
strace ls /tmp 2>&1 | tail -15
```

```text
openat(AT_FDCWD, "/tmp", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY) = 3
getdents64(3, ..., 32768)               = 80
getdents64(3, ..., 32768)               = 0
close(3)                                = 0
write(1, "file1.txt\nfile2.txt\n", 20)  = 20
...
exit_group(0)                           = ?
```

You can see `ls` opening the `/tmp` directory, reading its entries with `getdents64`, and writing the output.

A more practical example — tracing a process that can't find a config file:

```bash
strace -e openat ./my_app 2>&1 | grep "No such file"
```

```text
openat(AT_FDCWD, "/etc/my_app/config.yaml", O_RDONLY) = -1 ENOENT (No such file or directory)
```

Now you know exactly which path it's looking for. The `-e openat` filter shows only file-open calls, cutting through the noise.

You can also attach to a running process:

```bash
sudo strace -p 1100
```

This traces the SSH daemon live. Press Ctrl+C to stop. Use this sparingly in production — strace slows down the traced process.

---

## 7.12 Server Monitoring: Putting It All Together

When you're responsible for a Linux server — whether it's a web server, database, or application host — you need a systematic approach to monitoring. Here's the mental model.

### The Three Resources That Matter

Almost every performance problem comes down to one of three bottlenecks:

| Resource | Symptom | Tools |
|----------|---------|-------|
| CPU | High load average, slow responses | `top`, `htop`, `vmstat`, `uptime` |
| Memory | Swap usage climbing, OOM kills in logs | `free -h`, `vmstat`, `/proc/meminfo` |
| Disk I/O | High `wa%` in top, slow file operations | `iostat`, `vmstat`, `iotop` |

### A Quick Health Check

When you log into a server, this sequence takes 30 seconds and gives you a complete picture:

```bash
# 1. How long has it been up? Is the load reasonable?
uptime

# 2. Is memory OK?
free -h

# 3. Are disks filling up?
df -h

# 4. What's consuming resources right now?
top -bn1 | head -20

# 5. Any swap activity or I/O issues?
vmstat 1 3
```

If something looks wrong, you drill down with `ps`, `lsof`, `iostat`, or `strace` depending on which resource is the bottleneck.

### Load Average Rules of Thumb

Your VMs have 2 CPUs. Here's how to interpret load average:

| Load Avg (2 CPUs) | Meaning |
|-------------------|---------|
| 0.0 – 1.0 | Comfortable. CPUs have headroom. |
| 1.0 – 2.0 | Healthy. CPUs are well-utilized. |
| 2.0 – 3.0 | Busy. Tasks are starting to queue. |
| 3.0+ | Overloaded. Investigate immediately. |

Scale these numbers by your CPU count. A 16-core server with load average 8.0 is at 50% capacity — perfectly fine. The same number on a 2-core VM means processes are stacked four-deep in the queue.

### Memory Pressure Signals

Watch for these warning signs in `free -h` and `vmstat`:

1. **available** memory is below 10% of total — applications may start getting slow
2. **swap used** is non-zero and growing — the system is actively swapping, performance degrades
3. `si`/`so` in vmstat are consistently non-zero — active swap I/O, this is painful
4. **OOM Killer** messages in `/var/log/syslog` or `dmesg` — the kernel killed a process because it ran out of memory

Check the logs:

```bash
# Ubuntu
sudo grep -i "oom" /var/log/syslog

# Rocky
sudo grep -i "oom" /var/log/messages
```

If the OOM killer activates, it means the system was so memory-starved that the kernel chose to kill a process to survive. This is a critical event that requires investigation.

---

## 7.13 Distro Differences Summary

Most process and monitoring tools work identically on Ubuntu and Rocky. Here are the differences you'll encounter:

| Task | Ubuntu | Rocky |
|------|--------|-------|
| Install htop | `sudo apt install htop` | `sudo dnf install htop` |
| Install sysstat (iostat, vmstat) | `sudo apt install sysstat` | `sudo dnf install sysstat` |
| Install strace | `sudo apt install strace` | `sudo dnf install strace` |
| System log location | `/var/log/syslog` | `/var/log/messages` |
| View system journal | `journalctl` (both) | `journalctl` (both) |
| Default ps output | Identical | Identical |
| /proc filesystem | Identical | Identical |

The monitoring commands themselves (`ps`, `top`, `kill`, `free`, `df`, `du`, `lsof`, `vmstat`, `iostat`, `nice`, `strace`) work the same way on both distributions. The only differences are installation commands and log file locations — a pattern you've seen since Week 3 when we covered package management.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 7.1: Process Investigation](labs/lab_01_process_investigation.md)** — Use ps, top, /proc to investigate running processes, trace relationships, and find port listeners
- **[Lab 7.2: Resource Monitoring](labs/lab_02_resource_monitoring.md)** — Build a monitoring checklist, practice with htop, vmstat, iostat, and use lsof to find port conflicts

---

## Checklist

Before moving to Week 8, confirm you can:

- [ ] List all running processes with ps and interpret the output columns
- [ ] Find a specific process by name using pgrep or ps with grep
- [ ] Send signals to processes with kill and explain SIGTERM vs SIGKILL
- [ ] Move a process to the background and bring it back to the foreground
- [ ] Run a command that survives logout using nohup or disown
- [ ] Check memory usage with free and interpret available vs used memory
- [ ] Check disk usage with df and find large directories with du
- [ ] Read system information from /proc (CPU count, memory, process details)
- [ ] Use lsof to find which process is listening on a specific port
- [ ] Explain load average and what high values mean for system health

---

[← Previous Week](../week-06/README.md) · [Next Week →](../week-08/README.md)
