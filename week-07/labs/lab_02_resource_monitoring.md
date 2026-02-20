# Lab 7.2: Resource Monitoring

> **Objective:** Build a monitoring checklist: check CPU load, memory usage, disk space, open file descriptors, and network connections. Practice with htop, vmstat, iostat. Kill runaway processes. Use lsof.
>
> **Concepts practiced:** free, df, du, uptime, vmstat, iostat, htop, lsof, nice, /proc
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Ubuntu (works on Rocky with minor differences)

---

## Part 1: The Quick Health Check

A systematic approach matters. When you log into a server — whether for routine maintenance or because something is on fire — this sequence takes 30 seconds and tells you the state of the machine.

### Step 1: Check Uptime and Load

```bash
uptime
```

**Expected output:**

```text
 10:15:03 up 2:30,  1 user,  load average: 0.08, 0.05, 0.01
```

Record the three load average numbers. Your VM has 2 CPUs, so load averages below 2.0 mean the CPUs have capacity.

**Before you continue, predict:** If the 1-minute load average is 0.08 but the 15-minute average is 3.5, what does that tell you about recent system history?

(Answer: The system was heavily loaded recently but the spike has subsided. The 15-minute average is still catching up.)

### Step 2: Check Memory

```bash
free -h
```

**Expected output:**

```text
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       412Mi       3.1Gi        12Mi       502Mi       3.4Gi
Swap:          2.0Gi          0B       2.0Gi
```

Record these values:
- **available** memory: _______ (this is the number that matters)
- **swap used**: _______ (should be 0B on a healthy, lightly-loaded system)

Now get the same data from /proc:

```bash
grep -E "MemTotal|MemAvailable|SwapTotal|SwapFree" /proc/meminfo
```

**Expected output:**

```text
MemTotal:        3932160 kB
MemAvailable:    3538944 kB
SwapTotal:       2097152 kB
SwapFree:        2097152 kB
```

This is where `free` gets its data. The values will match (after unit conversion).

### Step 3: Check Disk Space

```bash
df -h
```

**Expected output:**

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda2        39G  4.2G   33G  12% /
tmpfs           1.9G     0  1.9G   0% /dev/shm
/dev/sda1       512M  6.1M  506M   2% /boot/efi
```

Check that no filesystem is above 80% usage. On your fresh VM, everything should be well below that.

Record the Use% for the root filesystem (`/`): _______

### Step 4: Quick CPU and Process Check

```bash
top -bn1 | head -5
```

The `-b` flag runs top in batch mode (non-interactive), and `-n1` runs it for exactly one iteration. This is how you capture top's output in a script or pipeline.

**Expected output (first 5 lines):**

```text
top - 10:16:12 up 2:31,  1 user,  load average: 0.05, 0.04, 0.01
Tasks: 112 total,   1 running, 111 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.3 us,  0.2 sy,  0.0 ni, 99.5 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :   3936.0 total,   3200.5 free,    412.3 used,    502.8 buff/cache
MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   3524.0 avail Mem
```

Check the `zombie` count on the Tasks line. It should be 0.

Check the `wa` value on the Cpu line. It should be near 0.0 on an idle system.

### Step 5: Check for I/O Problems

```bash
vmstat 1 3
```

**Expected output:**

```text
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 0  0      0 3276800  51200 463872    0    0    12     8   50  100  0  0 99  0  0
 0  0      0 3276544  51200 463872    0    0     0     4   42   88  0  0 100 0  0
 0  0      0 3276544  51200 463872    0    0     0     0   38   82  0  0 100 0  0
