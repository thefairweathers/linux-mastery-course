---
title: "Lab 11.2: Custom Service & Timer"
sidebar:
  order: 2
---


> **Objective:** Write a simple bash daemon script, create a systemd service unit for it, install and manage it, then create a systemd timer for a cleanup script.
>
> **Concepts practiced:** systemd unit files, [Unit]/[Service]/[Install] sections, systemd timers, ExecStart, Restart, User
>
> **Time estimate:** 40 minutes
>
> **VM(s) needed:** Ubuntu (works identically on Rocky)

---

## Part 1: Create a Custom Systemd Service

In this part, you'll install the provided daemon script, create a systemd service unit for it, and verify that systemd manages it correctly — including automatic restart after a crash.

### Step 1: Install the Daemon Script

The file `lab_02_daemon.sh` is provided in this lab directory. Copy it to a system location and make it executable:

```bash
sudo cp lab_02_daemon.sh /usr/local/bin/my-daemon.sh
sudo chmod +x /usr/local/bin/my-daemon.sh
```

Verify it runs manually (press `Ctrl+C` after a few seconds):

```bash
sudo /usr/local/bin/my-daemon.sh
```

Check that it wrote to the log:

```bash
cat /var/log/my-daemon.log
```

You should see a startup message and at least one running message with a timestamp and PID.

Clean up the test log before proceeding:

```bash
sudo rm -f /var/log/my-daemon.log
```

### Step 2: Create the Service Unit File

Create the unit file:

```bash
sudo nano /etc/systemd/system/my-daemon.service
```

Write the following content:

```ini
[Unit]
Description=My Custom Daemon (Lab 11.2)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/my-daemon.sh
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=my-daemon

[Install]
WantedBy=multi-user.target
```

Let's trace through the decisions you're making here:

- **`Type=simple`** — The script runs in the foreground (the `while true` loop never exits), so `simple` is correct
- **`Restart=on-failure`** — If the script dies unexpectedly, systemd restarts it
- **`RestartSec=5`** — Wait 5 seconds before restarting to avoid a tight crash loop
- **`StandardOutput=journal`** — The script writes to a file, but if it wrote to stdout, this captures it
- **`SyslogIdentifier=my-daemon`** — Tags journal entries for easy filtering
- **`WantedBy=multi-user.target`** — Starts at boot in normal multi-user mode

### Step 3: Reload, Enable, and Start

```bash
# Tell systemd about the new unit file
sudo systemctl daemon-reload

# Enable the service to start at boot
sudo systemctl enable my-daemon

# Start the service now
sudo systemctl start my-daemon
```

### Step 4: Verify the Service Is Running

```bash
systemctl status my-daemon
```

You should see:

- The green dot indicating active status
- `Active: active (running)` with an uptime
- The main PID running `my-daemon.sh`
- The `CGroup` showing the process tree

Check that it's writing to the log:

```bash
cat /var/log/my-daemon.log
```

You should see new entries with timestamps every 10 seconds.

Check the journal:

```bash
journalctl -u my-daemon -n 10 --no-pager
```

### Step 5: Test Automatic Restart

This is where systemd's process supervision shines. We'll kill the daemon and watch systemd bring it back.

First, note the current PID:

```bash
systemctl show my-daemon --property=MainPID --value
```

Now kill the process to simulate a crash:

```bash
sudo kill -9 "$(systemctl show my-daemon --property=MainPID --value)"
```

Wait for the restart (5 seconds, per `RestartSec=5`):

```bash
sleep 6
```

Check the status:

```bash
systemctl status my-daemon
```

Verify the PID changed (the service restarted with a new process):

```bash
systemctl show my-daemon --property=MainPID --value
```

Check the log for the restart:

```bash
tail -5 /var/log/my-daemon.log
```

You should see a new "Daemon starting at" entry followed by fresh "Daemon is running" entries with a new PID.

### Step 6: Test Stop and Disable

```bash
# Stop the service
sudo systemctl stop my-daemon

# Verify it stopped
systemctl is-active my-daemon
# Expected: inactive

# Disable it from starting at boot
sudo systemctl disable my-daemon

# Verify
systemctl is-enabled my-daemon
# Expected: disabled
```

Re-enable and start it — we'll need it running for Part 2:

```bash
sudo systemctl enable --now my-daemon
```

---

## Part 2: Create a Systemd Timer

Now you'll create a timer that runs the provided cleanup script on a schedule. This replaces what you would traditionally do with cron.

### Step 1: Install the Cleanup Script

The file `lab_02_cleanup.sh` is provided in this lab directory. Copy it to a system location:

