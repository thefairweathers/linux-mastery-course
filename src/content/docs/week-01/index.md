---
title: "Week 1: Welcome to Linux & VM Setup"
sidebar:
  order: 0
---


> **Goal:** Install Ubuntu Server and Rocky Linux VMs in Parallels on macOS, boot into both, and log in via SSH.


---

## 1.1 What Is Linux?

Linux is an operating system kernel — the core software that manages your hardware, runs your programs, and controls who gets access to what. When people say "Linux," they usually mean a complete operating system built around the Linux kernel: a kernel, system utilities, a package manager, and enough software to be useful. These complete packages are called **distributions** (or **distros**).

Here's the part that matters for your career: Linux runs the internet. Over 90% of the world's web servers, nearly all cloud infrastructure, every Android phone, most supercomputers, and virtually every container in every Kubernetes cluster — all Linux. When you deploy a web application, it almost certainly lands on a Linux server. When you run a Docker container, it's running a Linux process. When a CI/CD pipeline builds your code, it's running on Linux.

That's why you're here. Not to learn Linux trivia, but to become comfortable working in the environment where software actually runs in production.

## 1.2 A Brief History (Just Enough)

In 1991, a Finnish university student named Linus Torvalds built a free operating system kernel because he couldn't afford the commercial Unix systems his university used. He posted it online. Other people started contributing. That kernel — Linux — combined with the GNU project's system utilities to form a complete, free operating system.

The critical decision was the license: Linux is **open source** under the GPL, meaning anyone can use, modify, and distribute it. This is why hundreds of Linux distributions exist and why companies like Red Hat, Canonical, and SUSE can build businesses around it without owning it.

Two lineages matter for this course:

**Debian → Ubuntu.** Debian is one of the oldest community-driven distributions, known for stability and its `apt` package manager. Ubuntu is built on top of Debian by a company called Canonical. It's the most popular Linux distribution for servers and desktops, and it's what you'll encounter most often in cloud environments, tutorials, and Docker base images.

**Red Hat Enterprise Linux (RHEL) → Rocky Linux.** RHEL is the dominant enterprise Linux distribution — the one Fortune 500 companies pay for. Rocky Linux is a free, community-built clone of RHEL, created after CentOS (the previous free RHEL clone) changed its model. If you work in enterprise environments, government, or finance, you'll likely encounter RHEL or a compatible distribution.

This course teaches both. The commands are 90% identical, but knowing where they diverge — package management, firewall tools, service configuration, default paths — makes you versatile.

## 1.3 Where Linux Runs

Linux isn't just "the server OS." Here's where you'll encounter it:

| Environment | Why Linux | What you'll learn here |
|-------------|-----------|----------------------|
| Web servers | nginx, Apache, and application servers all run on Linux | Weeks 12–13 |
| API backends | Flask, Django, Node.js, Go — deployed on Linux servers or containers | Weeks 12–13 |
| Container hosts | Docker and Podman run Linux containers on Linux hosts | Weeks 15–17 |
| CI/CD runners | GitHub Actions, GitLab CI, Jenkins — Linux VMs or containers | Weeks 15–17 |
| Cloud instances | AWS EC2, GCP Compute, Azure VMs — predominantly Linux | Throughout |
| Databases | PostgreSQL, MySQL/MariaDB, Redis — all run on Linux in production | Week 13 |
| IoT devices | Raspberry Pi, routers, embedded systems | Concepts apply |
| Supercomputers | 100% of the world's top 500 supercomputers run Linux | — |

By the end of this course, you'll have hands-on experience with the first six rows of that table.

## 1.4 Why Two Distributions?

You might wonder why we don't just pick one. Two reasons.

First, the real world uses both families. Ubuntu dominates cloud deployments, developer environments, and Docker base images. RHEL-compatible distributions dominate enterprise data centers, government systems, and regulated industries. Employers won't ask "do you know Ubuntu?" — they'll ask "do you know Linux?" and expect you to work on whatever they run.

Second, learning two distributions forces you to understand Linux itself rather than memorizing one distribution's quirks. When a command works the same on both, you know it's a Linux concept. When it differs, you learn where the distribution layer sits and how to adapt.

The differences aren't dramatic — it's the same kernel, mostly the same tools. The main divergences you'll encounter:

| Area | Ubuntu | Rocky Linux |
|------|--------|-------------|
| Package manager | `apt` | `dnf` |
| Package format | `.deb` | `.rpm` |
| Firewall | `ufw` | `firewalld` |
| Default shell | bash | bash |
| Init system | systemd | systemd |
| SELinux | Available but not enforced by default | Enforced by default |
| Installer | Subiquity (text-based) | Anaconda (semi-graphical) |

## 1.5 Your Lab Environment: Parallels VMs on macOS

