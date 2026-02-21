---
title: "Lab 10.1: Disk Management"
sidebar:
  order: 1
---


> **Objective:** Add a virtual disk to your VM in Parallels, partition it with one ext4 and one XFS partition, create filesystems, mount them, and add to fstab for persistence across reboots.
>
> **Concepts practiced:** lsblk, fdisk, mkfs.ext4, mkfs.xfs, mount, /etc/fstab, blkid, UUID
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Ubuntu (repeat on Rocky if desired)

---

## Step 1: Add a Virtual Disk in Parallels

1. **Shut down your VM:**

```bash
sudo shutdown -h now
```

2. **In Parallels Desktop:**
   - Right-click your VM and select **Configure** (or the gear icon)
   - Go to **Hardware** → click **+** (Add)
   - Select **Hard Disk**
   - Set the size to **5 GB**
   - Click **Add**

3. **Start the VM** and log back in.

---

## Step 2: Find the New Disk

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

The new 5 GB disk is `/dev/sdb` — no partitions, no filesystem.

---

## Step 3: Partition the Disk

Create two partitions: 2 GB (for ext4) and 3 GB (for XFS):

```bash
sudo fdisk /dev/sdb
```

```text
Command (m for help): n
Select (default p): p
Partition number (1-4, default 1): 1
First sector (default 2048):            ← Enter
Last sector (default 10485759): +2G

Command (m for help): n
Select (default p): p
Partition number (2-4, default 2): 2
First sector (default 4196352):         ← Enter
Last sector (default 10485759):         ← Enter (use remaining)

Command (m for help): p
Device     Boot   Start      End  Sectors Size Id Type
/dev/sdb1          2048  4196351  4194304   2G 83 Linux
/dev/sdb2       4196352 10485759  6289408   3G 83 Linux

Command (m for help): w
```

**Verify:**

```bash
lsblk /dev/sdb
```

```text
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
sdb      8:16   0   5G  0 disk
├─sdb1   8:17   0   2G  0 part
└─sdb2   8:18   0   3G  0 part
```

---

## Step 4: Create Filesystems

```bash
sudo mkfs.ext4 -L "lab-ext4" /dev/sdb1
sudo mkfs.xfs -L "lab-xfs" /dev/sdb2
```

**Verify:**

```bash
lsblk -f /dev/sdb
```

```text
NAME   FSTYPE FSVER LABEL    UUID                                 MOUNTPOINTS
sdb
├─sdb1 ext4   1.0   lab-ext4 d4e5f6a7-b8c9-0123-4567-890abcdef012
└─sdb2 xfs          lab-xfs  e5f6a7b8-c9d0-1234-5678-90abcdef0123
```

---

## Step 5: Mount and Verify

```bash
sudo mkdir -p /mnt/lab-ext4 /mnt/lab-xfs
sudo mount /dev/sdb1 /mnt/lab-ext4
sudo mount /dev/sdb2 /mnt/lab-xfs
```

```bash
df -h /mnt/lab-ext4 /mnt/lab-xfs
```

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdb1       2.0G   24K  1.8G   1% /mnt/lab-ext4
/dev/sdb2       3.0G   33M  3.0G   2% /mnt/lab-xfs
```

Write test files:

```bash
echo "ext4 test file" | sudo tee /mnt/lab-ext4/test.txt
echo "xfs test file" | sudo tee /mnt/lab-xfs/test.txt
```

---

## Step 6: Get UUIDs

Device names can change if you add or remove disks. UUIDs don't. Always use UUIDs in fstab.

```bash
sudo blkid /dev/sdb1 /dev/sdb2
```

```text
/dev/sdb1: LABEL="lab-ext4" UUID="d4e5f6a7-b8c9-0123-4567-890abcdef012" TYPE="ext4" ...
/dev/sdb2: LABEL="lab-xfs" UUID="e5f6a7b8-c9d0-1234-5678-90abcdef0123" TYPE="xfs" ...
```

Copy both UUIDs for the next step. Your UUIDs will differ from these examples.

---

## Step 7: Add fstab Entries

Unmount first so we can test that fstab mounts them correctly:

```bash
sudo umount /mnt/lab-ext4 /mnt/lab-xfs
```

Edit `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Add at the end (replace UUIDs with your actual values):

```text
# Lab 10.1 — ext4 partition
UUID=d4e5f6a7-b8c9-0123-4567-890abcdef012  /mnt/lab-ext4  ext4  defaults,nofail  0  2

# Lab 10.1 — XFS partition
UUID=e5f6a7b8-c9d0-1234-5678-90abcdef0123  /mnt/lab-xfs   xfs   defaults,nofail  0  0
```

---

## Step 8: Test fstab

**Always test before rebooting** — a broken fstab entry can prevent boot:

```bash
sudo mount -a
```

No output means success. Verify:

```bash
df -h | grep lab
```

```text
/dev/sdb1       2.0G   24K  1.8G   1% /mnt/lab-ext4
/dev/sdb2       3.0G   33M  3.0G   2% /mnt/lab-xfs
```

Confirm test files survived:

```bash
cat /mnt/lab-ext4/test.txt
cat /mnt/lab-xfs/test.txt
```

---

## Step 9: Reboot and Verify Persistence

```bash
sudo reboot
```

After the VM comes back up:

```bash
df -h | grep lab
cat /mnt/lab-ext4/test.txt
cat /mnt/lab-xfs/test.txt
```

Both filesystems mounted automatically with data intact. This is persistent storage.

---

## Try Breaking It

### Wrong UUID in fstab

1. Edit `/etc/fstab` — change one character in the ext4 UUID
2. Run `sudo umount /mnt/lab-ext4 && sudo mount -a`

Result: `mount: /mnt/lab-ext4: can't find UUID=...`

Without `nofail`, this would drop the system to emergency mode on reboot. Fix by restoring the correct UUID.

### Wrong Filesystem Type

1. Change the type for `/mnt/lab-xfs` from `xfs` to `ext4` in fstab
2. Run `sudo umount /mnt/lab-xfs && sudo mount -a`

Result: `mount: /mnt/lab-xfs: wrong fs type, bad option, bad superblock on /dev/sdb2...`

Fix by restoring the correct type.

### Missing Mount Point

1. `sudo umount /mnt/lab-ext4 && sudo rmdir /mnt/lab-ext4`
2. `sudo mount -a`

Result: `mount: /mnt/lab-ext4: mount point does not exist.`

Fix: `sudo mkdir /mnt/lab-ext4`

---

## Verification Checklist

- [ ] Added a virtual disk and found it with `lsblk`
- [ ] Created two partitions with `fdisk`
- [ ] Created ext4 and XFS filesystems
- [ ] Mounted both and wrote test files
- [ ] Added UUID-based fstab entries with `nofail`
- [ ] Tested with `mount -a` before rebooting
- [ ] Both filesystems persisted after reboot
- [ ] Understand failure modes: wrong UUID, wrong type, missing mount point

---

## Cleanup (Optional)

If keeping the disk for Lab 10.2, leave everything as is. Otherwise:

```bash
sudo umount /mnt/lab-ext4 /mnt/lab-xfs
sudo rmdir /mnt/lab-ext4 /mnt/lab-xfs
sudo nano /etc/fstab   # Remove the Lab 10.1 entries
```
