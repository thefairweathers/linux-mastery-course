# Lab 6.2: Repository Setup

> **Objective:** Add third-party repositories on both distributions, install software from them, and verify GPG key trust.
>
> **Concepts practiced:** Repository management, GPG keys, PPAs, EPEL, third-party repos
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Overview

In this lab, you'll add Docker's official repository to both Ubuntu and Rocky Linux, install Docker from it, and verify the GPG key trust chain. This is a real-world task — Docker is one of the most commonly installed third-party packages on Linux servers.

You'll also enable EPEL on Rocky Linux and explore what it makes available.

---

## Part 1: Enable EPEL on Rocky Linux

Before working with Docker, let's enable EPEL on your Rocky VM. This is a quick win that dramatically expands your available software.

### Step 1: Check Current Repository List

```bash
dnf repolist
```

Note the number of available packages in each repository.

### Step 2: Install EPEL

```bash
sudo dnf install -y epel-release
```

### Step 3: Enable CRB (CodeReady Builder)

Many EPEL packages depend on packages in the CRB repository:

```bash
sudo dnf config-manager --set-enabled crb
```

### Step 4: Verify

```bash
dnf repolist
```

```text
repo id             repo name                                          status
appstream           Rocky Linux 9 - AppStream                          6,509
baseos              Rocky Linux 9 - BaseOS                             1,849
crb                 Rocky Linux 9 - CRB                                1,702
epel                Extra Packages for Enterprise Linux 9 - x86_64    22,143
extras              Rocky Linux 9 - Extras                                14
```

You now have access to over 22,000 additional packages.

### Step 5: Test EPEL

Install something from EPEL that isn't in the base repos:

```bash
dnf info hping3
```

```text
Available Packages
Name         : hping3
...
Repository   : epel
```

Notice the repository field says `epel`. This package isn't available without EPEL enabled.

```bash
sudo dnf install -y hping3
```

### Step 6: Examine the EPEL GPG Key

```bash
rpm -qa gpg-pubkey*
```

The EPEL key was imported automatically when you installed `epel-release`. This is the mechanism that establishes trust — your system now trusts packages signed by the EPEL maintainers.

---

## Part 2: Add Docker's Official Repository (Ubuntu)

Docker provides their own repository because the version in Ubuntu's default repos is often outdated. This process is representative of how most vendors distribute packages for Debian-based systems.

### Step 1: Remove Old Docker Packages (if any)

```bash
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null
```

### Step 2: Install Prerequisites

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
```

### Step 3: Add Docker's GPG Key

```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

This creates the keyrings directory, downloads Docker's GPG key (converting it to binary format with `gpg --dearmor`), and makes it readable by all users.

### Step 4: Add the Docker Repository

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

This creates a `.list` file with the repository definition. The `signed-by=` directive tells APT which GPG key to use, and the subshells automatically insert your architecture and Ubuntu version codename.

### Step 5: Verify the Repository File

```bash
cat /etc/apt/sources.list.d/docker.list
```

```text
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable
```

### Step 6: Update and Install Docker

```bash
sudo apt update
```

Watch the output. You should see a new line for the Docker repository:

```text
Get:4 https://download.docker.com/linux/ubuntu noble InRelease [48.8 kB]
Get:5 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages [28.4 kB]
```

Now install Docker:

```bash
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Step 7: Verify Docker Installation

```bash
docker --version
```

```text
Docker version 27.x.x, build xxxxxxx
```

Check which repository the package came from:

```bash
apt-cache policy docker-ce
```

```text
docker-ce:
  Installed: 5:27.x.x-1~ubuntu.24.04~noble
  Candidate: 5:27.x.x-1~ubuntu.24.04~noble
  Version table:
 *** 5:27.x.x-1~ubuntu.24.04~noble 500
        500 https://download.docker.com/linux/ubuntu noble/stable amd64 Packages
```

This confirms the package came from Docker's repository, not Ubuntu's default repos.

---

## Part 3: Add Docker's Official Repository (Rocky)

Now perform the same task on your Rocky VM. The process is different but the concept is identical: add a GPG key, configure the repository, install the software.

### Step 1: Remove Old Docker Packages (if any)

```bash
sudo dnf remove -y docker docker-client docker-client-latest docker-common \
  docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null
```

### Step 2: Install Prerequisites

```bash
sudo dnf install -y dnf-plugins-core
```

The `dnf-plugins-core` package provides the `config-manager` plugin, which makes adding repos easier.

### Step 3: Add Docker's Repository

```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
```

That single command does everything: downloads the `.repo` file (which contains the repository URL and GPG key location) and places it in `/etc/yum.repos.d/`.

### Step 4: Examine the Repository File

```bash
cat /etc/yum.repos.d/docker-ce.repo
```

```text
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/rhel/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/rhel/gpg
...
```

Key fields:
- `gpgcheck=1` — signature verification is enabled
- `gpgkey=` — the URL of the GPG key to use for verification
- `enabled=1` — this repo is active

### Step 5: Install Docker

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

The first time you install from a new repo, DNF prompts to import the GPG key. Since we used `-y`, it's accepted automatically. In production, verify the fingerprint matches Docker's published key before accepting.

### Step 6: Verify Docker Installation

```bash
docker --version
```

Check which repository provided the package:

```bash
dnf info docker-ce
```

The `Repository` field should show `docker-ce-stable`.

### Step 7: View Imported GPG Keys

```bash
rpm -qa gpg-pubkey* --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n'
```

This shows the key ID and summary for each imported key, making it easy to identify Docker's.

---

## Part 4: Verify GPG Trust

Confirm the trust chain is working on both systems.

**Ubuntu:**

```bash
gpg --show-keys /etc/apt/keyrings/docker.gpg
```

The `signed-by` directive in the repo definition ensures APT only trusts packages signed by this specific key.

**Rocky:**

Verify that installed files haven't been modified since installation:

```bash
rpm -Va docker-ce
```

No output means all files are exactly as they were when installed.

---

## Part 5: Compare the Process

| Step | Ubuntu | Rocky |
|------|--------|-------|
| Add GPG key | Download, dearmor, save to `/etc/apt/keyrings/` | Automatic from `.repo` file `gpgkey=` URL |
| Add repository | Write `.list` file to `/etc/apt/sources.list.d/` | `dnf config-manager --add-repo <url>` |
| Refresh index | `sudo apt update` | _(automatic on next install)_ |
| Key location | `/etc/apt/keyrings/docker.gpg` | Imported into RPM database |
| Repo config | `/etc/apt/sources.list.d/docker.list` | `/etc/yum.repos.d/docker-ce.repo` |

Rocky's process is simpler because the `.repo` file bundles everything. Ubuntu requires more manual steps but gives finer-grained control over key-to-repo binding.

---

## Cleanup (Optional)

If you want to remove Docker and the third-party repos after completing the lab:

**Ubuntu:**

```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.gpg
sudo apt update
```

**Rocky:**

```bash
sudo dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo rm /etc/yum.repos.d/docker-ce.repo
sudo dnf clean all
```

---

## What You Learned

After completing this lab, you have hands-on experience with:

- ✓ Enabling EPEL and CRB on Rocky Linux
- ✓ Adding a third-party repository with GPG key verification on Ubuntu
- ✓ Adding a third-party repository on Rocky Linux
- ✓ Understanding the trust model: GPG keys prove package authenticity
- ✓ Verifying which repository a package came from
- ✓ Recognizing the structural differences between APT and DNF repo management
- ✓ Installing production software (Docker) from official vendor repositories
