# Week 5: Users, Groups & Permissions

> **Goal:** Manage users and groups, understand and modify file permissions, and configure sudo access for service accounts.

[← Previous Week](../week-04/README.md) · [Next Week →](../week-06/README.md)

---

## 5.1 Why Permissions Matter

A Linux server is rarely a single-user affair. Even a modest web server might have:

- **root** — the all-powerful superuser
- **nginx** or **www-data** — the service account running your web server
- **postgres** — the service account running your database
- Two or three human admins who SSH in to deploy code and investigate problems

Without a permission model, any process could read the database password file, any user could overwrite the web server config, and a compromised service could reach anything on the system. Linux solves this with a straightforward but powerful model: every file and every process has an **owner**, a **group**, and a set of **permission bits** that control who can read, write, and execute.

This week you will learn to manage the users and groups that form one side of this equation, and then the permissions that form the other.

---

## 5.2 Users and UIDs

Every user on a Linux system is really just a number — a **User ID (UID)**. The mapping between names and numbers lives in `/etc/passwd`.

### Dissecting /etc/passwd

```bash
cat /etc/passwd | head -5
```

```text
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
```

Each line has seven colon-separated fields:

| Field | Example (root) | Meaning |
|-------|----------------|---------|
| 1 — Username | `root` | Human-readable login name |
| 2 — Password placeholder | `x` | An `x` means the real hash is in `/etc/shadow` |
| 3 — UID | `0` | Numeric user ID. 0 is always root |
| 4 — GID | `0` | Primary group ID |
| 5 — GECOS / Comment | `root` | Full name or description |
| 6 — Home directory | `/root` | Where the user lands on login |
| 7 — Login shell | `/bin/bash` | Program run at login |

### System Users vs Regular Users

Linux reserves a range of UIDs for system (service) accounts and another for human users:

| | Ubuntu | Rocky Linux |
|---|--------|-------------|
| Root | UID 0 | UID 0 |
| System accounts | UIDs 1–999 | UIDs 1–999 |
| Regular users | UIDs 1000+ | UIDs 1000+ |

You can confirm your own UID range defaults:

```bash
grep -E '^(UID_MIN|UID_MAX)' /etc/login.defs
```

```text
UID_MIN                  1000
UID_MAX                 60000
```

The key takeaway: when you create a service account for nginx or postgres, it gets a low UID automatically. When you create a human user, it gets a UID of 1000 or higher.

---

## 5.3 Passwords and the Shadow File

In the early days of Unix, password hashes were stored directly in `/etc/passwd`. The problem: `/etc/passwd` must be world-readable (programs need it to map UIDs to names), so anyone on the system could grab the hashes and crack them offline.

The solution is `/etc/shadow`, which is readable only by root.

```bash
sudo cat /etc/shadow | head -3
```

```text
root:$6$rounds=5000$salt...$hash...:19500:0:99999:7:::
daemon:*:19400:0:99999:7:::
bin:*:19400:0:99999:7:::
```

The important fields:

| Field | Meaning |
|-------|---------|
| 1 — Username | Matches the `/etc/passwd` entry |
| 2 — Password hash | `$6$...` = SHA-512. `*` or `!` = locked/no password |
| 3 — Last changed | Days since Jan 1, 1970 |
| 4 — Minimum age | Days before password can be changed again |
| 5 — Maximum age | Days until password must be changed |
| 6 — Warning period | Days before expiry to warn the user |
| 7 — Inactive period | Days after expiry before account is disabled |
| 8 — Expiration date | Absolute expiration (days since epoch) |

You rarely edit this file directly. Use `passwd` to change passwords and `chage` to manage aging policies.

```bash
# Check password aging info for a user
sudo chage -l username
```

---

## 5.4 Groups and GIDs

Groups let you grant permissions to multiple users at once. The group database lives in `/etc/group`:

```bash
cat /etc/group | grep -E '^(sudo|wheel|www-data|developers)'
```

Each line has four fields:

