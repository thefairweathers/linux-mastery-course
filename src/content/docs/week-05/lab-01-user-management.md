---
title: "Lab 5.1: User Management"
sidebar:
  order: 1
---


> **Objective:** Create users for different roles (admin, developer, deploy service account), assign groups, and configure sudo access with specific permissions.
>
> **Concepts practiced:** useradd, usermod, passwd, groupadd, sudo configuration, /etc/passwd, /etc/group, id command
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Scenario

You are setting up a fresh server that will be managed by a small team. You need to create:

1. An **admin** user (`sysadmin`) who has full sudo access
2. A **developer** user (`devuser`) who can deploy code but has limited sudo
3. A **deploy service account** (`deploy`) that automated tools use — no interactive login, no home directory
4. Two groups: `developers` and `ops`

You will do this on both Ubuntu and Rocky Linux to see the distro differences firsthand.

---

## Part 1: Create Groups

Run these on **both** VMs:

```bash
sudo groupadd developers
sudo groupadd ops
```

Verify the groups exist:

```bash
grep -E '^(developers|ops):' /etc/group
```

Expected output:

```text
developers:x:1001:
ops:x:1002:
```

The GIDs may differ on your system, but both groups should appear with empty member lists.

---

## Part 2: Create the Admin User

### On Ubuntu

```bash
sudo useradd -m -s /bin/bash -G sudo,ops -c "System Administrator" sysadmin
sudo passwd sysadmin
```

### On Rocky Linux

```bash
sudo useradd -m -s /bin/bash -G wheel,ops -c "System Administrator" sysadmin
sudo passwd sysadmin
```

Notice the only difference: `sudo` group on Ubuntu, `wheel` group on Rocky.

Verify the account:

```bash
id sysadmin
```

Expected output (Ubuntu):

```text
uid=1001(sysadmin) gid=1001(sysadmin) groups=1001(sysadmin),27(sudo),1002(ops)
```

Expected output (Rocky):

```text
uid=1001(sysadmin) gid=1001(sysadmin) groups=1001(sysadmin),10(wheel),1002(ops)
```

Confirm the `/etc/passwd` entry and home directory:

```bash
grep sysadmin /etc/passwd
ls -la /home/sysadmin/
```

---

## Part 3: Create the Developer User

Run on **both** VMs:

```bash
sudo useradd -m -s /bin/bash -G developers -c "Developer User" devuser
sudo passwd devuser
```

Verify:

```bash
id devuser
```

```text
uid=1002(devuser) gid=1003(devuser) groups=1003(devuser),1001(developers)
```

---

## Part 4: Create the Deploy Service Account

This account is for automated deployments. It must not have an interactive shell or a home directory.

Run on **both** VMs:

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin deploy
```

Verify it was created correctly:

```bash
grep deploy /etc/passwd
```

```text
deploy:x:998:998::/home/deploy:/usr/sbin/nologin
```

Confirm no home directory was created:

```bash
ls /home/deploy 2>&1
```

```text
ls: cannot access '/home/deploy': No such file or directory
```

Confirm login is blocked:

```bash
sudo su - deploy
```

```text
This account is currently not available.
```

Add the deploy account to the ops group:

```bash
sudo usermod -aG ops deploy
```

---

## Part 5: Configure sudo Access

### Grant devuser Limited sudo

The developer should be able to restart the application service but not have full root access. We will use a drop-in sudoers file.

On **both** VMs:

```bash
sudo visudo -f /etc/sudoers.d/devuser
```

Add this line:

```text
devuser ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp, /usr/bin/systemctl status myapp
```

Save and exit. Set the correct permissions:

```bash
sudo chmod 440 /etc/sudoers.d/devuser
```

### Grant deploy Limited sudo

The deploy service account needs to restart nginx without a password (since it cannot type one):

```bash
sudo visudo -f /etc/sudoers.d/deploy
```

```text
deploy ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx, /usr/bin/systemctl reload nginx, /usr/bin/systemctl status nginx
```

```bash
sudo chmod 440 /etc/sudoers.d/deploy
```

### Verify sudo Access

Check what each user can do:

```bash
sudo -l -U sysadmin   # Should show: (ALL : ALL) ALL
sudo -l -U devuser    # Should show: only systemctl restart/status myapp
sudo -l -U deploy     # Should show: only systemctl restart/reload/status nginx
```

---

## Part 6: Test on Both Distros

Repeat Parts 1 through 5 on whichever VM you have not yet done. Pay attention to these differences:

| Step | Ubuntu | Rocky Linux |
|------|--------|-------------|
| Admin sudo group | `-G sudo,ops` | `-G wheel,ops` |
| `useradd` home dir | Created by default | Requires `-m` |
| Default shell | `/bin/sh` (pass `-s /bin/bash`) | `/bin/bash` |

After completing both VMs, confirm on each:

```bash
# List all three users
grep -E '^(sysadmin|devuser|deploy):' /etc/passwd

# List both groups with members
grep -E '^(developers|ops):' /etc/group
```

---

## Try Breaking It

These exercises teach you what happens when things go wrong. Try each one and observe the result.

### 1. Forget the -a Flag with usermod

```bash
# WARNING: This replaces all supplementary groups with only "developers"
sudo usermod -G developers sysadmin

# Check the damage
id sysadmin
```

The admin just lost their sudo/wheel membership. Fix it:

```bash
# Ubuntu
sudo usermod -aG sudo,ops,developers sysadmin

# Rocky
sudo usermod -aG wheel,ops,developers sysadmin
```

Lesson: always use `-aG` (append to groups), never bare `-G`.

### 2. Create a Bad sudoers File

```bash
# This will catch syntax errors before saving
sudo visudo -f /etc/sudoers.d/broken
```

Type intentionally broken syntax:

```text
this is not valid sudoers syntax
```

When you try to save, `visudo` will warn you:

```text
>>> /etc/sudoers.d/broken: syntax error near line 1 <<<
What now?
```

Choose `e` to re-edit or `x` to discard. This is why you never use a regular editor on sudoers files.

### 3. Try to Log In as the Service Account

```bash
sudo su - deploy
```

```text
This account is currently not available.
```

```bash
ssh deploy@localhost
```

The SSH attempt will also fail because the shell is `/usr/sbin/nologin`. This is exactly what you want for a service account.

---

## Verify Your Work

Run through this checklist on **both** VMs:

```bash
# 1. Three users exist with correct properties
grep sysadmin /etc/passwd   # Should show /bin/bash, home dir
grep devuser /etc/passwd    # Should show /bin/bash, home dir
grep deploy /etc/passwd     # Should show /usr/sbin/nologin, system UID

# 2. Groups have correct members
id sysadmin     # Should include sudo/wheel + ops
id devuser      # Should include developers
id deploy       # Should include ops

# 3. Sudo access is correctly configured
sudo -l -U sysadmin    # ALL commands
sudo -l -U devuser     # Only systemctl restart/status myapp
sudo -l -U deploy      # Only systemctl restart/reload/status nginx

# 4. Service account cannot log in
sudo su - deploy        # Should say "not available"

# 5. sudoers drop-in files have correct permissions
ls -l /etc/sudoers.d/devuser /etc/sudoers.d/deploy
# Should both show -r--r----- (440)
```

If all five checks pass, you have completed this lab.

---

## Cleanup (Optional)

If you want to reset your VMs to their original state:

```bash
sudo userdel -r sysadmin
sudo userdel -r devuser
sudo userdel deploy
sudo groupdel developers
sudo groupdel ops
sudo rm -f /etc/sudoers.d/devuser /etc/sudoers.d/deploy
```
