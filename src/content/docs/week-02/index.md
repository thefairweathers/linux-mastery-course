---
title: "Week 2: The Shell & Navigating the Filesystem"
sidebar:
  order: 0
---


> **Goal:** Navigate the Linux filesystem, understand paths, and manage files and directories from the command line.


---

## 2.1 What Is a Shell?

When you type commands into your Linux terminal, you're not talking directly to the kernel. You're talking to a program called a **shell** — an interactive command interpreter that reads what you type, figures out what you mean, and asks the kernel to do the work. The shell is your primary interface to a Linux server. No mouse. No icons. Just text.

Think of the shell as a translator between you and the operating system. You say `ls /etc` and the shell parses that into "call the `ls` program with `/etc` as an argument," handles finding the program, launching it, and showing you the output.

### Which Shell Are We Using?

Several shells exist. Here are the ones you'll encounter:

| Shell | Full Name | Notes |
|-------|-----------|-------|
| `bash` | Bourne Again Shell | Default on most Linux servers. The one we use throughout this course. |
| `sh` | Bourne Shell | The original Unix shell. On modern Linux, `/bin/sh` is usually a link to `bash` or `dash`. |
| `zsh` | Z Shell | Default on macOS since Catalina. Popular for interactive use. Very similar to bash. |
| `fish` | Friendly Interactive Shell | User-friendly but not POSIX-compatible. Rare on servers. |
| `dash` | Debian Almquist Shell | Fast and minimal. Used for system scripts on Debian/Ubuntu, not interactive use. |

For server administration, bash is the standard. Scripts you find online, configuration examples, CI/CD pipelines — nearly all assume bash. That's what we'll use.

Verify your current shell on either VM:

```bash
echo "$SHELL"
```

**Expected output:**

```text
/bin/bash
```

You can also check which shell is actively running:

```bash
ps -p $$
```

The `$$` variable holds the process ID of your current shell. The output shows `bash` in the `CMD` column.

### The Prompt Revisited

Your prompt tells you who you are, where you are, and what machine you're on. From Week 1 you already know the format:

```text
student@ubuntu-vm:~$          # Ubuntu format
[student@rocky-vm ~]$          # Rocky format
```

The `~` represents your **home directory** — we'll cover that shortly. The `$` means you're a regular user. If you ever see `#`, you're running as root (the superuser), and you should be very careful about what you type.

---

## 2.2 The Linux Filesystem Hierarchy

