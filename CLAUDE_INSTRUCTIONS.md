# Claude Code Build Instructions — Linux Mastery Course

## Mission

Build a complete, 17-week Linux course as a GitHub-ready repository. The course takes a complete beginner from zero CLI knowledge through server administration, service infrastructure (web servers, DNS, databases, APIs), and container-based development workflows. It covers both Ubuntu and Rocky Linux, with labs running on Parallels VMs on macOS.

The course has two throughlines beyond general Linux literacy:

1. **Server administration** — running, securing, and troubleshooting real services: web servers, reverse proxies, DNS, databases, APIs, log aggregation.
2. **Container development** — not just "how to run Docker" but how to develop software targeting container workloads: writing Dockerfiles, multi-stage builds, dev/prod parity, compose-based stacks, health checks, debugging containers, and CI/CD-ready images.

A key arc connects Weeks 12–17: learners build a **three-tier application** (web frontend → API middleware → database) first as native services on Linux, then containerize it and deploy it as a production-ready Compose stack. This mirrors the real-world journey from "how does this work on a server?" to "how do I ship this in containers?"

**Build this systematically, one module at a time.** After each module, commit your work before moving to the next. This prevents context window overload and ensures recoverable progress.

---

## Repository Structure

```
linux-mastery/
├── README.md
├── .gitignore
├── week-01/
│   ├── README.md
│   └── labs/
│       ├── lab_01_*.md
│       └── lab_02_*.md
├── week-02/
│   ├── README.md
│   └── labs/
│       └── ...
...
└── week-17/
    ├── README.md
    └── labs/
        └── ...
```

---

## Curriculum Plan

Here is the exact week-by-week plan. Follow this precisely.

### Week 01 — Welcome to Linux & VM Setup
**Goal:** Install Ubuntu Server and Rocky Linux VMs in Parallels on macOS, boot into both, and log in via SSH.

Topics:
- What Linux is, brief history, why it dominates servers, cloud, and containers
- Linux distributions explained — why Ubuntu and Rocky Linux, what's the same vs different
- Where Linux runs: web servers, API backends, container hosts, CI/CD runners, IoT, supercomputers
- Downloading ISOs: Ubuntu Server 24.04 LTS and Rocky Linux 9
- Creating VMs in Parallels Desktop on macOS (step-by-step with recommended specs: 2 CPU, 4GB RAM, 40GB disk per VM)
- Walking through each installer (Ubuntu and Rocky), explaining every screen
- First login, understanding the console prompt
- Setting up SSH access from macOS Terminal (`ssh student@vm-ip`)
- Parallels-specific tips: shared folders, networking modes (Shared vs Bridged), snapshots for safe experimentation
- Take a snapshot now — you'll thank yourself later

Labs:
- `lab_01_ubuntu_vm_setup.md` — Full walkthrough: download, install, configure Ubuntu Server VM, verify SSH access from macOS
- `lab_02_rocky_vm_setup.md` — Same for Rocky Linux 9, noting installer differences (Anaconda vs Subiquity), verify SSH

### Week 02 — The Shell & Navigating the Filesystem
**Goal:** Navigate the Linux filesystem, understand paths, and manage files and directories from the command line.

Topics:
- What a shell is, bash vs other shells (zsh, fish, sh) — we'll use bash throughout
- The Linux filesystem hierarchy: `/`, `/home`, `/etc`, `/var`, `/tmp`, `/usr`, `/bin`, `/sbin`, `/opt`, `/srv`
- Why this layout matters for server admin: config in `/etc`, logs in `/var/log`, web content in `/var/www` or `/srv`
- Absolute vs relative paths, `.` and `..`, `~`
- Essential navigation: `pwd`, `cd`, `ls` (with flags: `-l`, `-a`, `-h`, `-R`, `-t`)
- Reading `ls -l` output: permissions, owner, group, size, timestamps
- File operations: `touch`, `mkdir` (with `-p`), `cp` (with `-r`), `mv`, `rm` (with `-r`, `-f`), `rmdir`
- Wildcards and globbing: `*`, `?`, `[]`, `{}`
- `file` command — identifying file types (useful when something has no extension)
- `stat` — detailed file metadata
- Tab completion and command history (`history`, `!!`, `!$`, `!N`, Ctrl+R reverse search)
- `alias` — creating shortcuts for common commands
- Distro differences: minimal at this level (note any path differences)

Labs:
- `lab_01_filesystem_exploration.md` — Navigate the filesystem, predict what's in key directories (`/etc`, `/var/log`, `/usr/bin`), verify, compare between Ubuntu and Rocky
- `lab_02_file_operations.md` — Create a mock project directory structure (simulating a web project with source, config, logs, data dirs), copy/move/rename files, use wildcards to batch-operate

### Week 03 — Reading, Searching & Manipulating Text
**Goal:** View, search, filter, and transform text files using core Linux utilities.