| Field | Example | Meaning |
|-------|---------|---------|
| 1 — Group name | `sudo` | Human-readable name |
| 2 — Password | `x` | Rarely used (group passwords are an ancient feature) |
| 3 — GID | `27` | Numeric group ID |
| 4 — Members | `alice,bob` | Comma-separated list of supplementary members |

### Primary vs Supplementary Groups

Every user has exactly one **primary group** (the GID in `/etc/passwd`). When that user creates a file, the file's group is set to their primary group by default.

A user can also belong to any number of **supplementary groups** (listed in `/etc/group`). These grant additional access — for example, membership in the `sudo` group grants the right to use `sudo`.

```bash
# Show primary and supplementary groups for the current user
id
```

```text
uid=1000(alice) gid=1000(alice) groups=1000(alice),27(sudo),1001(developers)
```

In this output, `alice` has:
- Primary group: `alice` (GID 1000)
- Supplementary groups: `sudo` (GID 27) and `developers` (GID 1001)

---

## 5.5 Inspecting Users and Sessions

A handful of commands give you quick answers about who's on the system and what they're doing:

| Command | What it tells you |
|---------|-------------------|
| `whoami` | Your current username |
| `id` | Your UID, primary GID, and all group memberships |
| `id alice` | Same info for a specific user |
| `groups` | Group names for the current user |
| `groups alice` | Group names for a specific user |
| `who` | Users currently logged in, with terminal and login time |
| `w` | Like `who` but adds idle time and current process |
| `last` | Login history from `/var/log/wtmp` |
| `last -n 10` | Last 10 logins |

On a production server, `w` is one of the first things you run when investigating an incident — it tells you who else is logged in right now and what they are running.

```bash
w
```

```text
 14:23:01 up 12 days,  3:41,  2 users,  load average: 0.08, 0.03, 0.01
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
alice    pts/0    10.0.0.50        13:10    0.00s  0.12s  0.01s w
bob      pts/1    10.0.0.51        14:00    3:22   0.05s  0.05s -bash
```

---

## 5.6 Creating and Managing Users

### useradd — Create a New User

The `useradd` command creates a user account. Its behavior differs slightly between distros:

| Flag | Meaning |
|------|---------|
| `-m` | Create the home directory (Ubuntu default, but explicit is safer) |
| `-s /bin/bash` | Set the login shell |
| `-G sudo,developers` | Add to supplementary groups (comma-separated, no spaces) |
| `-c "Alice Smith"` | Set the GECOS/comment field |
| `-u 1500` | Force a specific UID |
| `-d /home/alice` | Set a custom home directory path |
| `-e 2026-12-31` | Set account expiration date |

```bash
# Create a user with home directory, bash shell, and group membership
sudo useradd -m -s /bin/bash -G developers -c "Alice Smith" alice
```

After creating the user, set a password:

```bash
sudo passwd alice
```

A common gotcha: on Rocky Linux, `useradd` without `-m` does **not** create a home directory by default. Always pass `-m` if you want one.

| Behavior | Ubuntu | Rocky Linux |
|----------|--------|-------------|
| `useradd` creates home dir? | Yes (via `CREATE_HOME yes` in login.defs) | No — must pass `-m` |
| Default shell | `/bin/sh` | `/bin/bash` |
| Sudo group name | `sudo` | `wheel` |

### usermod — Modify an Existing User

```bash
# Add alice to the ops group (keep existing supplementary groups with -a)
sudo usermod -aG ops alice

# Change alice's shell
sudo usermod -s /bin/zsh alice

# Lock an account (prefix ! to the password hash in /etc/shadow)
sudo usermod -L alice

# Unlock it
sudo usermod -U alice
```

The `-a` flag in `-aG` is critical. Without it, `-G` **replaces** all supplementary groups rather than appending. This is one of the most common and damaging mistakes in user management.

### userdel — Delete a User

```bash
# Delete the user but keep their home directory
sudo userdel alice

# Delete the user AND their home directory
sudo userdel -r alice
```