On Windows, you have `C:\`, `D:\`, and each drive is its own tree. Linux takes a fundamentally different approach: there's one tree, and everything — every file, device, process, and configuration — hangs off a single root: `/`.

This isn't arbitrary. The **Filesystem Hierarchy Standard (FHS)** defines where things go, and every major distribution follows it. Once you learn this layout, you can walk into any Linux server and know where to look.

Here are the directories that matter most for server administration:

| Directory | Purpose | Why you care |
|-----------|---------|-------------|
| `/` | The root of the entire filesystem | Everything starts here |
| `/home` | User home directories (`/home/student`, etc.) | Where your files live |
| `/root` | Home directory for the root user | Separate from `/home` for security |
| `/etc` | System configuration files | Where you edit server configs (nginx, SSH, networking) |
| `/var` | Variable data — things that change at runtime | Logs (`/var/log`), mail, spool files |
| `/var/log` | System and application log files | First place to look when something breaks |
| `/tmp` | Temporary files — cleared on reboot | Safe scratch space for one-off work |
| `/usr` | User programs and read-only data | Most installed software lives here |
| `/usr/bin` | Standard user commands | `ls`, `grep`, `vim`, `python3` |
| `/usr/sbin` | System administration commands | `fdisk`, `iptables`, `useradd` |
| `/bin` | Essential user commands (often symlinked to `/usr/bin`) | On modern distros, merged with `/usr/bin` |
| `/sbin` | Essential system commands (often symlinked to `/usr/sbin`) | On modern distros, merged with `/usr/sbin` |
| `/opt` | Optional/third-party software | Commercial apps, manually installed tools |
| `/srv` | Data for services provided by the system | Web content, FTP data (convention varies) |
| `/dev` | Device files | Hardware represented as files (disks, terminals) |
| `/proc` | Virtual filesystem — process and kernel info | Not real files, but runtime system data |
| `/sys` | Virtual filesystem — hardware/driver info | Similar to `/proc`, more structured |
| `/boot` | Boot loader and kernel files | Rarely touched after install |
| `/mnt` | Temporary mount point | For manually mounting filesystems |
| `/media` | Removable media mount point | USB drives, CDs |

### Why This Matters for Server Administration

When you're administering a Linux server, you're constantly working with three of these:

**`/etc`** — This is where configuration lives. Need to change the SSH port? Edit `/etc/ssh/sshd_config`. Need to modify DNS settings? Check `/etc/resolv.conf`. Add a new user's shell? Look at `/etc/passwd`. Every service you install puts its configuration here.

**`/var/log`** — When a service fails, when a user can't log in, when disk space fills up — you check the logs. On Ubuntu, the main system log is `/var/log/syslog`. On Rocky, it's `/var/log/messages`. Application logs go here too: `/var/log/nginx/`, `/var/log/mysql/`, and so on.

**`/var/www`** or **`/srv`** — Web content. When you deploy a website, the files go in one of these directories. The convention varies between distributions and web servers, but the principle is the same: data served to the network lives under `/var` or `/srv`, not in your home directory.

### The /usr Merge

On modern Ubuntu and Rocky Linux, `/bin` is a symbolic link to `/usr/bin`, and `/sbin` is a symbolic link to `/usr/sbin`. This is called the **usrmerge**. You'll see this if you inspect them:

```bash
ls -ld /bin
```

**Expected output:**

```text
lrwxrwxrwx 1 root root 7 ... /bin -> usr/bin
```

This means `/bin/ls` and `/usr/bin/ls` are the same file. You can use either path. Older documentation may reference `/bin/bash` while newer systems show `/usr/bin/bash` — they're identical. Don't let this confuse you.

---

## 2.3 Absolute vs. Relative Paths

Every file and directory on a Linux system has an address. There are two ways to write that address.

An **absolute path** starts from the root (`/`) and spells out the complete location:

```text
/home/student/documents/report.txt
/etc/ssh/sshd_config
/var/log/syslog
```

Absolute paths are unambiguous. No matter where you are in the filesystem, `/etc/ssh/sshd_config` always means the same file.

A **relative path** starts from wherever you currently are:

```text
documents/report.txt        # from /home/student
../student/documents        # from /home/someuser
./script.sh                 # current directory
```

Three special symbols make relative paths work:

| Symbol | Meaning | Example |
|--------|---------|---------|
| `.` | Current directory | `./script.sh` runs a script in the current directory |
| `..` | Parent directory (one level up) | `cd ..` moves up one directory |
| `~` | Your home directory (`/home/student`) | `cd ~` goes home from anywhere |

Here's how they connect. If you're in `/home/student`:

```bash
# These all refer to the same file:
cat /home/student/notes.txt     # absolute
cat notes.txt                   # relative (from /home/student)
cat ./notes.txt                 # relative with explicit current dir
cat ~/notes.txt                 # using home shortcut
```

And from `/var/log`, to reach the same file:

```bash
cat /home/student/notes.txt         # absolute always works
cat ../../home/student/notes.txt    # relative: up two levels from /var/log, then down
```

Relative paths get unwieldy fast when you're far from the target. In scripts and documentation, prefer absolute paths — they're always clear. In interactive use, relative paths save typing when you're nearby.

---

## 2.4 Essential Navigation: pwd, cd, ls

These three commands are your compass, your legs, and your eyes.

### pwd — Print Working Directory

Always know where you are:

```bash
pwd
```

**Expected output:**

```text
/home/student
```

This is your anchor. When you're lost, `pwd` tells you exactly where you are in the filesystem tree.

### cd — Change Directory

Move around the filesystem:

```bash
# Go to an absolute path
cd /var/log