Throughout this course, you'll work on two virtual machines (VMs) running on your Mac using **Parallels Desktop**. A VM is a complete computer simulated in software — it has its own CPU allocation, memory, disk, and network interface, and it runs a real operating system. You can break things in a VM without affecting your Mac.

Why Parallels? It's the fastest and most reliable VM solution on Apple Silicon Macs. The free trial lasts long enough to get through this course, and if you purchase it, it'll serve you well beyond.

**Recommended VM specifications:**

| Resource | Per VM | Why |
|----------|--------|-----|
| CPUs | 2 | Enough for compiling, running services, and containers |
| RAM | 4 GB | Comfortable for a database server + web server + a few containers |
| Disk | 40 GB | Room for packages, container images, and database storage |

You'll need about 80 GB of free disk space total and at least 16 GB of RAM on your Mac (to run both VMs plus macOS comfortably).

## 1.6 Downloading the ISOs

An **ISO file** is a disk image — a perfect copy of an installation disc. You'll download one for each distribution.

**Ubuntu Server 24.04 LTS:**

Go to [https://ubuntu.com/download/server](https://ubuntu.com/download/server) and download the latest **Ubuntu Server 24.04 LTS** ISO. LTS stands for Long Term Support — Canonical supports it with security updates for five years. Always use LTS releases for servers. The ISO is approximately 2.5 GB.

Make sure you download **Server**, not Desktop. Server doesn't include a graphical interface — and that's the point. Real Linux servers don't have GUIs. You'll do everything from the command line, just like in production.

**Rocky Linux 9:**

Go to [https://rockylinux.org/download](https://rockylinux.org/download) and download the **Rocky Linux 9** minimal ISO (usually called "Minimal" or "Boot"). The minimal ISO is smaller (about 1.5–2 GB) and installs just the base system — you'll add packages as needed, which is how servers are configured in the real world: start minimal, add only what you need.

If only a DVD ISO is available (about 8-10 GB), that works too — it just takes longer to download. The installation process is the same.

## 1.7 Creating the Ubuntu Server VM

Open Parallels Desktop, then follow these steps:

**Step 1: Create a new VM.**

Click **File → New** (or the `+` button). Select **Install Windows or another OS from a DVD or image file**. Click **Continue**.

**Step 2: Select the ISO.**

Click **Choose Manually**, then locate the Ubuntu Server ISO you downloaded. Parallels may offer to set up Ubuntu automatically — **decline this** and choose **Customize settings before installation** so you can configure the VM properly.

**Step 3: Configure hardware.**

In the VM configuration dialog, set:
- **Name:** `ubuntu-server` (or whatever helps you identify it)
- **CPUs:** 2
- **Memory:** 4096 MB (4 GB)
- **Hard Disk:** 40 GB

Under **Network**, ensure the adapter is set to **Shared Network** (the default). This gives the VM internet access through your Mac's connection and assigns it a private IP address that your Mac can reach.

**Step 4: Start the installation.**

Click **Continue** to boot the VM from the ISO. You'll see the Ubuntu installer (Subiquity).

**Step 5: Walk through the installer.**

The Ubuntu Server installer is text-based. Here's what to select at each screen:

- **Language:** English
- **Installer update:** Accept the update if offered
- **Keyboard:** Your keyboard layout (usually detected automatically)
- **Installation type:** Ubuntu Server (not minimized)
- **Network:** The installer should detect your network interface and get an IP via DHCP. Note this IP — you'll use it for SSH.
- **Proxy:** Leave blank unless you're behind a corporate proxy
- **Mirror:** Accept the default archive mirror
- **Storage:** Use the entire disk (the default guided option is fine for learning). Accept the suggested partition layout.
- **Profile setup:** This is where you create your user account.
  - Your name: your name
  - Server name: `ubuntu-vm` (this becomes the hostname)
  - Username: `student` (we'll use this throughout the course)
  - Password: choose something you'll remember — you'll type it often
- **Ubuntu Pro:** Skip
- **SSH Server:** **Install OpenSSH server** — check this box. This is critical. Without it, you can't SSH in from your Mac.
- **Featured snaps:** Don't select any. You'll install software as needed.

**Step 6: Wait for installation.**

The installer downloads packages and configures the system. This takes 5–15 minutes depending on your internet speed.

**Step 7: Reboot.**

When the installer says **Installation complete**, select **Reboot Now**. If it asks you to remove the installation medium, Parallels usually handles this automatically. If the VM boots back into the installer, shut it down, go to VM settings, and remove the ISO from the CD/DVD drive.

**Step 8: First login.**

After reboot, you'll see a text login prompt:

```
ubuntu-vm login:
```

Type `student` and press Enter. Type your password and press Enter. You won't see any characters as you type the password — that's normal and intentional (it prevents shoulder-surfing).

You should see a prompt like:

```
student@ubuntu-vm:~$
```

That's your command line. You're in.

## 1.8 Creating the Rocky Linux VM

The process is similar but the installer looks different. Rocky Linux uses **Anaconda**, a semi-graphical installer.

**Steps 1–3** are identical to Ubuntu: create a new VM in Parallels, select the Rocky Linux ISO, configure 2 CPUs, 4 GB RAM, 40 GB disk, Shared Network.

Name this VM `rocky-linux` (or similar).

**Step 4: Boot and start the installer.**

When the VM boots, you'll see a boot menu. Select **Install Rocky Linux 9** and press Enter.

**Step 5: Walk through the Anaconda installer.**

The Anaconda installer presents a hub-and-spoke layout — a central screen with categories you can click into. Some items will have warning icons indicating they need attention before you can begin.

Work through each section:

- **Localization → Keyboard:** Your keyboard layout
- **Localization → Language Support:** English (or your preference)
- **Localization → Time & Date:** Your timezone. Enable **Network Time** if available.
- **Software → Software Selection:** Choose **Minimal Install**. You want a lean server. You can add software later with `dnf`. No GUI.
- **System → Installation Destination:** Click your 40 GB virtual disk. Select **Automatic** partitioning. Click **Done**.
- **System → Network & Host Name:**
  - Click your network interface (usually `enp0s5` or similar) and toggle it **ON**
  - Note the IP address assigned — you'll need it for SSH
  - Set the hostname to `rocky-vm` at the bottom of the screen
  - Click **Done**
- **User Settings → Root Password:** Set a strong root password. You'll rarely use it directly, but you need it.
- **User Settings → User Creation:**
  - Full name: your name
  - Username: `student`
  - Check **Make this user administrator** (this adds the user to the `wheel` group, which grants `sudo` access)
  - Set a password

**Step 6: Begin installation.**

Once all warning icons are resolved, click **Begin Installation**. The installation takes 5–15 minutes.

**Step 7: Reboot.**

Click **Reboot System** when prompted.

**Step 8: First login.**

After reboot, you'll see:

```
rocky-vm login:
```

Log in with `student` and your password. You should see:

```
[student@rocky-vm ~]$
```

Notice the prompt format is slightly different from Ubuntu (`[user@host dir]$` vs `user@host:dir$`). Same shell (bash), different default prompt configuration. The underlying system works the same way.

## 1.9 Understanding the Console Prompt

That text you see before your cursor — the **prompt** — tells you four things at a glance:

```
student@ubuntu-vm:~$
```

| Part | Meaning |
|------|---------|
| `student` | Your username — who you're logged in as |
| `@ubuntu-vm` | The hostname — which machine you're on |
| `~` | Your current directory (`~` is shorthand for your home directory, `/home/student`) |
| `$` | You're a regular user (a `#` means you're root — the superuser) |

On Rocky, the same information appears in a slightly different format:

```
[student@rocky-vm ~]$
```

Same data, different wrapping. Both are configurable, but the defaults tell you everything you need to know about where you are and who you are.

## 1.10 Setting Up SSH Access from macOS

You *can* type commands directly in the Parallels VM console, but you don't want to. The console window doesn't support copy-paste well, can't be resized properly, and doesn't support scrollback. Instead, you'll connect from your Mac's Terminal application using **SSH** (Secure Shell).

SSH creates an encrypted connection from your Mac to the Linux VM. It's the same tool you'd use to connect to a remote server in a data center or cloud instance. Learning to work over SSH from day one builds the right habits.

**Step 1: Find your VM's IP address.**

In each VM, run:

```bash
ip addr show
```

Look for an entry like `inet 10.211.55.X/24` on an interface like `enp0s5` or `eth0`. That `10.211.55.X` is your VM's IP address on the Parallels shared network. Your Mac can reach this address directly.

Alternatively, on Ubuntu:

```bash
hostname -I
```

On Rocky:

```bash
hostname -I
```

Both should print one or more IP addresses. Use the one on the `10.211.55.x` subnet (the Parallels network).

**Step 2: Connect from your Mac.**

Open **Terminal** on your Mac (Spotlight → type "Terminal" → Enter) and type:

```bash
ssh student@10.211.55.X
```

Replace `10.211.55.X` with your VM's actual IP address.

The first time you connect, SSH asks you to verify the host's fingerprint:

```
The authenticity of host '10.211.55.X (10.211.55.X)' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter. SSH saves this fingerprint so it can warn you if the server's identity changes later (which could indicate a security problem).

Enter your password when prompted. You're now connected to your Linux VM from your Mac's terminal. This is how you'll work for the rest of the course.

**Step 3: Test both VMs.**

Connect to your Ubuntu VM and your Rocky VM from separate Terminal tabs or windows:

```bash
# Tab 1
ssh student@10.211.55.X    # Ubuntu IP

# Tab 2
ssh student@10.211.55.Y    # Rocky IP
```

You should have both prompts side by side. Welcome to your Linux lab.

## 1.11 Installing SSH on Rocky (If Needed)

Ubuntu Server installs the SSH server during setup (you checked the box). Rocky's minimal install *usually* includes it, but if `ssh` connections are refused, install it:

```bash
sudo dnf install openssh-server
sudo systemctl enable --now sshd
```

The first command installs the SSH server. The second enables it to start at boot (`enable`) and starts it immediately (`--now`). Don't worry about `systemctl` yet — we'll cover it thoroughly in Week 11.

## 1.12 Parallels Tips for the Course

A few Parallels-specific tips that will save you time:

**Snapshots** are your safety net. A snapshot saves the entire state of a VM at a point in time. If you break something badly during a lab, you can revert to the snapshot instead of reinstalling.

Take a snapshot now — right after a clean install, before you change anything:

In Parallels, go to **Actions → Manage Snapshots** (or press `Cmd+Shift+S`). Click the `+` button. Name it "Clean Install" or "Fresh Setup."

Take another snapshot before any lab that warns you about destructive operations (disk partitioning, firewall changes, etc.).

**Networking modes:**

| Mode | How it works | When to use |
|------|-------------|-------------|
| Shared Network | VM gets a private IP, Mac acts as router. VM can reach the internet and your Mac can reach the VM. | Default — use this for the course |
| Bridged Network | VM gets an IP on your physical network, like another device on your Wi-Fi. | If Shared doesn't work, or when you need VMs visible to other devices |

Shared Network is the default and works best for this course. If you switch networks (home → office → coffee shop), Shared Network keeps working because it doesn't depend on the external network.

**Shared Folders** let you share directories between your Mac and the VM. This is useful later when you want to edit files on your Mac and test them in the VM. For now, you don't need it — SSH and command-line editors will be sufficient.

**Performance:** If a VM feels slow, check that you've allocated 2 CPUs and 4 GB RAM. Also ensure your Mac isn't running low on memory with both VMs active. Close heavy Mac applications if needed.

## 1.13 Your First Commands

Now that you're connected via SSH, try a few commands to verify everything works. Don't worry about understanding every detail — we'll cover all of these properly in Week 2.

Check which Linux distribution you're running:

```bash
cat /etc/os-release
```

On Ubuntu, you'll see output including `NAME="Ubuntu"` and `VERSION="24.04"`. On Rocky, you'll see `NAME="Rocky Linux"` and `VERSION="9.x"`.

Check the kernel version:

```bash
uname -r
```

This shows the Linux kernel version. Both VMs are running the same kernel family (Linux), even though the distribution layer on top is different.

Check how much disk space you have:

```bash
df -h /
```

The `-h` flag means "human-readable" — sizes in GB instead of raw bytes. You should see about 40 GB total with most of it free.

Check your username and hostname:

```bash
whoami
hostname
```

These confirm who you are and where you are — the same information that's in your prompt.

## 1.14 What's Ahead

Here's what you just accomplished: you downloaded two Linux distributions, created two virtual machines, installed a complete operating system on each, and established SSH access from your Mac. You have a fully functional Linux lab environment.

This is the same workflow that system administrators use to set up servers — except instead of Parallels, they're provisioning cloud instances, bare-metal servers, or VMs on enterprise hypervisors. The skills are directly transferable.

Starting next week, you'll learn to navigate the Linux filesystem, manage files, and start using the command line as your primary tool. By Week 17, these two VMs will be running a containerized, production-grade application stack.

Take your snapshots. You're ready.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 1.1: Ubuntu Server VM Setup](./lab-01-ubuntu-vm-setup)** — Full walkthrough of downloading, installing, and configuring your Ubuntu Server VM with SSH verification
- **[Lab 1.2: Rocky Linux VM Setup](./lab-02-rocky-vm-setup)** — Same process for Rocky Linux 9, noting installer differences

---

## Checklist

Before moving to Week 2, confirm you can:

- [ ] Explain what Linux is and why it dominates servers and containers
- [ ] Describe the difference between Ubuntu and Rocky Linux (and when you'd use each)
- [ ] Create a virtual machine in Parallels with appropriate specs
- [ ] Install Ubuntu Server from an ISO
- [ ] Install Rocky Linux from an ISO
- [ ] Log in to each VM at the console
- [ ] Find your VM's IP address with `ip addr show` or `hostname -I`
- [ ] Connect to each VM via SSH from your Mac's Terminal
- [ ] Take a Parallels snapshot of each VM
- [ ] Run basic commands like `cat /etc/os-release`, `uname -r`, `df -h`

---

