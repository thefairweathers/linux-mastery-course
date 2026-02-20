# Week 11: Systemd, Services & the Boot Process

> **Goal:** Manage services with systemd, understand the boot process, create custom service units, and configure services to start automatically.

[← Previous Week](../week-10/README.md) · [Next Week →](../week-12/README.md)

---

## Table of Contents

| Section | Topic |
|---------|-------|
| 11.1 | [The Linux Boot Process](#111-the-linux-boot-process) |
| 11.2 | [What Systemd Replaced — and Why](#112-what-systemd-replaced--and-why) |
| 11.3 | [Service Management with systemctl](#113-service-management-with-systemctl) |
| 11.4 | [Reading Service Status Output](#114-reading-service-status-output) |
| 11.5 | [Viewing Logs with journalctl](#115-viewing-logs-with-journalctl) |
| 11.6 | [Persistent Journal Storage](#116-persistent-journal-storage) |
| 11.7 | [Unit Types](#117-unit-types) |
| 11.8 | [Anatomy of a .service Unit File](#118-anatomy-of-a-service-unit-file) |
| 11.9 | [Key Service Directives](#119-key-service-directives) |
| 11.10 | [Creating a Custom Service Unit](#1110-creating-a-custom-service-unit) |
| 11.11 | [Systemd Timers](#1111-systemd-timers) |
| 11.12 | [Timer Unit Anatomy](#1112-timer-unit-anatomy) |
| 11.13 | [Cron vs Systemd Timer Syntax](#1113-cron-vs-systemd-timer-syntax) |
| 11.14 | [Targets and Runlevels](#1114-targets-and-runlevels) |
| 11.15 | [Boot Performance Analysis](#1115-boot-performance-analysis) |
| 11.16 | [Socket Activation](#1116-socket-activation) |
| 11.17 | [Distro Notes](#1117-distro-notes) |

---

## 11.1 The Linux Boot Process

Every time you power on a Linux machine, a precise chain of events unfolds. Understanding this chain is essential for troubleshooting boot failures and knowing where systemd fits into the picture.

Here is the full sequence from power button to login prompt:

```text
┌──────────────────────────────────────────────────────────────────────┐
│  1. Firmware (BIOS / UEFI)                                          │
│     └─→ POST, hardware init, find boot device                      │
│                                                                      │
│  2. Bootloader (GRUB2)                                               │
│     └─→ Load kernel + initramfs into memory                         │
│                                                                      │
│  3. Kernel                                                           │
│     └─→ Hardware detection, mount root filesystem, start PID 1      │
│                                                                      │
│  4. Init System (systemd — PID 1)                                    │
│     └─→ Read default target, build dependency tree                  │
│                                                                      │
│  5. Services                                                         │
│     └─→ Start units in parallel according to dependencies           │
│                                                                      │
│  6. Login Prompt                                                     │
│     └─→ getty (console) or display manager (graphical)              │
└──────────────────────────────────────────────────────────────────────┘
```

Let's walk through each stage.

### Stage 1: Firmware (BIOS / UEFI)

The **firmware** is the very first software that runs when you press the power button. It performs the **Power-On Self-Test (POST)** — checking that the CPU, memory, and essential hardware are functional. Then it looks for a boot device (hard drive, SSD, USB, network) based on the configured boot order.

Modern systems use **UEFI** (Unified Extensible Firmware Interface), which replaced the older **BIOS** (Basic Input/Output System). UEFI supports larger disks (GPT partition tables), faster boot times, and Secure Boot — a feature that verifies the bootloader hasn't been tampered with.

You can check which firmware your system uses:

```bash
# If this directory exists, you're running UEFI
ls /sys/firmware/efi
```

### Stage 2: Bootloader (GRUB2)

The firmware hands control to the **bootloader**. On both Ubuntu and Rocky Linux, this is **GRUB2** (GRand Unified Bootloader version 2). GRUB2's job is straightforward but critical:

1. Present a menu of available kernels (if configured to show it)
2. Load the selected kernel image into memory
3. Load the **initramfs** (initial RAM filesystem) — a temporary root filesystem containing drivers the kernel needs to mount the real root filesystem
4. Pass control to the kernel with any configured boot parameters

GRUB2's configuration lives in different locations depending on your firmware:

| Component | BIOS Systems | UEFI Systems |
|-----------|-------------|--------------|
| Config file | `/boot/grub2/grub.cfg` | `/boot/efi/EFI/<distro>/grub.cfg` |
| Defaults | `/etc/default/grub` | `/etc/default/grub` |
| Rebuild command | `grub2-mkconfig -o /boot/grub2/grub.cfg` | `grub2-mkconfig -o /boot/efi/EFI/<distro>/grub.cfg` |

> **Note:** On Ubuntu, the command is `grub-mkconfig` (without the `2`), and the config lives at `/boot/grub/grub.cfg`. On Rocky, it's `grub2-mkconfig`.

You can see the kernel parameters GRUB passed to your running system:

```bash
cat /proc/cmdline
```

```text
BOOT_IMAGE=(hd0,gpt2)/vmlinuz-5.15.0-91-generic root=/dev/mapper/ubuntu--vg-ubuntu--lv ro quiet splash
```

### Stage 3: Kernel

The **kernel** decompresses itself, initializes hardware drivers (using modules from initramfs), detects devices, and mounts the real root filesystem. Once the root filesystem is available, the kernel starts a single process — **PID 1** — which on modern distributions is systemd.

You can see PID 1 on your system:

```bash
ps -p 1 -o comm=
```

```text
systemd
```

### Stage 4: Init System (systemd)

**systemd** is the init system and service manager for modern Linux distributions. As PID 1, it is the ancestor of every other process on the system. Its first action is to read the **default target** (think of it as the desired system state) and build a dependency tree of all the units it needs to start.

```bash
# See what target your system boots into
systemctl get-default
```

```text
multi-user.target
```

On a server, this is typically `multi-user.target` (text mode, networking, services). On a desktop, it would be `graphical.target`.

### Stage 5: Services

systemd starts all required services **in parallel** where possible, respecting dependency ordering. This is one of systemd's key advantages over its predecessors — it doesn't start services one at a time in sequence.

### Stage 6: Login Prompt

Once the target is reached, a login prompt appears. For console access, systemd starts `getty` processes on virtual terminals. For graphical desktops, it starts a display manager like GDM or LightDM.

---

## 11.2 What Systemd Replaced — and Why

Before systemd, Linux used **SysVinit** (System V init) as its init system. SysVinit used numbered **runlevels** (0-6) and shell scripts in `/etc/init.d/` to manage services. While it worked, it had real limitations.

Here's why the Linux world moved to systemd:

| Feature | SysVinit | systemd |
|---------|----------|---------|
| Service startup | Sequential (one at a time) | Parallel (dependency-based) |
| Dependency handling | Manual ordering with numbered scripts | Declarative `After=`, `Requires=`, `Wants=` |
| Service monitoring | None — if a daemon dies, nobody notices | Automatic restart with `Restart=` directive |
| Logging | Scattered across `/var/log/*` files | Centralized binary journal (`journalctl`) |
| Configuration | Shell scripts (hundreds of lines) | Declarative unit files (typically 10-20 lines) |
| Boot speed | Slow (sequential) | Fast (parallel with socket activation) |
| Resource control | None built-in | cgroups integration for CPU/memory limits |
| Service status | Parse PID files (unreliable) | `systemctl status` with process tree |

A typical SysVinit service script was 50-200 lines of bash with start/stop/restart/status functions, PID file management, and error handling. The equivalent systemd unit file is usually under 20 lines of declarative configuration. We'll see this firsthand in Section 11.8.

> **Historical note:** systemd was adopted by Fedora in 2011, followed by Red Hat Enterprise Linux 7, Debian 8, and Ubuntu 15.04. Today, virtually every major Linux distribution uses systemd. Both Ubuntu and Rocky Linux have used systemd since their inception or early releases.

---

## 11.3 Service Management with systemctl

**`systemctl`** is your primary tool for interacting with systemd. If you've been managing packages since Week 6, you've likely already used `systemctl enable` after installing a service. Now let's get the full picture.

### Core Service Commands

```bash
# Start a service (runs it now, does not survive reboot)
sudo systemctl start sshd

# Stop a running service
sudo systemctl stop sshd

# Restart a service (stop + start — brief interruption)
sudo systemctl restart sshd

# Reload configuration without restarting (no downtime if supported)
sudo systemctl reload sshd

# Restart if running, do nothing if stopped
sudo systemctl try-restart sshd

# Reload if supported, otherwise restart (safest option)
sudo systemctl reload-or-restart sshd
```

### The Difference Between reload and restart

This distinction matters in production:

- **`restart`** — Stops the process, then starts a new one. Connections are dropped. Every service supports this.
- **`reload`** — Sends a signal (usually SIGHUP) telling the running process to re-read its configuration files. No downtime, no dropped connections. Not every service supports this.

When in doubt, use `reload-or-restart` — systemd will try reload first and fall back to restart.

### Enable and Disable

Starting a service runs it now. Enabling a service makes it start automatically at boot. These are independent operations:

```bash
# Enable a service to start at boot
sudo systemctl enable sshd

# Disable a service from starting at boot
sudo systemctl disable sshd

# Enable AND start in one command
sudo systemctl enable --now sshd

# Disable AND stop in one command
sudo systemctl disable --now sshd
```

When you enable a service, systemd creates a symlink from the target's `wants` directory to the unit file:

```bash
sudo systemctl enable nginx
```

```text
Created symlink /etc/systemd/system/multi-user.target.wants/nginx.service → /lib/systemd/system/nginx.service
```

### Query Service State

```bash
# Check if a service is currently running
systemctl is-active sshd
# Output: active (or inactive, failed)

# Check if a service is enabled for boot
systemctl is-enabled sshd
# Output: enabled (or disabled, static, masked)

# Check if a service has failed
systemctl is-failed sshd
# Output: active (meaning "not failed") or failed
```

These query commands are perfect for scripts because they set the exit code:

```bash
if systemctl is-active --quiet nginx; then
    echo "nginx is running"
else
    echo "nginx is NOT running"
fi
```

The `--quiet` flag suppresses output so only the exit code is used.

### Listing Services

```bash
# List all active services
systemctl list-units --type=service

# List all services (including inactive)
systemctl list-units --type=service --all

# List services that failed to start
systemctl list-units --type=service --state=failed

# List enabled services
systemctl list-unit-files --type=service --state=enabled
```

### Masking Services

Sometimes disabling isn't enough — you want to make absolutely sure a service cannot be started, even manually or as a dependency:

```bash
# Mask a service (links it to /dev/null)
sudo systemctl mask bluetooth

# Unmask a service
sudo systemctl unmask bluetooth
```

A masked service returns an error if anyone tries to start it:

```text
Failed to start bluetooth.service: Unit bluetooth.service is masked.
```

---

## 11.4 Reading Service Status Output

The `systemctl status` command is one of the most information-dense commands in Linux. Let's dissect every line:

```bash
systemctl status sshd
```

```text
● sshd.service - OpenBSD Secure Shell server
     Loaded: loaded (/lib/systemd/system/sshd.service; enabled; preset: enabled)
     Active: active (running) since Wed 2025-01-15 09:23:41 UTC; 3h 12min ago
       Docs: man:sshd(8)
             man:sshd_config(5)
   Main PID: 1234 (sshd)
      Tasks: 1 (limit: 4567)
     Memory: 5.2M
        CPU: 142ms
     CGroup: /system.slice/sshd.service
             └─1234 sshd: /usr/sbin/sshd -D [listener] 0 of 10-100 startups

Jan 15 09:23:41 ubuntu-server systemd[1]: Starting OpenBSD Secure Shell server...
Jan 15 09:23:41 ubuntu-server sshd[1234]: Server listening on 0.0.0.0 port 22.
Jan 15 09:23:41 ubuntu-server systemd[1]: Started OpenBSD Secure Shell server.
```

Here's what each line means:

| Line | Meaning |
|------|---------|
| `● sshd.service` | The dot color indicates state: **green** = active, **red** = failed, **white** = inactive |
| `- OpenBSD Secure Shell server` | The description from the unit file's `Description=` directive |
| `Loaded: loaded (...)` | The unit file path, whether it's enabled, and the vendor preset |
| `enabled` | This service starts at boot |
| `preset: enabled` | The distro vendor ships it as "enable by default" |
| `Active: active (running)` | Current state and how long it's been running |
| `Docs:` | Documentation references from the unit file |
| `Main PID: 1234 (sshd)` | The main process ID and its command name |
| `Tasks: 1` | Number of threads/processes in this service's cgroup |
| `Memory: 5.2M` | Current memory usage (tracked by cgroups) |
| `CPU: 142ms` | Cumulative CPU time consumed since last start |
| `CGroup:` | The cgroup hierarchy and process tree |
| Log lines at bottom | Most recent journal entries for this unit |

### Common Active States

| State | Meaning |
|-------|---------|
| `active (running)` | Service is running normally |
| `active (exited)` | Service ran successfully and exited (oneshot type) |
| `active (waiting)` | Service is running but waiting for an event |
| `inactive (dead)` | Service is not running |
| `failed` | Service tried to start but crashed or returned an error |
| `activating (start)` | Service is in the process of starting |
| `deactivating (stop)` | Service is in the process of stopping |

### Common Loaded States

| State | Meaning |
|-------|---------|
| `enabled` | Starts at boot (symlink exists in target wants directory) |
| `disabled` | Does not start at boot |
| `static` | Cannot be enabled directly; only started as a dependency of another unit |
| `masked` | Completely blocked — linked to `/dev/null` |
| `generated` | Dynamically created by a systemd generator |

---

## 11.5 Viewing Logs with journalctl

In Week 8, you learned about traditional log files in `/var/log/`. systemd adds its own centralized logging system called the **journal**, managed by `systemd-journald`. The journal captures:

- Everything that services write to stdout and stderr
- Kernel messages (previously only in `dmesg`)
- Syslog messages
- Audit messages
- Boot messages

The tool for reading the journal is **`journalctl`**.

### Basic Usage

```bash
# View all journal entries (oldest first, paged)
journalctl

# View entries with newest first
journalctl -r

# View only the last 50 entries
journalctl -n 50

# Follow the journal in real time (like tail -f)
journalctl -f
```

### Filter by Unit

This is the filter you'll use most often. When a service misbehaves, you want *its* logs, not everything:

```bash
# Show all logs for the sshd service
journalctl -u sshd

# Show logs for nginx, most recent first
journalctl -u nginx -r

# Follow a specific service's logs in real time
journalctl -u nginx -f

# Show logs for multiple units
journalctl -u nginx -u php-fpm
```

### Filter by Time

```bash
# Logs since a specific date/time
journalctl --since "2025-01-15 09:00:00"

# Logs in a time range
journalctl --since "2025-01-15 09:00:00" --until "2025-01-15 12:00:00"

# Logs from the last hour
journalctl --since "1 hour ago"

# Logs from today only
journalctl --since today

# Logs from yesterday
journalctl --since yesterday --until today
```

### Filter by Priority

Journal entries have priority levels matching syslog:

| Priority | Level | Meaning |
|----------|-------|---------|
| 0 | emerg | System is unusable |
| 1 | alert | Immediate action required |
| 2 | crit | Critical conditions |
| 3 | err | Error conditions |
| 4 | warning | Warning conditions |
| 5 | notice | Normal but significant |
| 6 | info | Informational messages |
| 7 | debug | Debug-level messages |

```bash
# Show only errors and above (0-3)
journalctl -p err

# Show warnings and above
journalctl -p warning

# Combine with unit filter
journalctl -u nginx -p err

# Show errors since last boot
journalctl -b -p err
```

When you specify a priority, you get that level **and all higher priorities** (lower numbers). So `-p err` shows emerg, alert, crit, and err.

### Filter by Boot

```bash
# Logs from the current boot only
journalctl -b

# Logs from the previous boot
journalctl -b -1

# Logs from two boots ago
journalctl -b -2

# List all available boots
journalctl --list-boots
```

```text
-2 abc123def456 Wed 2025-01-13 08:00:01 UTC—Wed 2025-01-13 23:59:59 UTC
-1 789ghi012jkl Thu 2025-01-14 08:00:01 UTC—Thu 2025-01-14 23:59:59 UTC
 0 mno345pqr678 Fri 2025-01-15 08:00:01 UTC—Fri 2025-01-15 12:35:22 UTC
```

> **Important:** Boot-based filtering requires persistent journal storage. By default, some distributions only keep logs in memory (`/run/log/journal/`), and they're lost on reboot. See Section 11.6 to fix this.

### Output Formats

```bash
# Verbose output with all metadata fields
journalctl -u sshd -o verbose

# JSON output (useful for scripts and piping to jq)
journalctl -u sshd -o json-pretty

# Short output with precise timestamps
journalctl -u sshd -o short-precise

# Only the message text, no metadata
journalctl -u sshd -o cat
```

### Combining Filters

Filters are additive — you can combine as many as you need:

```bash
# Errors from nginx in the last hour from the current boot
journalctl -u nginx -p err --since "1 hour ago" -b
```

### Disk Usage

The journal can grow large. Check and manage its size:

```bash
# Show how much disk space the journal uses
journalctl --disk-usage

# Remove old entries, keeping only the last 500MB
sudo journalctl --vacuum-size=500M

# Remove entries older than 2 weeks
sudo journalctl --vacuum-time=2weeks
```

---

## 11.6 Persistent Journal Storage

By default, `systemd-journald` stores logs in `/run/log/journal/`, which is a tmpfs — **logs are lost on reboot**. For servers, you almost always want persistent storage so you can investigate issues that happened before a reboot.

### Check Your Current Configuration

```bash
# See where journals are stored
ls /run/log/journal/    # Volatile (tmpfs, lost on reboot)
ls /var/log/journal/    # Persistent (survives reboot)
```

If `/var/log/journal/` exists and has contents, you already have persistent storage.

### Enable Persistent Storage

The journal configuration file is `/etc/systemd/journald.conf`. The key directive is `Storage=`:

```bash
sudo mkdir -p /var/log/journal
sudo systemd-tmpfiles --create --prefix /var/log/journal
```

Then edit the configuration:

```bash
sudo nano /etc/systemd/journald.conf
```

Find the `[Journal]` section and set:

```ini
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemKeepFree=1G
MaxRetentionSec=1month
```

| Directive | Meaning |
|-----------|---------|
| `Storage=persistent` | Always write to `/var/log/journal/` |
| `Storage=volatile` | Only write to `/run/log/journal/` (lost on reboot) |
| `Storage=auto` | Write to `/var/log/journal/` if the directory exists, otherwise volatile (this is the default) |
| `SystemMaxUse=500M` | Maximum disk space for journal files |
| `SystemKeepFree=1G` | Always keep at least this much disk space free |
| `MaxRetentionSec=1month` | Delete entries older than this |

Restart journald to apply:

```bash
sudo systemctl restart systemd-journald
```

Verify:

```bash
journalctl --disk-usage
ls -la /var/log/journal/
```

Now `journalctl -b -1` (previous boot) will work because logs survive reboots.

---

## 11.7 Unit Types

So far we've focused on services, but systemd manages much more than that. Everything systemd manages is a **unit**, and units come in several types:

| Unit Type | Extension | Purpose |
|-----------|-----------|---------|
| Service | `.service` | Processes and daemons |
| Timer | `.timer` | Scheduled tasks (replaces cron) |
| Socket | `.socket` | IPC/network socket activation |
| Mount | `.mount` | Filesystem mount points |
| Automount | `.automount` | On-demand filesystem mounting |
| Target | `.target` | Groups of units (like runlevels) |
| Path | `.path` | File/directory monitoring triggers |
| Device | `.device` | Kernel device exposure |
| Swap | `.swap` | Swap space activation |
| Slice | `.slice` | cgroup resource management |
| Scope | `.scope` | Externally created process groups |

The ones you'll use most in daily administration are **service**, **timer**, **socket**, and **target**. We'll cover each in detail.

```bash
# List all unit types
systemctl -t help

# List all loaded units of a specific type
systemctl list-units --type=timer
systemctl list-units --type=socket
systemctl list-units --type=mount
```

---

## 11.8 Anatomy of a .service Unit File

A systemd service unit file is a declarative configuration file, not a script. It tells systemd *what* to run and *how* to manage it. Unit files have three main sections.

### Where Unit Files Live

| Location | Purpose | Priority |
|----------|---------|----------|
| `/usr/lib/systemd/system/` | Vendor-provided unit files (installed by packages) | Lowest |
| `/etc/systemd/system/` | System administrator overrides and custom units | Highest |
| `/run/systemd/system/` | Runtime-generated units (transient) | Medium |

Files in `/etc/systemd/system/` override files with the same name in `/usr/lib/systemd/system/`. This means you should never edit vendor-provided files — instead, copy them to `/etc/` or use `systemctl edit` to create an override.

> **Note:** On Ubuntu, vendor units are in `/lib/systemd/system/` (which is a symlink to `/usr/lib/systemd/system/`). On Rocky, they're directly in `/usr/lib/systemd/system/`. Both paths work on both distros.

### The Three Sections

Here's a real-world example — let's look at the sshd service:

```bash
systemctl cat sshd
```

```ini
[Unit]
Description=OpenBSD Secure Shell server
Documentation=man:sshd(8) man:sshd_config(5)
After=network.target auditd.service
ConditionPathExists=!/etc/ssh/sshd_not_to_be_run

[Service]
EnvironmentFile=-/etc/default/ssh
ExecStartPre=/usr/sbin/sshd -t
ExecStart=/usr/sbin/sshd -D $SSHD_OPTS
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=notify
RuntimeDirectory=sshd
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
```

Let's break down each section.

### [Unit] Section — Identity and Dependencies

This section describes the unit and declares its relationships with other units:

| Directive | Meaning |
|-----------|---------|
| `Description=` | Human-readable description shown in `systemctl status` |
| `Documentation=` | URIs for documentation (man pages, URLs) |
| `After=` | Start this unit *after* the listed units (ordering only) |
| `Before=` | Start this unit *before* the listed units (ordering only) |
| `Requires=` | Hard dependency — if the required unit fails, this unit fails too |
| `Wants=` | Soft dependency — if the wanted unit fails, this unit still starts |
| `Conflicts=` | Cannot run at the same time as the listed units |
| `ConditionPathExists=` | Only start if this path exists (prefix `!` to negate) |

**The critical distinction:** `After=` controls *ordering* (when to start). `Requires=` and `Wants=` control *dependency* (whether to start). You often need both:

```ini
# "Start after network is up, and don't start if network fails"
After=network.target
Requires=network.target
```

```ini
# "Start after network is up, but start even if network fails"
After=network.target
Wants=network.target
```

### [Service] Section — How to Run

This section defines how the service process is managed:

| Directive | Meaning |
|-----------|---------|
| `Type=` | How systemd determines the service is "started" (see below) |
| `ExecStart=` | The command to start the service |
| `ExecStop=` | The command to stop the service (default: send SIGTERM) |
| `ExecReload=` | The command to reload configuration |
| `Restart=` | When to automatically restart (see below) |
| `RestartSec=` | Delay between restart attempts (default: 100ms) |
| `User=` | Run the service as this user |
| `Group=` | Run the service as this group |

**Service Types:**

| Type | Behavior |
|------|----------|
| `simple` | Default. systemd considers it started as soon as `ExecStart` runs |
| `forking` | The process forks and the parent exits. systemd waits for the fork |
| `oneshot` | Process exits after doing its work. Good for setup scripts |
| `notify` | Process sends a notification to systemd when ready |
| `idle` | Like simple, but waits until all other jobs finish |

### [Install] Section — Boot Integration

This section tells systemd what happens when you run `systemctl enable`:

| Directive | Meaning |
|-----------|---------|
| `WantedBy=` | When enabled, create a symlink in this target's `wants` directory |
| `RequiredBy=` | When enabled, create a symlink in this target's `requires` directory |
| `Alias=` | Additional names for this unit |

`WantedBy=multi-user.target` is the most common — it means "start this service when the system reaches multi-user mode" (normal server operation).

### Viewing Any Unit File

You can read any installed unit file without knowing its path:

```bash
# Print the unit file contents
systemctl cat nginx

# Show the unit file path
systemctl show -p FragmentPath nginx

# Show all properties of a unit
systemctl show nginx
```

### Editing Unit Files Safely

Never edit vendor unit files directly. Use drop-in overrides:

```bash
# Create a drop-in override (opens editor)
sudo systemctl edit nginx

# This creates /etc/systemd/system/nginx.service.d/override.conf
# Only put directives you want to CHANGE
```

```ini
[Service]
# Increase the timeout for a slow-starting application
TimeoutStartSec=120
```

```bash
# To replace the entire unit file instead
sudo systemctl edit --full nginx

# Always reload after editing
sudo systemctl daemon-reload
```

**`systemctl daemon-reload`** tells systemd to re-read all unit files from disk. You must run this after any change to unit files.

---

## 11.9 Key Service Directives

Let's go deeper into the directives you'll use most when creating or customizing services.

### ExecStart and Related

```ini
[Service]
# Pre-start check (run before the main process)
ExecStartPre=/usr/sbin/nginx -t

# The main process
ExecStart=/usr/sbin/nginx -g "daemon off;"

# Post-start actions
ExecStartPost=/bin/echo "nginx started"

# Reload command
ExecReload=/bin/kill -HUP $MAINPID

# Stop command (default sends SIGTERM, then SIGKILL after timeout)
ExecStop=/usr/sbin/nginx -s quit
```

The `$MAINPID` variable is automatically set by systemd to the PID of the main process.

> **Important:** `ExecStart=` must use absolute paths. You cannot write `ExecStart=nginx` — it must be `ExecStart=/usr/sbin/nginx`. Find the path with `which nginx`.

### Restart Policies

```ini
[Service]
Restart=on-failure
RestartSec=5
```

| Restart Value | When It Restarts |
|---------------|-----------------|
| `no` | Never (default) |
| `on-success` | Only if the process exits with code 0 |
| `on-failure` | On non-zero exit code, signal, timeout, or watchdog |
| `on-abnormal` | On signal, timeout, or watchdog (not on clean exit with error) |
| `on-abort` | Only on signal (e.g., SIGSEGV) |
| `on-watchdog` | Only on watchdog timeout |
| `always` | Always restart, no matter what |

For most services, `Restart=on-failure` is the right choice. Use `Restart=always` for critical services that must never be down.

`RestartSec=5` means "wait 5 seconds before restarting." This prevents a crashing service from consuming resources by restarting in a tight loop.

### Security and Isolation

```ini
[Service]
User=appuser
Group=appgroup
WorkingDirectory=/opt/myapp
Environment=NODE_ENV=production
EnvironmentFile=/opt/myapp/.env
```

| Directive | Purpose |
|-----------|---------|
| `User=` | Run as this user instead of root |
| `Group=` | Run as this group |
| `WorkingDirectory=` | Set the current directory before starting |
| `Environment=` | Set an environment variable (can appear multiple times) |
| `EnvironmentFile=` | Read environment variables from a file (one per line) |
| `ProtectSystem=` | Make system directories read-only (`true`, `full`, `strict`) |
| `ProtectHome=` | Make `/home`, `/root`, `/run/user` inaccessible |
| `NoNewPrivileges=` | Prevent privilege escalation |
| `PrivateTmp=` | Give the service its own `/tmp` directory |

The `EnvironmentFile=` directive is especially useful for keeping secrets out of unit files. The file format is simple:

```text
DATABASE_URL=postgres://localhost/mydb
SECRET_KEY=abc123
PORT=8080
```

A `-` prefix makes the file optional (no error if missing):

```ini
EnvironmentFile=-/opt/myapp/.env
```

### Resource Limits

```ini
[Service]
LimitNOFILE=65535
LimitNPROC=4096
MemoryMax=512M
CPUQuota=50%
```

These use cgroups (which you learned about conceptually in earlier weeks) to limit what the service can consume.

---

## 11.10 Creating a Custom Service Unit

Let's create a service from scratch. Imagine you have a Python web application that needs to run as a daemon.

### Step 1: Verify the Application Works

Always test your application manually first:

```bash
# Test that the script/application runs
/opt/myapp/venv/bin/python /opt/myapp/app.py
```

### Step 2: Create the Unit File

```bash
sudo nano /etc/systemd/system/myapp.service
```

```ini
[Unit]
Description=My Python Web Application
Documentation=https://github.com/example/myapp
After=network.target
Wants=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/myapp
EnvironmentFile=/opt/myapp/.env
ExecStart=/opt/myapp/venv/bin/python /opt/myapp/app.py
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

Let's trace through the decisions:

- **`Type=simple`** — The Python process stays in the foreground (doesn't fork)
- **`User=www-data`** — Run as a non-root user for security
- **`After=network.target`** — Don't start until networking is ready
- **`Restart=on-failure`** — Restart if it crashes, but not if we intentionally stop it
- **`RestartSec=5`** — Wait 5 seconds before restarting to avoid a crash loop
- **`StandardOutput=journal`** — Send stdout to the journal (default, but explicit is clear)
- **`SyslogIdentifier=myapp`** — Tag log entries as "myapp" for easy filtering

### Step 3: Reload, Enable, and Start

```bash
# Tell systemd about the new unit file
sudo systemctl daemon-reload

# Enable it to start at boot
sudo systemctl enable myapp

# Start it now
sudo systemctl start myapp

# Verify it's running
systemctl status myapp
```

### Step 4: Verify Logging

```bash
# Check the logs
journalctl -u myapp -f
```

### Step 5: Test Restart Behavior

```bash
# Find the PID
systemctl show myapp --property MainPID

# Kill the process (simulating a crash)
sudo kill -9 $(systemctl show myapp --property MainPID --value)

# Wait 5 seconds (RestartSec), then check — it should be running again
sleep 6 && systemctl status myapp
```

You should see the service active with a new PID and an uptime of just a few seconds.

---

## 11.11 Systemd Timers

**Systemd timers** are the modern replacement for cron jobs. While cron still works fine (and you learned it in Week 9), timers offer several advantages:

| Feature | cron | systemd timers |
|---------|------|----------------|
| Dependencies | None | Can depend on other units |
| Logging | Must configure manually | Automatic journal integration |
| Missed runs | Lost if system was off | `Persistent=true` catches up |
| Resource control | None | cgroup limits via service unit |
| Status checking | No built-in status | `systemctl list-timers` |
| Precision | 1 minute minimum | Microsecond precision |
| Randomized delay | Not supported | `RandomizedDelaySec=` |

A systemd timer requires **two unit files**:
1. A `.timer` unit that defines the schedule
2. A `.service` unit that defines what to run

By default, a timer named `foo.timer` triggers the service named `foo.service`. You can override this with the `Unit=` directive.

### Types of Timers

There are two kinds of timer triggers:

**Realtime (calendar) timers** — fire at specific dates/times, like cron:

```ini
OnCalendar=*-*-* 02:00:00          # Every day at 2:00 AM
OnCalendar=Mon *-*-* 09:00:00      # Every Monday at 9:00 AM
OnCalendar=*-*-01 00:00:00         # First day of every month at midnight
```

**Monotonic timers** — fire relative to some event:

```ini
OnBootSec=15min                    # 15 minutes after boot
OnUnitActiveSec=1h                 # 1 hour after the unit last activated
OnStartupSec=30s                   # 30 seconds after systemd started
OnUnitInactiveSec=30min            # 30 minutes after the unit last deactivated
```

You can combine both types in a single timer.

---

## 11.12 Timer Unit Anatomy

Let's create a complete timer that runs a cleanup script daily at 3:00 AM.

### The Service Unit (what to run)

```bash
sudo nano /etc/systemd/system/cleanup.service
```

```ini
[Unit]
Description=Daily cleanup task

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cleanup.sh
User=root
```

Note: No `[Install]` section is needed because this service won't be enabled directly — the timer triggers it.

`Type=oneshot` means the process runs once and exits. systemd waits for it to complete before considering the unit "started."

### The Timer Unit (when to run)

```bash
sudo nano /etc/systemd/system/cleanup.timer
```

```ini
[Unit]
Description=Run cleanup daily at 3:00 AM

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true
RandomizedDelaySec=300
AccuracySec=60

[Install]
WantedBy=timers.target
```

| Directive | Meaning |
|-----------|---------|
| `OnCalendar=` | When to fire (calendar/realtime schedule) |
| `Persistent=true` | If the timer was missed (system was off), run it at next opportunity |
| `RandomizedDelaySec=300` | Add a random delay of 0-300 seconds to avoid thundering herd |
| `AccuracySec=60` | Allow up to 60 seconds of imprecision (helps batch wakeups for power savings) |
| `WantedBy=timers.target` | Enable this timer when timers.target is active (boot) |

### Enable and Start the Timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cleanup.timer
```

Notice you enable the **timer**, not the service.

### Verify the Timer

```bash
# List all timers and when they'll next fire
systemctl list-timers

# Check the timer's status
systemctl status cleanup.timer

# Check when the service last ran
systemctl status cleanup.service
```

```text
NEXT                         LEFT          LAST                         PASSED       UNIT             ACTIVATES
Wed 2025-01-16 03:00:00 UTC  14h left      Tue 2025-01-15 03:04:22 UTC  10h ago      cleanup.timer    cleanup.service
```

### Test the Timer Manually

You can trigger the service immediately without waiting for the schedule:

```bash
# Run the service now (bypasses the timer)
sudo systemctl start cleanup.service

# Check the result
systemctl status cleanup.service
journalctl -u cleanup.service -n 20
```

---

## 11.13 Cron vs Systemd Timer Syntax

If you're used to cron (from Week 9), the calendar syntax takes some adjustment. Here's a side-by-side comparison:

### Calendar Expression Format

systemd's `OnCalendar=` uses the format:

```text
DayOfWeek Year-Month-Day Hour:Minute:Second
```

Where `*` means "every" and `..` means a range.

### Common Schedules

| Schedule | cron Expression | systemd OnCalendar |
|----------|-----------------|-------------------|
| Every minute | `* * * * *` | `*-*-* *:*:00` |
| Every 5 minutes | `*/5 * * * *` | `*-*-* *:00/5:00` |
| Every hour | `0 * * * *` | `*-*-* *:00:00` or `hourly` |
| Every day at midnight | `0 0 * * *` | `*-*-* 00:00:00` or `daily` |
| Every day at 3:30 AM | `30 3 * * *` | `*-*-* 03:30:00` |
| Every Monday at 9 AM | `0 9 * * 1` | `Mon *-*-* 09:00:00` |
| First of month at midnight | `0 0 1 * *` | `*-*-01 00:00:00` or `monthly` |
| Every weekday at 8 AM | `0 8 * * 1-5` | `Mon..Fri *-*-* 08:00:00` |
| Every 15 minutes | `*/15 * * * *` | `*-*-* *:00/15:00` |
| Jan and July 1st | `0 0 1 1,7 *` | `*-01,07-01 00:00:00` |

### Built-in Shortcuts

systemd provides several shorthand expressions:

| Shorthand | Equivalent |
|-----------|-----------|
| `minutely` | `*-*-* *:*:00` |
| `hourly` | `*-*-* *:00:00` |
| `daily` | `*-*-* 00:00:00` |
| `weekly` | `Mon *-*-* 00:00:00` |
| `monthly` | `*-*-01 00:00:00` |
| `yearly` | `*-01-01 00:00:00` |
| `quarterly` | `*-01,04,07,10-01 00:00:00` |

### Testing Calendar Expressions

The `systemd-analyze calendar` command is invaluable — it parses your expression and tells you exactly when it will fire:

```bash
systemd-analyze calendar "Mon..Fri *-*-* 08:00:00"
```

```text
  Original form: Mon..Fri *-*-* 08:00:00
Normalized form: Mon..Fri *-*-* 08:00:00
    Next elapse: Mon 2025-01-20 08:00:00 UTC
       (in UTC): Mon 2025-01-20 08:00:00 UTC
       From now: 4 days left
```

```bash
# Test multiple upcoming occurrences
systemd-analyze calendar --iterations=5 "daily"
```

```text
  Original form: daily
Normalized form: *-*-* 00:00:00
    Next elapse: Thu 2025-01-16 00:00:00 UTC
       From now: 11h left
       Iter. #2: Fri 2025-01-17 00:00:00 UTC
       Iter. #3: Sat 2025-01-18 00:00:00 UTC
       Iter. #4: Sun 2025-01-19 00:00:00 UTC
       Iter. #5: Mon 2025-01-20 00:00:00 UTC
```

Always test your calendar expressions before deploying a timer.

---

## 11.14 Targets and Runlevels

A **target** is a grouping of units that represents a system state. Targets replaced SysVinit's numbered runlevels. Here's the mapping:

| SysVinit Runlevel | systemd Target | Purpose |
|-------------------|---------------|---------|
| 0 | `poweroff.target` | Shut down the system |
| 1 | `rescue.target` | Single-user mode, minimal services, root shell |
| 2, 3, 4 | `multi-user.target` | Full multi-user mode, networking, no GUI |
| 5 | `graphical.target` | Multi-user with graphical desktop |
| 6 | `reboot.target` | Reboot the system |

There's also `emergency.target`, which is even more minimal than rescue — it mounts the root filesystem read-only and gives you a root shell. Use it when rescue mode won't boot.

### Viewing and Changing the Default Target

```bash
# See the current default target
systemctl get-default

# Change the default to multi-user (no GUI)
sudo systemctl set-default multi-user.target

# Change the default to graphical (with GUI)
sudo systemctl set-default graphical.target
```

### Switching Targets at Runtime

You can switch between targets without rebooting:

```bash
# Switch to rescue mode (drops to single-user root shell)
sudo systemctl isolate rescue.target

# Switch back to multi-user mode
sudo systemctl isolate multi-user.target

# Switch to graphical mode
sudo systemctl isolate graphical.target
```

The `isolate` command stops all units that aren't dependencies of the target, then starts the target and its dependencies. Only targets with `AllowIsolate=yes` can be isolated.

### What's in a Target?

Targets don't do anything themselves — they're collections of units. You can see what a target pulls in:

```bash
# List units that multi-user.target wants
systemctl list-dependencies multi-user.target

# Show the full dependency tree
systemctl list-dependencies multi-user.target --all
```

### Rescue and Emergency Modes

If your system has boot problems, you can force a target from the GRUB menu:

1. At the GRUB boot menu, press `e` to edit the boot entry
2. Find the line starting with `linux` (or `linux16`)
3. Append `systemd.unit=rescue.target` to the end of that line
4. Press `Ctrl+X` to boot

For emergency mode (even more minimal):

```text
systemd.unit=emergency.target
```

The difference:

| Mode | Root filesystem | Services | Networking |
|------|----------------|----------|------------|
| `rescue.target` | Read-write | Minimal (basic system) | Usually no |
| `emergency.target` | Read-only | None | No |

In emergency mode, you'll need to remount root as read-write before making changes:

```bash
mount -o remount,rw /
```

---

## 11.15 Boot Performance Analysis

systemd includes powerful tools for analyzing boot performance. When your server takes too long to start, these commands tell you exactly which services are the bottleneck.

### systemd-analyze

```bash
# Overall boot time
systemd-analyze
```

```text
Startup finished in 2.531s (kernel) + 4.892s (userspace) = 7.424s
graphical.target reached after 4.891s in userspace.
```

### blame — Slowest Services

```bash
# List services sorted by startup time (slowest first)
systemd-analyze blame
```

```text
3.201s NetworkManager-wait-online.service
1.023s snapd.service
 892ms dev-sda1.device
 756ms cloud-init.service
 534ms systemd-logind.service
 423ms ssh.service
 ...
```

### critical-chain — The Critical Path

`blame` shows individual times, but some services run in parallel. `critical-chain` shows the actual **critical path** — the chain of dependencies that determined boot time:

```bash
systemd-analyze critical-chain
```

```text
graphical.target @4.891s
└─multi-user.target @4.890s
  └─nginx.service @4.532s +357ms
    └─network-online.target @4.530s
      └─NetworkManager-wait-online.service @1.328s +3.201s
        └─NetworkManager.service @1.215s +112ms
          └─basic.target @1.204s
            └─sockets.target @1.204s
              └─snapd.socket @1.198s +5ms
```

Read this bottom-to-top. The `@` time is when the unit started, the `+` time is how long it took. In this example, `NetworkManager-wait-online.service` is the biggest bottleneck — it waited 3.2 seconds for network connectivity.

### Analyzing Specific Units

```bash
# Critical chain for a specific target
systemd-analyze critical-chain multi-user.target

# Plot an SVG boot chart (visual timeline)
systemd-analyze plot > /tmp/boot-chart.svg
```

The SVG plot creates a visual timeline showing exactly when each service started and how long it took, with parallel services shown side by side. Transfer it to your desktop to view in a browser.

### Identifying Slow Services

Common culprits for slow boot times:

| Service | Why It's Slow | Fix |
|---------|--------------|-----|
| `NetworkManager-wait-online.service` | Waits for DHCP lease | Disable if using static IP, or reduce DHCP timeout |
| `cloud-init.service` | Cloud metadata lookup | Disable on non-cloud VMs |
| `snapd.service` | Snap package initialization | Disable if not using snaps |
| `plymouth-quit-wait.service` | Boot splash animation | Disable on servers |
| `apt-daily.service` | Background package updates | Adjust timer schedule |

```bash
# Disable a slow service you don't need
sudo systemctl disable --now NetworkManager-wait-online.service

# Verify improvement
systemd-analyze blame | head -10
```

---

## 11.16 Socket Activation

**Socket activation** is an advanced systemd feature worth understanding, even if you don't create socket-activated services often. The idea: systemd creates the listening socket *before* starting the service. When a connection arrives, systemd starts the service and hands over the socket.

Benefits:
- **Faster boot** — Services don't start until they're actually needed
- **Automatic startup** — The service starts on first connection
- **Parallelism** — Dependent services can start immediately because the socket exists, even if the service behind it isn't ready yet

A classic example is `sshd.socket`:

```bash
# Check if sshd uses socket activation
systemctl status sshd.socket
```

```ini
# /lib/systemd/system/sshd.socket
[Unit]
Description=OpenBSD Secure Shell server socket

[Socket]
ListenStream=22
Accept=yes

[Install]
WantedBy=sockets.target
```

When socket activation is used, you enable the `.socket` unit instead of the `.service` unit:

```bash
# Instead of enabling the service
sudo systemctl disable sshd.service

# Enable the socket — sshd starts only when someone connects
sudo systemctl enable --now sshd.socket
```

Most of the time, you'll use regular service activation. Socket activation is primarily useful for services that receive infrequent connections and you'd rather not keep running at all times.

### How to Tell If a Service Uses Socket Activation

```bash
# List all active sockets
systemctl list-units --type=socket

# See the details
systemctl list-sockets
```

```text
LISTEN                        UNIT                  ACTIVATES
/run/dbus/system_bus_socket   dbus.socket           dbus.service
/run/snapd.socket             snapd.socket          snapd.service
[::]:22                       sshd.socket           sshd.service
```

---

## 11.17 Distro Notes

Both Ubuntu and Rocky Linux use systemd as their init system, and the commands are identical. However, there are some practical differences to be aware of:

### Service Naming Differences

| Service | Ubuntu Package / Name | Rocky Package / Name |
|---------|----------------------|---------------------|
| Web server | `nginx` / `nginx.service` | `nginx` / `nginx.service` |
| Web server (Apache) | `apache2` / `apache2.service` | `httpd` / `httpd.service` |
| SSH server | `openssh-server` / `ssh.service` | `openssh-server` / `sshd.service` |
| Firewall | `ufw` / `ufw.service` | `firewalld` / `firewalld.service` |
| Network manager | `network-manager` / `NetworkManager.service` | `NetworkManager` / `NetworkManager.service` |

Notice that Ubuntu's SSH service is `ssh.service` while Rocky uses `sshd.service`. This is a common source of confusion.

### Default Enabled Services

The two distros ship with different services enabled by default:

| Service | Ubuntu Default | Rocky Default |
|---------|---------------|--------------|
| `firewalld` | Not installed | Enabled |
| `ufw` | Installed, disabled | Not installed |
| `SELinux` | Not installed (uses AppArmor) | Enabled |
| `cockpit` | Not installed | Available, disabled |
| `chronyd` | Uses `systemd-timesyncd` | Enabled |

### Unit File Locations

| Location | Ubuntu | Rocky |
|----------|--------|-------|
| Vendor units | `/lib/systemd/system/` | `/usr/lib/systemd/system/` |
| Admin overrides | `/etc/systemd/system/` | `/etc/systemd/system/` |
| Config defaults | `/etc/default/<service>` | `/etc/sysconfig/<service>` |

On Ubuntu, environment files for services are typically in `/etc/default/` (e.g., `/etc/default/grub`). On Rocky, they're in `/etc/sysconfig/` (e.g., `/etc/sysconfig/network`).

### Journal Persistence Defaults

| Distro | Default Storage | Persistent by Default? |
|--------|----------------|----------------------|
| Ubuntu | `auto` | Yes — `/var/log/journal/` exists by default |
| Rocky | `auto` | Yes — `/var/log/journal/` exists by default |

Both modern versions typically have persistent journal storage out of the box, but it's worth verifying on your specific installation. Cloud images and minimal installs may differ.

---

## What's Next

You now have a solid understanding of how systemd manages services, handles logging, and replaces cron. These skills are foundational for everything that follows:

- **In Week 12**, you'll put systemd to work managing real services — deploying nginx as a reverse proxy and a Flask API application, each with their own service units.
- **In Week 17**, you'll create systemd timers for automated database backups, applying the timer concepts from this week to a real production scenario.

The transition from "I can start and stop services" to "I can create, troubleshoot, and optimize service units" is one of the biggest jumps in Linux administration. You've just made that jump.

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 11.1: Service Management](labs/lab_01_service_management.md)** — Install and manage a web server on both distros, intentionally break it, diagnose with journalctl
- **[Lab 11.2: Custom Service & Timer](labs/lab_02_custom_service.md)** — Create a custom daemon with a systemd service unit and a cleanup timer

---

## Checklist

Before moving to Week 12, confirm you can:

- [ ] Start, stop, restart, and reload a service with systemctl
- [ ] Enable a service to start at boot and verify with is-enabled
- [ ] Read and interpret systemctl status output completely
- [ ] Filter journal logs by unit, time range, and priority level
- [ ] Configure journald for persistent log storage
- [ ] Explain the three sections of a .service unit file
- [ ] Create a custom systemd service unit for a script or application
- [ ] Create a systemd timer that runs a task on a schedule
- [ ] Compare systemd timer syntax with cron syntax
- [ ] Use systemd-analyze to identify slow boot services
- [ ] Switch between systemd targets (multi-user, rescue)

---

[← Previous Week](../week-10/README.md) · [Next Week →](../week-12/README.md)
