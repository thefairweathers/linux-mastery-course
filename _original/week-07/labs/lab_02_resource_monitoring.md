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

When you log into a server — routine maintenance or incident response — this sequence takes 30 seconds and tells you the state of the machine.

### Step 1: Check Uptime and Load

```bash
uptime
```

**Expected output:**

```text
 10:15:03 up 2:30,  1 user,  load average: 0.08, 0.05, 0.01
```

Record the three load average numbers. Your VM has 2 CPUs, so load averages below 2.0 mean the CPUs have capacity.

**Before you continue, predict:** If the 1-minute load average is 0.08 but the 15-minute average is 3.5, what does that tell you? (Answer: The system was heavily loaded recently but the spike has subsided.)

### Step 2: Check Memory

```bash
free -h
```

Record these values:
- **available** memory: _______ (this is the number that actually matters)
- **swap used**: _______ (should be 0B on a healthy, lightly-loaded system)

Verify the source data:

```bash
grep -E "MemTotal|MemAvailable|SwapTotal|SwapFree" /proc/meminfo
```

This is where `free` gets its data. The values will match after unit conversion.

### Step 3: Check Disk Space

```bash
df -h
```

Check that no filesystem is above 80% usage. Record the Use% for root (`/`): _______

### Step 4: Quick CPU and Process Check

```bash
top -bn1 | head -5
```

The `-b` flag runs top in batch mode (non-interactive), `-n1` for one iteration. Check the `zombie` count on the Tasks line (should be 0) and the `wa` value on the Cpu line (should be near 0.0).

### Step 5: Check for I/O Problems

```bash
vmstat 1 3
```

The first line is an average since boot — ignore it. Look at lines 2 and 3:
- `b` (blocked processes): should be 0
- `si`/`so` (swap in/out): should be 0
- `wa` (I/O wait): should be 0 or very low

You've just completed a full health check in under a minute.

---

## Part 2: Using htop and iostat

### Step 6: Install and Explore htop

On Ubuntu:

```bash
sudo apt install -y htop
```

On Rocky:

```bash
sudo dnf install -y htop
```

Run htop and practice these operations:

```bash
htop
```

1. Observe the CPU bars at the top (green = user, red = kernel, blue = low-priority)
2. Press **F5** to toggle tree view (like live `pstree`)
3. Press **F4** to filter — type `sshd`, then clear the filter
4. Press **F6** to sort by `PERCENT_MEM`
5. Press **q** to quit

### Step 7: Check I/O Statistics

Install sysstat if needed:

```bash
# Ubuntu
sudo apt install -y sysstat

# Rocky
sudo dnf install -y sysstat
```

```bash
iostat -xz 2 3
```

Key values to check:
- `await` (average I/O wait in ms): under 10ms is excellent for an SSD
- `%util` (device utilization): under 10% on an idle system

---

## Part 3: Finding Large Directories

### Step 8: Trace Disk Usage Top-Down

Start from the root:

```bash
sudo du -sh /* 2>/dev/null | sort -rh | head -10
```

Drill into the largest directory:

```bash
sudo du -sh /usr/* 2>/dev/null | sort -rh | head -5
```

Then into /var:

```bash
sudo du -sh /var/* 2>/dev/null | sort -rh | head -5
```

**Before you continue, predict:** On a fresh server, which subdirectory of /var will be the largest? (Typically `/var/cache` or `/var/lib` — the package manager cache and databases.)

---

## Part 4: Finding Port Conflicts with lsof

### Step 9: List Listening Ports

```bash
sudo lsof -i -P -n | grep LISTEN
```

**Expected output:** At least sshd on port 22.

### Step 10: Simulate a Port Conflict

Start a listener on port 8080:

```bash
python3 -m http.server 8080 &
```

(If python3 is not installed, use `nc -l 8080 &` instead.)

Find it with lsof:

```bash
sudo lsof -i :8080
```

Try to start another listener on the same port:

```bash
python3 -m http.server 8080
```

**Expected output:** `OSError: [Errno 98] Address already in use`

This is the "port already in use" error you'll encounter in real life. `lsof -i :8080` immediately tells you the culprit.

Clean up using lsof's `-t` flag (outputs only PIDs):

```bash
kill "$(lsof -t -i :8080)"
```

Verify the port is free:

```bash
sudo lsof -i :8080
```

**Expected output:** No output (port is free).

---

## Part 5: Killing a Runaway Process

### Step 11: Create a Runaway Process

```bash
yes > /dev/null &
```

`yes` prints "y" endlessly. Even with output discarded, it consumes a full CPU core.

### Step 12: Observe the Impact

```bash
ps aux --sort=-%cpu | head -5
```

**Expected output:** `yes` at the top with near 100% CPU.

### Step 13: Renice Before Killing

Lower its priority first:

```bash
renice 19 -p "$(pgrep yes)"
```

**Expected output:** `old priority 0, new priority 19`

The process still uses CPU, but the scheduler gives all other processes preference.

### Step 14: Kill It

```bash
kill "$(pgrep yes)"
```

Verify:

```bash
pgrep yes
```

**Expected output:** No output (process is gone).

Check recovery with `uptime` — the 1-minute load average may still be elevated. Wait a minute and check again.

---

## Part 6: Combined Health Check (Optional Challenge)

### Step 15: One-Liner Health Check

Combine everything into a single command:

```bash
echo "=== UPTIME ===" && uptime && echo "=== MEMORY ===" && free -h && echo "=== DISK ===" && df -h / && echo "=== TOP 5 CPU ===" && ps aux --sort=-%cpu | head -6 && echo "=== TOP 5 MEM ===" && ps aux --sort=-%mem | head -6
```

In later weeks when we cover shell scripting, you could turn this into a proper monitoring script with thresholds and alerts.

---

## Verify Your Work

```bash
# Can you check memory?
free -h | grep "Mem:" | awk '{print "Available:", $7}'
```

Expected: `Available:` followed by a memory value (e.g., `3.4Gi`)

```bash
# Can you check disk space?
df -h / | tail -1 | awk '{print "Root usage:", $5}'
```

Expected: `Root usage:` followed by a percentage (e.g., `12%`)

```bash
# Can you find listeners?
ss -tlnp | grep -c "LISTEN"
```

Expected: 1 or more

```bash
# Can you use vmstat?
vmstat 1 2 | tail -1 | awk '{print "CPU idle:", $15"%"}'
```

Expected: `CPU idle:` followed by a high percentage (95%+)

```bash
# Is htop installed?
which htop && echo "htop is ready"
```

Expected: A path followed by `htop is ready`

If all checks pass, you have a solid toolkit for monitoring Linux systems. These same tools and workflows are what production engineers use daily. As you move into later weeks covering services, web servers, and containers, you'll rely on these monitoring skills constantly.
