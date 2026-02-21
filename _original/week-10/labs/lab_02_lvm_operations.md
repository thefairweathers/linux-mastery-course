# Lab 10.2: LVM Operations

> **Objective:** Create a full LVM stack (PV → VG → LV), format, mount, write data, then extend the LV and grow the filesystem without unmounting. Practice on both ext4 and XFS.
>
> **Concepts practiced:** pvcreate, vgcreate, lvcreate, lvextend, resize2fs, xfs_growfs, pvs, vgs, lvs
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Ubuntu (use the disk added in Lab 10.1, or add another)

---

## Prerequisites

You need a disk that is not currently in use.

**Option A — Reuse the disk from Lab 10.1:**

```bash
sudo umount /mnt/lab-ext4 /mnt/lab-xfs
sudo nano /etc/fstab   # Remove the Lab 10.1 entries
sudo wipefs -a /dev/sdb
```

**Option B — Add a new 5 GB disk** in Parallels (same steps as Lab 10.1). It will likely appear as `/dev/sdc` — adjust device names accordingly.

This lab uses `/dev/sdb`. Install LVM tools if needed:

| Distro | Install Command |
|--------|----------------|
| Ubuntu | `sudo apt install lvm2` |
| Rocky  | `sudo dnf install lvm2` |

---

## Step 1: Create a Physical Volume

```bash
sudo pvcreate /dev/sdb
```

```text
  Physical volume "/dev/sdb" successfully created.
```

**Verify:**

```bash
sudo pvs
```

```text
  PV         VG   Fmt  Attr PSize  PFree
  /dev/sdb        lvm2 a--  <5.00g <5.00g
```

The VG column is empty — this PV hasn't been assigned to a volume group yet.

---

## Step 2: Create a Volume Group

```bash
sudo vgcreate vg_lab /dev/sdb
```

```text
  Volume group "vg_lab" successfully created
```

**Verify:**

```bash
sudo vgs
```

```text
  VG     #PV #LV #SN Attr   VSize  VFree
  vg_lab   1   0   0 wz--n- <5.00g <5.00g
```

One PV, zero LVs, all 5 GB free.

---

## Step 3: Create Two Logical Volumes

One for ext4, one for XFS — to practice both resize methods:

```bash
sudo lvcreate -n lv_ext4 -L 1.5G vg_lab
sudo lvcreate -n lv_xfs -L 1.5G vg_lab
```

**Verify:**

```bash
sudo lvs
```

```text
  LV      VG     Attr       LSize
  lv_ext4 vg_lab -wi-a----- 1.50g
  lv_xfs  vg_lab -wi-a----- 1.50g
```

Check remaining VG space:

```bash
sudo vgs
```

```text
  VG     #PV #LV #SN Attr   VSize  VFree
  vg_lab   1   2   0 wz--n- <5.00g <2.00g
```

About 2 GB free — we'll use this to extend the LVs later.

---

## Step 4: Create Filesystems and Mount

```bash
sudo mkfs.ext4 -L "lvm-ext4" /dev/vg_lab/lv_ext4
sudo mkfs.xfs -L "lvm-xfs" /dev/vg_lab/lv_xfs

sudo mkdir -p /mnt/lvm-ext4 /mnt/lvm-xfs
sudo mount /dev/vg_lab/lv_ext4 /mnt/lvm-ext4
sudo mount /dev/vg_lab/lv_xfs /mnt/lvm-xfs
```

**Verify:**

```bash
df -h /mnt/lvm-ext4 /mnt/lvm-xfs
```

```text
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/vg_lab-lv_ext4  1.5G   24K  1.4G   1% /mnt/lvm-ext4
/dev/mapper/vg_lab-lv_xfs   1.5G   33M  1.5G   3% /mnt/lvm-xfs
```

Note: `df` shows `/dev/mapper/` paths — these are the same devices as `/dev/vg_lab/lv_*`.

---

## Step 5: Write Test Data

Write data with checksums so we can prove it survives the resize:

```bash
echo "This data must survive the ext4 resize." | sudo tee /mnt/lvm-ext4/survive_test.txt
sudo dd if=/dev/urandom of=/mnt/lvm-ext4/random_data.bin bs=1M count=50 2>/dev/null
md5sum /mnt/lvm-ext4/random_data.bin | sudo tee /mnt/lvm-ext4/checksum.txt

echo "This data must survive the XFS resize." | sudo tee /mnt/lvm-xfs/survive_test.txt
sudo dd if=/dev/urandom of=/mnt/lvm-xfs/random_data.bin bs=1M count=50 2>/dev/null
md5sum /mnt/lvm-xfs/random_data.bin | sudo tee /mnt/lvm-xfs/checksum.txt
```

---

## Step 6: Extend the ext4 Logical Volume

This is the core exercise — extending the LV and growing the filesystem while it's still mounted.

### Extend the LV:

```bash
sudo lvextend -L +1G /dev/vg_lab/lv_ext4
```