# Go up one level
cd ..

# Go to a subdirectory (relative)
cd nginx

# Go home (three equivalent ways)
cd
cd ~
cd /home/student

# Go to the previous directory (toggle)
cd -
```

That last one — `cd -` — is remarkably useful. It switches between your current and previous directory, like an "undo" for navigation. If you're bouncing between `/etc/nginx` and `/var/log/nginx` while debugging, `cd -` saves you from retyping the full path each time.

### ls — List Directory Contents

`ls` shows you what's in a directory. By itself, it's minimal:

```bash
ls
```

The real power is in the flags:

| Flag | Purpose | Example |
|------|---------|---------|
| `-l` | Long format — permissions, owner, size, date | `ls -l` |
| `-a` | Show all files, including hidden (dotfiles) | `ls -a` |
| `-h` | Human-readable sizes (KB, MB, GB) | `ls -lh` |
| `-R` | Recursive — show subdirectories too | `ls -R` |
| `-t` | Sort by modification time (newest first) | `ls -lt` |
| `-r` | Reverse sort order | `ls -ltr` |
| `-S` | Sort by file size (largest first) | `ls -lS` |
| `-d` | Show directory itself, not its contents | `ls -ld /etc` |

You can combine flags. The most common combination for daily work is:

```bash
ls -lah
```

This gives you the long format, including hidden files, with human-readable sizes.

Try it in your home directory:

```bash
ls -lah ~
```

**Expected output (similar to):**

```text
total 36K
drwxr-x--- 4 student student 4.0K Feb 20 10:00 .
drwxr-xr-x 3 root    root    4.0K Feb 15 09:00 ..
-rw------- 1 student student  220 Feb 15 09:00 .bash_history
-rw-r--r-- 1 student student  220 Feb 15 09:00 .bash_logout
-rw-r--r-- 1 student student 3.7K Feb 15 09:00 .bashrc
drwx------ 2 student student 4.0K Feb 15 09:05 .cache
-rw-r--r-- 1 student student  807 Feb 15 09:00 .profile
drwx------ 2 student student 4.0K Feb 15 09:05 .ssh
```

Notice the files starting with `.` — these are **hidden files** (also called dotfiles). They don't show up with plain `ls`, only with `ls -a`. Configuration files in your home directory are typically hidden so they don't clutter your view.

---

## 2.5 Reading ls -l Output

The long listing format packs a lot of information into a single line. Let's decode it:

```text
-rw-r--r-- 1 student student 3.7K Feb 15 09:00 .bashrc
```

Each field, left to right:

| Field | Value | Meaning |
|-------|-------|---------|
| File type | `-` | Regular file (`d` = directory, `l` = symbolic link) |
| Permissions | `rw-r--r--` | Owner can read+write, group can read, others can read |
| Hard links | `1` | Number of hard links to this file |
| Owner | `student` | The user who owns this file |
| Group | `student` | The group that owns this file |
| Size | `3.7K` | File size (with `-h` flag) |
| Timestamp | `Feb 15 09:00` | Last modification time |
| Name | `.bashrc` | The filename |

### File Type Indicator

The first character tells you what kind of entry this is:

| Character | Type |
|-----------|------|
| `-` | Regular file |
| `d` | Directory |
| `l` | Symbolic link |
| `c` | Character device |
| `b` | Block device |
| `p` | Named pipe |
| `s` | Socket |

You'll mostly see `-`, `d`, and `l`. The others appear in `/dev` and special locations.

### Permission Blocks

The nine characters after the file type are three blocks of three:

```text
rw-  r--  r--
│    │    │
│    │    └── Others (everyone else)
│    └─────── Group (members of the owning group)
└──────────── Owner (the file's user)
```

Each position is either a permission letter or `-` (denied):

| Letter | Meaning |
|--------|---------|
| `r` | Read — view the file contents (or list a directory) |
| `w` | Write — modify the file (or create/delete files in a directory) |
| `x` | Execute — run as a program (or enter a directory with `cd`) |
| `-` | That permission is not granted |

So `rw-r--r--` means: the owner can read and write, the group can only read, and everyone else can only read. No one can execute it (it's not a program).

We'll spend all of Week 5 on permissions. For now, just practice reading these fields so they become second nature.

---

## 2.6 File Operations

Now let's create, copy, move, and remove files and directories. These operations are fundamental — you'll use them every single day.

### touch — Create Files (or Update Timestamps)

`touch` creates an empty file if it doesn't exist, or updates the timestamp if it does:

```bash
touch myfile.txt
ls -l myfile.txt
```

**Expected output:**

```text
-rw-rw-r-- 1 student student 0 Feb 20 10:30 myfile.txt
```

Note the size: `0`. The file exists but is empty. `touch` is the quickest way to create placeholder files.

Create multiple files at once:

```bash
touch file1.txt file2.txt file3.txt
```

### mkdir — Create Directories

```bash
mkdir projects
```

To create a nested structure in one command, use the `-p` flag (create **p**arent directories as needed):

```bash
mkdir -p projects/webapp/src/templates
```

Without `-p`, this would fail because `projects/webapp/src` doesn't exist yet. With `-p`, `mkdir` creates each directory in the chain.

Verify the structure:

```bash
ls -R projects
```

**Expected output:**

```text
projects:
webapp

projects/webapp:
src

projects/webapp/src:
templates

projects/webapp/src/templates:
```

### cp — Copy Files and Directories

Copy a single file:

```bash
cp myfile.txt myfile_backup.txt
```

Copy a file into a directory:

```bash
cp myfile.txt projects/
```

Copy a directory and all its contents (the `-r` flag means **recursive**):

```bash
cp -r projects projects_backup
```

Without `-r`, `cp` refuses to copy directories. This is a safety feature — it forces you to be explicit about copying an entire directory tree.

### mv — Move and Rename

`mv` serves double duty. It moves files between locations *and* renames them — because in Linux, renaming is just "moving a file to a new name in the same directory."

Move a file into a directory:

```bash
mv myfile.txt projects/
```

Rename a file:

```bash
mv file1.txt report.txt
```

Move and rename in one step:

```bash
mv file2.txt projects/data.txt
```

Rename a directory:

```bash
mv projects_backup old_projects
```

Unlike `cp`, `mv` doesn't need `-r` for directories. It's just updating the directory entry, not copying data.

### rm — Remove Files

```bash
rm file3.txt
```

Remove a directory and everything inside it:

```bash
rm -r old_projects
```

The `-r` flag (recursive) deletes the directory and all its contents. Add `-f` (force) to suppress confirmation prompts:

```bash
rm -rf old_projects
```

A critical warning: **`rm` does not have a trash can.** When you `rm` a file, it's gone. There's no recycle bin, no undo. On a server, `rm -rf /` with root privileges will destroy your entire system. Always double-check your paths before pressing Enter, especially when using wildcards or variables.

Good habits that prevent disasters:

```bash
# List first, then delete
ls projects/temp/*.log         # see what would match
rm projects/temp/*.log         # now delete them

# Use -i for interactive confirmation on critical deletions
rm -ri important_directory/
```

### rmdir — Remove Empty Directories

`rmdir` only removes directories that are completely empty:

```bash
mkdir empty_dir
rmdir empty_dir           # works
mkdir -p full_dir/subdir
rmdir full_dir            # fails: directory is not empty
```

`rmdir` is safer than `rm -r` when you expect a directory to be empty. If it fails, something is still in there that you should investigate before deleting.

---

## 2.7 Wildcards and Globbing

Typing filenames one at a time gets old fast. **Wildcards** (also called **globs**) let you match multiple files with a pattern. The shell expands the pattern before the command runs — the command itself never sees the wildcards.

### The Star: `*`

Matches zero or more characters:

```bash
# List all .txt files
ls *.txt

# List all files starting with "report"
ls report*

# List all files with any extension
ls *.*

# Copy all .conf files to a backup directory
cp /etc/*.conf ~/config_backup/
```

### The Question Mark: `?`

Matches exactly one character:

```bash
# Match file1.txt, file2.txt, file3.txt but not file10.txt
ls file?.txt

# Match any three-letter filename with .log extension
ls ???.log
```

### Brackets: `[]`

Match any single character from a set:

```bash
# Match file1.txt, file2.txt, file3.txt
ls file[123].txt

# Match file1.txt through file5.txt (range)
ls file[1-5].txt

# Match files starting with a capital letter
ls [A-Z]*
```

### Braces: `{}`

Expand into specific comma-separated values. Unlike the others, braces aren't technically globbing — they're **brace expansion**, a bash feature:

```bash
# Create multiple files at once
touch report_{jan,feb,mar}.txt
ls report_*.txt
```

**Expected output:**

```text
report_feb.txt  report_jan.txt  report_mar.txt
```

```bash
# Create a directory structure in one command
mkdir -p project/{src,config,docs,tests}
```

Braces are especially useful for creating predictable structures and for commands that don't support wildcards directly.

### Combining Wildcards

Wildcards compose naturally:

```bash
# All .txt files starting with "data" in any subdirectory one level deep
ls */data*.txt

# All .log files in /var/log (that you can read)
ls /var/log/*.log
```

### A Crucial Detail: The Shell Expands Wildcards

When you type `ls *.txt`, the shell finds all matching files *before* `ls` runs. If there are three `.txt` files, `ls` actually receives `ls file1.txt file2.txt file3.txt`. The `ls` program never sees the `*`.

This matters when no files match:

```bash
ls *.xyz
```

If no `.xyz` files exist, bash passes the literal string `*.xyz` to `ls`, and `ls` reports "no such file." Other shells handle this differently. In bash, you can change this behavior, but the default is what you'll encounter on servers.

---

## 2.8 Identifying File Types with file

Filenames on Linux are just labels — the extension doesn't determine the file type. A file called `image.txt` could contain a PNG. A file with no extension could be a bash script. The `file` command examines the actual contents to determine what a file is:

```bash
file /etc/hostname
```

**Expected output:**

```text
/etc/hostname: ASCII text
```

```bash
file /usr/bin/ls
```

**Expected output:**

```text
/usr/bin/ls: ELF 64-bit LSB pie executable, ARM aarch64, ...
```

```bash
file /etc/ssh
```

**Expected output:**

```text
/etc/ssh: directory
```

`file` is invaluable when you encounter unknown files on a server. Download a file and not sure what it is? `file mystery_download` tells you immediately whether it's a tarball, a script, an image, or a binary.

Try it on a few common files:

```bash
file /etc/passwd
file /etc/shadow
file ~/.bashrc
file /dev/null
```

Each produces a different result because each file has different contents, regardless of its name.

---

## 2.9 Detailed Metadata with stat

While `ls -l` gives you the essentials, `stat` gives you everything the filesystem knows about a file:

```bash
stat ~/.bashrc
```

**Expected output (Ubuntu):**

```text
  File: /home/student/.bashrc
  Size: 3771         Blocks: 8          IO Block: 4096   regular file
Device: 801h/2049d   Inode: 262147      Links: 1
Access: (0644/-rw-r--r--)  Uid: ( 1000/ student)   Gid: ( 1000/ student)
Access: 2026-02-20 10:00:00.000000000 -0500
Modify: 2026-02-15 09:00:00.000000000 -0500
Change: 2026-02-15 09:00:00.000000000 -0500
 Birth: 2026-02-15 09:00:00.000000000 -0500
```

There are three timestamps (this confuses everyone at first):

| Timestamp | What it tracks | Updated when... |
|-----------|----------------|-----------------|
| **Access** (atime) | Last time the file was read | You `cat` or `less` the file |
| **Modify** (mtime) | Last time the contents changed | You edit and save the file |
| **Change** (ctime) | Last time metadata changed | Permissions, ownership, or content changes |

The `ls -l` timestamp is **mtime** — when the content was last modified. This is almost always the one you care about.

`stat` also shows the **inode** number — a unique identifier for the file on the filesystem. You won't need inodes often, but they matter when dealing with hard links and filesystem troubleshooting.

---

## 2.10 Tab Completion and Command History

Efficient shell use isn't about memorizing everything — it's about typing less and finding things fast.

### Tab Completion

The single most important productivity feature in bash. Press **Tab** to auto-complete:

```bash
# Type this much, then press Tab:
cd /etc/ssh/ss
# Bash completes it to:
cd /etc/ssh/sshd_config
```

If there are multiple matches, press Tab twice to see all options:

```bash
ls /etc/ss        # press Tab twice
# Shows:
# ssh/   ssl/
```

Tab completion works for:
- File and directory paths
- Command names
- Some command arguments (if bash-completion is installed)

Use it relentlessly. It saves time and prevents typos.

### Command History

Bash remembers every command you type (stored in `~/.bash_history`). Several tools let you access that history:

**The `history` command** shows your recent commands with line numbers:

```bash
history
```

**Expected output:**

```text
    1  cat /etc/os-release
    2  ls -la
    3  cd /var/log
    4  pwd
    ...
```

**History shortcuts:**

| Shortcut | What it does |
|----------|-------------|
| `!!` | Repeat the last command |
| `!$` | Use the last argument of the previous command |
| `!N` | Repeat command number N from history |
| `!string` | Repeat the most recent command starting with `string` |

The most useful of these is `!$`. Watch:

```bash
mkdir -p /home/student/projects/webapp
cd !$
# cd receives /home/student/projects/webapp
```

And `!!` is commonly used with `sudo` when you forget you need elevated privileges:

```bash
cat /etc/shadow              # Permission denied
sudo !!                      # Reruns as: sudo cat /etc/shadow
```

### Ctrl+R — Reverse History Search

This is the power move. Press **Ctrl+R** and start typing any part of a previous command. Bash searches backward through your history:

```text
(reverse-i-search)`ssh': ssh student@10.211.55.3
```

Press **Ctrl+R** again to cycle through older matches. Press **Enter** to execute the found command, or **Ctrl+C** to cancel.

When you're managing servers and regularly running long commands with multiple flags, Ctrl+R is faster than retyping and more reliable than the up arrow.

### Other Useful Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Ctrl+A** | Move cursor to beginning of line |
| **Ctrl+E** | Move cursor to end of line |
| **Ctrl+W** | Delete the word before the cursor |
| **Ctrl+U** | Delete from cursor to beginning of line |
| **Ctrl+K** | Delete from cursor to end of line |
| **Ctrl+L** | Clear the screen (same as `clear` command) |

---

## 2.11 Creating Aliases

If you find yourself typing the same long command repeatedly, create an **alias** — a shortcut:

```bash
alias ll='ls -lah'
alias la='ls -la'
alias ..='cd ..'
alias ...='cd ../..'
```

Now `ll` runs `ls -lah`, `..` moves up one directory, and so on. Test it:

```bash
alias ll='ls -lah'
ll /etc
```

Check what aliases are currently defined:

```bash
alias
```

Remove an alias:

```bash
unalias ll
```

### Making Aliases Permanent

Aliases defined on the command line disappear when you log out. To make them permanent, add them to your `~/.bashrc` file:

```bash
echo 'alias ll="ls -lah"' >> ~/.bashrc
echo 'alias la="ls -la"' >> ~/.bashrc
echo 'alias ..="cd .."' >> ~/.bashrc
```

The `>>` operator appends to the file (we'll cover redirection in Week 3). After editing `.bashrc`, load the changes in your current session:

```bash
source ~/.bashrc
```

Or simply log out and back in.

Some practical aliases used by working system administrators:

```bash
alias grep='grep --color=auto'       # Highlight matches
alias df='df -h'                      # Always human-readable
alias free='free -h'                  # Always human-readable
alias mkdir='mkdir -pv'               # Always create parents, verbose
alias ports='ss -tulnp'              # Show listening ports
```

Don't go overboard with aliases. If you create an alias that shadows a real command (like `alias rm='rm -i'`), you'll develop habits that don't transfer to other systems. Use aliases to add flags to commands you always use the same way, not to rename commands.

---

## 2.12 Distro Differences

At this level — shell basics, filesystem navigation, file operations — Ubuntu and Rocky Linux are virtually identical. The same commands, same paths, same behavior. The FHS ensures `/etc`, `/var`, `/home`, and the rest are in the same place on both.

A few minor differences you might notice:

| Area | Ubuntu | Rocky Linux |
|------|--------|-------------|
| Default prompt format | `user@host:dir$` | `[user@host dir]$` |
| Default `ls` colors | Enabled | Enabled |
| Bash version | Usually 5.2+ | Usually 5.1+ |
| `~/.bashrc` contents | Includes some aliases and color settings | More minimal |
| `/var/log/syslog` | Present (main system log) | Absent (use `/var/log/messages` instead) |
| Bash-completion package | Usually pre-installed | May need `dnf install bash-completion` |

The log file difference is worth noting. When you're troubleshooting on Ubuntu, you check `/var/log/syslog`. On Rocky (and all RHEL-family systems), you check `/var/log/messages`. Same purpose, different name. Both systems also support `journalctl` for reading systemd logs, which we'll cover in Week 11.

If tab completion feels incomplete on Rocky's minimal install, add the bash-completion package:

```bash
sudo dnf install bash-completion
```

Then log out and back in for it to take effect.

---

## 2.13 Putting It All Together

Let's combine everything from this week in a realistic sequence. Imagine you've just SSH'd into a new server and want to understand its layout:

```bash
# Where am I?
pwd

# What's in my home directory?
ls -lah

# What Linux is this?
cat /etc/os-release

# Explore the filesystem
cd /etc
ls | head -20                   # first 20 entries
ls -la ssh/                     # SSH configuration
cd /var/log
ls -lt | head -10               # 10 most recently modified logs

# Create a working area
cd ~
mkdir -p projects/{scripts,configs,data}
touch projects/scripts/deploy.sh
touch projects/configs/{app.conf,db.conf}
touch projects/data/users.csv

# Verify the structure
ls -R projects/

# Check what kind of files we're dealing with
file projects/scripts/deploy.sh
file /etc/passwd

# Create a quick alias for this session
alias ll='ls -lah'
ll projects/

# Check where we've been
history | tail -20
```

This is the typical rhythm of working on a Linux server: navigate, inspect, create, verify. Every command you learned this week is a tool in that rhythm.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 2.1: Filesystem Exploration](./lab-01-filesystem-exploration)** — Navigate the filesystem, explore key directories, compare Ubuntu and Rocky
- **[Lab 2.2: File Operations](./lab-02-file-operations)** — Create a mock project structure, practice file operations and wildcards

---

## Checklist

Before moving to Week 3, confirm you can:

- [ ] Explain what a shell is and identify which shell you're using
- [ ] Navigate the filesystem using cd with absolute and relative paths
- [ ] List files with ls and interpret ls -l output (permissions, owner, size, date)
- [ ] Create files and directories including nested structures with mkdir -p
- [ ] Copy, move, and rename files and directories
- [ ] Remove files and directories safely
- [ ] Use wildcards (*, ?, []) to match multiple files
- [ ] Identify file types with the file command
- [ ] Use tab completion and search command history with Ctrl+R
- [ ] Create aliases for frequently used commands
- [ ] Name at least 5 important directories and explain their purpose

---

