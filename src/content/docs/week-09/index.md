---
title: "Week 9: Networking Fundamentals"
sidebar:
  order: 0
---


> **Goal:** Configure networking, troubleshoot connectivity, and understand how Linux handles network communication.


---

## Table of Contents

- [9.1 Networking Concepts Refresher](#91-networking-concepts-refresher)
- [9.2 Network Interfaces](#92-network-interfaces)
- [9.3 DNS Resolution](#93-dns-resolution)
- [9.4 DNS Query Tools](#94-dns-query-tools)
- [9.5 Testing Connectivity](#95-testing-connectivity)
- [9.6 Port and Socket Inspection](#96-port-and-socket-inspection)
- [9.7 Network Configuration](#97-network-configuration)
- [9.8 Static IP Configuration](#98-static-ip-configuration)
- [9.9 Firewall Concepts](#99-firewall-concepts)
- [9.10 ufw — Ubuntu Firewall](#910-ufw--ubuntu-firewall)
- [9.11 firewalld — Rocky Linux Firewall](#911-firewalld--rocky-linux-firewall)
- [9.12 Firewall Comparison](#912-firewall-comparison)
- [9.13 SSH Deep Dive](#913-ssh-deep-dive)
- [9.14 File Transfer](#914-file-transfer)
- [9.15 curl and wget](#915-curl-and-wget)
- [Labs](#labs)
- [Checklist](#checklist)

---

## 9.1 Networking Concepts Refresher

Before you touch a single command, let's make sure the fundamentals are solid. Networking problems are almost always conceptual — you miscounted a subnet, forgot which port a service listens on, or didn't realize DNS was caching a stale record.

### IP Addresses

An **IP address** uniquely identifies a host on a network.

**IPv4** uses 32-bit addresses written as four octets: `192.168.1.50`. Each octet ranges from 0 to 255, giving roughly 4.3 billion addresses total — not nearly enough for the modern internet.

**IPv6** uses 128-bit addresses: `2001:0db8:85a3:0000:0000:8a2e:0370:7334`. Leading zeros can be dropped, and consecutive all-zero groups collapse to `::`: `2001:db8:85a3::8a2e:370:7334`.

We'll work primarily with IPv4 since that's what your lab VMs use, but recognize IPv6 when you see it.

### Subnets and CIDR Notation

A **subnet** divides a network into smaller segments. **CIDR notation** expresses both the network address and its size: `192.168.1.0/24`. The `/24` means the first 24 bits identify the network, leaving 8 bits for hosts (254 usable addresses).

| CIDR | Subnet Mask     | Usable Hosts | Common Use           |
|------|-----------------|--------------|----------------------|
| /8   | 255.0.0.0       | 16,777,214   | Large enterprise/ISP |
| /16  | 255.255.0.0     | 65,534       | Medium enterprise    |
| /24  | 255.255.255.0   | 254          | Typical LAN segment  |
| /30  | 255.255.255.252 | 2            | Point-to-point links |
| /32  | 255.255.255.255 | 1            | Single host route    |

### Ports

A **port** (0-65535) identifies a specific service on a host. Ports below 1024 are **privileged** — only root can bind to them.

| Port  | Protocol | Service    |
|-------|----------|------------|
| 22    | TCP      | SSH        |
| 53    | TCP/UDP  | DNS        |
| 80    | TCP      | HTTP       |
| 443   | TCP      | HTTPS      |
| 3306  | TCP      | MySQL      |
| 5432  | TCP      | PostgreSQL |

### DNS, DHCP, and Transport Protocols

The **Domain Name System** translates names like `example.com` into IP addresses. It's hierarchical: root servers → top-level domains → authoritative nameservers. Your system asks a **recursive resolver** (e.g., `8.8.8.8`) which does the heavy lifting.

**DHCP** (Dynamic Host Configuration Protocol) automatically assigns IP addresses, gateways, and DNS servers to hosts on a network.

**TCP** is connection-oriented with guaranteed delivery (SSH, HTTP). **UDP** is connectionless and best-effort (DNS queries, streaming). Most services you'll manage use TCP.

---

## 9.2 Network Interfaces

Back in Week 3, we used `ip addr` to find our VM's IP. Now let's understand the full picture.

The `ip` command (from the **iproute2** package) is the modern standard. View all interfaces:

```bash
ip addr show
```

```text
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
2: enp0s3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP
    link/ether 08:00:27:a1:b2:c3 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.50/24 brd 192.168.1.255 scope global dynamic enp0s3
```

Key details: `lo` is the **loopback interface** (127.0.0.1). `enp0s3` uses **predictable network interface names** based on hardware location (not the old `eth0` convention). `state UP` means active. `dynamic` means DHCP-assigned.

View the routing table:

```bash
ip route show
```

```text
default via 192.168.1.1 dev enp0s3 proto dhcp metric 100
192.168.1.0/24 dev enp0s3 proto kernel scope link src 192.168.1.50 metric 100
```

The **default gateway** (`192.168.1.1`) is where packets go when there's no more specific route. The second line says "for 192.168.1.0/24, use enp0s3 directly" — local subnet traffic doesn't need a router.

Other useful variations:

```bash
ip -4 addr show           # IPv4 only
ip -6 addr show           # IPv6 only
ip addr show dev enp0s3   # Specific interface
ip link show              # Link state (up/down) only
```

### Legacy Tools

You'll encounter `ifconfig` and `route` in older documentation. They come from the **net-tools** package, no longer installed by default. Know they exist; use `ip`.

| Legacy Command     | Modern Equivalent     |
|--------------------|-----------------------|
| `ifconfig`         | `ip addr show`        |
| `ifconfig eth0 up` | `ip link set eth0 up` |
| `route`            | `ip route show`       |

---

## 9.3 DNS Resolution

When you type `ping google.com`, your system translates that name into an IP. Here's the chain.

**`/etc/nsswitch.conf`** controls the resolution order:

```bash
grep '^hosts:' /etc/nsswitch.conf
```

```text
hosts:          files dns mymachines
```

First check **files** (`/etc/hosts`), then **dns**. If `/etc/hosts` has an entry, DNS is never queried.

**`/etc/hosts`** maps hostnames to IPs locally. Useful for overriding DNS or naming lab VMs:

```bash
echo "192.168.1.51  rocky" | sudo tee -a /etc/hosts
```

Now `ping rocky` resolves to 192.168.1.51 without any DNS server.

**`/etc/resolv.conf`** specifies which DNS servers to query:

```text
nameserver 192.168.1.1
nameserver 8.8.8.8
search example.com
```

The `search` directive appends domain suffixes to short names. On modern systems, this file is managed by `systemd-resolved` (Ubuntu) or NetworkManager (Rocky) — don't edit it directly unless you know what's managing it.

---

## 9.4 DNS Query Tools

`dig` is the most powerful DNS query tool. Learn it well.

```bash
dig example.com
```

```text
;; ANSWER SECTION:
example.com.            86400   IN      A       93.184.216.34

;; Query time: 23 msec
;; SERVER: 192.168.1.1#53(192.168.1.1) (UDP)
```

Key parts: **status: NOERROR** (success), the **ANSWER SECTION** (actual result), **86400** (TTL in seconds — cacheable for 24 hours), and **SERVER** (which DNS server answered).

**Query specific record types:**

```bash
dig example.com A         # IPv4 address (default)
dig example.com AAAA      # IPv6 address
dig example.com MX        # Mail exchange servers
dig example.com NS        # Authoritative nameservers
dig example.com CNAME     # Canonical name (alias)
dig example.com TXT       # Text records (SPF, DKIM, verification)
```

**Other useful dig options:**

```bash
dig @8.8.8.8 example.com    # Query a specific DNS server
dig +short example.com       # Just the IP, no extras
dig +trace example.com       # Trace the full resolution path
dig -x 93.184.216.34         # Reverse lookup (IP → hostname)
```

**`host`** and **`nslookup`** are simpler alternatives:

```bash
host example.com                  # Clean, readable output
nslookup -type=MX example.com    # Query specific record type
```

For scripting and debugging, use `dig`. For a quick "what's the IP?", `host` or `dig +short` work well.

---

## 9.5 Testing Connectivity

When something doesn't connect, work methodically from the bottom of the stack up.

### ping

`ping` sends **ICMP echo request** packets:

```bash
ping -c 4 google.com
```

```text
64 bytes from lax17s62-in-f14.1e100.net (142.250.80.46): icmp_seq=1 ttl=118 time=5.23 ms
--- google.com ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3005ms
```

Watch for: **0% packet loss** (any loss is a problem), **ttl** (decremented by each router), and **time** (round-trip latency). If ping by IP works but by hostname fails, it's DNS, not network.

Always use `-c` on Linux — without it, `ping` runs forever.

### traceroute and mtr

**traceroute** shows every hop between you and the destination:

```bash
traceroute google.com
```

`* * *` means a hop didn't respond — many routers block ICMP probes, so this isn't always a problem. If the trace stops entirely, that's where connectivity breaks.

**mtr** combines ping and traceroute into a live display:

```bash
mtr -r -c 10 google.com     # Report mode: 10 probes, then print summary
```

`mtr` is the single best tool for diagnosing intermittent packet loss. The report mode (`-r`) is excellent for sharing with ISPs.

---

## 9.6 Port and Socket Inspection

If a service isn't reachable, the first question: is it actually listening?

```bash
sudo ss -tlnp
```

| Flag | Meaning                                  |
|------|------------------------------------------|
| `-t` | TCP sockets only                         |
| `-l` | Listening sockets only                   |
| `-n` | Numeric ports (don't resolve names)      |
| `-p` | Show process using each socket           |

```text
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=1234,fd=3))
LISTEN  0       4096    127.0.0.53:53       0.0.0.0:*          users:(("systemd-resolve",pid=567,fd=12))
LISTEN  0       511     0.0.0.0:80          0.0.0.0:*          users:(("nginx",pid=890,fd=6))
```

The distinction between `0.0.0.0` (all interfaces) and `127.0.0.1` (localhost only) matters. A service bound to `127.0.0.1` is only reachable from the same machine.

```bash
sudo ss -tulnp    # Include UDP sockets
ss -tn             # All TCP connections (not just listening)
ss -s              # Summary statistics
```

You'll see `netstat -tlnp` in older docs. Same flags, same concept. `netstat` requires `net-tools`; use `ss`.

---

## 9.7 Network Configuration

Ubuntu and Rocky diverge significantly here.

### Ubuntu: Netplan

**Netplan** configuration lives in YAML files under `/etc/netplan/`:

```yaml
# /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: true
```

```bash
sudo netplan apply    # Apply changes
sudo netplan try      # Apply temporarily, auto-revert after 120s if not confirmed
```

`netplan try` is a safety net for remote servers — if your config kills the network, it rolls back automatically.

### Rocky: NetworkManager and nmcli

```bash
nmcli connection show          # List all connections
nmcli connection show enp0s3   # Details of a specific connection
nmcli device status            # Device status overview
sudo nmtui                     # Text-based UI for interactive config
```

---

## 9.8 Static IP Configuration

Servers should have static IPs — you don't want your web server's address changing at DHCP's whim.

### Ubuntu: Netplan

```yaml
# /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    enp0s3:
      dhcp4: no
      addresses:
        - 192.168.1.50/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
        search: [example.com]
```

```bash
sudo netplan apply
ip addr show enp0s3
```

YAML rules: spaces only (no tabs), `addresses` is a list (note the `-`), and `routes` replaces the deprecated `gateway4`.

### Rocky: nmcli

```bash
sudo nmcli connection modify enp0s3 ipv4.method manual
sudo nmcli connection modify enp0s3 ipv4.addresses 192.168.1.51/24
sudo nmcli connection modify enp0s3 ipv4.gateway 192.168.1.1
sudo nmcli connection modify enp0s3 ipv4.dns "8.8.8.8 8.8.4.4"
sudo nmcli connection modify enp0s3 ipv4.dns-search "example.com"
sudo nmcli connection down enp0s3 && sudo nmcli connection up enp0s3
```

### Comparison

| Task            | Ubuntu (Netplan)                            | Rocky (nmcli)                              |
|-----------------|---------------------------------------------|--------------------------------------------|
| Config location | `/etc/netplan/*.yaml`                       | `/etc/NetworkManager/system-connections/`   |
| Set static IP   | `addresses: [192.168.1.50/24]`              | `nmcli con mod ... ipv4.addresses ...`     |
| Set gateway     | `routes: [{to: default, via: 192.168.1.1}]` | `nmcli con mod ... ipv4.gateway ...`      |
| Set DNS         | `nameservers: {addresses: [8.8.8.8]}`       | `nmcli con mod ... ipv4.dns ...`          |
| Apply           | `sudo netplan apply`                        | `sudo nmcli con down/up <name>`            |
| Safe apply      | `sudo netplan try`                          | N/A (use nmtui for interactive)            |

---

## 9.9 Firewall Concepts

A **firewall** controls which network traffic is allowed in and out. Default posture for servers: deny everything, then allow only what's needed.

Every listening port is an attack surface. If PostgreSQL (port 5432) should only be local, a firewall ensures external traffic to 5432 is dropped.

Linux firewalls use **netfilter** at the kernel level. The tools you interact with are frontends:

```text
┌─────────────────────────────────────────┐
│  ufw (Ubuntu)  │  firewalld (Rocky)     │  ← User-friendly frontends
├─────────────────────────────────────────┤
│  iptables / nftables                    │  ← Rule management tools
├─────────────────────────────────────────┤
│  netfilter (kernel)                     │  ← Actual packet filtering
└─────────────────────────────────────────┘
```

---

## 9.10 ufw — Ubuntu Firewall

**ufw** (Uncomplicated Firewall) is Ubuntu's default firewall frontend.

```bash
sudo ufw status verbose    # Check current state
```

Safe startup for remote servers — allow SSH first:

```bash
sudo ufw allow ssh
sudo ufw enable
```

### Rules

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow by service name or port
sudo ufw allow http               # Port 80/tcp
sudo ufw allow 8080/tcp
sudo ufw allow 53/udp

# Allow from specific sources
sudo ufw allow from 192.168.1.51
sudo ufw allow from 192.168.1.51 to any port 5432
sudo ufw allow from 192.168.1.0/24 to any port 22

# Deny
sudo ufw deny 3306/tcp
```

### Managing Rules

```bash
sudo ufw status numbered       # Show rules with numbers
sudo ufw delete 3              # Delete rule #3
sudo ufw delete allow 80/tcp   # Delete by specification
sudo ufw app list              # Show application profiles
sudo ufw allow "OpenSSH"       # Allow by profile name
sudo ufw reset                 # Remove all rules, start over
```

---

## 9.11 firewalld — Rocky Linux Firewall

Rocky uses **firewalld**, which organizes rules into **zones**. Each interface is assigned to a zone; the default is `public`.

| Zone     | Description                                           |
|----------|-------------------------------------------------------|
| drop     | Drop all incoming, no reply                           |
| block    | Reject all incoming (sends rejection reply)           |
| public   | Default. Untrusted networks. Allow selected services. |
| trusted  | Allow all traffic                                     |

```bash
sudo firewall-cmd --state
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --list-all
```

### Services and Ports

```bash
sudo firewall-cmd --get-services                       # List known services
sudo firewall-cmd --permanent --add-service=http       # Allow HTTP permanently
sudo firewall-cmd --permanent --add-port=8080/tcp      # Allow a specific port
sudo firewall-cmd --reload                             # Apply permanent changes

# Remove rules
sudo firewall-cmd --permanent --remove-service=cockpit
sudo firewall-cmd --permanent --remove-port=8080/tcp
sudo firewall-cmd --reload
```

The `--permanent` flag writes to disk. Without it, changes are runtime only — lost on reload or reboot. This is useful for testing: try at runtime, then add permanently if it works.

### Rich Rules

For granular control (e.g., allow PostgreSQL from one IP):

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.50" port port="5432" protocol="tcp" accept'
sudo firewall-cmd --reload
```

---

## 9.12 Firewall Comparison

| Task                | Ubuntu (ufw)                        | Rocky (firewalld)                                  |
|---------------------|-------------------------------------|----------------------------------------------------|
| Check status        | `sudo ufw status`                   | `sudo firewall-cmd --state`                        |
| Enable              | `sudo ufw enable`                   | `sudo systemctl enable --now firewalld`            |
| Allow SSH           | `sudo ufw allow ssh`                | `sudo firewall-cmd --permanent --add-service=ssh`  |
| Allow HTTP          | `sudo ufw allow http`               | `sudo firewall-cmd --permanent --add-service=http` |
| Allow port          | `sudo ufw allow 8080/tcp`           | `sudo firewall-cmd --permanent --add-port=8080/tcp`|
| Allow from IP       | `sudo ufw allow from 192.168.1.51`  | Rich rule (see 9.11)                               |
| Remove rule         | `sudo ufw delete allow http`        | `sudo firewall-cmd --permanent --remove-service=http`|
| Apply changes       | Immediate                           | `sudo firewall-cmd --reload`                       |
| List rules          | `sudo ufw status numbered`          | `sudo firewall-cmd --list-all`                     |

Key difference: ufw applies immediately. firewalld needs `--permanent` plus `--reload`.

---

## 9.13 SSH Deep Dive

You've been using SSH since Week 3. Now let's use it properly.

### Key-Based Authentication

Password auth works, but key-based auth is more secure (no password to brute-force), more convenient, and required by many production environments.

**1. Generate a key pair** on the client:

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

**ed25519** is the recommended algorithm. The private key (`id_ed25519`) never leaves your machine. The public key (`id_ed25519.pub`) goes on every server you want to access.

**2. Copy the public key to the server:**

```bash
ssh-copy-id user@192.168.1.51
```

**3. Test:** `ssh user@192.168.1.51` should not ask for a password.

**Permissions must be correct** — SSH silently falls back to password if they're wrong:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys     # On the server
```

### ~/.ssh/config

Instead of `ssh -i ~/.ssh/id_ed25519 -p 2222 adminuser@192.168.1.51`, create `~/.ssh/config`:

```text
Host rocky
    HostName 192.168.1.51
    User adminuser
    IdentityFile ~/.ssh/id_ed25519

Host ubuntu
    HostName 192.168.1.50
    User adminuser
    IdentityFile ~/.ssh/id_ed25519

Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Now: `ssh rocky`. The `Host *` block applies to all connections — `ServerAliveInterval 60` sends keepalives to prevent idle disconnections.

### Agent Forwarding

When you SSH to server A and need to reach server B, **agent forwarding** lets A use keys from your local agent — without copying your private key there:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh -A user@server-a         # From server-a, you can now ssh to server-b
```

In config: `ForwardAgent yes`. Only enable for servers you trust.

### SSH Tunnels

**Local forwarding** — access a remote service through a local port:

```bash
ssh -L 5432:localhost:5432 user@database-server
```

Now `psql -h localhost` connects to the remote database through the SSH tunnel.

**Remote forwarding** — expose a local service on a remote server:

```bash
ssh -R 8080:localhost:3000 user@remote-server
```

### Disabling Password Auth

Once key-based auth works, edit `/etc/ssh/sshd_config`:

```text
PasswordAuthentication no
PubkeyAuthentication yes
```

```bash
sudo systemctl restart sshd
```

> **Warning:** Test key-based auth in a second terminal before closing your current session.

---

## 9.14 File Transfer

### scp — Secure Copy

```bash
scp localfile.txt user@192.168.1.51:/home/user/
scp user@192.168.1.51:/var/log/syslog ./syslog.txt
scp -r /local/directory user@192.168.1.51:/remote/path/
scp localfile.txt rocky:/home/user/           # Uses SSH config
```

Fine for quick copies. For anything serious, use `rsync`.

### rsync — The Serious Tool

**rsync** only transfers what's changed, supports compression, and handles interruptions:

```bash
rsync -avz /local/path/ user@192.168.1.51:/remote/path/
```

| Flag        | Meaning                                                          |
|-------------|------------------------------------------------------------------|
| `-a`        | Archive: preserves permissions, timestamps, symlinks             |
| `-v`        | Verbose                                                          |
| `-z`        | Compress during transfer                                         |
| `--delete`  | Remove destination files that don't exist on source              |
| `--dry-run` | Preview without doing anything                                   |
| `-P`        | Progress bar + resume partial transfers                          |
| `--exclude` | Skip files matching a pattern                                    |

**Always `--dry-run` first with `--delete`:**

```bash
rsync -avz --delete --dry-run /local/path/ user@192.168.1.51:/remote/path/
```

> **Trailing slash matters!** `/local/path/` copies *contents* of path. `/local/path` (no slash) copies the directory itself into the destination.

### sftp

Interactive FTP-like session over SSH. Useful for browsing before transferring:

```bash
sftp user@192.168.1.51
sftp> get syslog
sftp> put localfile.txt
```

---

## 9.15 curl and wget

### wget — Download Files

```bash
wget https://example.com/file.tar.gz
wget -O /tmp/file.tar.gz https://example.com/file.tar.gz
wget -c https://example.com/largefile.iso     # Resume partial download
```

### curl — API Testing and More

**Basic usage:**

```bash
curl -s https://example.com                   # Fetch URL (silent)
curl -o output.html https://example.com       # Save to file
curl -L https://example.com/redirect          # Follow redirects
curl -I https://example.com                   # Headers only
curl -i https://example.com                   # Headers + body
```

**API testing:**

```bash
# POST with JSON
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"name": "alice", "email": "alice@example.com"}' \
  https://api.example.com/users

# Auth header
curl -s -H "Authorization: Bearer mytoken123" https://api.example.com/protected

# Just the status code
curl -s -o /dev/null -w "%{http_code}" https://example.com
```

| Flag | Meaning                                        |
|------|------------------------------------------------|
| `-X` | HTTP method (GET, POST, PUT, DELETE)           |
| `-H` | Add a header                                   |
| `-d` | Request body data                              |
| `-o` | Write output to file                           |
| `-s` | Silent mode                                    |
| `-w` | Write out variables after completion           |
| `-L` | Follow redirects                               |
| `-I` | HEAD request (headers only)                    |
| `-i` | Include response headers in output             |
| `-v` | Verbose (full request/response for debugging)  |
| `-k` | Skip TLS verification (testing only)           |

**Response details:**

```bash
curl -s -o /dev/null -w "HTTP Code: %{http_code}\nTime: %{time_total}s\nSize: %{size_download} bytes\n" https://example.com
```

When something isn't working, `curl -v` is your first move — it shows the complete request/response exchange including TLS handshake.

### curl vs wget

| Feature            | curl                         | wget                    |
|--------------------|------------------------------|-------------------------|
| Primary purpose    | Data transfer, API testing   | File downloading        |
| POST/PUT/DELETE    | Yes (`-X`)                   | Limited                 |
| Recursive download | No                           | Yes (`-r`)              |
| Pipe to stdout     | Default                      | Requires `-O -`         |
| Response inspection| Yes (`-w`, `-i`, `-v`)       | Limited                 |

### Preview: Week 12

In Week 12, you'll configure nginx as a reverse proxy and use `curl` to test every endpoint — verifying response codes, checking headers, and confirming proxy rules work correctly.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 9.1: Network Diagnostics](./lab-01-network-diagnostics)** — Diagnose networking: verify interfaces, test DNS, trace routes, identify listening services, check firewalls
- **[Lab 9.2: SSH & Firewall Configuration](./lab-02-ssh-and-firewall)** — Set up SSH key-based auth between VMs, configure firewalls on both distros

---

## Checklist

Before moving to Week 10, confirm you can:

- [ ] Display network interface configuration with ip addr and ip route
- [ ] Resolve DNS names with dig and explain the output
- [ ] Test connectivity with ping and trace the route with traceroute or mtr
- [ ] List listening ports and their associated processes with ss -tlnp
- [ ] Configure a static IP address on both Ubuntu (Netplan) and Rocky (nmcli)
- [ ] Configure ufw on Ubuntu to allow and deny specific ports
- [ ] Configure firewalld on Rocky to add services and ports permanently
- [ ] Generate SSH keys and set up key-based authentication
- [ ] Create SSH config entries for quick connections to multiple hosts
- [ ] Transfer files between systems with scp and rsync
- [ ] Use curl to make GET and POST requests and inspect response headers

---