Topics:
- Why text is central to Linux — config files, logs, pipes, `/proc`, everything is text or can be
- Viewing files: `cat`, `less`, `more`, `head`, `tail`, `tail -f` (following live logs — critical for server admin)
- Searching: `grep` (basic patterns, `-i`, `-r`, `-n`, `-v`, `-c`, `-l`, `-E` for extended regex)
- Introduction to regular expressions (basic: `.`, `*`, `+`, `^`, `$`, `[]`, `\`, `|`, `()`, `{n,m}`)
- Cutting and rearranging: `cut` (with `-d` and `-f`), `sort` (numeric, reverse, by field), `uniq` (with `-c`), `wc`
- Stream editing: `sed` basics — substitution (`s/old/new/g`), delete lines (`d`), print lines (`p`), in-place editing (`-i`)
- Field processing: `awk` basics — print columns, custom field separator (`-F`), simple conditions, `BEGIN`/`END`
- `diff` and `comm` for comparing files (useful for comparing configs across servers)
- `find` command: by name, type, size, modification time, `-exec`
- `locate` and `updatedb` for fast filename searches

Labs:
- `lab_01_log_analysis.md` — Analyze a sample web server access log: find 404 errors, count hits per endpoint, extract unique IPs, find the top 10 clients by request count, identify suspicious patterns
- `lab_02_text_pipeline.md` — Build progressively complex pipelines combining grep, cut, sort, uniq, awk to answer questions about `/etc/passwd`, process lists, and a provided sample dataset

### Week 04 — Pipes, Redirection & The Unix Philosophy
**Goal:** Chain commands together using pipes and redirection, understand stdin/stdout/stderr, and write compound one-liners.

Topics:
- Unix philosophy: small tools that do one job well, text streams as universal interface
- Standard streams: stdin (0), stdout (1), stderr (2) — they're file descriptors
- Output redirection: `>`, `>>`, `2>`, `2>&1`, `&>` — with clear examples of each
- Input redirection: `<`, here documents `<<EOF`, here strings `<<<`
- Pipes: `|` — connecting stdout of one command to stdin of the next
- `tee` — split output to file and screen simultaneously (invaluable for debugging pipelines)
- Command substitution: `$(command)` — embedding command output in another command
- `xargs` — building argument lists from stdin, `-I{}` for placement, `-P` for parallelism
- Process substitution: `<(command)` — treating command output as a file (for tools that need filenames)
- Command chaining: `;`, `&&`, `||` — sequential, on-success, on-failure
- Combining everything: real-world pipeline examples relevant to server admin (parsing access logs, finding large files, checking service status across patterns)

Labs:
- `lab_01_redirection_mastery.md` — Exercises on redirecting stdout/stderr separately, appending, combining streams, here documents for multi-line input
- `lab_02_pipeline_challenges.md` — Solve 10 progressively harder problems using pipes: find the 5 largest log files, extract unique domains from an email log, build a quick-and-dirty disk usage report, generate a summary of failed SSH attempts from auth.log

### Week 05 — Users, Groups & Permissions
**Goal:** Manage users and groups, understand and modify file permissions, and configure sudo access for service accounts.

Topics:
- Multi-user concepts: why permissions matter on servers (multiple services, multiple admins)
- Users and UIDs: `/etc/passwd` dissected line by line, system users vs regular users
- Passwords and shadow file: `/etc/shadow` (why it exists, basic structure)
- Groups and GIDs: `/etc/group`, primary vs supplementary groups
- `whoami`, `id`, `groups`, `who`, `w`, `last`
- Creating/managing users: `useradd` (with `-m`, `-s`, `-G`), `usermod`, `userdel`, `passwd`
- Creating/managing groups: `groupadd`, `groupmod`, `gpasswd`
- Service accounts: creating users for running services (e.g., `www-data`, `nginx`, `postgres`) — no login shell, no home directory
- File permissions: read/write/execute, what they mean for files vs directories
- Symbolic notation: `rwxr-xr--`
- Numeric (octal) permissions: 755, 644, 600, 750, etc. — common patterns and when to use each
- `chmod` — symbolic and numeric methods
- `chown` and `chgrp` — changing ownership
- Special permissions: setuid, setgid, sticky bit — what they do and real-world examples (`/tmp`, `passwd`)
- `umask` — default permission masks, configuring sensible defaults
- `sudo` and `/etc/sudoers` — how privilege escalation works, `visudo`, granting specific commands
- Distro differences: Ubuntu uses `sudo` group, Rocky uses `wheel` group

Labs:
- `lab_01_user_management.md` — Create users for different roles (admin, developer, deploy service account), assign groups, configure sudo access with specific permissions, test (run on BOTH Ubuntu and Rocky, note differences)
- `lab_02_permission_scenarios.md` — Solve real-world permission scenarios: shared project directory for a dev team, a deploy user that can restart services but not read sensitive configs, web server document root permissions, securing SSH keys

### Week 06 — Package Management & Software Installation
**Goal:** Install, update, remove, and manage software using apt (Ubuntu) and dnf (Rocky Linux), and understand repository management.

Topics:
- What package managers do: dependency resolution, version management, security verification
- Repositories: what they are, how trust works (GPG keys), official vs third-party
- Ubuntu/Debian: `apt update`, `apt install`, `apt remove`, `apt purge`, `apt search`, `apt show`, `apt upgrade`, `apt full-upgrade`, `apt list --installed`
- Rocky/RHEL: `dnf install`, `dnf remove`, `dnf search`, `dnf info`, `dnf update`, `dnf group list`, `dnf group install`, `dnf list installed`
- Side-by-side comparison table: apt vs dnf for every common operation
- Repository management: adding PPAs (Ubuntu), enabling EPEL and CRB (Rocky)
- Package files: `.deb` vs `.rpm`, `dpkg` vs `rpm` for local package inspection
- Package cache, cleaning up: `apt autoremove`, `apt clean`, `dnf autoremove`, `dnf clean all`
- Security updates: `apt list --upgradable`, `dnf check-update`, unattended-upgrades (Ubuntu) and dnf-automatic (Rocky)
- Module streams (Rocky/RHEL): `dnf module list`, switching between versions of software (e.g., Node.js 18 vs 20)
- When to compile from source (and why to avoid it when a package exists)
- Installing development tools: `build-essential` (Ubuntu), `groupinstall "Development Tools"` (Rocky)

Labs:
- `lab_01_package_management.md` — Install, query, inspect, and remove packages on BOTH distros side-by-side: install nginx, htop, tree, curl, jq. Compare commands, package names, file locations.
- `lab_02_repository_setup.md` — Add third-party repos on both distros (e.g., Docker's official repo, Node.js repo), install software from them, verify GPG keys, compare the process

### Week 07 — Processes, Jobs & System Monitoring
**Goal:** Understand how Linux manages processes, monitor system resources, and control running programs.

Topics:
- What a process is: PID, PPID, UID, process states (R, S, D, Z, T)
- Viewing processes: `ps aux`, `ps -ef`, `pstree`, `pidof`, `pgrep`
- Real-time monitoring: `top` (understanding all fields), `htop` (install it — interactive, filterable)
- Process signals: `kill`, `killall`, `pkill`, common signals table (SIGTERM=15, SIGKILL=9, SIGHUP=1, SIGINT=2, SIGUSR1=10)
- Graceful vs forceful termination: why you try SIGTERM before SIGKILL
- Job control: `&`, `Ctrl+Z`, `bg`, `fg`, `jobs`, `disown`
- `nohup` and `disown` — running processes that survive logout
- System resources: `free -h`, `df -h`, `du -sh`, `uptime`, `lscpu`, `lsblk`, `vmstat`, `iostat`
- `/proc` filesystem: `/proc/cpuinfo`, `/proc/meminfo`, `/proc/[pid]/status`, `/proc/[pid]/fd`
- `lsof` — what files/sockets are processes using (critical for debugging "port already in use")
- `nice` and `renice` — process priority
- `strace` — tracing system calls (brief intro, invaluable for debugging)
- Server monitoring context: why you care about load average, memory pressure, disk I/O

Labs:
- `lab_01_process_investigation.md` — Use ps, top, /proc to investigate running processes: find what's using the most memory, trace parent-child relationships, identify zombie processes, find which process is listening on port 22
- `lab_02_resource_monitoring.md` — Build a monitoring checklist: check CPU load, memory usage, disk space, open file descriptors, network connections. Practice with `htop`, `vmstat`, `iostat`. Kill runaway processes. Use `lsof` to find port conflicts.

### Week 08 — Bash Scripting Fundamentals
**Goal:** Write bash scripts that automate common server administration tasks using variables, conditionals, loops, and functions.

Topics:
- Why scripting: automation, reproducibility, incident response, deployment
- Script structure: shebang (`#!/bin/bash`), comments, `set -euo pipefail` (and what each flag does)
- Making scripts executable: `chmod +x`, running with `./` vs `bash`
- Variables: assignment (no spaces around `=`!), `$VAR`, `"$VAR"` (ALWAYS quote), `${VAR}`
- Special variables: `$0`, `$1`...`$9`, `$#`, `$@`, `$?`, `$$`, `$!`
- User input: `read`, command-line arguments, `shift`
- Conditionals: `if`/`elif`/`else`/`fi`, `[[ ]]` vs `[ ]` (prefer `[[ ]]` in bash)
- String comparisons: `==`, `!=`, `-z`, `-n`, `=~` (regex match)
- Numeric comparisons: `-eq`, `-ne`, `-lt`, `-gt`, `-le`, `-ge`
- File tests: `-f`, `-d`, `-e`, `-r`, `-w`, `-x`, `-s`, `-L`
- Compound conditions: `&&`, `||`, `!`
- Loops: `for item in list`, C-style `for ((i=0; i<10; i++))`, `while`, `until`, `while read line`
- `case` statements — cleaner than long if/elif chains
- Functions: declaration, local variables (`local`), return values vs stdout capture
- Exit codes and error handling: checking `$?`, `|| exit 1`, `trap` for cleanup
- Arithmetic: `$(( ))`, `let`
- String manipulation: `${var#pattern}`, `${var%pattern}`, `${var/old/new}`, `${var:offset:length}`, `${#var}`

Labs:
- `lab_01_system_report.sh` — Write a script that generates a system health report: hostname, distro name, uptime, CPU count, memory usage, disk usage for all mounted filesystems, top 5 processes by memory, logged-in users, listening ports. Scaffolded with TODOs and built-in tests.
- `lab_02_service_checker.sh` — Write a script that takes a list of service names as arguments, checks if each is active (using `systemctl`), reports status, optionally restarts failed services with a `--restart` flag. Scaffolded with TODOs and built-in tests.

### Week 09 — Networking Fundamentals
**Goal:** Configure networking, troubleshoot connectivity, and understand how Linux handles network communication.

Topics:
- Networking concepts refresher: IP addresses (v4 and v6 basics), subnets and CIDR notation, ports, DNS, DHCP, TCP vs UDP
- Network interfaces: `ip addr`, `ip link`, `ip route` (modern) vs `ifconfig`, `route` (legacy — mention but don't teach)
- DNS resolution: how it works end-to-end — `/etc/resolv.conf`, `/etc/hosts`, `/etc/nsswitch.conf`
- DNS tools: `dig`, `nslookup`, `host` — querying records (A, AAAA, CNAME, MX, NS, TXT)
- Testing connectivity: `ping`, `traceroute`/`tracepath`, `mtr`
- Port and socket inspection: `ss -tlnp` (modern) vs `netstat` (legacy), understanding output columns
- Network configuration: Ubuntu (Netplan YAML in `/etc/netplan/`) vs Rocky (NetworkManager, `nmcli`, `nmtui`)
- Static IP configuration on both distros (essential for servers)
- Firewall concepts: why, what, where in the network stack
- `ufw` (Ubuntu): `enable`, `allow`, `deny`, `status`, application profiles
- `firewalld` (Rocky): `firewall-cmd`, zones, services, ports, `--permanent`, `--reload`
- Side-by-side firewall comparison table
- SSH deep dive: key-based authentication (generating keys, `ssh-copy-id`, `authorized_keys`), `~/.ssh/config` for managing multiple hosts, agent forwarding, local/remote port tunneling
- File transfer: `scp`, `rsync` (with common flags: `-avz`, `--delete`, `--dry-run`), `sftp`
- `curl` and `wget` — fetching URLs, testing APIs, downloading files
- `curl` for API testing: `-X POST`, `-H`, `-d`, `-o`, `-s`, `-w`, response codes

Labs:
- `lab_01_network_diagnostics.md` — Diagnose networking scenarios: verify interface config, test DNS resolution, trace routes, identify listening services, check firewall rules. Run on both distros.
- `lab_02_ssh_and_firewall.md` — Set up SSH key-based auth between your two VMs, create `~/.ssh/config` entries, configure firewalls on both (ufw on Ubuntu, firewalld on Rocky) to allow SSH and HTTP only, verify with `ss` and `curl`

### Week 10 — Storage, Filesystems & Disk Management
**Goal:** Partition disks, create filesystems, mount storage, and manage disk space on a Linux server.

Topics:
- Block devices and storage concepts: `/dev/sda`, `/dev/vda`, partitions vs whole disks
- Viewing storage: `lsblk`, `fdisk -l`, `blkid`, `lsscsi`
- Partitioning: `fdisk` (MBR), `gdisk`/`parted` (GPT) — when to use which
- Filesystems: ext4 (Ubuntu default), XFS (Rocky default), differences and trade-offs
- Creating filesystems: `mkfs.ext4`, `mkfs.xfs`
- Mounting: `mount`, understanding mount options (`noexec`, `nosuid`, `nodev`, `ro`)
- `/etc/fstab`: syntax, UUID vs device names (and why UUIDs are critical), `nofail` option
- `umount` and troubleshooting "target is busy" (`lsof`, `fuser`)
- LVM concepts: physical volumes → volume groups → logical volumes
- LVM commands: `pvcreate`, `pvs`, `vgcreate`, `vgs`, `lvcreate`, `lvs`
- Extending LVM: `lvextend` + `resize2fs`/`xfs_growfs` — the real power of LVM
- Thin provisioning with LVM (brief — relevant to container storage drivers)
- Swap space: what it is, `mkswap`, `swapon`, adding to fstab, swappiness tuning
- Disk usage analysis: `df -h`, `du -sh`, `ncdu` (interactive), finding space hogs
- Filesystem maintenance: `fsck`, `xfs_repair`, when and how (hint: never on mounted filesystems)

Labs:
- `lab_01_disk_management.md` — Add a virtual disk to your VM in Parallels, partition it (one ext4, one XFS partition), create filesystems, mount them, add to fstab, verify persistence across reboot
- `lab_02_lvm_operations.md` — Create a full LVM stack: PV → VG → LV, format, mount, write data, then extend the LV and grow the filesystem without unmounting. Practice on both ext4 and XFS.

### Week 11 — Systemd, Services & the Boot Process
**Goal:** Manage services with systemd, understand the boot process, create custom service units, and configure services to start automatically.

Topics:
- The boot process: firmware (BIOS/UEFI) → bootloader (GRUB2) → kernel → init system (systemd) → services → login
- What systemd replaced (SysVinit) and why — dependency management, parallelism, logging
- Service management: `systemctl start`, `stop`, `restart`, `reload`, `status`, `enable`, `disable`, `is-active`, `is-enabled`
- Service status output: understanding every line (loaded, active, PID, memory, cgroup, recent logs)
- Viewing logs: `journalctl` — filtering by unit (`-u`), time (`--since`, `--until`), priority (`-p`), following (`-f`), boot (`-b`)
- Log persistence: configuring journald for persistent storage (important for servers)
- Unit types: service, timer, socket, mount, target, path
- Anatomy of a `.service` unit file: `[Unit]`, `[Service]`, `[Install]` sections
- Key service directives: `ExecStart`, `ExecReload`, `Restart`, `RestartSec`, `User`, `Group`, `WorkingDirectory`, `Environment`, `EnvironmentFile`
- Creating a custom service unit from scratch — step by step
- Systemd timers: replacing cron with `OnCalendar`, `OnBootSec`, `OnUnitActiveSec`
- Timer unit anatomy: `[Timer]` section, `Persistent=true`
- Cron syntax vs systemd timer syntax comparison table
- Targets and runlevels: `multi-user.target`, `graphical.target`, `rescue.target`, `emergency.target`
- `systemd-analyze` — boot performance analysis: `blame`, `critical-chain`
- Socket activation (brief): starting services on-demand when a connection arrives
- Distro notes: both use systemd, but default-enabled services differ; nginx vs httpd package naming

Labs:
- `lab_01_service_management.md` — Install and manage a web server: nginx on Ubuntu, httpd on Rocky. Start, stop, enable, break the config intentionally, read error logs with `journalctl`, fix it. Compare service file locations and names.
- `lab_02_custom_service.md` — Write a simple bash script that acts as a daemon (loops, writes to a log), create a systemd service unit for it, install it, start/enable it, verify it survives reboot. Then create a systemd timer that runs a cleanup script every hour. Includes `lab_02_daemon.sh` and `lab_02_cleanup.sh` scaffolds.

### Week 12 — Web Servers, DNS & Running Service Infrastructure
**Goal:** Configure and run nginx as a web server and reverse proxy, set up local DNS resolution, serve a backend API through a reverse proxy, and understand how service infrastructure connects.

Topics:
- The role of web servers in modern infrastructure: serving static files, reverse proxying to app containers, TLS termination, load balancing
- nginx architecture: master process, worker processes, event-driven model
- Installing nginx on both distros, verifying with `curl localhost`
- nginx configuration structure: `/etc/nginx/nginx.conf`, `sites-available`/`sites-enabled` (Ubuntu) vs `conf.d/` (Rocky)
- Serving static content: `root`, `index`, `location` blocks, `try_files`
- Virtual hosts / server blocks: hosting multiple sites on one server
- Reverse proxy configuration: `proxy_pass`, `proxy_set_header` (Host, X-Real-IP, X-Forwarded-For, X-Forwarded-Proto)
- Running a simple backend: install Python3, run a minimal Flask API (provided scaffold), proxy through nginx
- API patterns: what makes a good API endpoint, JSON responses, status codes
- Common nginx directives table: `listen`, `server_name`, `root`, `location`, `proxy_pass`, `proxy_set_header`, `error_log`, `access_log`, `client_max_body_size`
- Testing configuration: `nginx -t`, `systemctl reload nginx` (reload vs restart)
- DNS concepts deep dive: zones, record types (A, AAAA, CNAME, MX, NS, SOA, TXT, SRV, PTR), TTL, authoritative vs recursive
- Setting up a local DNS resolver with `dnsmasq`: install, configure `/etc/dnsmasq.conf`, add custom domain entries, point VMs at it
- DNS for service discovery: why containers and microservices rely on DNS internally
- `/etc/hosts` for quick local overrides (development use case)
- TLS/HTTPS concepts: certificates, certificate authorities, Let's Encrypt, how the handshake works
- Configuring TLS in nginx: certificate files, redirect HTTP→HTTPS, security headers
- `certbot` walkthrough (conceptual — full hands-on requires a public domain)
- Access logs and error logs: combined format, custom formats, reading them for troubleshooting
- HTTP status codes table: 200, 201, 204, 301, 302, 400, 401, 403, 404, 405, 413, 500, 502, 503, 504 — what each means, common causes, how to fix
- Health check endpoints: why every service needs `/healthz` and `/ready`, what they should check
- Preview: "In Week 13, we'll add a database to this stack — turning our nginx + API setup into a real three-tier application."

Labs:
- `lab_01_web_server_setup.md` — Configure nginx to serve a static site with two virtual hosts on Ubuntu. On Rocky, do the same with the `conf.d/` pattern. Add custom access log format. Test with `curl` and verify logs. Intentionally break the config and diagnose with `nginx -t` and `journalctl`.
- `lab_02_reverse_proxy_and_dns.md` — Run a provided Flask API (`app.py` scaffold) on port 8080, configure nginx as reverse proxy on port 80, set up `dnsmasq` so `myapp.local` resolves to the VM, add a `/healthz` endpoint to the API. Test the full chain: DNS → nginx → backend → JSON response. Verify headers are forwarded correctly.

### Week 13 — Databases: PostgreSQL & MariaDB
**Goal:** Install and configure database servers, perform essential SQL operations, manage database users and permissions, back up and restore data, and connect a database to the API from Week 12 to build a complete three-tier application.

Topics:
- Why databases matter: every real application stores state — what happens without a proper database
- Relational database concepts: tables, rows, columns, primary keys, foreign keys, indexes, schemas
- PostgreSQL vs MariaDB (MySQL): history, philosophical differences, when to choose which
  - PostgreSQL: standards-compliant, extensible, JSON support, preferred for complex queries
  - MariaDB: MySQL-compatible fork, simpler admin, widespread CMS/web app support (WordPress, etc.)
  - Comparison table: default ports, config file locations, client tools, data directory paths, license
- **PostgreSQL on Ubuntu:**
  - Installing: `apt install postgresql postgresql-client`
  - How PostgreSQL runs: `postgres` system user, `pg_ctlcluster`, systemd service (`postgresql@15-main`)
  - Configuration files: `postgresql.conf` (server settings), `pg_hba.conf` (client authentication — this is the one that trips everyone up)
  - Understanding `pg_hba.conf`: connection type, database, user, address, auth method — line by line
  - Changing `listen_addresses` to allow remote connections (default is localhost only)
  - The `psql` client: connecting, `\l` (list databases), `\dt` (list tables), `\d tablename` (describe), `\q` (quit), `\?` (help)
  - Connecting: `sudo -u postgres psql`, `psql -h localhost -U username -d dbname`
- **MariaDB on Rocky:**
  - Installing: `dnf install mariadb-server mariadb`
  - `mysql_secure_installation` — what each step does and why
  - Configuration: `/etc/my.cnf`, `/etc/my.cnf.d/` directory
  - The `mariadb` (or `mysql`) client: connecting, `SHOW DATABASES;`, `SHOW TABLES;`, `DESCRIBE tablename;`
  - Connecting: `sudo mariadb`, `mariadb -h localhost -u username -p`
- Side-by-side comparison table: PostgreSQL vs MariaDB for every common admin task (start/stop, connect, list databases, create user, grant permissions, config locations, log locations)
- **SQL fundamentals** (enough to be productive, not a full SQL course):
  - `CREATE DATABASE`, `\c dbname` (psql) / `USE dbname;` (MariaDB)
  - `CREATE TABLE` with column types: `INTEGER`, `SERIAL`/`AUTO_INCREMENT`, `VARCHAR(n)`, `TEXT`, `BOOLEAN`, `TIMESTAMP`, `DECIMAL`
  - Type comparison table: PostgreSQL types vs MariaDB types
  - `INSERT INTO` — single and multiple rows
  - `SELECT` — `WHERE`, `ORDER BY`, `LIMIT`, `COUNT()`, `SUM()`, `AVG()`, `GROUP BY`
  - `UPDATE` and `DELETE` — with `WHERE` (and why forgetting `WHERE` is terrifying)
  - `JOIN` basics: `INNER JOIN`, `LEFT JOIN` — with a concrete example (e.g., users and orders)
  - `CREATE INDEX` — what indexes do, when to add them, when they hurt
  - `ALTER TABLE` — adding columns, changing types
- **Database user and permission management:**
  - PostgreSQL: `CREATE ROLE`, `CREATE USER`, `GRANT`, `REVOKE`, roles vs users, `\du` to list
  - MariaDB: `CREATE USER`, `GRANT`, `REVOKE`, `FLUSH PRIVILEGES`, `SELECT user, host FROM mysql.user`
  - Principle of least privilege: application users should NOT be superusers
  - Creating a dedicated application user with access to only one database
- **Backup and restore:**
  - PostgreSQL: `pg_dump` (single database), `pg_dumpall` (all databases), `pg_restore`, plain SQL vs custom format
  - MariaDB: `mysqldump` (single database, all databases), restoring with `mariadb < dump.sql`
  - Automating backups: script + systemd timer (connecting to Week 11)
  - Testing restores: a backup you haven't tested is not a backup
- **Connecting to the application layer:**
  - Installing Python database drivers: `psycopg2` (PostgreSQL), `pymysql` or `mysql-connector-python` (MariaDB)
  - Environment variables for database credentials: `DATABASE_URL`, `DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`
  - Connection pooling concepts (brief): why opening a new connection per request is expensive
- **The three-tier architecture:**
  - Tier 1: Web server / reverse proxy (nginx — from Week 12)
  - Tier 2: Application / API middleware (Flask app — from Week 12, now with database access)
  - Tier 3: Database server (PostgreSQL or MariaDB — this week)
  - How requests flow: browser → nginx (port 80) → Flask API (port 8080) → PostgreSQL (port 5432) → response back up the chain
  - Why this separation matters: security (database not exposed to internet), scalability (each tier scales independently), maintainability
- **Monitoring and troubleshooting databases:**
  - PostgreSQL: `pg_stat_activity` (active queries), `pg_stat_user_tables` (table stats), slow query log
  - MariaDB: `SHOW PROCESSLIST`, `SHOW STATUS`, slow query log
  - Common problems: connection refused (listen_addresses, pg_hba.conf, firewall), too many connections, slow queries
  - Reading database logs: `journalctl -u postgresql`, `/var/log/mariadb/`
- Preview: "In Weeks 15–17, we'll containerize this entire three-tier stack with Docker Compose — the same architecture, but portable and reproducible."

Labs:
- `lab_01_database_server_setup.md` — Install PostgreSQL on Ubuntu and MariaDB on Rocky. On each: secure the installation, create a database and application user with limited permissions, create tables, insert sample data, query it, set up `pg_hba.conf` (PostgreSQL) or user grants (MariaDB) for remote access from the other VM, verify connectivity with the client tool from the other VM. Back up the database and restore it to verify. Compare the experience side-by-side.
- `lab_02_three_tier_app.md` — Build the full three-tier application on Ubuntu: (1) PostgreSQL database with a `tasks` table (id, title, status, created_at). (2) Extend the Flask API from Week 12 to connect to PostgreSQL and expose CRUD endpoints: `GET /tasks`, `POST /tasks`, `PUT /tasks/:id`, `DELETE /tasks/:id` (provided `app.py` scaffold with TODOs for the database queries). (3) nginx reverse proxy from Week 12 fronting the API. Test the full flow with `curl`: create tasks, list them, update status, delete. Verify data persists in the database. Add a `/healthz` endpoint that checks database connectivity. This is the same app you'll containerize in Weeks 16–17.
- `lab_02_app.py` — Provided scaffold: Flask app with routes stubbed out, database connection using environment variables, TODO markers for SQL queries. Includes `requirements.txt` with flask and psycopg2-binary.

### Week 14 — Advanced Scripting & Automation
**Goal:** Write production-quality shell scripts using advanced patterns for server automation, deployment, and operational tasks.

Topics:
- Review and build on Week 8 fundamentals — now with real server automation context
- Robust scripting: `set -euo pipefail` revisited, `trap` for cleanup (temp files, lock files, PID files)
- Temp file handling: `mktemp`, `mktemp -d`, cleanup traps
- Parsing arguments: `getopts` for short options, `while/case` pattern for long options (`--verbose`, `--dry-run`)
- Arrays: indexed (`arr=(a b c)`), associative (`declare -A map`), iteration, `${#arr[@]}`
- Here documents for embedded configs: generating nginx configs, systemd units, Dockerfiles from scripts
- Process substitution: `<()` and `>()` — comparing outputs, feeding tools that need filenames
- Subshells vs current shell: `()` vs `{}`, when each matters
- File locking: `flock` — preventing concurrent script execution (critical for cron/timer scripts)
- Logging patterns: log function with timestamps and levels, writing to syslog with `logger`
- Configuration files: sourcing external config with `.`, defaults with `${VAR:-default}`, validation
- Secrets handling: environment variables, avoiding secrets in scripts, reading from files
- Portable scripting notes: POSIX sh vs bash, `#!/usr/bin/env bash`
- ShellCheck: linting your scripts, fixing common warnings
- Script structure template: argument parsing → validation → main logic → cleanup
- `jq` for JSON processing: parsing API responses, extracting fields, filtering (ties to API/container work coming next)

Labs:
- `lab_01_log_rotator.sh` — Build a log rotation script: parse arguments (`--directory`, `--max-age`, `--compress`, `--dry-run`), find old logs, compress or delete them, use file locking, log all actions with timestamps. Scaffolded with TODOs and tests.
- `lab_02_db_backup_script.sh` — Build a database backup script that ties together Weeks 8, 11, 13, and 14: parse arguments (`--database`, `--output-dir`, `--retain-days`, `--compress`), run `pg_dump`, compress with gzip, rotate old backups, log results, send a summary to syslog with `logger`. Scaffolded with TODOs and tests. This is the backup script you'll later automate with a systemd timer and eventually run inside a container.

### Week 15 — Container Fundamentals
**Goal:** Understand containerization concepts, run and manage containers with Docker and Podman, and work with images, volumes, and container networking.

Topics:
- What containers actually are: process isolation using namespaces (pid, net, mnt, uts, ipc, user) and cgroups — not lightweight VMs
- Containers vs VMs: architecture comparison, when to use which, why containers won for application deployment
- The OCI standard: images and runtimes are interchangeable between Docker and Podman
- Docker vs Podman: daemon-based vs daemonless, root vs rootless, socket vs fork, CLI compatibility
- Installing Docker Engine on Ubuntu (from Docker's official repo — NOT the `docker.io` Ubuntu package or snap)
- Installing Podman on Rocky (`dnf install podman` — it may already be there)
- Container lifecycle: `run`, `ps`, `ps -a`, `stop`, `start`, `restart`, `rm`, `logs`, `inspect`
- Understanding `docker run` flags: `-d` (detach), `-it` (interactive), `--name`, `--rm` (auto-cleanup)
- Interactive containers: `exec -it container bash`, `attach` vs `exec` (and why `exec` is almost always what you want)
- Images: `pull`, `images`, `rmi`, `tag`, `history`, image naming convention (`registry/namespace/repo:tag`)
- Image registries: Docker Hub, GitHub Container Registry (ghcr.io), Quay.io, private registries
- Image layers: how they work, copy-on-write, why layer count and order matter
- Port mapping: `-p hostPort:containerPort`, `-p hostIP:hostPort:containerPort`, `-P` (publish all)
- Environment variables: `-e KEY=VALUE`, `--env-file .env`
- Container filesystem: ephemeral by default — why data disappears when containers are removed
- Volumes: named volumes (`-v mydata:/var/lib/data`), bind mounts (`-v /host/path:/container/path`), `tmpfs` mounts
- When to use named volumes vs bind mounts: production data persistence vs development code mounting
- Container networking: default bridge network, `--network`, container DNS
- Custom networks: `docker network create mynet`, DNS-based service discovery by container name
- Connecting containers: running an app container and a database container on the same network
- Resource limits: `--memory`, `--cpus` — preventing one container from starving others
- Inspecting and debugging: `inspect` (full JSON metadata), `stats` (live resource usage), `top` (processes), `diff` (filesystem changes), `logs --follow`
- Cleaning up: `system prune`, `volume prune`, `image prune`, `container prune`
- Docker vs Podman commands comparison table (nearly identical, note `podman` has `--pod` and `podman generate systemd`)
- Connection to the three-tier app: "Remember the PostgreSQL database from Week 13? Let's run it in a container instead."

Labs:
- `lab_01_container_basics.md` — Pull and run containers (nginx, alpine, python), inspect them, exec into running containers, work with port mapping, pass environment variables, manage the full lifecycle. Run every exercise on BOTH Docker (Ubuntu) and Podman (Rocky), noting any behavioral differences.
- `lab_02_volumes_and_networking.md` — Create a named volume, run a PostgreSQL container with persistent data on it, insert data using `psql` from the host (connecting to the container's mapped port), stop/remove the container, start a new one with the same volume, verify data survived. Create a custom bridge network, run a Flask API container and a PostgreSQL container on it, verify the API can reach the database by container name. Run on both Docker and Podman.

### Week 16 — Building Images & Container Development Workflows
**Goal:** Write production-quality Dockerfiles, implement multi-stage builds, set up container-based development environments, and containerize the three-tier application from Weeks 12–13.

Topics:
- The Dockerfile (Docker) / Containerfile (Podman): same syntax, different conventional names
- Dockerfile instructions — one at a time, with clear motivation and examples:
  - `FROM` — choosing base images: official images, `alpine` vs `slim` vs `bullseye`, `distroless` for production
  - `RUN` — executing build commands, layer implications, chaining with `&&` and `\` line continuations, cleaning up caches in the same layer
  - `COPY` vs `ADD` — always prefer `COPY` unless you need URL fetching or tar auto-extraction
  - `WORKDIR` — setting the working directory (never `cd` in `RUN`)
  - `ENV` — build-time AND runtime environment variables
  - `ARG` — build-time only variables, useful for version pinning
  - `EXPOSE` — documentation, NOT port publishing (a common misconception)
  - `USER` — running as non-root, creating a dedicated user in the Dockerfile
  - `CMD` vs `ENTRYPOINT` — exec form vs shell form, how they combine, when to use each
  - `HEALTHCHECK` — defining container health: interval, timeout, retries, start period
  - `LABEL` — metadata (maintainer, version, description)
  - `STOPSIGNAL` — graceful shutdown (brief)
- `.dockerignore` — excluding files from the build context, why it matters for build speed and security
- Build context: what gets sent to the daemon, keeping it small
- Layer caching strategy: put things that change LEAST at the top, things that change MOST at the bottom
  - Example: system packages → language dependencies (`requirements.txt`) → application code (`COPY . .`)
  - Why copying `requirements.txt` before `COPY . .` matters
- Multi-stage builds: the key to small, secure production images
  - Pattern: `FROM python:3.12 AS builder` → install deps → `FROM python:3.12-slim` → copy only what's needed
  - Multiple examples: Python with C extensions, Node.js frontend build, Go binary
- Building: `docker build -t name:tag .`, `--no-cache`, `--target` for specific stages, `--build-arg`
- Image size optimization: comparing image sizes with `docker images`, using `docker history` to find bloated layers
- **Containerizing the three-tier app:**
  - Writing a Dockerfile for the Flask API from Week 13: base image, dependencies, source code, non-root user, health check
  - nginx reverse proxy as a container: custom `nginx.conf` baked into the image or mounted
  - PostgreSQL: using the official image with environment variables and init scripts
  - Preview: "In Week 17, we'll orchestrate all three with Docker Compose"
- Development workflow with containers:
  - Bind mounts for live code reload: `-v "$(pwd)":/app` — edit on host, run in container
  - Development vs production images: multi-stage with a `dev` target (`--target dev`)
  - Dev Dockerfiles: installing dev dependencies, debug tools, hot-reload watchers
- Container logging best practices: write to stdout/stderr (not files), let the orchestrator handle log routing
- Image security:
  - Run as non-root USER (verify with `docker exec whoami`)
  - Read-only filesystem: `--read-only` flag, `tmpfs` for writable temp directories
  - Minimal base images reduce attack surface
  - Scanning: `docker scout cves`, `trivy image name:tag`
  - Pinning versions: `FROM python:3.12.1-slim` not `FROM python:latest`
- Tagging strategy: `latest` is an anti-pattern in production, use semver (`v1.2.3`) or git SHA
- Pushing images: `docker login`, `docker tag`, `docker push`

Labs:
- `lab_01_dockerfile_mastery.md` — Write Dockerfiles for three progressively complex scenarios: (1) a static site served by nginx — start naive, then optimize. (2) The Flask API from Week 13 with `requirements.txt` — optimize layer caching, add non-root user and health check. (3) A multi-stage Node.js build — build in one stage, run in `node:slim`. Compare image sizes at each step. Includes provided scaffold files.
- `lab_02_containerize_three_tier.md` — Containerize the three-tier application from Weeks 12–13: (1) Write a Dockerfile for the Flask API (with health check, non-root user, optimized layers). (2) Create a custom nginx container with the reverse proxy config baked in. (3) Run all three containers (nginx, Flask API, PostgreSQL) on a custom Docker network with proper port mapping, environment variables, and a named volume for database persistence. Test the full request flow with `curl`. Verify data persists across container restarts. This is the manual version of what you'll automate with Compose in Week 17.

### Week 17 — Docker Compose, Production Patterns & Capstone Deployment
**Goal:** Orchestrate multi-container applications with Docker Compose, implement production deployment patterns, and deploy the complete three-tier stack with proper security, backups, and monitoring — combining everything from Weeks 1–16.

Topics:
- **Docker Compose deep dive** (Compose V2 — `docker compose` not the legacy `docker-compose`):
  - Top-level keys: `services`, `volumes`, `networks`, `configs`, `secrets`
  - Service config: `image`, `build` (with `context` and `dockerfile`), `ports`, `environment`, `env_file`, `volumes`, `depends_on`, `restart`, `healthcheck`, `command`, `entrypoint`
  - `depends_on` with health conditions: `condition: service_healthy`, `condition: service_started` — proper startup ordering so the API waits for the database
  - Named volumes: data persistence across `docker compose down` / `up` cycles
  - Custom networks: isolating frontend from backend services (nginx can reach API, but NOT the database directly)
  - Profiles: optional services for debugging or admin (`--profile debug`, `--profile monitoring`)
  - Override files: `compose.override.yml` for dev-specific config (bind mounts, debug ports), `-f` flag for production compose
  - Variable substitution: `${VAR:-default}` in compose files, `.env` file auto-loading
- `podman-compose` on Rocky: compatibility, differences, `podman generate systemd` for production
- **Composing the three-tier app:**
  - Translating the manual `docker run` commands from Week 16 into a `compose.yml`
  - Network architecture: `frontend` network (nginx ↔ API), `backend` network (API ↔ PostgreSQL) — database NOT on the frontend network
  - PostgreSQL initialization: mounting SQL scripts to `/docker-entrypoint-initdb.d/`
  - Health checks on every service: nginx (HTTP check), API (`/healthz`), PostgreSQL (`pg_isready`)
  - `depends_on` with `condition: service_healthy` so the API starts only after PostgreSQL is ready
- **Production deployment patterns:**
  - Environment separation: dev compose (bind mounts, debug ports) vs production compose (built images, no bind mounts)
  - Secrets management: mounted secret files vs env vars (env vars leak into `docker inspect`)
  - Restart policies: `no`, `always`, `on-failure:5`, `unless-stopped` — when to use each
  - Logging: `logging` directive, `json-file` driver with `max-size` and `max-file` limits
  - Resource constraints: `deploy.resources.limits.memory`, `deploy.resources.limits.cpus`
- **Production architecture:**
  - nginx reverse proxy container → API container(s) → database container
  - Request flow: client → DNS → host firewall → nginx container (port 80/443) → API container (internal) → PostgreSQL container (internal) → response
  - Host-level nginx vs container nginx: trade-offs (TLS termination, Let's Encrypt integration)
- **Database operations in containers:**
  - Persistent volumes: always named volumes, never bind mounts for database data directories
  - Initialization scripts: SQL files in `/docker-entrypoint-initdb.d/` — only run on first start
  - Backup strategies: `docker exec` + `pg_dump`, scheduled backup scripts (tying together the backup script from Week 14)
  - Restore testing: spin up a fresh container, mount the backup, verify data
- **Container monitoring and observability:**
  - `docker compose logs -f`, `docker stats`
  - Health check patterns: HTTP, TCP, command-based
  - Structured logging (JSON format) and centralized logging concepts
  - Prometheus + Grafana (conceptual overview — what they do, not a full setup)
- **CI/CD concepts for container workflows:**
  - Build → test → push → deploy pipeline (conceptual)
  - Building images in CI: `docker build`, tagging with git SHA, pushing to registry
  - Deployment strategies: rolling update, blue-green (conceptual)
  - GitOps: infrastructure and deployment defined in version control
- **Server hardening checklist for container hosts:**
  - SSH: disable password auth, change port, `AllowUsers`
  - Firewall: only expose needed ports (80, 443, SSH)
  - fail2ban: install, configure jail for SSH
  - Automatic security updates
  - Docker daemon security: non-root containers, user namespaces (brief)
- **Backup strategy for the full stack:**
  - What to back up: database volumes, config files, TLS certificates, compose files, `.env` files
  - Automating backups: the backup script from Week 14 + systemd timer from Week 11
  - Off-site backup concepts: rsync to another server, S3-compatible storage
- **Performance baseline:** `docker stats`, host `vmstat`/`iostat`, recording "normal" to detect "abnormal"
- **What's next:** Kubernetes (what it adds beyond Compose), Ansible/Terraform for infrastructure automation, cloud platforms (AWS ECS/EKS, GCP Cloud Run/GKE, Azure ACI/AKS), container registries (ECR, GCR, ACR), Linux certifications (LPIC-1, RHCSA, CKA)

Labs:
- `lab_01_compose_three_tier.md` — Translate the manually-wired three-tier app from Week 16 into a Docker Compose stack. Write `compose.yml` with: nginx reverse proxy, Flask API (built from Dockerfile), PostgreSQL (official image with init script and named volume). Configure: custom networks (frontend + backend), health checks on all services, `depends_on` with health conditions, environment files, restart policies, logging limits. Test the full request chain with `curl`. Tear down and bring back up — verify data persists. Write a `compose.override.yml` for development (bind-mounted source, debug port). Run the equivalent with `podman-compose` on Rocky, noting differences. Includes provided `compose.yml` scaffold with TODOs.
- `lab_02_capstone_deployment.md` — The capstone. Deploy the complete three-tier stack on your Ubuntu VM with production patterns. This lab ties together every week of the course:
  - **Filesystem & navigation (Week 2):** Organize the project with a proper directory layout
  - **Text processing (Week 3):** Parse access logs to verify traffic flow
  - **Permissions (Week 5):** Secure config files, `.env` files, and TLS certificates with appropriate ownership and modes
  - **Package management (Week 6):** Install Docker, fail2ban, certbot
  - **Process monitoring (Week 7):** Verify services are running, check resource usage
  - **Scripting (Weeks 8, 14):** Automated database backup script with rotation and logging
  - **Networking & firewall (Week 9):** Configure ufw to allow only 80, 443, and SSH
  - **Systemd (Week 11):** Create a systemd timer for automated backups, configure Docker to start on boot
  - **Web server & DNS (Week 12):** Host-level nginx for TLS termination (self-signed cert for the lab), proxying to the Compose stack
  - **Database (Week 13):** PostgreSQL with proper initialization, application user, backup/restore verification
  - **Containers (Weeks 15–17):** The full Compose stack with health checks, proper networking, persistent volumes
  - **Security hardening:** SSH lockdown, firewall, fail2ban, non-root containers
  - **Monitoring script:** A health-check script that curls every endpoint, checks container status, and reports failures
  - **Architecture documentation:** Write a README documenting the full stack architecture, request flow, backup procedures, and troubleshooting guide
  - The lab provides a structured checklist but expects the learner to apply knowledge from all prior weeks to implement each piece. Verification commands are provided at each stage.

---

## Build Execution Plan

**CRITICAL: Build one module at a time in this exact order. After each step, the work should be committable.**

### Phase 0: Scaffolding
```bash
mkdir -p linux-mastery/week-{01..17}/labs
touch linux-mastery/.gitignore
```
Create the `.gitignore`:
```
*.swp
*.swo
*~
.DS_Store
.vagrant/
*.log
*.tmp
.env
node_modules/
__pycache__/
*.pyc
.venv/
```
Then create the root `README.md` (see Root README spec below).

**Commit: "Initial scaffolding and root README"**

### Phase 1–17: Build Each Week

For EACH week (01 through 17), do the following in order:

1. **Read this plan's entry for that week** — topics, labs, goal
2. **Write `week-NN/README.md`** — the full lesson following the Weekly README Format Spec below
3. **Write each lab file** in `week-NN/labs/` following the Lab Format Spec below
4. **Write any scaffold code files** referenced by labs (e.g., `app.py`, `requirements.txt`, `server.js`, `compose.yml`)
5. **Verify navigation links** — previous/next week links are correct
6. **Commit: "Add week NN: Module Title"**

**DO NOT skip ahead. DO NOT batch multiple weeks. One week per cycle.**

---

## Root README Spec

The root `linux-mastery/README.md` must include:

1. **Title:** `Linux Mastery: From Zero to Production`
2. **Tagline:** `A 17-week hands-on course for beginners who want to develop software on Linux, run production services, manage databases, and master container workflows.`
3. **About section:** 2-3 paragraphs covering: dual-distro approach (Ubuntu + Rocky), Parallels VM setup on Mac, progression from CLI basics through server infrastructure and databases to container-based development, the three-tier app arc (build natively → containerize → deploy), who it's for, what makes it different
4. **How to Use table:** File purposes, recommended workflow (read lesson → type along in your VM → experiment → complete labs)
5. **Course Structure table:** All 17 weeks with week number, module name, and topic summary
6. **Prerequisites:** macOS with Parallels Desktop, 16GB+ RAM recommended, no prior Linux experience required
7. **Quick Start:** Clone repo, start with Week 01
8. **Philosophy:** Three principles — why before how, small blocks with immediate explanation, build real things

---

## Weekly README Format Spec

Every `week-NN/README.md` must follow this structure:

### Header
```markdown
# Week N: Module Title

> **Goal:** One sentence — what the learner can DO after this week.

[← Previous Week](../week-NN/README.md) · [Next Week →](../week-NN/README.md)

---
```
(Week 01 has no previous link. Week 17 has no next link.)

### Section Pattern
Each concept follows: **context → code → explanation → build on it**

```markdown
## N.1 Section Title

Start with WHY. What problem does this solve? What would go wrong without it?
Use an analogy if helpful. Connect to prior weeks when possible.

Then show a small command or code block (1-8 lines):

```bash
command here
```

Expected output (when it teaches something):

```
output here
```

Then explain each line: what it does, why it's written this way,
what happens if you change parts, how it connects to the concept above.

Then build on it with the next small block. Repeat.
```

### Key section rules:
- One concept per section
- Progressive complexity within each section (simplest example first)
- Tables for reference data (flags, comparisons, distro differences, HTTP status codes, SQL types, etc.)
- Bold for key terms on FIRST introduction only
- **Dual-distro callouts:** When commands differ between Ubuntu and Rocky, show BOTH clearly with a comparison table or side-by-side code blocks. Never bury differences in footnotes.
- **Three-tier app references (Weeks 12–17):** Explicitly connect concepts to the running application. "This is the same pattern your Flask API uses to talk to PostgreSQL." "The nginx config here is identical to what you'll bake into a container image in Week 16."
- Connect backward to prior weeks explicitly ("Remember from Week 5 how we set permissions? The same principle applies here...")
- Occasionally preview future weeks ("We'll automate this with containers in Week 15")
- For server/infrastructure topics: always explain why a sysadmin cares, what can go wrong, how to troubleshoot

### Footer
```markdown
---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab N.1: Title](labs/lab_01_name.ext)** — One-sentence description
- **[Lab N.2: Title](labs/lab_02_name.ext)** — One-sentence description

---

## Checklist

Before moving to Week N+1, confirm you can:

- [ ] Skill phrased as something you can DO (verb + action)
- [ ] Another skill
- ...

---

[← Previous Week](../week-NN/README.md) · [Next Week →](../week-NN/README.md)
```

---

## Lab Format Spec

### For `.md` labs (instruction-based):

```markdown
# Lab N.X: Title

> **Objective:** What the learner will accomplish.
>
> **Concepts practiced:** List of concepts from this and prior weeks.
>
> **Time estimate:** NN minutes
>
> **VM(s) needed:** Ubuntu / Rocky / Both

---

## Part 1: Section Name

### Step 1: Description

Run this command:

```bash
command
```

**Expected output:**

```
what they should see
```

**Before you continue, predict:** What do you think will happen if you ...?

### Step 2: ...

(continue with numbered steps, expected output, prediction questions)

---

## Try Breaking It

1. Try doing X wrong. What error do you get? What does it tell you?
2. Try omitting Y. What happens?

---

## Verify Your Work

Run these commands to confirm everything is working:

```bash
verification command
```

Expected: description of correct output
```

### For `.sh` labs (script-based):

```bash
#!/bin/bash
# =============================================================================
# Lab N.X: Title
# =============================================================================
#
# OBJECTIVE:
#   What this script should do when complete.
#
# CONCEPTS PRACTICED:
#   - Concept 1 (Week N)
#   - Concept 2 (Week M, if from a prior week)
#
# HOW TO RUN:
#   chmod +x lab_0N_name.sh
#   ./lab_0N_name.sh
#
# HOW TO TEST:
#   The script includes built-in tests at the bottom.
#   All tests pass when your implementation is correct.
#
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# TODO 1: Description of what to implement
# HINT: See README.md section N.X for help with [specific concept]
# ---------------------------------------------------------------------------
function_name() {
    local param="$1"

    # TODO: Your implementation here

}

# ---------------------------------------------------------------------------
# TODO 2: Next function (progressively harder)
# HINT: Remember from Week N how we used [concept]...
# ---------------------------------------------------------------------------

# ... more TODOs ...

# =============================================================================
# TESTS — Do not modify below this line
# =============================================================================
echo "Running tests..."
errors=0

# Test 1
result=$(function_name "test_input")
if [[ "$result" == "expected_output" ]]; then
    echo "  ✓ Test 1 passed: description"
else
    echo "  ✗ Test 1 FAILED: expected 'expected_output', got '$result'"
    ((errors++))
fi

# ... more tests ...

echo ""
if [[ $errors -eq 0 ]]; then
    echo "All tests passed!"
else
    echo "$errors test(s) failed."
    exit 1
fi
```

### For scaffold code files (provided to learners for use in labs):

When a lab requires a working application (e.g., `app.py`, `requirements.txt`, `server.js`, `compose.yml`), provide it as a complete or near-complete file in the `labs/` directory. Scaffolds that the learner fills in should have clear TODO markers. Scaffolds that are tools for the lab (not exercises themselves) should be complete and working. Keep them minimal, well-commented, and focused on demonstrating the infrastructure concept.

**The three-tier app scaffold files evolve across weeks:**
- **Week 12:** `app.py` — minimal Flask API (no database), `requirements.txt` with flask only
- **Week 13:** `lab_02_app.py` — Flask API with database routes (TODOs for SQL queries), `requirements.txt` adds psycopg2-binary
- **Week 16:** Dockerfile for the API, nginx config for the reverse proxy container
- **Week 17:** `compose.yml` scaffold with TODOs, `compose.override.yml` for dev, `.env.example`, `init.sql` for PostgreSQL initialization

Each evolution should reference the prior version: "This is the same `app.py` from Week 13, now with a Dockerfile."

---

## Writing Style Rules

Follow these strictly:

1. **Authoritative but warm.** Senior engineer mentoring a colleague, not a professor lecturing.
2. **Direct.** Lead with the concept. "Here's the problem:" not "In this section we'll explore..."
3. **Honest about complexity.** Say "This is confusing the first time" when something genuinely is.
4. **Server-admin and container-dev perspective.** When introducing concepts, explain why someone running services or building container workloads cares. "You'll see this in every Dockerfile" or "This is how you debug a 502 from your reverse proxy" or "Forget the WHERE clause on a DELETE and you'll learn a hard lesson about backups."
5. **No emojis** in lesson content. Only ✓ and ✗ in test output and checklists.
6. **Minimal bullet points in prose.** Use paragraphs for explanations. Reserve lists for genuinely list-shaped content.
7. **Tables for structured reference** — flags, distro comparisons, HTTP codes, SQL types, Dockerfile instructions, Docker/Podman comparisons, PostgreSQL vs MariaDB comparisons.
8. **Bold for key terms** on first introduction only.
9. **Code blocks with language tags** — `bash`, `sql`, `python`, `ini`, `yaml`, `nginx`, `dockerfile`, `javascript`, `json`, `text`, etc.
10. **Show full commands.** Complete command first, shortcuts after.
11. **Show expected output** when it teaches something.
12. **Explain error messages** when something might fail.
13. **Always quote variables in bash:** `"$VAR"` not `$VAR`.

---

## Dual-Distro Approach

This course runs on BOTH Ubuntu and Rocky Linux. Handle differences like this:

- **When commands are identical:** Show once, note it works on both.
- **When commands differ slightly:** Use a comparison table:

```markdown
| Task | Ubuntu | Rocky Linux |
|------|--------|-------------|
| Install nginx | `sudo apt install nginx` | `sudo dnf install nginx` |
| Install PostgreSQL | `sudo apt install postgresql` | `sudo dnf install postgresql-server` |
| Firewall allow HTTP | `sudo ufw allow 80/tcp` | `sudo firewall-cmd --add-service=http --permanent` |
| Install Docker | `sudo apt install docker-ce` | `sudo dnf install docker-ce` (or Podman) |
```

- **When concepts differ significantly** (package management, firewall tools, network config, Docker vs Podman, PostgreSQL vs MariaDB): Give each distro its own subsection with full walkthroughs.
- **Week 13 specifically:** PostgreSQL on Ubuntu, MariaDB on Rocky — teach both, compare side-by-side. The three-tier app labs use PostgreSQL (since the API scaffold uses psycopg2), but the lesson covers both.
- **Labs on both distros:** Say so explicitly in the lab header.
- **Labs that are distro-specific:** Note which VM to use.

---

## Three-Tier Application Arc

The three-tier app (nginx → Flask API → PostgreSQL) is a narrative thread through Weeks 12–17:

| Week | What happens to the app |
|------|------------------------|
| 12 | Flask API (no database) + nginx reverse proxy — native services on Ubuntu |
| 13 | Add PostgreSQL, connect the API to the database, full CRUD endpoints — native three-tier stack |
| 14 | Write a backup script for the database (used later in production deployment) |
| 15 | Run PostgreSQL and the API in containers manually (docker run), learn volumes and networking |
| 16 | Write Dockerfiles for the API and nginx, containerize all three tiers, wire them together manually |
| 17 | Orchestrate with Docker Compose, add production patterns, capstone deployment with security and backups |

This progression means the learner understands every layer before it gets abstracted. They know what nginx is doing because they configured it by hand in Week 12 before putting it in a container in Week 16. They know what `pg_hba.conf` does because they edited it in Week 13 before environment variables replaced it in Week 15.

**When writing scaffold files:** Reference the prior version. "This is the `app.py` from Week 13, now packaged with a Dockerfile." Don't make the learner wonder where the code came from.

---

## Lesson Length Targets

Each week's README.md should be approximately:
- **Weeks 1-2:** 800-1200 lines (setup needs detail)
- **Weeks 3-8:** 600-1000 lines (core concepts)
- **Weeks 9-11:** 700-1100 lines (complex server topics)
- **Week 12:** 800-1200 lines (web servers + DNS is substantial)
- **Week 13:** 900-1300 lines (databases are a big topic — two database systems plus SQL plus the three-tier app)
- **Week 14:** 600-900 lines (advanced scripting, building on Week 8)
- **Weeks 15-16:** 800-1200 lines (container topics need thorough coverage)
- **Week 17:** 700-1000 lines (orchestration + capstone context)

Each lab should be approximately:
- **Markdown labs:** 150-350 lines
- **Script labs:** 100-250 lines (including scaffolding and tests)
- **Capstone lab (17.2):** 400-600 lines (it's comprehensive and ties together 17 weeks)

These are guidelines, not hard limits. Quality matters more than line count.

---

## Quality Checklist

Before considering a week complete, verify:

- [ ] README.md has correct header with goal and navigation links
- [ ] Every concept section follows the context → code → explanation pattern
- [ ] Code blocks have language tags
- [ ] Distro differences are called out clearly (tables or dual examples)
- [ ] Server-admin, database, and container relevance is woven in where appropriate
- [ ] Three-tier app connections are made explicit in Weeks 12–17
- [ ] Labs have clear objectives, concept lists, VM requirements, and verification steps
- [ ] Script labs have TODO markers, hints referencing specific README sections, and built-in tests
- [ ] Scaffold code files are consistent across weeks (the `app.py` in Week 16 is a recognizable evolution of the one from Week 13)
- [ ] Checklist items are phrased as skills (verb + action)
- [ ] Previous/next week navigation links point to correct directories
- [ ] No references to concepts not yet introduced (unless flagged as preview)
- [ ] Commands shown are complete
- [ ] Any scaffold code files referenced in labs exist in the labs/ directory

---

## Execution Command

```bash
cd /path/to/workspace
git init linux-mastery
cd linux-mastery

# Phase 0: Scaffolding
mkdir -p week-{01..17}/labs
# Create .gitignore and root README.md
# git add -A && git commit -m "Initial scaffolding and root README"

# Phase 1: Week 01
# Create week-01/README.md and week-01/labs/*
# git add -A && git commit -m "Add week 01: Welcome to Linux & VM Setup"

# Phase 2: Week 02
# Create week-02/README.md and week-02/labs/*
# git add -A && git commit -m "Add week 02: The Shell & Navigating the Filesystem"

# ... continue through Week 17
```

Build ALL 17 weeks. Do not stop and ask if the user wants more. Complete the entire course.