On a production system, you often want to keep the home directory for audit purposes. Lock the account with `usermod -L` instead of deleting.

---

## 5.7 Creating and Managing Groups

### groupadd — Create a Group

```bash
sudo groupadd developers
sudo groupadd -g 2000 ops    # with a specific GID
```

### groupmod — Modify a Group

```bash
# Rename a group
sudo groupmod -n engineering developers
```

### gpasswd — Manage Group Membership

While `usermod -aG` works, `gpasswd` provides a group-centric approach:

```bash
# Add alice to developers
sudo gpasswd -a alice developers

# Remove alice from developers
sudo gpasswd -d alice developers
```

### Deleting a Group

```bash
sudo groupdel developers
```

You cannot delete a group if it is any user's primary group. Reassign the user's primary group first.

---

## 5.8 Service Accounts

Services like web servers and databases should never run as root. Instead, they run under dedicated **service accounts** with minimal privileges. A proper service account has:

- No login shell (set to `/usr/sbin/nologin` or `/bin/false`)
- No home directory (or a non-standard one owned by the service)
- No password
- A system-range UID (below 1000)

```bash
# Create a service account for an application called "myapp"
sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp
```

Let's verify:

```bash
grep myapp /etc/passwd
```

```text
myapp:x:998:998::/home/myapp:/usr/sbin/nologin
```

The `--system` flag tells `useradd` to pick a UID in the system range. The `--shell /usr/sbin/nologin` ensures no one can log in as this user — if they try, they get a polite rejection:

```bash
sudo su - myapp
```

```text
This account is currently not available.
```

Common service accounts you will encounter:

| Account | Service | Typical UID |
|---------|---------|-------------|
| `www-data` | Apache/Nginx (Ubuntu) | 33 |
| `nginx` | Nginx (Rocky) | Dynamic (system range) |
| `postgres` | PostgreSQL | Dynamic (system range) |
| `mysql` | MySQL/MariaDB | 27 (Rocky) or dynamic |
| `nobody` | Catch-all unprivileged account | 65534 |

---

## 5.9 File Permissions — The Core Model

Every file and directory on a Linux system has three sets of permissions for three categories of users:

| Category | Abbreviation | Who matches |
|----------|-------------|-------------|
| Owner (user) | `u` | The user who owns the file |
| Group | `g` | Members of the file's group |
| Others | `o` | Everyone else |

Each category can have three permission types:

| Permission | On a file | On a directory |
|-----------|-----------|----------------|
| **Read (r)** | View file contents | List directory contents (`ls`) |
| **Write (w)** | Modify file contents | Create, delete, rename files inside |
| **Execute (x)** | Run as a program | Enter the directory (`cd`) |

That last row surprises people. For directories, execute does not mean "run it" — it means "traverse it." Without execute on a directory, you cannot `cd` into it or access any file inside, even if you know the full path.

```bash
ls -l /etc/hostname
```

```text
-rw-r--r-- 1 root root 11 Jan 15 08:30 /etc/hostname
```

Reading the permission string `-rw-r--r--`:

```text
-   rw-   r--   r--
│    │     │     │
│    │     │     └── Others: read only
│    │     └── Group: read only
│    └── Owner: read + write
└── File type (- = regular file, d = directory, l = symlink)
```

---

## 5.10 Symbolic Permission Notation

The letters `r`, `w`, and `x` form the **symbolic notation**. When you see `rwxr-xr--`, read it in groups of three:

| Position | Characters | Meaning |
|----------|-----------|---------|
| 1–3 | `rwx` | Owner can read, write, execute |
| 4–6 | `r-x` | Group can read and execute (no write) |
| 7–9 | `r--` | Others can read only |

A `-` in any position means that permission is not granted.

Common patterns you will see in practice:

