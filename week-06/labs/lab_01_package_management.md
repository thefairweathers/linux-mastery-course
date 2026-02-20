# Lab 6.1: Package Management

> **Objective:** Install, query, inspect, and remove packages on both Ubuntu and Rocky Linux side-by-side.
>
> **Concepts practiced:** apt, dnf, dpkg, rpm, package queries, dependency resolution
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Overview

In this lab, you'll perform the same package management tasks on both distributions, comparing the commands and output at each step. Work through each section on **both VMs** — run the Ubuntu commands on your Ubuntu VM and the Rocky commands on your Rocky VM.

---

## Step 1: Update the Package Index

Before installing anything, make sure your package index is current.

**Ubuntu:**

```bash
sudo apt update
```

**Rocky:**

```bash
sudo dnf makecache
```

On Rocky, `dnf makecache` explicitly refreshes the metadata cache. DNF does this automatically when the cache is stale, but it's good practice to do it explicitly before a lab session.

---

## Step 2: Search for Packages

Search for `htop`, an interactive process viewer.

**Ubuntu:**

```bash
apt search htop
```

**Rocky:**

```bash
dnf search htop
```

Now search for `tree`, a tool that displays directory structures:

**Ubuntu:**

```bash
apt search ^tree$
```

**Rocky:**

```bash
dnf search tree
```

On Ubuntu, `apt search` uses regex patterns, so `^tree$` matches only the exact package name. Without the anchors, you'd get every package that mentions "tree" anywhere in its name or description.

---

## Step 3: View Package Details Before Installing

Check what you're about to install.

**Ubuntu:**

```bash
apt show nginx
apt show htop
```

**Rocky:**

```bash
dnf info nginx
dnf info htop
```

Take note of:
- The version that will be installed
- The package size
- The dependencies listed

---

## Step 4: Install Multiple Packages

Install `nginx`, `htop`, `tree`, `curl`, and `jq` on both systems.

**Ubuntu:**

```bash
sudo apt install -y nginx htop tree curl jq
```

**Rocky:**

```bash
sudo dnf install -y nginx htop tree curl jq
```

The `-y` flag answers "yes" to confirmation prompts automatically. In production, you'd want to review the transaction summary first, but for lab work it speeds things up.

Review what was installed. Notice that both package managers pulled in dependencies beyond just the five packages you requested.

---

## Step 5: Verify Installation

Confirm the packages are installed and check their versions.

**Ubuntu:**

```bash
dpkg -l nginx htop tree curl jq
```

```text
||/ Name       Version                 Architecture Description
+++-==========-=======================-============-============================
ii  curl       8.5.0-2ubuntu10.6       amd64        command line tool for ...
ii  htop       3.3.0-4build1           amd64        interactive processes viewer
ii  nginx      1.24.0-2ubuntu7.1       all          small, powerful, scalable...
...
```

The `ii` at the start means the package is **i**nstalled and should be **i**nstalled (desired state matches actual state).

**Rocky:**

```bash
rpm -q nginx htop tree curl jq
```

```text
nginx-1.22.1-4.module+el9.x86_64
htop-3.2.2-2.el9.x86_64
tree-1.8.0-10.el9.x86_64
...
```

---

## Step 6: Query Which Package Owns a File

Find out which package installed a specific file.

**Ubuntu:**

```bash
dpkg -S /usr/sbin/nginx
dpkg -S /usr/bin/curl
```

```text
nginx-core: /usr/sbin/nginx
curl: /usr/bin/curl
```

**Rocky:**

```bash
rpm -qf /usr/sbin/nginx
rpm -qf /usr/bin/curl
```

```text
nginx-core-1.22.1-4.module+el9.x86_64
curl-7.76.1-29.el9_4.x86_64
```

Try a file you didn't install yourself — who provides `/usr/bin/bash`?

**Ubuntu:** `dpkg -S /usr/bin/bash`
**Rocky:** `rpm -qf /usr/bin/bash`

This works for any file on the system — incredibly useful for troubleshooting.

---

## Step 7: List Files Installed by a Package

See every file that a package put on your system.

**Ubuntu:**

```bash
dpkg -L tree
```

**Rocky:**

```bash
rpm -ql tree
```

Compare the output. You'll notice differences in where the man pages and documentation are placed, but the binary itself (`/usr/bin/tree`) is in the same location on both distributions.

Now list the files for `nginx` (the main package):

**Ubuntu:**

```bash
dpkg -L nginx
```

**Rocky:**

```bash
rpm -ql nginx
```

Notice that on Ubuntu, the `nginx` package itself is a metapackage — it contains very few files and depends on `nginx-core` for the actual binary. On Rocky, the structure is similar: `nginx` depends on `nginx-core`.