```bash
sudo cp lab_02_cleanup.sh /usr/local/bin/cleanup.sh
sudo chmod +x /usr/local/bin/cleanup.sh
```

Test it manually:

```bash
sudo /usr/local/bin/cleanup.sh
```

Check that it logged its activity:

```bash
cat /var/log/cleanup.log
```

You should see "Cleanup started" and "Cleanup finished" entries.

### Step 2: Create the Service Unit for the Timer

A timer needs a matching service unit. Create it:

```bash
sudo nano /etc/systemd/system/cleanup.service
```

```ini
[Unit]
Description=Cleanup old logs and temp files (Lab 11.2)

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleanup.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=cleanup
```

Key points:

- **`Type=oneshot`** — The script runs once and exits; it's not a long-running daemon
- **No `[Install]` section** — This service is triggered by the timer, not enabled directly

### Step 3: Create the Timer Unit

```bash
sudo nano /etc/systemd/system/cleanup.timer
```

```ini
[Unit]
Description=Run cleanup every 5 minutes (Lab 11.2)

[Timer]
OnCalendar=*-*-* *:00/5:00
Persistent=true
AccuracySec=30

[Install]
WantedBy=timers.target
```

Let's trace through these directives:

- **`OnCalendar=*-*-* *:00/5:00`** — Run every 5 minutes (at :00, :05, :10, :15, etc.)
- **`Persistent=true`** — If the system was off when a run was due, run it at next opportunity
- **`AccuracySec=30`** — Allow up to 30 seconds of imprecision (lets systemd batch wakeups)
- **`WantedBy=timers.target`** — Activate this timer at boot

> **Note:** We use 5 minutes for the lab so you can see it fire quickly. In production, a cleanup job would typically run daily or hourly.

### Step 4: Verify the Calendar Expression

Before enabling, test that systemd parses your expression correctly:

```bash
systemd-analyze calendar "*-*-* *:00/5:00"
```

Check the next few fire times:

```bash
systemd-analyze calendar --iterations=3 "*-*-* *:00/5:00"
```

### Step 5: Enable and Start the Timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cleanup.timer
```

Note: You enable the **timer**, not the service. The timer triggers the service.

### Step 6: Verify the Timer Is Scheduled

```bash
systemctl list-timers --all
```

You should see `cleanup.timer` in the list with a `NEXT` fire time and the `ACTIVATES` column showing `cleanup.service`.

Check the timer's status:

```bash
systemctl status cleanup.timer
```

### Step 7: Wait for It to Fire (or Trigger Manually)

You can either wait for the next scheduled run or trigger it immediately:

```bash
# Option A: Trigger the service manually (don't wait)
sudo systemctl start cleanup.service

# Option B: Wait for the timer (up to 5 minutes)
```

After it runs, check the results:

```bash
# Check the service status (should show "inactive (dead)" for a oneshot)
systemctl status cleanup.service
```

```bash
# Check the cleanup log
cat /var/log/cleanup.log
```

```bash
# Check the journal for the cleanup service
journalctl -u cleanup.service -n 10 --no-pager
```

### Step 8: Verify the Timer Updated After Running

```bash
systemctl list-timers cleanup.timer
```

The `LAST` column should now show when the service last ran, and `NEXT` should show the next scheduled run.

---

## Part 3: Clean Up

When you're finished with the lab, clean up the services and files:

```bash
# Stop and disable the timer
sudo systemctl disable --now cleanup.timer

# Stop and disable the daemon service
sudo systemctl disable --now my-daemon

# Remove the unit files
sudo rm /etc/systemd/system/my-daemon.service
sudo rm /etc/systemd/system/cleanup.service
sudo rm /etc/systemd/system/cleanup.timer

# Reload systemd
sudo systemctl daemon-reload

# Remove the scripts and logs
sudo rm /usr/local/bin/my-daemon.sh
sudo rm /usr/local/bin/cleanup.sh
sudo rm -f /var/log/my-daemon.log
sudo rm -f /var/log/cleanup.log
```

---

## Verification Checklist

Before marking this lab complete, confirm:

- [ ] The daemon script ran as a systemd service with correct PID shown in status
- [ ] The service automatically restarted after being killed (new PID, fresh uptime)
- [ ] The timer appeared in `systemctl list-timers` with correct NEXT fire time
- [ ] The cleanup service ran (check `/var/log/cleanup.log` for entries)
- [ ] You can explain the difference between `Type=simple` and `Type=oneshot`
- [ ] You can explain why the cleanup service has no `[Install]` section
- [ ] You understand why you enable the `.timer` unit, not the `.service` unit