| Symbolic | Meaning | Typical use |
|----------|---------|-------------|
| `rwxr-xr-x` | Owner full, group+others read+execute | Executables, directories |
| `rw-r--r--` | Owner read+write, group+others read | Config files, documents |
| `rw-------` | Owner read+write only | Private keys, passwords |
| `rwxr-x---` | Owner full, group read+execute, others nothing | Shared team directories |
| `rwxrwxrwt` | Everyone full, plus sticky bit | `/tmp` |

---

## 5.11 Numeric (Octal) Permissions

Each permission bit has a numeric value:

| Permission | Value |
|-----------|-------|
| Read (r) | 4 |
| Write (w) | 2 |
| Execute (x) | 1 |
| None (-) | 0 |

You sum the values for each category to get a three-digit **octal** number:

```text
rwx = 4+2+1 = 7
r-x = 4+0+1 = 5
r-- = 4+0+0 = 4

rwxr-xr-- = 754
```

The most common permission sets you will use daily:

| Octal | Symbolic | Typical use |
|-------|----------|-------------|
| `755` | `rwxr-xr-x` | Executables, public directories |
| `644` | `rw-r--r--` | Regular files (configs, documents) |
| `600` | `rw-------` | Private files (SSH keys, secrets) |
| `700` | `rwx------` | Private directories (`~/.ssh`) |
| `750` | `rwxr-x---` | Shared directories (group access only) |
| `640` | `rw-r-----` | Shared config files (group can read) |
| `775` | `rwxrwxr-x` | Shared project directories |
| `664` | `rw-rw-r--` | Shared project files |

Practice converting back and forth until it is second nature. You will read and write these every day.

---

## 5.12 chmod — Changing Permissions

`chmod` changes the permission bits on files and directories. It supports both symbolic and numeric methods.

### Numeric Method

```bash
# Set to exactly 755
chmod 755 script.sh

# Set to exactly 600
chmod 600 ~/.ssh/id_rsa
```

This is the most common approach because it sets all nine bits in one shot, leaving no ambiguity.

### Symbolic Method

The symbolic method uses operators to modify specific bits:

| Operator | Meaning |
|----------|---------|
| `+` | Add permission |
| `-` | Remove permission |
| `=` | Set exactly (remove anything not specified) |

Combined with the category letters (`u` for user/owner, `g` for group, `o` for others, `a` for all):

```bash
# Add execute for the owner
chmod u+x script.sh

# Remove write for group and others
chmod go-w config.txt

# Set group to read+execute only (removes write if it was set)
chmod g=rx shared_dir/

# Add write for group, remove all permissions for others
chmod g+w,o= project_dir/

# Make a script executable for everyone
chmod a+x deploy.sh
```

### Recursive Changes

Use `-R` to apply permissions recursively:

```bash
# Set directory and all contents to 750
chmod -R 750 /opt/myapp/

# Be careful — this sets the same permissions on files AND directories.
# Files usually should NOT have execute. A better pattern:
find /opt/myapp/ -type d -exec chmod 750 {} \;
find /opt/myapp/ -type f -exec chmod 640 {} \;
```

The `find` approach is a common real-world pattern: set directories to one permission and files to another.

---

## 5.13 chown and chgrp — Changing Ownership

### chown — Change Owner (and Optionally Group)

```bash
# Change owner to alice
sudo chown alice file.txt

# Change owner to alice and group to developers
sudo chown alice:developers file.txt

# Change only the group (note the leading colon)
sudo chown :developers file.txt

# Recursive
sudo chown -R alice:developers /opt/myapp/
```

Only root can change file ownership. A regular user cannot give away their files (this prevents users from evading disk quotas).

### chgrp — Change Group Only

```bash
# Change group to developers
sudo chgrp developers file.txt

# Recursive
sudo chgrp -R developers /opt/myapp/
```

A regular user can change the group of their own files, but only to a group they belong to.

---

## 5.14 Special Permissions

Beyond the basic nine bits, Linux has three special permission bits that solve specific real-world problems.

### setuid (Set User ID)

When the **setuid** bit is set on an executable, it runs with the permissions of the file's **owner**, not the user who launched it.

```bash
ls -l /usr/bin/passwd
```