```

Remember: the first line is an average since boot. Look at lines 2 and 3 for current behavior.

Check these columns:
- `b` (blocked processes): should be 0
- `si`/`so` (swap in/out): should be 0
- `wa` (I/O wait): should be 0 or very low

You've just completed a full health check in under a minute. In production, this is your starting point every time.

---

## Part 2: Installing and Using htop

### Step 6: Install htop

On Ubuntu:

```bash
sudo apt install -y htop
```

On Rocky:

```bash
sudo dnf install -y htop
```

### Step 7: Explore htop

```bash
htop
```

Once inside htop, practice these operations:

1. **Observe the CPU bars** at the top. Each bar represents one CPU core. Green is user-space, red is kernel-space, blue is low-priority.

2. Press **F5** to toggle tree view. This shows the same parent-child hierarchy as `pstree`, but live and interactive.

3. Press **F4** to filter. Type `sshd` and press Enter. Only SSH-related processes appear. Press **F4** again and clear the filter.

4. Press **F6** to choose a sort column. Select `PERCENT_MEM` to sort by memory usage. Press Enter.

5. Use arrow keys to select a process. Press **F9** to open the signal menu. You can see all available signals listed. Press Escape to cancel (don't kill anything yet).

6. Press **F2** to open the setup screen. Explore the options. Press Escape when done.

7. Press **q** to quit htop.

---

## Part 3: Monitoring I/O with iostat

### Step 8: Install sysstat (if needed)

`iostat` is part of the `sysstat` package.

On Ubuntu:

```bash
sudo apt install -y sysstat
```

On Rocky:

```bash
sudo dnf install -y sysstat
```

### Step 9: Check I/O Statistics

```bash
iostat -xz 2 3
```

**Expected output:**

```text
avg-cpu:  %user   %nice %system %iowait  %steal   %idle
           0.10    0.00    0.08    0.01    0.00   99.81

