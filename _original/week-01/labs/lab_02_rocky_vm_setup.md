# Lab 1.2: Rocky Linux VM Setup

> **Objective:** Download, install, and configure a Rocky Linux 9 virtual machine in Parallels Desktop, then verify SSH access from your Mac.
>
> **Concepts practiced:** ISO downloading, VM creation, Anaconda installer, SSH connectivity, comparing two Linux distributions
>
> **Time estimate:** 30–45 minutes
>
> **VM(s) needed:** None yet — you're building one

---

## Part 1: Download the ISO

### Step 1: Get Rocky Linux 9

Open your web browser on your Mac and navigate to:

```
https://rockylinux.org/download
```

Download the **Rocky Linux 9** minimal or boot ISO for your architecture (ARM64 for Apple Silicon Macs, x86_64 for Intel Macs). If only a DVD ISO is available, that works too — it's just a larger download.

### Step 2: Verify the download

In your Mac terminal:

```bash
ls -lh ~/Downloads/Rocky-*-minimal*.iso
```

**Expected output:** A file roughly 1.5–2 GB (minimal) or 8–10 GB (DVD).

---

## Part 2: Create the VM in Parallels

### Step 3: Create a new virtual machine

Follow the same process as Lab 1.1:

1. **File → New** in Parallels Desktop
2. **Install from DVD or image file**
3. Select the Rocky Linux ISO
4. **Decline automatic setup** — you want to walk through the installer
5. Check **Customize settings before installation**

### Step 4: Configure VM hardware

| Setting | Value |
|---------|-------|
| Name | `rocky-linux` |
| CPUs | 2 |
| Memory | 4096 MB (4 GB) |
| Hard Disk | 40 GB |
| Network | Shared Network (default) |

Click **Continue** to boot the VM.

---

## Part 3: Install Rocky Linux

### Step 5: Boot and select installation

When the VM boots, you'll see a boot menu. Use the arrow keys to select:

```
Install Rocky Linux 9
```

Press Enter. The Anaconda installer loads (this takes a minute).

**Before you continue, predict:** How will this installer look different from Ubuntu's Subiquity installer?

### Step 6: Walk through the Anaconda installer

Anaconda uses a hub-and-spoke layout — one central screen with categories. Items with warning icons need your attention before installation can begin.

Work through each section:

**Localization:**

1. **Keyboard:** Select your keyboard layout. Click **Done**.
2. **Language Support:** English is usually pre-selected. Click **Done**.
3. **Time & Date:** Select your timezone. Enable **Network Time** if available. Click **Done**.

**Software:**

4. **Software Selection:** Select **Minimal Install** in the left column. Don't add any additional packages from the right column. Click **Done**.

This is important — minimal means minimal. No GUI, no development tools, no extras. You'll install what you need later with `dnf`. This mirrors how production servers are configured: start lean, add only what's required.

**System:**

5. **Installation Destination:** Click your 40 GB virtual disk. Ensure **Automatic** partitioning is selected. Click **Done**.

6. **Network & Host Name:**
   - Click your network interface (often `enp0s5` or similar)
   - Toggle the switch to **ON** — this is critical! Rocky does NOT enable networking by default during installation
   - Watch for an IP address to appear (something like `10.211.55.X`)
   - **Write down this IP address**
   - At the bottom of the screen, change the hostname from `localhost.localdomain` to `rocky-vm`
   - Click **Apply**, then **Done**

**User Settings:**