```text
-rwsr-xr-x 1 root root 68208 Mar 14  2025 /usr/bin/passwd
```

Notice the `s` in the owner's execute position. The `passwd` command needs to write to `/etc/shadow`, which is owned by root. Without setuid, regular users could never change their own passwords.

```bash
# Set the setuid bit
chmod u+s program
chmod 4755 program     # The leading 4 means setuid
```

Setuid is powerful and dangerous. A bug in a setuid-root program is a privilege escalation vulnerability. Only a handful of system programs should ever have it.

### setgid (Set Group ID)

On an executable, **setgid** works like setuid but for the group: the process runs with the file's group, not the user's group. But the more common use is on directories.

When setgid is set on a directory, new files and subdirectories created inside inherit the directory's group rather than the creator's primary group. This is essential for shared project directories.

```bash
ls -ld /srv/project/
```

```text
drwxrwsr-x 2 root developers 4096 Feb 10 09:00 /srv/project/
```

The `s` in the group execute position means setgid is active.

```bash
# Set setgid on a directory
chmod g+s /srv/project/
chmod 2775 /srv/project/    # The leading 2 means setgid
```

Without setgid, if Alice (primary group `alice`) creates a file in a shared directory, the file's group would be `alice` — and Bob might not be able to write to it. With setgid, the file's group is automatically `developers`.

### Sticky Bit

The **sticky bit** on a directory prevents users from deleting or renaming files they do not own, even if they have write permission on the directory. The classic example is `/tmp`:

```bash
ls -ld /tmp
```

```text
drwxrwxrwt 15 root root 4096 Feb 20 12:00 /tmp
```

The `t` in the others execute position is the sticky bit. Everyone can write to `/tmp` (creating files), but you can only delete your own files.

```bash
# Set the sticky bit
chmod +t /shared/
chmod 1777 /shared/     # The leading 1 means sticky bit
```

### Special Permissions Summary

| Bit | Octal prefix | Symbolic | On files | On directories |
|-----|-------------|----------|----------|----------------|
| setuid | 4 | `u+s` | Run as file owner | (rarely used) |
| setgid | 2 | `g+s` | Run as file group | New files inherit directory group |
| sticky | 1 | `+t` | (rarely used) | Only file owner can delete |

### Four-Digit Octal Notation

When you see a four-digit octal like `4755`, the first digit encodes the special bits:

```text
4755 = setuid (4) + owner rwx (7) + group r-x (5) + others r-x (5)
2775 = setgid (2) + owner rwx (7) + group rwx (7) + others r-x (5)
1777 = sticky (1) + owner rwx (7) + group rwx (7) + others rwx (7)
```

---

## 5.15 umask — Default Permission Masks

When a process creates a new file or directory, the **umask** controls which permission bits are turned off by default.

```bash
umask
```

```text
0022
```

The math works by subtraction (conceptually — it is actually a bitwise AND with the complement):

| | Base permissions | umask 0022 | Result |
|---|---|---|---|
| New file | 666 (rw-rw-rw-) | 022 | 644 (rw-r--r--) |
| New directory | 777 (rwxrwxrwx) | 022 | 755 (rwxr-xr-x) |

New files start at 666 (not 777) because the kernel does not set execute by default for regular files.

Common umask values:

| umask | File result | Dir result | Use case |
|-------|-------------|------------|----------|
| `0022` | 644 | 755 | System default — others can read |
| `0027` | 640 | 750 | Tighter — others get nothing |
| `0077` | 600 | 700 | Private — only owner has access |
| `0002` | 664 | 775 | Collaborative — group can write |

### Setting umask

```bash
# Set for the current shell session
umask 0027

# Verify
umask
```

To make it permanent, add the `umask` command to the user's `~/.bashrc` or `~/.profile`. System-wide defaults can be set in `/etc/login.defs` or `/etc/profile`.

### Seeing umask in Action

```bash
umask 0022
touch testfile
mkdir testdir
ls -l testfile
ls -ld testdir
```

