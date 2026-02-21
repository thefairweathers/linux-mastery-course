---
title: "Week 6: Package Management & Software Installation"
sidebar:
  order: 0
---


> **Goal:** Install, update, remove, and manage software using apt (Ubuntu) and dnf (Rocky Linux), and understand repository management.


---

## Table of Contents

| Section | Topic |
|---------|-------|
| 6.1 | [What Package Managers Do](#61-what-package-managers-do) |
| 6.2 | [Repositories and Trust](#62-repositories-and-trust) |
| 6.3 | [Ubuntu/Debian: apt](#63-ubuntudebian-apt) |
| 6.4 | [Rocky/RHEL: dnf](#64-rockyrhel-dnf) |
| 6.5 | [Side-by-Side: apt vs dnf](#65-side-by-side-apt-vs-dnf) |
| 6.6 | [Repository Management](#66-repository-management) |
| 6.7 | [Package Files: .deb vs .rpm](#67-package-files-deb-vs-rpm) |
| 6.8 | [Package Cache and Cleanup](#68-package-cache-and-cleanup) |
| 6.9 | [Security Updates](#69-security-updates) |
| 6.10 | [Module Streams (Rocky/RHEL)](#610-module-streams-rockyrhel) |
| 6.11 | [Compiling from Source](#611-compiling-from-source) |
| 6.12 | [Installing Development Tools](#612-installing-development-tools) |

---

## 6.1 What Package Managers Do

Back in Week 1, we talked about Linux distributions and how they differ. One of the biggest differences is the **package manager** — the tool that handles installing, updating, and removing software. Understanding it is fundamental to administering any Linux system.

A package manager does three critical things:

### Dependency Resolution

Software rarely stands alone. A web server needs cryptography libraries. A text editor needs a terminal toolkit. A **dependency** is a piece of software that another piece of software requires to function.

When you ask the package manager to install `nginx`, it figures out every library and tool that nginx needs, checks what you already have, and installs only what's missing — in the right order.

Without a package manager, you'd be chasing down dependencies by hand, compiling each one, and hoping the versions are compatible. Anyone who's done that understands why package managers exist.

### Version Management

The package manager tracks exactly which version of every package is installed. When you run an update, it knows what you have, what's available, and how to get from one to the other. It handles version conflicts — if package A needs library version 2.x but package B needs version 3.x, the package manager will tell you before breaking anything.

### Security Verification

Every package in a repository is **cryptographically signed**. When your system downloads a package, the package manager verifies the signature against a trusted key before installing anything. This means:

- You know the package came from who it claims to come from
- You know the package hasn't been tampered with in transit
- You know the package hasn't been corrupted during download

If the signature doesn't match, the installation stops. This is your first line of defense against supply chain attacks.

---

## 6.2 Repositories and Trust

A **repository** (or "repo") is a server that hosts packages for your distribution. Think of it as an app store, but one where everything is free, curated by your distribution's maintainers, and verified with cryptographic signatures.

### How Repositories Work

Your system has a list of repositories it trusts. When you ask to install software, the package manager:

1. Downloads the latest index of available packages from each repository
2. Finds the package you requested (and its dependencies)
3. Downloads the packages
4. Verifies their signatures
5. Installs them

### GPG Keys and Trust

**GPG (GNU Privacy Guard) keys** are how repositories prove their identity. The trust model works like this:

1. The repository maintainer creates a GPG key pair (public and private)
2. They sign every package with their private key
3. Your system stores their public key
4. When you download a package, the package manager uses the public key to verify the signature

When you add a new repository, you must also add its GPG key. If you skip this step (or disable signature checking), you're blindly trusting that whatever you download is legitimate.

### Official vs Third-Party Repositories

**Official repositories** are maintained by your distribution's team. They're enabled by default and their GPG keys ship with the OS. Packages here are tested for compatibility with your specific distribution version.

**Third-party repositories** are maintained by outside organizations or individuals. Examples include:

- Docker's official repository (maintained by Docker, Inc.)
- PPAs on Ubuntu (maintained by individuals or teams)
- EPEL on Rocky (maintained by the Fedora community)

Third-party repos are necessary — not everything is in the official repos — but they carry more risk. The maintainer could abandon the repo, push a bad update, or have their signing key compromised. Only add third-party repos from sources you trust.

---

## 6.3 Ubuntu/Debian: apt

Ubuntu and Debian use the **APT (Advanced Package Tool)** system. The command-line tool is `apt`, which replaced the older `apt-get` and `apt-cache` commands (those still work, but `apt` is cleaner for interactive use).

### Updating the Package Index

Before installing anything, update the local package index. This downloads the latest list of available packages from all configured repositories:

```bash
sudo apt update
```

```text
Hit:1 http://us.archive.ubuntu.com/ubuntu noble InRelease
Get:2 http://us.archive.ubuntu.com/ubuntu noble-updates InRelease [126 kB]
Get:3 http://security.ubuntu.com/ubuntu noble-security InRelease [126 kB]
...
Reading package lists... Done
Building dependency tree... Done
42 packages can be upgraded. Run 'apt list --upgradable' to see them.
```

This does not install or upgrade anything — it only refreshes the index. Always run this before installing packages to ensure you're getting the latest versions.

### Searching for Packages

Find packages by name or description:

```bash
apt search nginx
```

```text
nginx/noble-updates 1.24.0-2ubuntu7.1 amd64
  small, powerful, scalable web/proxy server
...
```

### Viewing Package Details

Get detailed information about a package before installing:

```bash
apt show nginx
```

```text
Package: nginx
Version: 1.24.0-2ubuntu7.1
Installed-Size: 1,614 kB
Depends: nginx-common (= 1.24.0-2ubuntu7.1), libnginx-mod-http-geoip2, ...
Description: small, powerful, scalable web/proxy server
...
```

This shows the version, size, dependencies, and description — everything you need before installing.

### Installing Packages

```bash
sudo apt install nginx
```

APT shows you exactly what it plans to install, including dependencies, and asks for confirmation:

```text
The following NEW packages will be installed:
  libnginx-mod-http-geoip2 libnginx-mod-http-image-filter ... nginx nginx-common
0 upgraded, 8 newly installed, 0 to remove and 42 not upgraded.
Need to get 1,042 kB of archives.
Do you want to continue? [Y/n]
```

Install multiple packages at once:

```bash
sudo apt install nginx htop tree curl jq
```

### Removing Packages

Remove a package but keep its configuration files:

```bash
sudo apt remove nginx
```

Remove a package and its configuration files (**purge**):

```bash
sudo apt purge nginx
```

The difference matters. If you `remove` nginx and reinstall it later, your old configuration files are still there. If you `purge`, you start clean. Use `purge` when you want a complete removal.

### Listing Installed Packages

```bash
apt list --installed
```

This produces a long list. Filter it with `grep`:

```bash
apt list --installed 2>/dev/null | grep nginx
```

The `2>/dev/null` suppresses a warning about the output not being stable for scripting — as we learned in Week 4 with I/O redirection, `2>` redirects stderr.

### Upgrading Packages

Upgrade all installed packages to their latest available versions:

```bash
sudo apt upgrade
```

This upgrades packages but will never remove an installed package or install a new one to satisfy dependencies. For a more complete upgrade that handles dependency changes:

```bash
sudo apt full-upgrade
```

Use `full-upgrade` for major distribution upgrades. For routine updates, `upgrade` is the safer choice.

### Listing Upgradable Packages

See what would be upgraded before committing:

```bash
apt list --upgradable
```

---

## 6.4 Rocky/RHEL: dnf

Rocky Linux and the RHEL family use **DNF (Dandified YUM)**, the successor to the older `yum` command. On Rocky Linux 9, `yum` is a symlink to `dnf` — they're the same tool.

### Searching for Packages

```bash
dnf search nginx
```

```text
======================== Name Exactly Matched: nginx ===========================
nginx.x86_64 : A high performance web server and reverse proxy server
======================== Name & Summary Matched: nginx =========================
nginx-all-modules.noarch : A meta package that installs all available Nginx modules
...
```

### Viewing Package Details

```bash
dnf info nginx
```

```text
Available Packages
Name         : nginx
Version      : 1.22.1
Release      : 4.module+el9+123+abcdef
Architecture : x86_64
Size         : 45 k
Repository   : appstream
Summary      : A high performance web server and reverse proxy server
```

### Installing Packages

```bash
sudo dnf install nginx
```

DNF also shows a transaction summary before proceeding:

```text
Dependencies resolved.
================================================================================
 Package            Arch     Version                     Repository   Size
================================================================================
Installing:
 nginx              x86_64   1:1.22.1-4.module+el9       appstream    45 k
Installing dependencies:
 nginx-core         x86_64   1:1.22.1-4.module+el9       appstream   592 k
...
Transaction Summary
================================================================================
Install  6 Packages
Is this ok [y/N]:
```

Note the default is `N` (no) on DNF, whereas APT defaults to `Y` (yes). DNF is more conservative.

Install multiple packages:

```bash
sudo dnf install nginx htop tree curl jq
```

### Removing Packages

```bash
sudo dnf remove nginx
```

DNF does not have a separate `purge` command. When you remove a package, configuration files marked as such are left behind with a `.rpmsave` extension. This is similar to `apt remove` (not `apt purge`).

### Listing Installed Packages

```bash
dnf list installed
```

Filter with `grep`:

```bash
dnf list installed | grep nginx
```

### Updating Packages

Update all packages:

```bash
sudo dnf update
```

Unlike APT, there's no distinction between `update` and `upgrade` — `dnf upgrade` is an alias for `dnf update`. Both do the same thing and will handle dependency changes.

Check what updates are available without installing them:

```bash
dnf check-update
```

### Group Packages

DNF has a concept of **package groups** — curated collections of packages for a specific purpose. List available groups:

```bash
dnf group list
```

```text
Available Environment Groups:
   Server with GUI
   Server
   Minimal Install
   ...
Available Groups:
   Development Tools
   Network Servers
   Security Tools
   System Tools
```

See what's in a group:

```bash
dnf group info "Development Tools"
```

Install an entire group:

```bash
sudo dnf group install "Development Tools"
```

---

## 6.5 Side-by-Side: apt vs dnf

This is your reference table. Bookmark it.

| Operation | Ubuntu (apt) | Rocky (dnf) |
|-----------|-------------|-------------|
| Update package index | `sudo apt update` | _(automatic with most dnf commands)_ |
| Search for a package | `apt search <name>` | `dnf search <name>` |
| Show package details | `apt show <name>` | `dnf info <name>` |
| Install a package | `sudo apt install <name>` | `sudo dnf install <name>` |
| Remove a package | `sudo apt remove <name>` | `sudo dnf remove <name>` |
| Remove + config files | `sudo apt purge <name>` | _(no direct equivalent)_ |
| List installed packages | `apt list --installed` | `dnf list installed` |
| Check for updates | `apt list --upgradable` | `dnf check-update` |
| Upgrade all packages | `sudo apt upgrade` | `sudo dnf update` |
| Full upgrade (dep changes) | `sudo apt full-upgrade` | `sudo dnf update` _(same)_ |
| Find which package owns a file | `dpkg -S /path/to/file` | `rpm -qf /path/to/file` |
| List files in a package | `dpkg -L <name>` | `rpm -ql <name>` |
| Find package providing a file | `apt-file search /path` | `dnf provides /path` |
| Install a local package file | `sudo dpkg -i file.deb` | `sudo dnf install file.rpm` |
| Reinstall a package | `sudo apt reinstall <name>` | `sudo dnf reinstall <name>` |
| Show package dependencies | `apt depends <name>` | `dnf deplist <name>` |
| Show reverse dependencies | `apt rdepends <name>` | `dnf repoquery --whatrequires <name>` |
| Clean package cache | `sudo apt clean` | `sudo dnf clean all` |
| Remove unneeded deps | `sudo apt autoremove` | `sudo dnf autoremove` |
| Install package group | _(no equivalent)_ | `sudo dnf group install "<name>"` |
| List package groups | _(no equivalent)_ | `dnf group list` |

One key workflow difference: APT requires you to run `apt update` to refresh the package index before installing or upgrading. DNF refreshes its metadata automatically when it's stale (by default, metadata expires after 48 hours). You can force a refresh with `dnf makecache`.

---

## 6.6 Repository Management

### Ubuntu: Adding PPAs and Third-Party Repos

A **PPA (Personal Package Archive)** is a repository hosted on Launchpad, Ubuntu's development platform. PPAs are the most common way to get newer versions of software on Ubuntu.

Add a PPA:

```bash
sudo add-apt-repository ppa:ondrej/nginx
sudo apt update
```

The `add-apt-repository` command does two things: adds the repository source and imports the GPG key. After adding the repo, always run `apt update` to fetch the new package index.

Remove a PPA:

```bash
sudo add-apt-repository --remove ppa:ondrej/nginx
sudo apt update
```

For non-PPA third-party repositories (like Docker, Node.js, or PostgreSQL), the process involves manually adding the GPG key and repository source. We'll walk through this in detail in Lab 6.2.

List all configured repositories:

```bash
apt-cache policy
```

Or look at the source files directly:

```bash
ls /etc/apt/sources.list.d/
```

Remember from Week 3 where we explored the filesystem hierarchy — `/etc` is where system configuration lives. Repository definitions are no exception.

### Rocky: Enabling EPEL and CRB

**EPEL (Extra Packages for Enterprise Linux)** is a repository maintained by the Fedora community that provides high-quality additional packages for RHEL-based distributions. It's the single most important third-party repository for Rocky Linux.

Enable EPEL:

```bash
sudo dnf install epel-release
```

That's it. The `epel-release` package contains the repository configuration and GPG key. This is the cleanest way to add a repository — the repo configuration is itself a package.

Many EPEL packages depend on the **CRB (CodeReady Builder)** repository, which provides development headers and libraries. Enable it:

```bash
sudo dnf config-manager --set-enabled crb
```

Verify EPEL is configured:

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

Notice how EPEL adds over 22,000 additional packages. That's a massive expansion of available software.

For non-EPEL third-party repos on Rocky, you typically create a `.repo` file in `/etc/yum.repos.d/` and import the GPG key. We'll do exactly this in Lab 6.2.

List all configured repositories:

```bash
dnf repolist all
```

This shows both enabled and disabled repositories, which is useful for troubleshooting.

---

## 6.7 Package Files: .deb vs .rpm

Every package your system installs started as a file: `.deb` on Ubuntu/Debian, `.rpm` on Rocky/RHEL. Understanding these files lets you inspect packages before installing them and troubleshoot installation issues.

### .deb Files (Ubuntu/Debian)

The tool for working with `.deb` files directly is `dpkg` — the **Debian Package** manager. While `apt` handles repositories, dependencies, and downloads, `dpkg` handles the actual installation of individual package files.

Download a package without installing it:

```bash
apt download nginx
```

This puts the `.deb` file in your current directory.

Inspect the package contents:

```bash
dpkg -I nginx_1.24.0-2ubuntu7.1_amd64.deb
```

```text
 new Debian package, version 2.0.
 Package: nginx
 Version: 1.24.0-2ubuntu7.1
 Architecture: amd64
 Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
 Depends: nginx-common (= 1.24.0-2ubuntu7.1), ...
 Description: small, powerful, scalable web/proxy server
```

List the files a `.deb` would install:

```bash
dpkg -c nginx_1.24.0-2ubuntu7.1_amd64.deb
```

For already-installed packages, find which package owns a file:

```bash
dpkg -S /usr/sbin/nginx
```

```text
nginx-core: /usr/sbin/nginx
```

List all files installed by a package:

```bash
dpkg -L nginx-core
```

### .rpm Files (Rocky/RHEL)

The tool for `.rpm` files is `rpm` — the **RPM Package Manager** (a recursive acronym).

Download a package without installing it:

```bash
dnf download nginx
```

Query an `.rpm` file for information:

```bash
rpm -qip nginx-1.22.1-4.module+el9.x86_64.rpm
```

The flags: `-q` query, `-i` info, `-p` package file (rather than installed database).

List files in an `.rpm` file:

```bash
rpm -qlp nginx-1.22.1-4.module+el9.x86_64.rpm
```

For installed packages, find which package owns a file:

```bash
rpm -qf /usr/sbin/nginx
```

```text
nginx-core-1.22.1-4.module+el9.x86_64
```

List all files installed by a package:

```bash
rpm -ql nginx-core
```

### Quick Reference: dpkg vs rpm

| Operation | dpkg (Ubuntu) | rpm (Rocky) |
|-----------|--------------|-------------|
| Package info (file) | `dpkg -I file.deb` | `rpm -qip file.rpm` |
| List contents (file) | `dpkg -c file.deb` | `rpm -qlp file.rpm` |
| Install local file | `sudo dpkg -i file.deb` | `sudo rpm -ivh file.rpm` |
| Which package owns a file | `dpkg -S /path/to/file` | `rpm -qf /path/to/file` |
| List installed files | `dpkg -L package` | `rpm -ql package` |
| List all installed | `dpkg -l` | `rpm -qa` |
| Verify package integrity | `dpkg -V package` | `rpm -V package` |

One important distinction: if you install a `.deb` file with `dpkg -i` and it has unmet dependencies, `dpkg` will fail. You then run `sudo apt install -f` to resolve them. With DNF, `sudo dnf install file.rpm` handles dependencies automatically because DNF operates at a higher level than `rpm`.

---

## 6.8 Package Cache and Cleanup

Every package your system downloads is cached locally. Over time, this cache grows and can consume significant disk space, especially on servers that get regular updates.

### Ubuntu: Cleaning the Cache

See how large the cache is:

```bash
du -sh /var/cache/apt/archives/
```

Remove cached packages that can no longer be downloaded (old versions):

```bash
sudo apt autoclean
```

Remove the entire package cache:

```bash
sudo apt clean
```

Remove packages that were installed as dependencies but are no longer needed:

```bash
sudo apt autoremove
```

This is common after removing a large package. Its dependencies might still be installed even though nothing else needs them. The package manager calls these **orphaned dependencies**.

A single cleanup command that does everything:

```bash
sudo apt autoremove && sudo apt clean
```

### Rocky: Cleaning the Cache

See how large the cache is:

```bash
du -sh /var/cache/dnf/
```

Remove all cached data (packages, metadata, everything):

```bash
sudo dnf clean all
```

Remove orphaned dependencies:

```bash
sudo dnf autoremove
```

> **A word of caution:** `dnf autoremove` can sometimes be aggressive. On Rocky Linux, it may identify packages as unneeded that you actually want. Always review the list of packages it proposes to remove before confirming. On production servers, many administrators skip `autoremove` entirely and only use `dnf clean all`.

### When to Clean

- **After major upgrades** — old package versions are sitting in the cache
- **On disk-constrained systems** — VMs and containers often have small disks
- **Before creating images or snapshots** — no point including cached `.deb` or `.rpm` files in your golden image

---

## 6.9 Security Updates

Keeping software updated is one of the most important things you do as a system administrator. Unpatched vulnerabilities are the number one way systems get compromised. Period.

### Ubuntu: Security Updates

List packages with available security updates:

```bash
apt list --upgradable 2>/dev/null | grep -i security
```

Install only security updates:

```bash
sudo apt upgrade -y --only-upgrade
```

For a more targeted approach, Ubuntu provides `unattended-upgrades` — a tool that automatically installs security updates:

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

The configuration file lives at `/etc/apt/apt.conf.d/50unattended-upgrades`. The defaults are sensible: security updates are applied automatically, and the system emails root if there are problems. You can also configure automatic reboots for kernel updates:

```text
// Automatically reboot if required
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
```

### Rocky: Security Updates

Check for available updates:

```bash
dnf check-update
```

List only security updates:

```bash
dnf updateinfo list security
```

Install only security updates:

```bash
sudo dnf update --security
```

For automatic updates, Rocky uses `dnf-automatic`:

```bash
sudo dnf install dnf-automatic
```

Configure it:

```bash
sudo vi /etc/dnf/automatic.conf
```

Key settings in that file:

```text
[commands]
# What type of updates to apply:
#   default    = all
#   security   = security only
upgrade_type = security

# Whether to actually apply updates or just download:
apply_updates = yes

[emitters]
# How to notify about updates
emit_via = motd
```

Enable and start the timer:

```bash
sudo systemctl enable --now dnf-automatic.timer
```

Verify it's active:

```bash
systemctl status dnf-automatic.timer
```

### Why Automatic Security Updates Matter

On a personal workstation, you might remember to run updates regularly. On servers — especially ones running 24/7 with no one logged in — automatic security updates are essential. A critical vulnerability can be disclosed and exploited within hours. If your server sits unpatched for days or weeks, it's a target.

The trade-off is that an automatic update could break something. That's why both `unattended-upgrades` and `dnf-automatic` default to security-only updates — these are the most critical and least likely to cause compatibility issues.

---

## 6.10 Module Streams (Rocky/RHEL)

**Module streams** are a feature unique to the RHEL family. They solve a real problem: how do you offer multiple versions of the same software in the same repository?

For example, your repository might offer both Node.js 18 and Node.js 20. On Ubuntu, you'd need separate PPAs. On Rocky, they're available as different streams of the `nodejs` module.

### Listing Available Modules

```bash
dnf module list
```

```text
Rocky Linux 9 - AppStream
Name       Stream    Profiles               Summary
maven      3.8       common [d]             Java project management
nginx      1.22      common [d]             nginx webserver
nginx      1.24      common                 nginx webserver
nodejs     18        common [d], development, ... Node.js runtime
nodejs     20        common, development, ...    Node.js runtime
php        8.1       common [d], devel, minimal  PHP scripting language
php        8.2       common, devel, minimal      PHP scripting language
...
```

The `[d]` marker indicates the default stream — what you get if you just run `dnf install nodejs` without specifying a stream.

### Enabling a Specific Stream

Install the default stream:

```bash
sudo dnf install nodejs
```

Install a specific stream:

```bash
sudo dnf module enable nodejs:20
sudo dnf install nodejs
```

Or in one step:

```bash
sudo dnf module install nodejs:20
```

### Switching Streams

Switching from one stream to another requires resetting the module first:

```bash
sudo dnf module reset nodejs
sudo dnf module enable nodejs:20
sudo dnf distro-sync
```

> **Warning:** Switching streams on a production system can be disruptive. The version change may not be backward-compatible. Always test in a non-production environment first.

### Listing Enabled Modules

```bash
dnf module list --enabled
```

Module streams don't exist on Ubuntu. The closest equivalent is using PPAs or Snap packages to get different versions of the same software. The module system is one area where the RHEL family provides a more structured approach.

---

## 6.11 Compiling from Source

Sometimes the software you need isn't in any repository. Or you need a specific version with specific compile-time options. In those cases, you compile from source.

### When to Compile from Source

- The software isn't packaged for your distribution
- You need a specific version that isn't available
- You need custom compile-time flags (e.g., nginx with a non-standard module)
- You're developing or patching the software yourself

### When NOT to Compile from Source

- A package exists in the official repos (use it)
- A package exists in a trusted third-party repo (use it)
- You want automatic security updates (compiled software doesn't get them)
- You're managing many servers (every server needs the same manual compile)

### The General Process

Most open-source software follows this pattern:

```bash
wget https://example.com/software-1.0.tar.gz
tar xzf software-1.0.tar.gz
cd software-1.0
./configure --prefix=/usr/local
make
sudo make install
```

The `--prefix=/usr/local` flag installs into `/usr/local` rather than `/usr`, keeping manually compiled software separate from package-managed software. Remember from Week 3: `/usr/local` is specifically for locally installed software.

### The Downside

Software you compile from source lives outside the package manager. It:

- Won't receive automatic updates
- Won't be tracked for dependencies
- Won't be cleaned up automatically
- Can conflict with packaged versions

For these reasons, always prefer a package when one exists. Compiling from source is a last resort, not a first choice.

---

## 6.12 Installing Development Tools

Whether you're compiling software from source or building your own projects, you need a compiler and related development tools.

### Ubuntu: build-essential

```bash
sudo apt install build-essential
```

This metapackage installs `gcc`, `g++`, `make`, C library development headers, and Debian package development tools.

Verify the installation:

```bash
gcc --version
make --version
```

If you need additional development libraries (common when compiling from source), they typically have a `-dev` suffix on Ubuntu:

```bash
sudo apt install libssl-dev libcurl4-openssl-dev zlib1g-dev
```

### Rocky: Development Tools Group

```bash
sudo dnf group install "Development Tools"
```

This installs a comprehensive set including `gcc`, `gcc-c++`, `make`, `autoconf`, `automake`, `libtool`, `pkgconfig`, `git`, and `patch`.

Verify:

```bash
gcc --version
make --version
```

On Rocky, development headers use a `-devel` suffix (not `-dev`):

```bash
sudo dnf install openssl-devel libcurl-devel zlib-devel
```

### Quick Reference: Development Packages

| Need | Ubuntu Package | Rocky Package |
|------|---------------|---------------|
| C compiler | `gcc` | `gcc` |
| C++ compiler | `g++` | `gcc-c++` |
| Build tools (bundle) | `build-essential` | `"Development Tools"` group |
| SSL development headers | `libssl-dev` | `openssl-devel` |
| Curl development headers | `libcurl4-openssl-dev` | `libcurl-devel` |
| Compression library | `zlib1g-dev` | `zlib-devel` |
| Python development headers | `python3-dev` | `python3-devel` |
| Development header suffix | `-dev` | `-devel` |

The naming convention difference (`-dev` vs `-devel`) is one of those things you just have to remember. If you're searching for a development package and can't find it, try the other suffix.

---

## Summary

Package management is how you maintain your Linux systems. The tools differ between distributions, but the concepts are universal:

1. **Repositories** host verified, signed packages
2. **Package managers** handle dependencies, downloads, and installation
3. **APT** (Ubuntu) and **DNF** (Rocky) are your primary tools
4. **dpkg** and **rpm** handle individual package files
5. **Security updates** should be applied promptly and ideally automated
6. **Third-party repos** extend your available software but require trust decisions
7. **Compiling from source** is a last resort when no package exists

The side-by-side comparison table in Section 6.5 is your cheat sheet. Refer back to it until the commands are second nature.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 6.1: Package Management](./lab-01-package-management)** — Install, query, and manage packages on both distros side-by-side
- **[Lab 6.2: Repository Setup](./lab-02-repository-setup)** — Add third-party repositories on both distros, install software from them

---

## Checklist

Before moving to Week 7, confirm you can:

- [ ] Search for, install, and remove packages on both Ubuntu (apt) and Rocky (dnf)
- [ ] Query installed packages and find which package provides a specific file
- [ ] Update all packages on both distributions
- [ ] Add a third-party repository with GPG key verification on both distros
- [ ] Enable EPEL on Rocky Linux
- [ ] Inspect a .deb or .rpm package file without installing it
- [ ] Clean the package cache to reclaim disk space
- [ ] Explain why unattended security updates matter on servers
- [ ] Install development tools on both distributions

---