```text
  Size of logical volume vg_lab/lv_ext4 changed from 1.50 GiB to 2.50 GiB.
  Logical volume vg_lab/lv_ext4 successfully resized.
```

### Check the gap between LV and filesystem:

```bash
sudo lvs /dev/vg_lab/lv_ext4
df -h /mnt/lvm-ext4
```

The LV reports 2.5 GB, but `df` still shows 1.5 GB — the filesystem doesn't know about the extra space yet.

### Grow the ext4 filesystem:

```bash
sudo resize2fs /dev/vg_lab/lv_ext4
```

```text
Filesystem at /dev/vg_lab/lv_ext4 is mounted on /mnt/lvm-ext4; on-line resizing required
The filesystem on /dev/vg_lab/lv_ext4 is now 655360 (4k) blocks long.
```

### Verify it worked:

```bash
df -h /mnt/lvm-ext4
```

```text
Filesystem                  Size  Used Avail Use% Mounted on
/dev/mapper/vg_lab-lv_ext4  2.5G   51M  2.3G   3% /mnt/lvm-ext4
```

### Verify data survived:

```bash
cat /mnt/lvm-ext4/survive_test.txt
md5sum /mnt/lvm-ext4/random_data.bin
cat /mnt/lvm-ext4/checksum.txt
```

The md5sum output should match the checksum file.

---

## Step 7: Extend the XFS Logical Volume

Same process, different resize command. XFS uses `xfs_growfs` with the **mount point** (not device path).

```bash
sudo lvextend -L +1G /dev/vg_lab/lv_xfs
sudo xfs_growfs /mnt/lvm-xfs
```

```text
data blocks changed from 393216 to 655360
```

### Verify:

```bash
df -h /mnt/lvm-xfs
```

```text
Filesystem                 Size  Used Avail Use% Mounted on
/dev/mapper/vg_lab-lv_xfs  2.5G   83M  2.4G   4% /mnt/lvm-xfs
```

### Verify data survived:

```bash
cat /mnt/lvm-xfs/survive_test.txt
md5sum /mnt/lvm-xfs/random_data.bin
cat /mnt/lvm-xfs/checksum.txt
```

Checksums match.

---

## Step 8: The lvextend -r Shortcut

In production, use `-r` to combine extend and resize in one command:

```bash
# If VG has remaining free space:
sudo lvextend -r -l +100%FREE /dev/vg_lab/lv_ext4
```

The `-r` flag detects the filesystem type and runs the appropriate resize tool automatically. This is the command you'll use 99% of the time.

---

## Step 9: Review the Full Stack

```bash
sudo pvs
```

```text
  PV         VG     Fmt  Attr PSize  PFree
  /dev/sdb   vg_lab lvm2 a--  <5.00g    0
```

```bash
sudo vgs
```

```text
  VG     #PV #LV #SN Attr   VSize  VFree
  vg_lab   1   2   0 wz--n- <5.00g    0
```

```bash
sudo lvs
```

```text
  LV      VG     Attr       LSize
  lv_ext4 vg_lab -wi-ao---- 2.50g
  lv_xfs  vg_lab -wi-ao---- 2.50g
```

```bash
lsblk /dev/sdb
```

```text
NAME              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sdb                 8:16   0    5G  0 disk
├─vg_lab-lv_ext4  253:0    0  2.5G  0 lvm  /mnt/lvm-ext4
└─vg_lab-lv_xfs   253:1    0  2.5G  0 lvm  /mnt/lvm-xfs
```

The TYPE column shows `lvm` instead of `part`.

---

## Key Differences to Remember

| Operation | ext4 | XFS |
|-----------|------|-----|
| Resize command | `resize2fs /dev/vg_lab/lv_ext4` | `xfs_growfs /mnt/lvm-xfs` |
| Takes | Device path | Mount point |
| Can grow online | Yes | Yes |
| Can shrink | Yes (offline only) | No (never) |
| Combined with lvextend -r | Yes | Yes |

---

## Verification Checklist

- [ ] Created a physical volume with `pvcreate` and verified with `pvs`
- [ ] Created a volume group with `vgcreate` and verified with `vgs`
- [ ] Created two logical volumes with `lvcreate` and verified with `lvs`
- [ ] Formatted one LV as ext4 and one as XFS
- [ ] Mounted both LVs and wrote test data with checksums
- [ ] Extended the ext4 LV and grew the filesystem with `resize2fs`
- [ ] Extended the XFS LV and grew the filesystem with `xfs_growfs`
- [ ] All test data survived both resize operations (checksums match)
- [ ] Understand that `resize2fs` takes a device path, `xfs_growfs` takes a mount point
- [ ] Know that `lvextend -r` automates the resize step

---

## Cleanup (Optional)

```bash
sudo umount /mnt/lvm-ext4 /mnt/lvm-xfs
sudo lvremove /dev/vg_lab/lv_ext4 && sudo lvremove /dev/vg_lab/lv_xfs
sudo vgremove vg_lab && sudo pvremove /dev/sdb && sudo rmdir /mnt/lvm-ext4 /mnt/lvm-xfs
```
