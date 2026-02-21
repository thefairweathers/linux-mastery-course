---
title: "Lab 6.1: Package Management"
sidebar:
  order: 1
---


> **Objective:** Install, query, inspect, and remove packages on both Ubuntu and Rocky Linux side-by-side.
>
> **Concepts practiced:** apt, dnf, dpkg, rpm, package queries, dependency resolution
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Overview

Work through each section on **both VMs** — run the Ubuntu commands on your Ubuntu VM and the Rocky commands on your Rocky VM.

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

On Rocky, `dnf makecache` explicitly refreshes the metadata cache. DNF does this automatically when the cache is stale, but it's good practice before a lab session.

---

## Step 2: Search for Packages

**Ubuntu:**

```bash
apt search htop
```

**Rocky:**

```bash
dnf search htop
```

Now search for `tree`:

**Ubuntu:**

```bash
apt search ^tree$
```

**Rocky:**

```bash
dnf search tree
```

On Ubuntu, `apt search` uses regex, so `^tree$` matches only the exact name. Without anchors, you'd match every package mentioning "tree" anywhere.

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

The `-y` flag answers "yes" to confirmation prompts automatically. In production, review the transaction summary first, but for lab work it speeds things up. Notice that both package managers pulled in dependencies beyond just the five packages you requested.

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

## Step 7: List Files and Inspect Package Info

See every file that a package put on your system.

**Ubuntu:** `dpkg -L tree`
**Rocky:** `rpm -ql tree`

Compare the output. The binary (`/usr/bin/tree`) is in the same location on both, but man pages and documentation paths differ.

Now get detailed information about an installed package.

**Ubuntu:** `apt show jq`
**Rocky:** `dnf info jq`

Compare: Which repository did the package come from? What dependencies are listed? How do the version numbers differ?

---

## Step 9: Find What Package Provides a Command

Sometimes you know the command you want but not the package name. Both distros have tools for this.

**Ubuntu:**

```bash
sudo apt install -y apt-file
sudo apt-file update
apt-file search /usr/bin/dig
```

```text
bind9-dnsutils: /usr/bin/dig
```

**Rocky:**

```bash
dnf provides /usr/bin/dig
```

```text
bind-utils-9.16.23-18.el9_4.x86_64 : Utilities for querying DNS name servers
Repo        : appstream
Matched from:
Filename    : /usr/bin/dig
```

Notice the package names differ: `bind9-dnsutils` on Ubuntu vs `bind-utils` on Rocky. This is common.

---

## Step 10: Remove a Package

Remove `htop` from both systems.

**Ubuntu:**

```bash
sudo apt remove -y htop
dpkg -l htop
```

```text
rc  htop  3.3.0-4build1  amd64  interactive processes viewer
```

The `rc` status means **r**emoved but **c**onfig files remain. Purge them:

```bash
sudo apt purge -y htop
dpkg -l htop 2>/dev/null || echo "Package fully removed"
```

**Rocky:**

```bash
sudo dnf remove -y htop
rpm -q htop
```

```text
package htop is not installed
```

---

## Step 11: Dependency Resolution and Cleanup

Remove nginx and observe the dependency chain.

**Ubuntu:**

```bash
sudo apt remove -y nginx
sudo apt autoremove -y
```

APT tells you which dependent packages will also be removed. The `autoremove` cleans up orphaned dependencies.

**Rocky:**

```bash
sudo dnf remove -y nginx
```

DNF removes orphaned dependencies as part of the remove operation by default.

Now reinstall nginx, then clean the package caches:

**Ubuntu:**

```bash
sudo apt install -y nginx
du -sh /var/cache/apt/archives/
sudo apt clean
du -sh /var/cache/apt/archives/
```

**Rocky:**

```bash
sudo dnf install -y nginx
du -sh /var/cache/dnf/
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
- ✓ Recognizing that the same software often has different package names across distros