Device            r/s     w/s     rkB/s     wkB/s   await  %util
sda              0.30    0.80     8.00     32.00    1.20   0.15
```

Key values to record:
- `%iowait`: _______ (should be near 0 on an idle system)
- `await` (average I/O wait in ms): _______ (under 10ms is excellent for an SSD)
- `%util` (device utilization): _______ (under 10% on an idle system)

The flags: `-x` shows extended statistics, `-z` hides devices with zero activity, `2 3` means sample every 2 seconds for 3 iterations.

---

## Part 4: Finding Large Directories

### Step 10: Find Where Disk Space Is Used

Start from the top:

```bash
sudo du -sh /* 2>/dev/null | sort -rh | head -10
```

**Expected output (approximately):**

```text
5.1G    /usr
1.2G    /var
380M    /lib
150M    /boot
42M     /etc
22M     /run
12M     /home
...
```

Drill into the largest directory:

```bash
sudo du -sh /usr/* 2>/dev/null | sort -rh | head -5
```

Then into /var:

```bash
sudo du -sh /var/* 2>/dev/null | sort -rh | head -5
```

**Before you continue, predict:** On a fresh server, which subdirectory of /var will be the largest?

(Typically `/var/cache` or `/var/lib` — the package manager cache and package databases.)

### Step 11: Check Your Home Directory

```bash
du -sh ~/* 2>/dev/null | sort -rh
```

On a fresh system this will be minimal. As the course progresses and you create files, this is how you'd track down space usage in your home directory.

---

## Part 5: Finding Port Conflicts with lsof

### Step 12: List All Listening Ports

```bash
sudo lsof -i -P -n | grep LISTEN
```

**Expected output:**

```text
sshd     1100  root    3u  IPv4  25432      0t0  TCP *:22 (LISTEN)
sshd     1100  root    4u  IPv6  25434      0t0  TCP *:22 (LISTEN)
```

You should see sshd on port 22. There may be other services depending on what you've installed in previous weeks.

### Step 13: Simulate a Port Conflict

Start a simple listener on port 8080:

```bash
# Start a process listening on port 8080
python3 -m http.server 8080 &
```

(If python3 is not installed, use: `nc -l 8080 &` instead.)

Verify it's listening:

```bash
sudo lsof -i :8080
```

**Expected output:**

```text
COMMAND    PID    USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
python3   1600 student    3u  IPv4  28500      0t0  TCP *:8080 (LISTEN)
```

Now try to start another listener on the same port:

```bash
python3 -m http.server 8080
```

**Expected output:**

```text
OSError: [Errno 98] Address already in use
```

This is the "port already in use" error you'll encounter in real life. Now you know how to find the culprit — `lsof -i :8080` immediately tells you the PID and command.

Clean up:

```bash
kill "$(lsof -t -i :8080)"
```

The `-t` flag makes lsof output only PIDs, which feeds directly into `kill`.

Verify the port is free:

```bash
sudo lsof -i :8080
```

**Expected output:** No output (the port is free).

---

## Part 6: Creating and Killing a Runaway Process

### Step 14: Create a Runaway Process

This simulates a process that's consuming CPU and producing output endlessly:

```bash
yes > /dev/null &
```

`yes` prints "y" endlessly. Redirecting to `/dev/null` discards the output, but the process still consumes CPU.

Record the PID: _______

### Step 15: Observe the Impact

Check the CPU usage immediately:

```bash
top -bn1 | head -12
```

You should see the `yes` process consuming close to 100% of one CPU. The load average will start climbing.

Check with `ps`:

```bash
ps aux --sort=-%cpu | head -5
```

**Expected output:** The `yes` process at the top with high %CPU.

### Step 16: Use renice Before Killing

Instead of killing it immediately, practice lowering its priority first:

```bash
# Replace PID with the actual PID of the yes process
renice 19 -p "$(pgrep yes)"
```

**Expected output:**

```text
<PID> (process ID) old priority 0, new priority 19
```

Run `top -bn1 | head -12` again. The process still uses CPU, but with the lowest priority. If other processes needed CPU time, the scheduler would give them preference.

### Step 17: Kill the Runaway

Now kill it properly — SIGTERM first:

```bash
kill "$(pgrep yes)"
```

Verify it's gone:

```bash
pgrep yes
```

**Expected output:** No output (the process is gone).

If it were still running (which it shouldn't be for `yes`, but some processes ignore SIGTERM):

```bash
kill -9 "$(pgrep yes)"
```

### Step 18: Check Recovery

```bash
uptime
```

The 1-minute load average may still be elevated. Wait a minute and check again — it should drop back toward 0. The 5-minute and 15-minute averages smooth out slower, showing the history of the spike.

---

## Part 7: Building a Monitoring Script (Optional Challenge)

### Step 19: Combine Everything

Create a one-liner that performs a complete health check:

```bash
echo "=== UPTIME ===" && uptime && echo "=== MEMORY ===" && free -h && echo "=== DISK ===" && df -h / && echo "=== LOAD ===" && cat /proc/loadavg && echo "=== TOP 5 BY CPU ===" && ps aux --sort=-%cpu | head -6 && echo "=== TOP 5 BY MEM ===" && ps aux --sort=-%mem | head -6
```

This produces a complete snapshot of system health. In later weeks when we cover shell scripting, you could turn this into a proper monitoring script with thresholds and alerts.

---

## Verify Your Work

Run these commands and confirm the expected results:

```bash
# Can you check memory?
free -h | grep "Mem:" | awk '{print "Available:", $7}'
```

Expected: `Available:` followed by a memory value (e.g., `3.4Gi`)

```bash
# Can you check disk space?
df -h / | tail -1 | awk '{print "Root disk usage:", $5}'
```

Expected: `Root disk usage:` followed by a percentage (e.g., `12%`)

```bash
# Can you find listeners?
ss -tlnp | grep -c "LISTEN"
```

Expected: A number of 1 or more (at least sshd is listening)

```bash
# Can you use vmstat?
vmstat 1 2 | tail -1 | awk '{print "CPU idle:", $15"%"}'
```

Expected: `CPU idle:` followed by a high percentage (95%+ on an idle system)

```bash
# Is htop installed?
which htop && echo "htop is ready"
```

Expected: A path followed by `htop is ready`

```bash
# Can you find large directories?
sudo du -sh /usr 2>/dev/null
```

Expected: A size value for /usr (typically 3-6 GB)

If all checks pass, you have a solid toolkit for monitoring Linux systems. These are the same tools and workflows that production engineers use daily. As you move into later weeks covering services (Week 11), web servers (Week 12), and containers (Week 15+), you'll use these monitoring skills to verify that everything is running correctly.
