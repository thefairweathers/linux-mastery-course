---
title: "Lab 9.2: SSH & Firewall Configuration"
sidebar:
  order: 2
---


> **Objective:** Set up SSH key-based authentication between your two VMs, create SSH config entries, and configure firewalls on both distros to allow only SSH and HTTP.
>
> **Concepts practiced:** ssh-keygen, ssh-copy-id, ~/.ssh/config, ufw, firewalld, ss, curl
>
> **Time estimate:** 40 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Part 1: SSH Key-Based Authentication

### Step 1: Generate an SSH Key Pair on Ubuntu

On your **Ubuntu** VM:

```bash
ssh-keygen -t ed25519 -C "lab-key"
```

Accept the default file location. For this lab, skip the passphrase (in production, always set one).

Verify the key pair:

```bash
ls -la ~/.ssh/id_ed25519*
```

You should see `id_ed25519` (private, permissions `600`) and `id_ed25519.pub` (public).

### Step 2: Copy the Public Key to Rocky

```bash
ssh-copy-id <your-user>@<rocky-ip>
```

You'll be prompted for your password on Rocky one last time.

### Step 3: Test Passwordless Login

```bash
ssh <your-user>@<rocky-ip>
```

No password prompt means it worked. If you're still prompted, check permissions on Rocky:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Log out: `exit`

### Step 4: Generate a Key on Rocky and Copy to Ubuntu

On **Rocky**, do the reverse:

```bash
ssh-keygen -t ed25519 -C "lab-key-rocky"
ssh-copy-id <your-user>@<ubuntu-ip>
ssh <your-user>@<ubuntu-ip>        # Test it
exit
```

Both VMs can now SSH to each other without passwords.

---

## Part 2: SSH Config

### Step 5: Create SSH Config on Ubuntu

```bash
cat > ~/.ssh/config << 'EOF'
Host rocky
    HostName <rocky-ip>
    User <your-user>
    IdentityFile ~/.ssh/id_ed25519

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
EOF
chmod 600 ~/.ssh/config
```

Replace `<rocky-ip>` and `<your-user>` with actual values. Test: `ssh rocky`

### Step 6: Create SSH Config on Rocky

```bash
cat > ~/.ssh/config << 'EOF'
Host ubuntu
    HostName <ubuntu-ip>
    User <your-user>
    IdentityFile ~/.ssh/id_ed25519

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
EOF
chmod 600 ~/.ssh/config
```

Test: `ssh ubuntu`

---

## Part 3: Configure ufw on Ubuntu

### Step 7: Set Up the Firewall

```bash
sudo ufw status                    # Likely "inactive"
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh                 # Allow SSH BEFORE enabling!
sudo ufw allow http
sudo ufw enable
```

### Step 8: Verify

```bash
sudo ufw status numbered
```

Expected:

```text
Status: active

     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 22/tcp (v6)                ALLOW IN    Anywhere (v6)
[ 4] 80/tcp (v6)                ALLOW IN    Anywhere (v6)
```

Open a **new terminal** and SSH in to verify you haven't locked yourself out.

---

## Part 4: Configure firewalld on Rocky

### Step 9: Set Up the Firewall

```bash
sudo firewall-cmd --state          # Should be "running"
sudo firewall-cmd --list-all       # Note current services
```

Remove services you don't need and ensure only ssh and http remain:

```bash
sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --permanent --remove-service=dhcpv6-client
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

### Step 10: Verify

```bash
sudo firewall-cmd --list-all
```

Only `http` and `ssh` should appear under services.

---

## Part 5: Verification

### Step 11: Test SSH Between VMs

```bash
# From Ubuntu
ssh rocky "hostname && echo 'SSH OK'"

# From Rocky
ssh ubuntu "hostname && echo 'SSH OK'"
```

Both should execute without a password prompt.

### Step 12: Test That Blocked Ports Are Blocked

Start a temporary listener on Rocky on an unlisted port:

```bash
# On Rocky
python3 -m http.server 9999 &
```

From Ubuntu, try to connect:

```bash
curl -s --connect-timeout 5 http://<rocky-ip>:9999
echo "Exit code: $?"
```

Should fail (non-zero exit code) because port 9999 isn't allowed through firewalld.

Now test an allowed port. If a web server is running on Rocky port 80:

```bash
curl -s --connect-timeout 5 -o /dev/null -w "HTTP %{http_code}\n" http://<rocky-ip>:80
```

If no web server is running, start a temporary one: `sudo python3 -m http.server 80 &`

**Clean up** on Rocky:

```bash
kill %1
sudo kill %2 2>/dev/null    # If you started a port 80 listener
```

### Step 13: Final Status Check

**Ubuntu:**

```bash
sudo ufw status verbose
```

**Rocky:**

```bash
sudo firewall-cmd --list-all
```

---

## Bonus: Restrict SSH by Source IP

Restrict SSH to only the other VM's IP address.

**Ubuntu:**

```bash
sudo ufw delete allow ssh
sudo ufw allow from <rocky-ip> to any port 22
```

**Rocky:**

```bash
sudo firewall-cmd --permanent --remove-service=ssh
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="<ubuntu-ip>" port port="22" protocol="tcp" accept'
sudo firewall-cmd --reload
```

To undo and allow SSH from anywhere again:

```bash
# Ubuntu
sudo ufw delete allow from <rocky-ip> to any port 22
sudo ufw allow ssh

# Rocky
sudo firewall-cmd --permanent --remove-rich-rule='rule family="ipv4" source address="<ubuntu-ip>" port port="22" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

---

## Verify Your Work

- [ ] SSH key pair exists on both VMs (`~/.ssh/id_ed25519` and `~/.ssh/id_ed25519.pub`)
- [ ] Passwordless SSH works in both directions
- [ ] `ssh rocky` and `ssh ubuntu` work via config shortcuts
- [ ] ufw on Ubuntu allows only SSH (22) and HTTP (80)
- [ ] firewalld on Rocky allows only ssh and http services
- [ ] Connection to an unlisted port (9999) is blocked on both VMs
- [ ] Connection to an allowed port (22 or 80) succeeds on both VMs

---

