---
title: "Week 10: Storage, Filesystems & Disk Management"
sidebar:
  order: 0
---


> **Goal:** Partition disks, create filesystems, mount storage, and manage disk space on a Linux server.


---

## Table of Contents

| Section | Topic |
|---------|-------|
| 10.1 | [Block Devices and Storage Concepts](#101-block-devices-and-storage-concepts) |
| 10.2 | [Viewing Storage](#102-viewing-storage) |
| 10.3 | [Partitioning: MBR vs GPT](#103-partitioning-mbr-vs-gpt) |
| 10.4 | [Partitioning with fdisk](#104-partitioning-with-fdisk) |
| 10.5 | [Partitioning with gdisk and parted (GPT)](#105-partitioning-with-gdisk-and-parted-gpt) |
| 10.6 | [Filesystems: ext4 vs XFS](#106-filesystems-ext4-vs-xfs) |
| 10.7 | [Creating Filesystems](#107-creating-filesystems) |
| 10.8 | [Mounting Filesystems](#108-mounting-filesystems) |
| 10.9 | [Persistent Mounts with /etc/fstab](#109-persistent-mounts-with-etcfstab) |
| 10.10 | [Unmounting and Troubleshooting "Target Is Busy"](#1010-unmounting-and-troubleshooting-target-is-busy) |
| 10.11 | [LVM Concepts](#1011-lvm-concepts) |
| 10.12 | [LVM Commands](#1012-lvm-commands) |
| 10.13 | [Extending LVM — The Real Power](#1013-extending-lvm--the-real-power) |
| 10.14 | [Thin Provisioning with LVM](#1014-thin-provisioning-with-lvm) |
| 10.15 | [Swap Space](#1015-swap-space) |
| 10.16 | [Disk Usage Analysis](#1016-disk-usage-analysis) |
| 10.17 | [Filesystem Maintenance](#1017-filesystem-maintenance) |

---

## 10.1 Block Devices and Storage Concepts

In Week 2, we navigated the filesystem — everything hanging off `/`. This week, we go one level deeper: what lives *beneath* the filesystem. Every file you've ever created sits on a storage device, and understanding how Linux talks to those devices is essential for server administration.

### What Is a Block Device?

A **block device** is any storage device that Linux reads and writes in fixed-size chunks called blocks (typically 512 bytes or 4 KB). Hard drives, SSDs, USB sticks, virtual disks — they all appear as block devices under `/dev/`.

| Device Path | Meaning |
|-------------|---------|
| `/dev/sda` | First SCSI/SATA/SAS disk (or virtual disk using the SCSI driver) |
| `/dev/sdb` | Second SCSI/SATA disk |
| `/dev/vda` | First virtio disk (common in KVM/QEMU VMs) |
| `/dev/nvme0n1` | First NVMe SSD |
| `/dev/xvda` | First Xen virtual disk (AWS EC2) |

The letters increment: `sda`, `sdb`, `sdc`. In Parallels VMs, your primary disk is typically `/dev/sda`.

### Partitions vs Whole Disks

A **partition** is a logical subdivision of a disk. When you partition `/dev/sda`, you get `/dev/sda1`, `/dev/sda2`, etc. Each partition gets its own filesystem, mount point, and data:

```text
Physical Disk: /dev/sda (50 GB)
├── /dev/sda1  (1 GB)   → /boot
├── /dev/sda2  (20 GB)  → /
└── /dev/sda3  (29 GB)  → /home
```

You can use a whole disk without partitioning (common with LVM), but partitioning provides isolation (a full `/home` doesn't crash root), different filesystem types per partition, and independent management.

The files under `/dev/` are interfaces to kernel device drivers, not regular files. Writing directly to `/dev/sda` writes raw data to the physical disk — this is why storage operations require root privileges and careful attention to device names.

---

## 10.2 Viewing Storage

Before you touch any disk, you need to see what you have.

### lsblk — List Block Devices

The most useful starting point:

```bash
lsblk
```

```text
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda      8:0    0   50G  0 disk
├─sda1   8:1    0    1G  0 part /boot
├─sda2   8:2    0   20G  0 part /
└─sda3   8:3    0   29G  0 part /home
sdb      8:16   0    5G  0 disk
```

| Column | Meaning |
|--------|---------|
| NAME | Device name (without `/dev/` prefix) |
| SIZE | Device size |
| TYPE | disk, part (partition), lvm, rom, etc. |
| MOUNTPOINTS | Where it's mounted (blank = not mounted) |

Add `-f` to see filesystem information including UUIDs:

```bash
lsblk -f
```

```text
NAME   FSTYPE FSVER LABEL UUID                                 MOUNTPOINTS
sda
├─sda1 ext4   1.0         a1b2c3d4-e5f6-7890-abcd-ef1234567890 /boot
├─sda2 ext4   1.0         b2c3d4e5-f6a7-8901-bcde-f12345678901 /
└─sda3 ext4   1.0         c3d4e5f6-a7b8-9012-cdef-123456789012 /home
sdb
```

Notice `sdb` has no filesystem — it's a raw, unpartitioned disk.

### fdisk -l — Detailed Partition Tables

```bash
sudo fdisk -l /dev/sda
```

```text
Disk /dev/sda: 50 GiB, 53687091200 bytes, 104857600 sectors
Disklabel type: gpt

Device       Start       End  Sectors Size Type
/dev/sda1     2048   2097151  2095104   1G Linux filesystem
/dev/sda2  2097152  43954175 41857024  20G Linux filesystem
/dev/sda3 43954176 104857566 60903391  29G Linux filesystem
```

This gives you sector-level detail and the partition table type (GPT or MBR/dos).

### blkid — Block Device Attributes

```bash
sudo blkid
```

```text
/dev/sda1: UUID="a1b2c3d4-e5f6-7890-abcd-ef1234567890" TYPE="ext4" PARTUUID="..."
/dev/sda2: UUID="b2c3d4e5-f6a7-8901-bcde-f12345678901" TYPE="ext4" PARTUUID="..."
```

The **UUID (Universally Unique Identifier)** is assigned when you create a filesystem. Unlike device names, UUIDs don't change when you add or remove disks — critical for `/etc/fstab`.

### lsscsi — List SCSI Devices

On systems with SCSI/SAS storage (or virtual SCSI), `lsscsi` shows the controller-level view:

```bash
# Install: sudo apt install lsscsi  (Ubuntu) / sudo dnf install lsscsi (Rocky)
lsscsi
```

```text
[0:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sda
[0:0:1:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdb
```

Most useful in hardware environments where you need to trace a disk back to a specific controller.

---

## 10.3 Partitioning: MBR vs GPT

Before you partition a disk, you need to choose a **partition table** format:

**MBR (Master Boot Record)** — the legacy format from 1983:
- Maximum disk size: **2 TB**
- Maximum **4 primary partitions** (workaround with extended partitions)
- No redundancy — single 512-byte sector stores the table

**GPT (GUID Partition Table)** — the modern format:
- Maximum disk size: **9.4 ZB** (effectively unlimited)
- Up to **128 partitions** by default
- Backup copy of the partition table at the end of the disk

| Scenario | Use |
|----------|-----|
| Disk ≤ 2 TB on legacy BIOS | MBR is fine |
| Disk > 2 TB | Must use GPT |
| UEFI boot | Must use GPT |
| New servers (any size) | GPT — no reason to use MBR |

**Rule of thumb:** use GPT unless you're maintaining a legacy system. Both Ubuntu and Rocky default to GPT for new installations.

---

## 10.4 Partitioning with fdisk

`fdisk` is the classic interactive partitioning tool. Modern versions handle both MBR and GPT. Let's partition a fresh 5 GB disk (`/dev/sdb`) into 2 GB and 3 GB:

```bash
sudo fdisk /dev/sdb
```

```text
Command (m for help): n        ← Create new partition
Select (default p): p          ← Primary partition
Partition number (1-4, default 1): 1
First sector (default 2048):               ← Press Enter
Last sector (default 10485759): +2G        ← 2 GB partition

Command (m for help): n        ← Second partition
Select (default p): p
Partition number (2-4, default 2): 2
First sector (default 4196352):            ← Press Enter
Last sector (default 10485759):            ← Press Enter (use rest)

Command (m for help): p        ← Print to verify
Device     Boot   Start      End  Sectors Size Id Type
/dev/sdb1          2048  4196351  4194304   2G 83 Linux
/dev/sdb2       4196352 10485759  6289408   3G 83 Linux

Command (m for help): w        ← Write changes and exit
```

Key fdisk commands:

| Command | Action |
|---------|--------|
| `n` | New partition |
| `d` | Delete partition |
| `p` | Print partition table |
| `t` | Change partition type |
| `w` | Write changes to disk |
| `q` | Quit without saving |

Nothing is written until you press `w`. After writing, inform the kernel and verify:

```bash
sudo partprobe /dev/sdb
lsblk /dev/sdb
```

```text
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sdb      8:16   0   5G  0 disk
├─sdb1   8:17   0   2G  0 part
└─sdb2   8:18   0   3G  0 part
```

---

## 10.5 Partitioning with gdisk and parted (GPT)

### gdisk

`gdisk` is the GPT equivalent of fdisk with a nearly identical interface:

```bash
sudo gdisk /dev/sdb
```

```text
Command (? for help): n
Partition number (1-128, default 1): 1
First sector (default = 2048):                     ← Enter
Last sector (default = 10485759): +2G
Hex code or GUID (Enter = 8300):                   ← Enter

Command (? for help): w       ← Write and exit
```

Install if needed: `sudo apt install gdisk` (Ubuntu) / `sudo dnf install gdisk` (Rocky).

### parted

`parted` is more scriptable and handles both MBR and GPT. Unlike fdisk, **parted writes changes immediately**:

```bash
sudo parted /dev/sdb
```

```text
(parted) mklabel gpt
(parted) mkpart primary ext4 0% 40%
(parted) mkpart primary xfs 40% 100%
(parted) print
(parted) quit
```

Non-interactive for scripting:

```bash
sudo parted -s /dev/sdb mklabel gpt
sudo parted -s /dev/sdb mkpart primary ext4 0% 40%
sudo parted -s /dev/sdb mkpart primary xfs 40% 100%
```

---

## 10.6 Filesystems: ext4 vs XFS

A partition is raw blocks. To store files, you need a **filesystem** — the structure that organizes data into files and directories, tracks permissions, and handles journaling for crash recovery.

**ext4 (Fourth Extended Filesystem)** is the default on Ubuntu/Debian. Stable workhorse since 2008. Can be grown online and **shrunk offline** — unique among major Linux filesystems.

**XFS** is the default on Rocky/RHEL/Fedora. Designed for large-scale storage. Excellent parallel I/O performance. Can be grown online but **can never be shrunk**.

| Feature | ext4 | XFS |
|---------|------|-----|
| Default on | Ubuntu, Debian | Rocky, RHEL, Fedora |
| Max file size | 16 TB | 8 EB |
| Max FS size | 1 EB | 8 EB |
| Shrinkable | Yes (offline) | No |
| Growable online | Yes | Yes |
| Inode allocation | Fixed at creation | Dynamic |
| Large file / parallel I/O | Good | Excellent |
| Repair tool | `fsck.ext4` | `xfs_repair` |
| Grow tool | `resize2fs` | `xfs_growfs` |

**When to use which:** ext4 for general-purpose servers and partitions you might shrink. XFS for large filesystems, media workloads, and heavy parallel I/O. For most use cases, either works fine — pick the default for your distro unless you have a specific reason not to.

---

## 10.7 Creating Filesystems

Once you have partitions, create filesystems with `mkfs`:

```bash
sudo mkfs.ext4 /dev/sdb1
```

```text
mke2fs 1.47.0 (5-Feb-2023)
Creating filesystem with 524288 4k blocks and 131072 inodes
Filesystem UUID: d4e5f6a7-b8c9-0123-4567-890abcdef012
...
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done
```

```bash
sudo mkfs.xfs /dev/sdb2
```

```text
meta-data=/dev/sdb2              isize=512    agcount=4, agsize=196608 blks
...
realtime =none                   extsz=4096   blocks=0, rtextents=0
```

Note the UUID in the mkfs.ext4 output — you'll need it for `/etc/fstab`.

Common options:

| Option | ext4 | XFS | Purpose |
|--------|------|-----|---------|
| `-L label` | Yes | Yes | Set a human-readable label |
| `-f` | N/A | Yes | Force creation (XFS won't overwrite without it) |

Example with labels:

```bash
sudo mkfs.ext4 -L "app-data" /dev/sdb1
sudo mkfs.xfs -L "media-store" /dev/sdb2
```

**Warning:** `mkfs` destroys all data on the target. There is no confirmation prompt.

---

## 10.8 Mounting Filesystems

A filesystem isn't accessible until you **mount** it — attach it to a directory in the filesystem tree.

```bash
sudo mkdir -p /mnt/data /mnt/media
sudo mount /dev/sdb1 /mnt/data
sudo mount /dev/sdb2 /mnt/media
```

Verify:

```bash
df -h /mnt/data /mnt/media
```

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       2.0G   24K  1.8G   1% /mnt/data
/dev/sdb2       3.0G   33M  3.0G   2% /mnt/media
```

### Mount Options

| Option | Effect |
|--------|--------|
| `noexec` | Prevents execution of binaries on this filesystem |
| `nosuid` | Ignores SUID/SGID bits (covered in Week 5) |
| `nodev` | Prevents interpretation of device files |
| `ro` | Read-only mount |
| `defaults` | Alias for `rw,suid,dev,exec,auto,nouser,async` |
| `noatime` | Don't update access times on reads (performance boost) |

Example with security-hardened options for a data partition:

```bash
sudo mount -o noexec,nosuid,nodev /dev/sdb1 /mnt/data
```

View current mounts with `findmnt --real` or `mount | grep "^/dev"`.

---

## 10.9 Persistent Mounts with /etc/fstab

The problem with `mount`: it's temporary. Reboot and your mounts are gone. Add them to `/etc/fstab` for persistence.

### fstab Syntax

```text
<device>    <mount-point>    <type>    <options>       <dump>  <fsck-order>
```

| Field | Purpose | Example |
|-------|---------|---------|
| device | What to mount | `UUID=d4e5f6a7-...` |
| mount-point | Where to mount it | `/mnt/data` |
| type | Filesystem type | `ext4`, `xfs`, `swap` |
| options | Mount options | `defaults,noexec` |
| dump | Backup flag (0 = skip) | `0` |
| fsck-order | Boot-time check (0 = skip, 1 = root, 2 = other) | `2` |

### Why UUIDs Are Critical

Device names like `/dev/sdb1` are assigned by detection order. Add a new disk and what was `/dev/sdb` might become `/dev/sdc`. If fstab references `/dev/sdb1`, it could mount the wrong filesystem or fail to boot. **UUIDs never change** (unless you reformat).

```bash
sudo blkid /dev/sdb1
```

```text
/dev/sdb1: UUID="d4e5f6a7-b8c9-0123-4567-890abcdef012" TYPE="ext4"
```

### Example fstab Entries

```text
# App data (ext4)
UUID=d4e5f6a7-b8c9-0123-4567-890abcdef012  /mnt/data   ext4  defaults,noexec,nosuid,nodev  0  2

# Media storage (XFS) — fsck-order 0 because XFS uses xfs_repair, not fsck
UUID=e5f6a7b8-c9d0-1234-5678-90abcdef0123  /mnt/media  xfs   defaults,noatime              0  0
```

### The nofail Option

If a device in fstab is missing at boot, the system drops to emergency mode. The **`nofail`** option prevents this — the system boots normally and skips the missing mount. Use it for non-essential storage, removable disks, and cloud volumes.

### Testing fstab

**Always test before rebooting:**

```bash
sudo umount /mnt/data /mnt/media
sudo mount -a
df -h | grep /mnt
```

If `mount -a` fails, fix fstab before rebooting. A broken entry can prevent boot.

| Common Mistake | Consequence |
|----------------|-------------|
| Typo in UUID | Mount fails; may drop to emergency mode |
| Wrong filesystem type | "wrong fs type" error |
| Missing mount point directory | "mount point does not exist" |
| Device name instead of UUID | May mount wrong FS after hardware changes |
| No `nofail` on removable storage | System hangs if device is removed |

---

## 10.10 Unmounting and Troubleshooting "Target Is Busy"

```bash
sudo umount /mnt/data
```

If you get `target is busy`, something is holding the filesystem open. Find it:

**With lsof:**

```bash
sudo lsof +f -- /mnt/data
```

```text
COMMAND   PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
bash     1234    tim  cwd    DIR    8,17     4096    2 /mnt/data
vim      1235    tim    4r   REG    8,17    28672   12 /mnt/data/config.yml
```

**With fuser:**

```bash
sudo fuser -mv /mnt/data
```

```text
                     USER        PID ACCESS COMMAND
/mnt/data:           tim        1234 ..c.. bash
                     tim        1235 .r... vim
```

ACCESS codes: `c` = current directory, `r` = reading, `e` = executing, `m` = memory-mapped.

**Resolution options** (least to most aggressive):

1. `cd` out of the directory, close files
2. `kill 1234` — terminate the process
3. `sudo fuser -km /mnt/data` — SIGKILL all processes using the mount
4. `sudo umount -l /mnt/data` — lazy unmount (detaches immediately, cleans up when processes finish)

The lazy unmount is a last resort — it can leave resources in a confusing state.

---

## 10.11 LVM Concepts

Fixed partitions have a fundamental problem: you guess sizes at setup, and six months later you've guessed wrong. `/` is full while `/home` has 20 GB free. Traditional partitions can't be easily resized or span multiple disks.

**LVM (Logical Volume Manager)** adds an abstraction layer between disks and filesystems:

```text
Physical Disks           LVM Layer              Filesystems
┌────────────┐     ┌──────────────────┐     ┌──────────────┐
│ /dev/sdb   │────▶│ Physical Volume  │     │              │
│ (5 GB)     │     │ (PV)             │     │              │
└────────────┘     └────────┬─────────┘     │  /mnt/data   │
                            │               │  ext4 on LV  │
                   ┌────────▼─────────┐     │              │
                   │  Volume Group    │────▶│              │
                   │  "vg_data"       │     └──────────────┘
┌────────────┐     └────────┬─────────┘
│ /dev/sdc   │────▶│ Physical Volume  │
│ (10 GB)    │     │ (PV)             │
└────────────┘     └──────────────────┘
```

The three layers:

1. **Physical Volume (PV):** A disk or partition initialized for LVM with `pvcreate`
2. **Volume Group (VG):** A storage pool combining one or more PVs — name it (e.g., `vg_data`) and carve volumes from it
3. **Logical Volume (LV):** A virtual partition carved from a VG — format it, mount it, resize it on the fly

| Problem | LVM Solution |
|---------|-------------|
| Partition too small | Extend the LV and grow the filesystem |
| Need more storage | Add a new disk as a PV, extend the VG |
| Span multiple disks | Create a VG from multiple PVs |
| Snapshots for backups | LVM supports point-in-time snapshots |

LVM is standard in production. RHEL/Rocky installations use it by default; Ubuntu Server does too.

---

## 10.12 LVM Commands

### Creating the Stack

```bash
# Initialize a disk for LVM
sudo pvcreate /dev/sdb

# Create a volume group
sudo vgcreate vg_data /dev/sdb

# Create logical volumes
sudo lvcreate -n lv_app -L 2G vg_data
sudo lvcreate -n lv_logs -L 2G vg_data
```

### Inspecting Each Layer

```bash
sudo pvs    # Physical volumes
```

```text
  PV         VG       Fmt  Attr PSize  PFree
  /dev/sdb   vg_data  lvm2 a--  5.00g 1020.00m
```

```bash
sudo vgs    # Volume groups
```

```text
  VG       #PV #LV #SN Attr   VSize  VFree
  vg_data    1   2   0 wz--n- <5.00g 1020.00m
```

```bash
sudo lvs    # Logical volumes
```

```text
  LV      VG       Attr       LSize
  lv_app  vg_data  -wi-a----- 2.00g
  lv_logs vg_data  -wi-a----- 2.00g
```

### LV Device Paths

LVM creates device files in two locations (both point to the same device):

```text
/dev/vg_data/lv_app          ← Convenient path
/dev/mapper/vg_data-lv_app   ← Device-mapper path (shown by df and lsblk)
```

### Format and Mount

```bash
sudo mkfs.ext4 /dev/vg_data/lv_app
sudo mkfs.xfs /dev/vg_data/lv_logs

sudo mkdir -p /mnt/app /mnt/logs
sudo mount /dev/vg_data/lv_app /mnt/app
sudo mount /dev/vg_data/lv_logs /mnt/logs
```

---

## 10.13 Extending LVM — The Real Power

Running out of space on `/mnt/app`? Grow it without downtime, without unmounting, without data loss.

### Check Available Space

```bash
sudo vgs
```

```text
  VG       #PV #LV #SN Attr   VSize  VFree
  vg_data    1   2   0 wz--n- <5.00g 1020.00m
```

### Extend the LV and Grow the Filesystem

**For ext4** (resize2fs takes the device path):

```bash
sudo lvextend -L +500M /dev/vg_data/lv_app
sudo resize2fs /dev/vg_data/lv_app
```

**For XFS** (xfs_growfs takes the mount point):

```bash
sudo lvextend -L +500M /dev/vg_data/lv_logs
sudo xfs_growfs /mnt/logs
```

### The Shortcut: lvextend -r

Combine both steps — `lvextend -r` automatically calls the right resize tool:

```bash
sudo lvextend -r -L +500M /dev/vg_data/lv_app
```

This is the command you'll use in practice. The `-r` flag detects ext4 vs XFS and runs `resize2fs` or `xfs_growfs` accordingly.

### Adding a New Disk to a Volume Group

When the VG is full, add another physical disk:

```bash
sudo pvcreate /dev/sdc
sudo vgextend vg_data /dev/sdc
sudo lvextend -r -l +100%FREE /dev/vg_data/lv_app
```

You just grew a filesystem across two physical disks with no downtime.

---

## 10.14 Thin Provisioning with LVM

Standard LVM allocates space immediately — a 100 GB LV consumes 100 GB from the VG. **Thin provisioning** allocates on demand, only when data is written.

```text
Volume Group: vg_data (50 GB total)
└── Thin Pool: tp_data (30 GB)
    ├── Thin LV: lv_web1 (100 GB virtual — 5 GB used)
    ├── Thin LV: lv_web2 (100 GB virtual — 3 GB used)
    └── Thin LV: lv_web3 (100 GB virtual — 2 GB used)
```

Three "100 GB" volumes, but only 10 GB of actual storage consumed.

```bash
# Create a thin pool
sudo lvcreate --type thin-pool -n tp_data -L 30G vg_data

# Create thin volumes (virtual size can exceed pool size)
sudo lvcreate --type thin -n lv_web1 -V 100G --thinpool tp_data vg_data
```

This matters because thin provisioning is the storage model behind container runtimes — Docker uses it to avoid preallocating disk space for every container.

**The risk:** if thin volumes fill beyond the pool's capacity, writes fail. Monitor thin pool usage and alert at 80%.

---

## 10.15 Swap Space

**Swap** is disk space the kernel uses as an extension of RAM. When physical memory fills up, the kernel moves less-used pages to disk, freeing RAM for active processes.

Without swap, a full RAM condition triggers the **OOM (Out of Memory) killer**, which terminates processes. Swap provides breathing room.

### How Much Swap?

| RAM | Recommended Swap |
|-----|-----------------|
| ≤ 2 GB | 2x RAM |
| 2-8 GB | Equal to RAM |
| 8-64 GB | At least 4 GB |
| > 64 GB | At least 4 GB |

### Creating Swap

**On a partition:**

```bash
sudo mkswap /dev/sdb3
sudo swapon /dev/sdb3
swapon --show
```

**As a file:**

```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Adding Swap to fstab

```text
UUID=f6a7b8c9-d0e1-2345-6789-0abcdef12345  none  swap  sw  0  0
# Or for a swap file:
/swapfile  none  swap  sw  0  0
```

### Swappiness Tuning

The **`swappiness`** parameter (0-100) controls how aggressively the kernel swaps:

| Value | Behavior |
|-------|----------|
| 0 | Only swap to avoid OOM |
| 10 | Swap reluctantly (good for databases) |
| 60 | Default |
| 100 | Swap aggressively |

```bash
# Check current value
cat /proc/sys/vm/swappiness

# Set temporarily
sudo sysctl vm.swappiness=10

# Set permanently
echo "vm.swappiness=10" | sudo tee /etc/sysctl.d/99-swappiness.conf
```

For database servers (PostgreSQL, MySQL), swappiness of 10 or lower is common.

---

## 10.16 Disk Usage Analysis

Disks fill up. Knowing where the space went is a skill you'll use weekly.

### df — Disk Free

Shows usage per mounted filesystem:

```bash
df -h
```

```text
Filesystem                 Size  Used Avail Use% Mounted on
/dev/sda2                   20G   8.2G  11G  44% /
/dev/sda1                  974M  130M  778M  15% /boot
/dev/mapper/vg_data-lv_app 2.5G  1.1G  1.3G  46% /mnt/app
```

**Use%** is the number you care about most. Alert at 80%, investigate at 90%, panic at 95%.

### du — Disk Usage

`df` tells you *which* filesystem is full. `du` tells you *what's using the space*:

```bash
sudo du -sh /var/*/  | sort -rh | head -5
```

```text
3.2G    /var/log/
580M    /var/lib/
148M    /var/cache/
```

Drill into the hog:

```bash
sudo du -sh /var/log/*/  | sort -rh | head -5
```

Now you know journal logs are eating 2.8 GB — clean up with `journalctl --vacuum-size=500M` (covered in Week 3).

### ncdu — Interactive Disk Usage

`ncdu` is a terminal-based analyzer far more pleasant than chaining `du` and `sort`:

```bash
# Install: sudo apt install ncdu (Ubuntu) / sudo dnf install ncdu (Rocky)
sudo ncdu /var
```

Navigate with arrow keys, delete with `d`, sort by name or size. The fastest way to find space hogs interactively.

### Finding Large Files

```bash
sudo find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -10
```

Common culprits: old logs, core dumps, package caches, forgotten ISO images.

---

## 10.17 Filesystem Maintenance

### fsck — Filesystem Check (ext4)

**Never run fsck on a mounted filesystem.** It reads and writes raw disk blocks — doing that while the kernel is also using the filesystem will corrupt data.

```bash
sudo umount /dev/sdb1
sudo fsck.ext4 /dev/sdb1
```

```text
e2fsck 1.47.0 (5-Feb-2023)
/dev/sdb1: clean, 11/131072 files, 26156/524288 blocks
```

Auto-fix errors: `sudo fsck.ext4 -y /dev/sdb1`

### xfs_repair — XFS Filesystem Repair

XFS uses its own repair tool:

```bash
sudo umount /dev/sdb2
sudo xfs_repair /dev/sdb2
```

If the log is dirty (unclean shutdown), mount and unmount first to replay the journal:

```bash
sudo mount /dev/sdb2 /mnt/temp && sudo umount /mnt/temp
sudo xfs_repair /dev/sdb2
```

Last resort — force log zeroing (may lose recent data): `sudo xfs_repair -L /dev/sdb2`

### When to Run Filesystem Checks

| Situation | Action |
|-----------|--------|
| After unclean shutdown | Runs automatically at boot |
| Suspicious I/O errors in dmesg | Unmount and repair |
| Routine check | Rarely needed — journaling handles most issues |
| On a mounted filesystem | **Never.** Unmount first. Always. |

### Boot-Time Checks

Controlled by the sixth field in `/etc/fstab`: `0` = skip, `1` = root first, `2` = other filesystems after root. If errors can't be auto-fixed, the system drops to single-user mode.

### Disk Health with SMART

**SMART (Self-Monitoring, Analysis, and Reporting Technology)** tracks drive metrics like temperature, error rates, and reallocated sectors:

```bash
# Install: sudo apt install smartmontools (Ubuntu) / sudo dnf install smartmontools (Rocky)
sudo smartctl -a /dev/sda
```

A "PASSED" result doesn't guarantee health, but "FAILED" means replace immediately. In VMs, SMART data typically isn't available.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 10.1: Disk Management](./lab-01-disk-management)** — Add a virtual disk, partition it, create filesystems, mount them, and add to fstab
- **[Lab 10.2: LVM Operations](./lab-02-lvm-operations)** — Create a full LVM stack, format, mount, write data, then extend the LV and grow the filesystem

---

## Checklist

Before moving to Week 11, confirm you can:

- [ ] List block devices and partitions with lsblk and fdisk -l
- [ ] Partition a disk with fdisk or gdisk
- [ ] Create ext4 and XFS filesystems with mkfs
- [ ] Mount a filesystem manually and verify it with df
- [ ] Write an /etc/fstab entry using UUID and verify it with mount -a
- [ ] Explain the difference between ext4 and XFS and when to use each
- [ ] Create a complete LVM stack: physical volume, volume group, logical volume
- [ ] Extend a logical volume and grow the filesystem without unmounting
- [ ] Create and enable swap space
- [ ] Find the largest directories on a filesystem with du
- [ ] Troubleshoot a "target is busy" unmount error with lsof or fuser

---

