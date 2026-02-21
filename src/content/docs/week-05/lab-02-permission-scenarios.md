---
title: "Lab 5.2: Permission Scenarios"
sidebar:
  order: 2
---


> **Objective:** Solve real-world permission scenarios: shared project directory, deploy user restrictions, web server document root, and SSH key security.
>
> **Concepts practiced:** chmod, chown, chgrp, setgid, sticky bit, umask, directory permissions
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Ubuntu (exercises work on Rocky with minor path differences)

---

## Prerequisites

This lab builds on the users and groups created in Lab 5.1. If you have not completed it, create the following first:

```bash
sudo groupadd developers
sudo groupadd ops
sudo useradd -m -s /bin/bash -G developers -c "Developer User" devuser
sudo useradd -m -s /bin/bash -G developers -c "Developer Two" devuser2
sudo useradd --system --no-create-home --shell /usr/sbin/nologin deploy
sudo usermod -aG ops deploy
sudo passwd devuser
sudo passwd devuser2
```

---

## Scenario 1: Shared Project Directory

Your development team needs a shared directory at `/srv/project` where all developers can create, edit, and delete files. Files created by any team member must be accessible to the entire team.

### Set Up the Directory

```bash
sudo mkdir -p /srv/project
sudo chown root:developers /srv/project
sudo chmod 2775 /srv/project
```

Breaking down `2775`:
- `2` -- setgid bit: new files inherit the `developers` group
- `7` -- owner (root): read + write + execute
- `7` -- group (developers): read + write + execute
- `5` -- others: read + execute (can browse, cannot modify)

Verify:

```bash
ls -ld /srv/project
```

```text
drwxrwsr-x 2 root developers 4096 Feb 20 10:00 /srv/project
```

Confirm the `s` in the group execute position -- that is the setgid bit.

### Test File Creation

```bash
sudo -u devuser touch /srv/project/app.py
ls -l /srv/project/app.py
```

```text
-rw-rw-r-- 1 devuser developers 0 Feb 20 10:01 /srv/project/app.py
```

The file's group is `developers` (not `devuser`), thanks to setgid. Verify that devuser2 can edit it:

```bash
sudo -u devuser2 sh -c 'echo "# updated by devuser2" >> /srv/project/app.py'
```

Both developers can write to each other's files because the group is `developers` and the group has write permission.

### Add Sticky Bit (Optional Protection)

To prevent developers from deleting each other's files:

```bash
sudo chmod +t /srv/project
ls -ld /srv/project
```

```text
drwxrwsr-t 2 root developers 4096 Feb 20 10:01 /srv/project
```

Test it:

```bash
sudo -u devuser touch /srv/project/devuser_file.txt
sudo -u devuser2 rm /srv/project/devuser_file.txt
```

```text
rm: cannot remove '/srv/project/devuser_file.txt': Operation not permitted
```

---

## Scenario 2: Deploy User with Restricted sudo

The deploy service account needs to restart nginx after deployments but must not read sensitive configuration files.

### Create and Lock Down a Sensitive Config

```bash
sudo mkdir -p /etc/myapp
echo 'DB_PASSWORD=supersecret' | sudo tee /etc/myapp/database.conf > /dev/null
sudo chown root:root /etc/myapp/database.conf
sudo chmod 600 /etc/myapp/database.conf
```

Verify the deploy account cannot read it:

```bash
sudo -u deploy cat /etc/myapp/database.conf
```

```text
cat: /etc/myapp/database.conf: Permission denied
```

### Grant Controlled Service Restart

If not already done in Lab 5.1:

```bash
sudo visudo -f /etc/sudoers.d/deploy
```

```text
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx, /usr/bin/systemctl status nginx
```

```bash
sudo chmod 440 /etc/sudoers.d/deploy
```

### Verify the Boundaries

```bash
# deploy CAN manage nginx
sudo -u deploy sudo /usr/bin/systemctl status nginx

# deploy CANNOT read the config
sudo -u deploy cat /etc/myapp/database.conf
# Permission denied

# deploy CANNOT use sudo for arbitrary commands
sudo -u deploy sudo cat /etc/myapp/database.conf
# Sorry, user deploy is not allowed to execute '/usr/bin/cat ...'
```

The deploy account can do exactly what it needs and nothing more -- this is the principle of least privilege.

---

## Scenario 3: Web Server Document Root

Configure `/var/www/html` so the web server can read all files, a deploy process can update them, and other users cannot modify content.

### Set Ownership and Permissions

On Ubuntu the web server runs as `www-data`. On Rocky it runs as `nginx`.

```bash
sudo mkdir -p /var/www/html

# Ubuntu
sudo chown -R www-data:www-data /var/www/html

# Rocky (if using Rocky instead)
# sudo chown -R nginx:nginx /var/www/html
```