7. **Root Password:** Set a strong root password and note it. Select **Allow root SSH login** only if you want to (for this course, you'll use `student` with `sudo`, not root directly).

8. **User Creation:**
   - Full name: `Student`
   - Username: `student`
   - Check **Make this user administrator** (this adds the user to the `wheel` group — Rocky's equivalent of Ubuntu's `sudo` group)
   - Set a password
   - Click **Done**

### Step 7: Begin installation

Once all warning icons are resolved, click **Begin Installation** at the bottom of the hub screen.

Watch the progress. Installation takes 5–15 minutes.

### Step 8: Reboot

When installation completes, click **Reboot System**.

If the VM boots back into the installer, shut down the VM, remove the ISO from the CD/DVD drive in VM settings, and start it again.

---

## Part 4: First Login and SSH Verification

### Step 9: Log in at the console

After reboot, you'll see:

```
rocky-vm login:
```

Log in with `student` and your password.

**Expected output:**

```
[student@rocky-vm ~]$
```

Notice the prompt differences from Ubuntu:

| Element | Ubuntu | Rocky |
|---------|--------|-------|
| Format | `user@host:dir$` | `[user@host dir]$` |
| Example | `student@ubuntu-vm:~$` | `[student@rocky-vm ~]$` |

Same information, different formatting. Both are bash prompts.

### Step 10: Check network connectivity

Rocky's minimal install might not have the network enabled after reboot (even though you enabled it during installation). Check:

```bash
ip addr show
```

If you see an IP address on your interface, you're good. If not, bring the network up:

```bash
sudo nmcli connection up enp0s5
```

Replace `enp0s5` with your actual interface name (shown in the `ip addr` output). You'll need to enter your password for `sudo`.

To make the network connection persist across reboots:

```bash
sudo nmcli connection modify enp0s5 connection.autoconnect yes
```

### Step 11: Find your IP address

```bash
hostname -I
```

**Expected output:**

```
10.211.55.4
```

Your number will differ. Write it down.

### Step 12: Verify SSH is running

```bash
sudo systemctl is-active sshd
```

**Expected output:** `active`

If SSH is not installed or not running:

```bash
sudo dnf install -y openssh-server
sudo systemctl enable --now sshd
```

### Step 13: Connect via SSH from your Mac

Open a **new Terminal window on your Mac** and run:

```bash
ssh student@10.211.55.4
```

Replace with your Rocky VM's actual IP.

Accept the host fingerprint (type `yes`), enter your password.

**Expected result:** You're at the `[student@rocky-vm ~]$` prompt in your Mac's Terminal.

### Step 14: Verify the system

```bash
cat /etc/os-release | head -3
```

**Expected output:**

```
NAME="Rocky Linux"
VERSION="9.x (Blue Onyx)"
ID="rocky"
```

```bash
uname -r
```

**Expected output:** A kernel version string like `5.14.0-xxx.el9.aarch64`

```bash
df -h /
```

**Expected output:** About 40 GB total.

```bash
free -h
```

**Expected output:** About 4 GB total.

---

## Part 5: Compare the Two Distributions

### Step 15: Side-by-side comparison

Open two Terminal tabs on your Mac — one SSH'd into Ubuntu, one into Rocky. Run the same commands on both and compare:

```bash
# What distribution is this?
cat /etc/os-release | head -4

# What kernel version?
uname -r

# How much disk space?
df -h /

# What's the hostname?
hostname

# What's my user ID?
id
```

**Note what's the same** (kernel type, basic commands, output format) **and what's different** (distribution name, kernel version numbers, default user groups).

On Ubuntu, your user is in the `sudo` group. On Rocky, your user is in the `wheel` group. Both grant administrator privileges — just different names.

```bash
# On Ubuntu
groups
# Output includes: sudo

# On Rocky
groups
# Output includes: wheel
```

---

## Part 6: Take a Snapshot

### Step 16: Snapshot your clean install

In Parallels, with the Rocky Linux VM selected, go to **Actions → Manage Snapshots** (`Cmd+Shift+S`).

Create a snapshot named:

```
Clean Install - Rocky Linux 9
```

---

## Try Breaking It

Before you finish, try these experiments to build intuition:

1. **Try logging in with a wrong password three times.** What happens? Does the VM lock you out?

2. **Try SSH'ing as a user that doesn't exist:**
   ```bash
   ssh nobody@10.211.55.4
   ```
   What error do you get?

3. **Find a difference in installed software.** Try running `curl` on both VMs:
   ```bash
   curl --version
   ```
   Ubuntu Server includes `curl` by default. Rocky minimal might not. If Rocky doesn't have it, you'll learn to install it in Week 6.

---

## Verify Your Work

Run these commands on your Rocky VM and confirm the output:

```bash
# Verify you're on Rocky Linux
grep "Rocky" /etc/os-release
```

Expected: Lines containing "Rocky"

```bash
# Verify SSH is running
systemctl is-active sshd
```

Expected: `active`

```bash
# Verify your username
whoami
```

Expected: `student`

```bash
# Verify your hostname
hostname
```

Expected: `rocky-vm`

```bash
# Verify network connectivity
ping -c 3 8.8.8.8
```

Expected: Three successful ping replies

```bash
# Verify DNS
ping -c 3 google.com
```

Expected: Three successful ping replies

If all of these pass, both VMs are ready. You have a complete Linux lab environment. Take your snapshots and move on to Week 2.