```text
-rw-r--r-- 1 alice alice    0 Feb 20 14:00 testfile
drwxr-xr-x 2 alice alice 4096 Feb 20 14:00 testdir
```

```bash
umask 0077
touch privatefile
mkdir privatedir
ls -l privatefile
ls -ld privatedir
```

```text
-rw------- 1 alice alice    0 Feb 20 14:00 privatefile
drwx------ 2 alice alice 4096 Feb 20 14:00 privatedir
```

---

## 5.16 sudo and the sudoers File

### How sudo Works

The `sudo` command allows a permitted user to run a command as another user (root by default). It works through a configuration file at `/etc/sudoers`.

When you run `sudo somecommand`:

1. `sudo` checks `/etc/sudoers` (and files in `/etc/sudoers.d/`) to see if you are allowed.
2. If allowed, it prompts for **your** password (not root's), unless configured otherwise.
3. It caches your credential for a short time (usually 15 minutes), so repeated `sudo` calls do not re-prompt.
4. It logs the command to syslog for auditing.

### The sudo Group vs the wheel Group

This is one of the most visible distro differences you will encounter:

| | Ubuntu | Rocky Linux |
|---|--------|-------------|
| Sudo-capable group | `sudo` | `wheel` |
| Default sudoers rule | `%sudo ALL=(ALL:ALL) ALL` | `%wheel ALL=(ALL) ALL` |
| First user has sudo? | Yes (installer adds them) | If selected during install |

To grant a user full sudo access:

```bash
# Ubuntu
sudo usermod -aG sudo alice

# Rocky Linux
sudo usermod -aG wheel alice
```

### Editing /etc/sudoers with visudo

Never edit `/etc/sudoers` directly with a text editor. Use `visudo`, which validates your syntax before saving — a syntax error in sudoers can lock you out of sudo entirely.

```bash
sudo visudo
```

### sudoers Syntax

The general format of a sudoers rule:

```text
who    where=(as_whom)    what

alice  ALL=(ALL:ALL)      ALL
```

Breaking it down:

| Part | Meaning |
|------|---------|
| `alice` | The user (or `%groupname` for a group) |
| `ALL` (first) | On all hosts (relevant for shared sudoers files) |
| `(ALL:ALL)` | Can run as any user and any group |
| `ALL` (last) | Can run any command |

### Granting Specific Commands

Full sudo is often too much. You can restrict a user to specific commands:

```bash
sudo visudo
```

```text
# Allow deploy to restart nginx and nothing else
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx

# Allow developers to view logs but not edit them
%developers ALL=(ALL) NOPASSWD: /usr/bin/journalctl
```

The `NOPASSWD:` prefix skips the password prompt — useful for service accounts and automated deployments.

### Drop-in Files in /etc/sudoers.d/

Rather than editing the main sudoers file, you can create separate files:

```bash
sudo visudo -f /etc/sudoers.d/deploy
```

```text
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx
```

This is cleaner for automation (Ansible, Puppet, etc.) and easier to manage. The main sudoers file includes these via a directive:

```text
@includedir /etc/sudoers.d
```

Make sure the file has the correct permissions:

```bash
sudo chmod 440 /etc/sudoers.d/deploy
```

### Testing sudo Access

```bash
# Check what you can run
sudo -l

# Test a specific command
sudo -l -U deploy
```

```text
User deploy may run the following commands on this host:
    (ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx
```

---

## 5.17 Distro Differences Summary

| Feature | Ubuntu | Rocky Linux |
|---------|--------|-------------|
| Sudo group | `sudo` | `wheel` |
| `useradd` creates home by default? | Yes | No (use `-m`) |
| Default shell for new users | `/bin/sh` | `/bin/bash` |
| Web server user (Apache) | `www-data` | `apache` |
| Web server user (Nginx) | `www-data` | `nginx` |
| Root login via SSH | Disabled by default | Enabled by default (CentOS heritage) |
| Password hashing | SHA-512 (`$6$`) | SHA-512 (`$6$`) |
| User private groups | Yes (each user gets their own group) | Yes |

### User Private Groups

Both Ubuntu and Rocky Linux use the **User Private Group (UPG)** scheme: when you create user `alice`, a group `alice` is also created with the same GID, and it becomes her primary group. This means new files Alice creates are owned by group `alice` rather than a shared group like `users`.

UPG makes it safe to use a umask of `0002` (files are group-writable) because the group is private by default — no one else is in it unless you explicitly add them.

---

## 5.18 Putting It All Together — Real-World Patterns

### Pattern 1: Shared Project Directory

A team of developers needs to collaborate in `/srv/project/`:

```bash
# Create the group
sudo groupadd webteam

# Add users to the group
sudo usermod -aG webteam alice
sudo usermod -aG webteam bob

# Create the directory
sudo mkdir -p /srv/project

# Set ownership and setgid
sudo chown root:webteam /srv/project
sudo chmod 2775 /srv/project
```

Now any file created inside `/srv/project/` automatically belongs to group `webteam`, and all team members can read and write.

### Pattern 2: Service Account for a Web App

```bash
# Create the service account
sudo useradd --system --no-create-home --shell /usr/sbin/nologin myapp

# Create application directories
sudo mkdir -p /opt/myapp/{bin,config,data,logs}

# Set ownership
sudo chown -R myapp:myapp /opt/myapp/

# Restrictive permissions — only the service can access
sudo chmod 750 /opt/myapp/
sudo chmod 700 /opt/myapp/config   # configs are extra sensitive
sudo chmod 750 /opt/myapp/data
sudo chmod 750 /opt/myapp/logs
```

### Pattern 3: Securing SSH Keys

```bash
# Directory must be 700
chmod 700 ~/.ssh

# Private key must be 600
chmod 600 ~/.ssh/id_rsa

# Public key and authorized_keys can be 644
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/authorized_keys
```

SSH is strict about permissions — if your `~/.ssh` directory or private key is too permissive, SSH will refuse to use it.

### Pattern 4: Web Server Document Root

```bash
# Ubuntu (www-data)
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;

# Rocky Linux (nginx)
sudo chown -R nginx:nginx /usr/share/nginx/html
sudo find /usr/share/nginx/html -type d -exec chmod 755 {} \;
sudo find /usr/share/nginx/html -type f -exec chmod 644 {} \;
```

If a deploy user needs to update the web content, add them to the web server's group and use setgid:

```bash
# Ubuntu example
sudo usermod -aG www-data deploy
sudo chown -R www-data:www-data /var/www/html
sudo chmod 2775 /var/www/html
sudo find /var/www/html -type f -exec chmod 664 {} \;
```

---

## Labs

Complete the labs in the [labs/](labs/) directory:

- **[Lab 5.1: User Management](labs/lab_01_user_management.md)** — Create users for different roles, assign groups, configure sudo access on both Ubuntu and Rocky
- **[Lab 5.2: Permission Scenarios](labs/lab_02_permission_scenarios.md)** — Solve real-world permission scenarios including shared directories, service accounts, and web server permissions

---

## Checklist

Before moving to Week 6, confirm you can:

- [ ] Read and interpret every field in /etc/passwd
- [ ] Create users with useradd, set passwords with passwd
- [ ] Create groups and add users to them
- [ ] Create a service account with no login shell and no home directory
- [ ] Read and interpret ls -l permission output in both symbolic and numeric notation
- [ ] Change permissions with chmod using both symbolic and numeric methods
- [ ] Change file ownership with chown and chgrp
- [ ] Explain setuid, setgid, and sticky bit with real-world examples
- [ ] Configure sudo access by editing /etc/sudoers with visudo
- [ ] Explain the difference between the sudo group (Ubuntu) and wheel group (Rocky)
- [ ] Set an appropriate umask for different use cases

---

[← Previous Week](../week-04/README.md) · [Next Week →](../week-06/README.md)