Set directories to `2775` (setgid so new files inherit the group) and files to `664`:

```bash
sudo find /var/www/html -type d -exec chmod 2775 {} \;
sudo find /var/www/html -type f -exec chmod 664 {} \;
```

### Allow Deploy to Update Content

```bash
# Ubuntu
sudo usermod -aG www-data deploy

# Rocky
# sudo usermod -aG nginx deploy
```

### Create Test Content

```bash
echo "<h1>Deployed content</h1>" | sudo tee /var/www/html/index.html > /dev/null
sudo chown www-data:www-data /var/www/html/index.html
sudo chmod 664 /var/www/html/index.html
```

Verify:

```bash
ls -la /var/www/html/
```

```text
total 12
drwxrwsr-x 2 www-data www-data 4096 Feb 20 10:15 .
drwxr-xr-x 3 root     root     4096 Feb 20 10:10 ..
-rw-rw-r-- 1 www-data www-data   26 Feb 20 10:15 index.html
```

For private sites that should not be browsable on the filesystem, tighten to `2750`/`640`:

```bash
sudo find /var/www/html -type d -exec chmod 2750 {} \;
sudo find /var/www/html -type f -exec chmod 640 {} \;
```

---

## Scenario 4: Securing SSH Keys

SSH is strict about file permissions. If your keys are too open, SSH refuses to use them.

### Create the Directory and Key Files

```bash
sudo -u devuser mkdir -p /home/devuser/.ssh
sudo chmod 700 /home/devuser/.ssh
sudo chown devuser:devuser /home/devuser/.ssh

# Simulate key files (in practice, ssh-keygen creates these)
sudo -u devuser touch /home/devuser/.ssh/id_rsa
sudo -u devuser touch /home/devuser/.ssh/id_rsa.pub
sudo -u devuser touch /home/devuser/.ssh/authorized_keys
```

### Set the Required Permissions

```bash
sudo chmod 600 /home/devuser/.ssh/id_rsa           # Private key -- owner only
sudo chmod 644 /home/devuser/.ssh/id_rsa.pub       # Public key -- safe to share
sudo chmod 644 /home/devuser/.ssh/authorized_keys   # Controls who can log in
```

### Verify

```bash
ls -la /home/devuser/.ssh/
```

```text
drwx------ 2 devuser devuser 4096 Feb 20 10:20 .
-rw-r--r-- 1 devuser devuser    0 Feb 20 10:20 authorized_keys
-rw------- 1 devuser devuser    0 Feb 20 10:20 id_rsa
-rw-r--r-- 1 devuser devuser    0 Feb 20 10:20 id_rsa.pub
```

### See What Happens with Wrong Permissions

```bash
sudo chmod 644 /home/devuser/.ssh/id_rsa
```

SSH produces this error when you try to use the key:

```text
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for '/home/devuser/.ssh/id_rsa' are too open.
It is required that your private key files are NOT accessible by others.
This private key will be ignored.
```

Fix it:

```bash
sudo chmod 600 /home/devuser/.ssh/id_rsa
```

### SSH Permission Requirements

| File/Directory | Required | Why |
|----------------|----------|-----|
| `~/.ssh/` | `700` | Only owner can list or enter |
| `~/.ssh/id_rsa` | `600` | Private key -- owner read/write only |
| `~/.ssh/id_rsa.pub` | `644` | Public -- safe to share |
| `~/.ssh/authorized_keys` | `644` or `600` | Controls who can log in |
| `~` (home dir) | Not writable by group/others | SSH checks this too |

---

## Verify Your Work

```bash
# Scenario 1: Shared project directory
ls -ld /srv/project
# drwxrwsr-x (or drwxrwsr-t with sticky bit), group = developers

sudo -u devuser touch /srv/project/verify_test
ls -l /srv/project/verify_test
# Group should be developers (not devuser)
sudo rm /srv/project/verify_test

# Scenario 2: Deploy restrictions
sudo -u deploy cat /etc/myapp/database.conf 2>&1
# Permission denied
sudo -l -U deploy
# Only systemctl commands

# Scenario 3: Web document root
ls -ld /var/www/html
# Should show setgid bit (s in group execute)

# Scenario 4: SSH key permissions
stat -c '%a %n' /home/devuser/.ssh /home/devuser/.ssh/*
# 700  ~/.ssh
# 644  authorized_keys
# 600  id_rsa
# 644  id_rsa.pub
```

---

## Cleanup (Optional)

```bash
sudo rm -rf /srv/project
sudo rm -rf /etc/myapp
sudo rm -rf /var/www/html/index.html
sudo rm -rf /home/devuser/.ssh
```
