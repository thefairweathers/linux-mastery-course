# Lab 2.2: File Operations

> **Objective:** Create a mock web project directory structure, practice copying, moving, renaming files, and using wildcards for batch operations.
>
> **Concepts practiced:** mkdir, touch, cp, mv, rm, wildcards, file command
>
> **Time estimate:** 30 minutes
>
> **VM(s) needed:** Ubuntu (exercises work identically on Rocky)

---

## Setup

SSH into your Ubuntu VM and confirm you're in your home directory:

```bash
ssh student@<ubuntu-ip>
cd ~
pwd
```

**Expected output:** `/home/student`

---

## Part 1: Build a Project Structure

### Step 1: Create the project skeleton

```bash
mkdir -p ~/webapp/{src,config,logs,data,backups,docs}
mkdir -p ~/webapp/src/{templates,static/{css,js,images}}
mkdir -p ~/webapp/config/{dev,staging,prod}
```

Verify the structure:

```bash
ls -R ~/webapp
```

You should see the full tree: `src/` with `templates/` and `static/` subdirectories, `config/` with `dev/`, `staging/`, and `prod/`, plus `logs/`, `data/`, `backups/`, and `docs/`.

### Step 2: Create project files

```bash
# Source files
touch ~/webapp/src/{app.py,utils.py}
touch ~/webapp/src/templates/{index.html,about.html,contact.html}
touch ~/webapp/src/static/css/{main.css,reset.css}
touch ~/webapp/src/static/js/app.js
touch ~/webapp/src/static/images/logo.png

# Config, data, logs, and docs
touch ~/webapp/config/{dev,staging,prod}/{app.conf,db.conf}
touch ~/webapp/data/{users.csv,products.csv,orders.csv}
touch ~/webapp/logs/{app.log,error.log,access.log}
touch ~/webapp/docs/{README.md,API.md,DEPLOY.md}
```

### Step 3: Verify the file count

```bash
find ~/webapp -type f | wc -l
```

**Expected output:** `24`

---

## Part 2: Copy Operations

### Step 4: Copy a single file

```bash
cp ~/webapp/config/dev/app.conf ~/webapp/config/dev/app.conf.bak
ls ~/webapp/config/dev/
```

**Expected output:** `app.conf  app.conf.bak  db.conf`

### Step 5: Copy files into a different directory

```bash
cp ~/webapp/config/dev/app.conf ~/webapp/config/staging/
```

The staging directory already had an `app.conf` — `cp` overwrites it silently. In production, use `cp -i` to get a warning before overwriting.

### Step 6: Copy an entire directory

```bash
cp -r ~/webapp/src ~/webapp/backups/src_backup
ls ~/webapp/backups/src_backup/
```

**Expected output:** `app.py  static  templates  utils.py`

The `-r` flag copies the directory and everything inside it recursively.

### Step 7: Verify the copy is independent

```bash
touch ~/webapp/src/newfile.py
ls ~/webapp/backups/src_backup/newfile.py
```

**Expected:** The `ls` fails — `newfile.py` only exists in `src/`, not in the backup. Copies are independent. Clean up with `rm ~/webapp/src/newfile.py`.

---

## Part 3: Move and Rename Operations

### Step 8: Rename a file

```bash
mv ~/webapp/docs/README.md ~/webapp/docs/OVERVIEW.md
ls ~/webapp/docs/
```

**Expected output:** `API.md  DEPLOY.md  OVERVIEW.md`

### Step 9: Move a file to a different directory

```bash
mv ~/webapp/docs/DEPLOY.md ~/webapp/config/
ls ~/webapp/config/DEPLOY.md
```

`DEPLOY.md` is now in `config/` instead of `docs/`.

### Step 10: Move and rename in one step

```bash
mv ~/webapp/config/DEPLOY.md ~/webapp/docs/deployment_guide.md
ls ~/webapp/docs/
```

**Expected output:** `API.md  OVERVIEW.md  deployment_guide.md`

### Step 11: Rename a directory

```bash
mv ~/webapp/backups/src_backup ~/webapp/backups/src_v1
ls ~/webapp/backups/
```

**Expected output:** `src_v1` — directories rename the same way as files, no special flags needed.

---

## Part 4: Wildcard Operations

### Step 12: List files with wildcards

```bash
ls ~/webapp/src/templates/*.html       # All HTML templates
ls ~/webapp/config/*/*.conf            # All .conf files across environments
ls ~/webapp/data/*.csv                 # All CSV data files
```

