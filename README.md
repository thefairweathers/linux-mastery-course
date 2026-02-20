# Linux Mastery: From Zero to Production

> A 17-week hands-on course for beginners who want to develop software on Linux, run production services, manage databases, and master container workflows.

---

## About This Course

This course takes you from zero Linux experience to confidently administering servers, managing databases, and deploying containerized applications. You'll work on two real Linux distributions — **Ubuntu Server** and **Rocky Linux** — running as virtual machines on your Mac. Every concept is taught through hands-on practice: you type real commands, break real things, fix them, and build real infrastructure.

The course has two throughlines beyond general Linux literacy. First, **server administration**: running, securing, and troubleshooting real services like web servers, reverse proxies, DNS resolvers, databases, and APIs. Second, **container development**: not just running Docker containers, but developing software that targets container workloads — writing Dockerfiles, optimizing builds, achieving dev/prod parity, and deploying multi-service stacks with Docker Compose.

A narrative arc connects the final six weeks: you'll build a **three-tier application** (nginx reverse proxy → Flask API → PostgreSQL database) first as native Linux services, then containerize each component, and finally orchestrate the entire stack with Docker Compose in a production-ready deployment. By the time you finish, you'll understand every layer because you configured each one by hand before it got abstracted.

---

## How to Use This Course

| File | Purpose |
|------|---------|
| `week-NN/README.md` | The lesson — read this first, type along in your VM |
| `week-NN/labs/` | Hands-on exercises to practice each week's concepts |
| `week-NN/labs/*.md` | Step-by-step guided labs with verification |
| `week-NN/labs/*.sh` | Script labs with TODOs for you to complete and built-in tests |
| `week-NN/labs/*.py`, `*.yml`, etc. | Scaffold files used by labs |

**Recommended workflow:**

1. Read the week's lesson (`README.md`), typing every command in your VM as you go
2. Experiment — change flags, break things intentionally, read error messages
3. Complete both labs in order
4. Run through the end-of-week checklist before moving on

---

## Course Structure

| Week | Module | Topics |
|------|--------|--------|
| 01 | Welcome to Linux & VM Setup | What Linux is, installing Ubuntu Server and Rocky Linux VMs in Parallels, SSH access |
| 02 | The Shell & Navigating the Filesystem | Bash, filesystem hierarchy, paths, file operations, wildcards, history |
| 03 | Reading, Searching & Manipulating Text | cat, less, grep, regex, cut, sort, uniq, sed, awk, find |
| 04 | Pipes, Redirection & The Unix Philosophy | stdin/stdout/stderr, pipes, tee, xargs, command chaining |
| 05 | Users, Groups & Permissions | Users, groups, chmod, chown, sudo, special permissions, umask |
| 06 | Package Management & Software Installation | apt, dnf, repositories, GPG keys, security updates |
| 07 | Processes, Jobs & System Monitoring | ps, top, signals, job control, /proc, lsof, resource monitoring |
| 08 | Bash Scripting Fundamentals | Variables, conditionals, loops, functions, exit codes, string manipulation |
| 09 | Networking Fundamentals | IP, DNS, SSH, firewalls (ufw/firewalld), curl, rsync |
| 10 | Storage, Filesystems & Disk Management | Partitioning, ext4/XFS, mounting, fstab, LVM, swap |
| 11 | Systemd, Services & the Boot Process | systemctl, journalctl, unit files, timers, boot process |
| 12 | Web Servers, DNS & Service Infrastructure | nginx, virtual hosts, reverse proxy, Flask API, dnsmasq, TLS |
| 13 | Databases: PostgreSQL & MariaDB | SQL, database administration, backups, three-tier application |
| 14 | Advanced Scripting & Automation | Argument parsing, arrays, file locking, logging, jq |
| 15 | Container Fundamentals | Docker, Podman, images, volumes, networking, container lifecycle |
| 16 | Building Images & Container Development | Dockerfiles, multi-stage builds, optimization, containerizing the three-tier app |
| 17 | Docker Compose, Production Patterns & Capstone | Compose, production deployment, security hardening, capstone project |

---

## Prerequisites

- **macOS** with [Parallels Desktop](https://www.parallels.com/) installed (a free trial works for the duration of the course)
- **16 GB RAM** recommended (you'll run two VMs simultaneously)
- **80 GB free disk space** (40 GB per VM)
- **No prior Linux experience required** — the course starts from absolute zero

---

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/linux-mastery-course.git
cd linux-mastery-course
```

Open `week-01/README.md` and begin. By the end of that first week, you'll have two working Linux virtual machines and SSH access from your Mac's terminal.

---

## Philosophy

**Why before how.** Every concept starts with the problem it solves. You'll understand *why* file permissions exist before you memorize `chmod 755`. You'll know *why* containers won before you write your first Dockerfile.

**Small blocks with immediate feedback.** Each concept is a short explanation followed by a command you type and output you verify. No 20-page theory chapters before you touch a keyboard.

**Build real things.** This isn't a reference manual — it's a construction project. By Week 17, you'll have a production-ready, containerized, three-tier application with automated backups, health checks, firewall rules, and a security-hardened host. Every piece of that stack was something you built and understood individually before assembling the whole.
