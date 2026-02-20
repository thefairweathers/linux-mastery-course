# Lab 1.1: Ubuntu Server VM Setup

> **Objective:** Download, install, and configure an Ubuntu Server 24.04 LTS virtual machine in Parallels Desktop, then verify SSH access from your Mac.
>
> **Concepts practiced:** ISO downloading, VM creation, Linux installation, SSH connectivity
>
> **Time estimate:** 30–45 minutes
>
> **VM(s) needed:** None yet — you're building one

---

## Part 1: Download the ISO

### Step 1: Get Ubuntu Server 24.04 LTS

Open your web browser on your Mac and navigate to:

```
https://ubuntu.com/download/server
```

Download the **Ubuntu Server 24.04 LTS** ISO image. The file will be approximately 2.5 GB.

**Before you continue, predict:** Why do we use Server instead of Desktop? What will be different about the experience?

### Step 2: Verify the download

Check that the file downloaded completely. In your Mac terminal:

```bash
ls -lh ~/Downloads/ubuntu-*-live-server-*.iso
```

**Expected output:**

```
-rw-r--r--@ 1 you  staff   2.5G  ... ubuntu-24.04-live-server-arm64.iso
```

The exact filename may vary (especially `arm64` vs `amd64` depending on your Mac). The important thing is that it's roughly 2–3 GB and the download completed.

---

## Part 2: Create the VM in Parallels

### Step 3: Launch Parallels Desktop

Open Parallels Desktop. If you haven't already, install it from [parallels.com](https://www.parallels.com/) — the free trial works.

### Step 4: Create a new virtual machine

1. Click **File → New** (or the `+` button in the Control Center)
2. Select **Install Windows or another OS from a DVD or image file**
3. Click **Continue**
4. Click **Choose Manually** and locate the Ubuntu Server ISO you downloaded
5. If Parallels offers **Express Installation** or automatic setup, **decline it** — you want to walk through the installer manually to understand each step
6. Check **Customize settings before installation**

### Step 5: Configure VM hardware

In the configuration dialog, set:

| Setting | Value |
|---------|-------|
| Name | `ubuntu-server` |
| CPUs | 2 |
| Memory | 4096 MB (4 GB) |
| Hard Disk | 40 GB |
| Network | Shared Network (default) |

Click **Continue** to start the VM.

### Step 6: Install Ubuntu Server

The VM boots from the ISO and the Subiquity installer launches. Work through each screen:

1. **Language:** Select English
2. **Installer update:** Accept if offered
3. **Keyboard:** Accept detected layout or choose yours
4. **Installation type:** Ubuntu Server (not minimized)
5. **Network:** Verify that an interface is detected and has an IP address via DHCP. **Write down this IP address** — you'll need it for SSH.
6. **Proxy:** Leave blank
7. **Mirror:** Accept the default
8. **Storage:** Accept the default "Use an entire disk" option and the suggested layout
9. **Profile setup:**
   - Your name: `Student`
   - Server name: `ubuntu-vm`
   - Username: `student`
   - Password: choose something memorable — you'll type it frequently
10. **Ubuntu Pro:** Skip
11. **SSH server:** **Check "Install OpenSSH server"** — this is essential
12. **Featured snaps:** Don't select any

**Before you continue, predict:** What does installing the SSH server actually do? What would happen if you skipped this step?

### Step 7: Wait and reboot

Watch the progress. The installer downloads packages and configures the system (5–15 minutes).

When it shows **Installation complete**, select **Reboot Now**.

If the VM boots back into the installer after reboot, shut down the VM, go to **Hardware → CD/DVD**, and disconnect or remove the ISO image. Then start the VM again.

---

## Part 3: First Login and SSH Verification

### Step 8: Log in at the console

After the VM reboots, you'll see:

```
ubuntu-vm login:
```

Type `student` and press Enter. Type your password and press Enter.

**Expected output:**

```
Welcome to Ubuntu 24.04 LTS (GNU/Linux ...)

 * Documentation:  https://help.ubuntu.com
 ...

student@ubuntu-vm:~$
```

You're logged in. The `$` at the end of the prompt confirms you're a regular user (not root).

### Step 9: Find your IP address

```bash
ip addr show
```

Look for a line like:

```
inet 10.211.55.3/24 brd 10.211.55.255 scope global dynamic enp0s5
```

The `10.211.55.3` is your VM's IP address. Your specific number will differ.

A quicker way:

```bash
hostname -I
```

**Expected output:**

```
10.211.55.3
```

**Write this IP down.** You'll use it every time you connect.

### Step 10: Connect via SSH from your Mac

Open a **new Terminal window on your Mac** (not inside the VM) and run:

```bash
ssh student@10.211.55.3
```

Replace `10.211.55.3` with your VM's actual IP.

The first time, SSH asks to verify the host:

```
The authenticity of host '10.211.55.3 (10.211.55.3)' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter. Enter your password.

**Expected result:** You're now at the same `student@ubuntu-vm:~$` prompt, but in your Mac's Terminal — with proper copy-paste, scrollback, and resizing.

### Step 11: Verify the system

Run these commands to confirm everything is working:

```bash
cat /etc/os-release | head -3
```

**Expected output:**

```
PRETTY_NAME="Ubuntu 24.04 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
```

```bash
uname -r
```

**Expected output:** A kernel version string like `6.8.0-xx-generic`

```bash
df -h /
```

**Expected output:** About 40 GB total, most of it available.

```bash
free -h
```

**Expected output:** About 4 GB total memory (the amount you allocated to the VM).

---

## Part 4: Take a Snapshot

### Step 12: Snapshot your clean install

In Parallels, go to **Actions → Manage Snapshots** (or `Cmd+Shift+S`).

Click the `+` button. Name the snapshot:

```
Clean Install - Ubuntu Server 24.04
```

This preserves the current state. If you ever break something beyond repair, you can restore this snapshot and be back to a fresh system in seconds.

---

## Verify Your Work

Run these commands and confirm the output matches your expectations:

```bash
# Verify you're on Ubuntu
grep "Ubuntu" /etc/os-release
```

Expected: Lines containing "Ubuntu"

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

Expected: `ubuntu-vm`

```bash
# Verify network connectivity
ping -c 3 8.8.8.8
```

Expected: Three successful ping replies

```bash
# Verify DNS works
ping -c 3 google.com
```

Expected: Three successful ping replies (confirming DNS resolution works too)

If all of these pass, your Ubuntu Server VM is ready. Move on to Lab 1.2 to set up Rocky Linux.