### Step 13: Use ? and [] for precise matching

```bash
# Create numbered report files
touch ~/webapp/data/report_{1,2,3,4,5,10,11,12}.csv

# Match single-digit reports only (? = exactly one character)
ls ~/webapp/data/report_?.csv
```

**Expected:** Lists `report_1.csv` through `report_5.csv` only. `report_10.csv` and beyond are excluded because `?` matches exactly one character.

```bash
# Match reports 1-3 only using character ranges
ls ~/webapp/data/report_[1-3].csv
```

### Step 14: Batch copy with wildcards

```bash
cp ~/webapp/data/*.csv ~/webapp/backups/
ls ~/webapp/backups/*.csv | wc -l
```

### Step 15: Batch move with wildcards

```bash
mkdir ~/webapp/data/reports
mv ~/webapp/data/report_*.csv ~/webapp/data/reports/
ls ~/webapp/data/reports/
```

### Step 16: Batch delete with wildcards

Practice the "list first, then delete" habit:

```bash
# First, see what matches
ls ~/webapp/data/reports/report_1*.csv

# Now delete them
rm ~/webapp/data/reports/report_1*.csv

# Verify
ls ~/webapp/data/reports/
```

**Expected output:** `report_2.csv  report_3.csv  report_4.csv  report_5.csv`

Only files matching `report_1*` were removed: `report_1.csv`, `report_10.csv`, `report_11.csv`, and `report_12.csv`.

---

## Part 5: File Identification

### Step 17: Use file on empty and non-empty files

```bash
file ~/webapp/src/app.py
file ~/webapp/config
```

**Expected:** `app.py` shows `empty` (created with `touch`), `config` shows `directory`.

Now add content and check again:

```bash
echo '#!/bin/bash' > ~/webapp/src/deploy.sh
echo 'echo "Deploying..."' >> ~/webapp/src/deploy.sh
file ~/webapp/src/deploy.sh
```

**Expected output:** `Bash shell script, ASCII text executable`

The `file` command identifies the script by its `#!/bin/bash` shebang line, not its `.sh` extension.

### Step 18: Check metadata with stat

```bash
stat ~/webapp/src/deploy.sh
```

Note the three timestamps (Access, Modify, Change) and the permissions.

---

## Part 6: Cleanup

### Step 19: Remove the entire project

```bash
ls ~/webapp              # verify you're deleting the right thing
rm -r ~/webapp
ls ~/webapp
```

**Expected:** `ls: cannot access '/home/student/webapp': No such file or directory`

The entire tree is gone. No confirmation, no recycle bin. Always verify paths before `rm -r`.

---

## Try Breaking It

```bash
# Try removing a non-empty directory with rmdir
mkdir -p ~/test_dir/sub_dir
rmdir ~/test_dir
```

**Expected:** `rmdir: failed to remove '/home/student/test_dir': Directory not empty`

```bash
# Try copying a directory without -r
cp ~/test_dir ~/test_dir_copy
```

**Expected:** `cp: -r not specified; omitting directory '/home/student/test_dir'`

```bash
rm -r ~/test_dir     # clean up
```

---

## Verify Your Work

Rebuild a small structure and verify each skill:

```bash
# 1. Create a nested structure
mkdir -p ~/verify/{alpha,beta,gamma}
ls ~/verify
# Expected: alpha  beta  gamma

# 2. Create multiple files with brace expansion
touch ~/verify/alpha/{one,two,three}.txt
ls ~/verify/alpha/
# Expected: one.txt  three.txt  two.txt

# 3. Copy a directory recursively
cp -r ~/verify/alpha ~/verify/beta/alpha_copy
ls ~/verify/beta/alpha_copy/
# Expected: one.txt  three.txt  two.txt

# 4. Rename a file
mv ~/verify/alpha/one.txt ~/verify/alpha/first.txt
ls ~/verify/alpha/
# Expected: first.txt  three.txt  two.txt

# 5. Use wildcards
ls ~/verify/alpha/*.txt
# Expected: all three .txt files listed

# 6. Identify a file type
echo '#!/bin/bash' > ~/verify/alpha/script.sh
file ~/verify/alpha/script.sh
# Expected: mentions "Bash shell script"

# 7. Clean up
rm -r ~/verify
ls ~/verify 2>/dev/null || echo "Successfully removed"
# Expected: Successfully removed
```

If every step produced the expected output, you have solid command of file operations. You're ready for Week 3.
