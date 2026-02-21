---
title: "Lab 9.1: Network Diagnostics"
sidebar:
  order: 1
---


> **Objective:** Diagnose networking scenarios: verify interface configuration, test DNS resolution, trace routes, identify listening services, and check firewall rules on both distros.
>
> **Concepts practiced:** ip addr, ip route, dig, ping, traceroute, ss, ufw, firewall-cmd
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Exercise 1: Verify Interface Configuration

On **both** VMs, inspect the network interfaces and record the key information.

### Ubuntu

```bash
ip addr show
```

Identify and write down:
1. The name of the primary network interface (not `lo`).
2. The IPv4 address and CIDR mask.
3. The MAC address (`link/ether` line).
4. Whether the address is `dynamic` (DHCP) or `static`.

Now check the routing table:

```bash
ip route show
```

5. What is the default gateway IP address?
6. Which interface is the default route using?

### Rocky

Run the same commands on Rocky and record the same six items:

```bash
ip addr show
ip route show
```

### Verify Your Work

Both VMs should have:
- An active interface in `state UP`
- An IPv4 address on the same subnet (so they can communicate)
- A default gateway pointing to your network's router

Confirm the VMs can reach each other:

```bash
# From Ubuntu, ping Rocky's IP
ping -c 3 <rocky-ip>

# From Rocky, ping Ubuntu's IP
ping -c 3 <ubuntu-ip>
```