---

## Step 8: Inspect Package Information for Installed Packages

Get detailed information about an installed package.

**Ubuntu:**

```bash
apt show jq
```

**Rocky:**

```bash
dnf info jq
```

Compare:
- Where does each distro say the package came from (which repository)?
- What are the listed dependencies?
- How do the version numbers differ?

---

## Step 9: Find What Package Provides a Command

Sometimes you know the command you want but not the package name. Both distros have tools for this.

**Ubuntu:**

The `apt-file` tool needs to be installed first:

```bash
sudo apt install -y apt-file
sudo apt-file update
```

Now search for which package provides a file:

```bash
apt-file search /usr/bin/dig
```

```text
bind9-dnsutils: /usr/bin/dig
```

**Rocky:**

DNF has this built in with the `provides` subcommand:

```bash
dnf provides /usr/bin/dig
```

```text
bind-utils-9.16.23-18.el9_4.x86_64 : Utilities for querying DNS name servers
Repo        : appstream
Matched from:
Filename    : /usr/bin/dig
```

Notice the package names differ: `bind9-dnsutils` on Ubuntu, `bind-utils` on Rocky. This is common — the same software is often packaged under different names.

---

## Step 10: Remove a Package

Remove `htop` from both systems.

**Ubuntu:**

```bash
sudo apt remove -y htop
```

Verify it's gone:

```bash
which htop
```

```text
(no output — the command is gone)
```

Check if configuration files remain:

```bash
dpkg -l htop
```

```text
rc  htop  3.3.0-4build1  amd64  interactive processes viewer
```

The `rc` status means **r**emoved but **c**onfig files remain. Now purge those config files:

```bash
sudo apt purge -y htop
dpkg -l htop 2>/dev/null || echo "Package fully removed"
```

**Rocky:**

```bash
sudo dnf remove -y htop
```

Verify:

```bash
which htop
```

```text
/usr/bin/which: no htop in (/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin)
```

```bash
rpm -q htop
```

```text
package htop is not installed
```

---

## Step 11: Examine Dependency Resolution

Let's see what happens when you remove a package that others depend on.

**Ubuntu:**

```bash
sudo apt remove -y nginx
```

Watch the output. APT will tell you which other packages will also be removed (packages that depended on nginx). Then run:

```bash
sudo apt autoremove -y
```

This cleans up any orphaned dependencies that were pulled in with nginx but are no longer needed by anything.

**Rocky:**

```bash
sudo dnf remove -y nginx
```

DNF also shows you the dependency chain that will be removed. Unlike APT, DNF removes orphaned dependencies as part of the remove operation by default.

---

## Step 12: Reinstall and Clean Up

Reinstall nginx to leave both systems in a known state:

**Ubuntu:**

```bash
sudo apt install -y nginx
```

**Rocky:**

```bash
sudo dnf install -y nginx
```

Check the package cache size on both systems.

**Ubuntu:**

```bash
du -sh /var/cache/apt/archives/
```

**Rocky:**

```bash
du -sh /var/cache/dnf/
```

Clean the caches:

**Ubuntu:**

```bash
sudo apt clean
du -sh /var/cache/apt/archives/
```

**Rocky:**

```bash
sudo dnf clean all
du -sh /var/cache/dnf/
```

Note how much space was recovered.

---

## Summary Comparison

| Task | Ubuntu Command | Rocky Command |
|------|---------------|---------------|
| Update index | `sudo apt update` | `sudo dnf makecache` |
| Search | `apt search <name>` | `dnf search <name>` |
| Show details | `apt show <name>` | `dnf info <name>` |
| Install | `sudo apt install -y <names>` | `sudo dnf install -y <names>` |
| Verify installed | `dpkg -l <name>` | `rpm -q <name>` |
| File ownership | `dpkg -S /path` | `rpm -qf /path` |
| List files | `dpkg -L <name>` | `rpm -ql <name>` |
| Find provider | `apt-file search /path` | `dnf provides /path` |
| Remove | `sudo apt remove <name>` | `sudo dnf remove <name>` |
| Purge | `sudo apt purge <name>` | _(no equivalent)_ |
| Clean orphans | `sudo apt autoremove` | _(included in remove)_ |
| Clean cache | `sudo apt clean` | `sudo dnf clean all` |

---

## What You Learned

After completing this lab, you have hands-on experience with:

- ✓ Installing and removing packages on both distributions
- ✓ Querying the package database to find installed packages
- ✓ Determining which package provides a specific file
- ✓ Listing files that belong to a package
- ✓ Understanding the difference between `remove` and `purge` on Ubuntu
- ✓ Cleaning the package cache to reclaim disk space
- ✓ Recognizing that the same software often has different package names across distributions