If pings fail between VMs, check:
- Are both interfaces UP? (`ip link show`)
- Are they on the same subnet? (Compare the network portions of their addresses.)
- Is a firewall blocking ICMP? (We'll check firewalls in Exercise 5.)

---

## Exercise 2: Verify the Default Gateway

The default gateway is your path to the outside world. Let's confirm it's reachable and working.

### On Both VMs

```bash
# Ping the default gateway
ping -c 3 $(ip route show default | awk '{print $3}')
```

That command extracts the gateway IP from `ip route show default` and pings it directly. If this fails, you have a Layer 2 or Layer 3 problem — the VM can't reach its own router.

Now test external connectivity:

```bash
# Ping an external IP (bypasses DNS)
ping -c 3 8.8.8.8
```

If the gateway ping succeeds but `8.8.8.8` fails, the problem is upstream from your gateway (ISP issue, NAT misconfiguration, etc.).

Now test with a hostname:

```bash
ping -c 3 google.com
```

If `8.8.8.8` works but `google.com` fails, it's a DNS problem. The network is fine.

This three-step process (gateway → external IP → external hostname) is the standard network troubleshooting sequence. Memorize it.

---

## Exercise 3: Test DNS Resolution

### Query A Records

On **Ubuntu**, use `dig` to look up several domains:

```bash
dig google.com A
dig github.com A
dig example.com A
```

For each query, identify:
1. The **status** (should be `NOERROR`).
2. The IP address(es) in the **ANSWER SECTION**.
3. The **TTL** value.
4. Which **SERVER** answered the query.

### Query Different Record Types

Still on Ubuntu:

```bash
# Mail exchange records
dig google.com MX

# Nameserver records
dig google.com NS

# IPv6 address
dig google.com AAAA

# Text records (often used for SPF, domain verification)
dig google.com TXT
```

For the MX query, note the **priority numbers** before the mail server hostnames. Lower numbers mean higher priority.

### Use dig +short for Quick Answers

```bash
dig +short google.com
dig +short google.com MX
dig +short google.com NS
```

### Query a Specific DNS Server

Compare results from different DNS providers:

```bash
dig @8.8.8.8 example.com        # Google DNS
dig @1.1.1.1 example.com        # Cloudflare DNS
```

Do they return the same IP? They usually will for well-known domains, but propagation delays for recent changes can cause differences.

### Reverse DNS Lookup

Pick one of the IP addresses from your earlier queries and do a reverse lookup:

```bash
dig -x 93.184.216.34
```

Does it return a hostname? Not all IPs have reverse DNS configured — if you get `NXDOMAIN`, that's normal.

### Repeat on Rocky

Run at least the basic A record and MX queries on Rocky to confirm DNS works there too:

```bash
dig google.com A
dig google.com MX
```

---

## Exercise 4: Trace a Route

### Using traceroute

From **Ubuntu**:

```bash
traceroute google.com
```

Count the number of hops. Note any hops that show `* * *` (routers that don't respond to traceroute probes).

Repeat from **Rocky**:

```bash
traceroute google.com
```

Compare the two outputs. If both VMs are on the same network, the routes should be identical or very similar.

### Using mtr

`mtr` combines ping and traceroute into a single live display. Try it on either VM:

```bash
# Report mode: send 10 probes and print results
mtr -r -c 10 google.com
```

In the output, look for:
- **Loss%** — any hop with consistent loss indicates a potential problem at that point.
- **Avg** — the average latency at each hop. Latency should generally increase as you get further from your network.

> **Note:** If `mtr` or `traceroute` is not installed, install it:
>
> - Ubuntu: `sudo apt install mtr-tiny traceroute`
> - Rocky: `sudo dnf install mtr traceroute`

---

## Exercise 5: List Listening Services

### On Ubuntu

```bash
sudo ss -tlnp
```

Record every listening service. For each line, identify:
1. The **port** number.
2. The **bind address** (`0.0.0.0` = all interfaces, `127.0.0.1` = localhost only).
3. The **process name** and PID.

You should see at least `sshd` on port 22. If you've installed a web server in previous weeks, you may see that too.

Now include UDP:

```bash
sudo ss -tulnp
```

What additional services appear? You'll likely see `systemd-resolve` on UDP port 53 (Ubuntu) or similar.

### On Rocky

```bash
sudo ss -tlnp
sudo ss -tulnp
```

Compare the listening services between the two VMs. Are they the same? Different? Why might they differ?

---

## Exercise 6: Check Firewall Status

### Ubuntu (ufw)

```bash
sudo ufw status verbose
```

If the output shows `Status: inactive`, the firewall is not running. Note this — you'll enable it in Lab 9.2.

If it's active, record:
- The **default incoming** policy (should be `deny`).
- The **default outgoing** policy (should be `allow`).
- Any **rules** currently configured.

### Rocky (firewalld)

```bash
sudo firewall-cmd --state
sudo firewall-cmd --list-all
```

firewalld is typically active by default on Rocky. Record:
- The **active zone** (usually `public`).
- Which **services** are allowed.
- Which **ports** are explicitly opened.
- Which **interface** is assigned to the zone.

---

## Try Breaking It

Controlled experiments help you recognize symptoms. Try each one, observe the error, then undo.

### 1. Break DNS Resolution

On Ubuntu, temporarily point DNS to a non-existent server:

```bash
sudo resolvectl dns enp0s3 192.0.2.1    # Reserved IP, won't work
```

Now try `ping google.com` (should timeout), `ping 8.8.8.8` (should work), and `dig google.com` (should timeout). This is the classic "I can ping IPs but not hostnames" scenario.

**Fix it:** `sudo resolvectl dns enp0s3 8.8.8.8`

### 2. Observe a Blocked Port

On Rocky, start a listener on an unlisted port, then try to reach it from Ubuntu:

```bash
# Rocky
python3 -m http.server 8080 &

# Ubuntu
curl -s --connect-timeout 5 http://<rocky-ip>:8080    # Should timeout
```

Now allow it temporarily on Rocky and retry:

```bash
sudo firewall-cmd --add-port=8080/tcp     # Runtime only
```

The curl from Ubuntu should now succeed. Clean up:

```bash
sudo firewall-cmd --remove-port=8080/tcp
kill %1
```

---

## Verify Your Work

After completing all exercises, confirm:

- [ ] You can identify the interface name, IP address, and MAC address on both VMs
- [ ] You can identify the default gateway on both VMs
- [ ] The three-step connectivity test passes (gateway → external IP → hostname)
- [ ] You can query A, MX, NS, and TXT records with dig
- [ ] You can trace the route to an external host with traceroute or mtr
- [ ] You can list all listening TCP and UDP services with ss
- [ ] You know the current firewall status on both VMs
- [ ] You successfully demonstrated a DNS failure and a firewall block, then fixed both

---

