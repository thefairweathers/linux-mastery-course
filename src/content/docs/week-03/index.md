---
title: "Week 3: Reading, Searching & Manipulating Text"
sidebar:
  order: 0
---


> **Goal:** View, search, filter, and transform text files using core Linux utilities.


---

## Table of Contents

| Section | Topic |
|---------|-------|
| 3.1 | [Why Text Is Central to Linux](#31-why-text-is-central-to-linux) |
| 3.2 | [Viewing Files: cat, less, more, head, tail](#32-viewing-files-cat-less-more-head-tail) |
| 3.3 | [Searching with grep](#33-searching-with-grep) |
| 3.4 | [Introduction to Regular Expressions](#34-introduction-to-regular-expressions) |
| 3.5 | [Cutting and Rearranging: cut, sort, uniq, wc](#35-cutting-and-rearranging-cut-sort-uniq-wc) |
| 3.6 | [Stream Editing with sed](#36-stream-editing-with-sed) |
| 3.7 | [Field Processing with awk](#37-field-processing-with-awk) |
| 3.8 | [Comparing Files: diff and comm](#38-comparing-files-diff-and-comm) |
| 3.9 | [Finding Files with find](#39-finding-files-with-find) |
| 3.10 | [Fast Filename Searches: locate and updatedb](#310-fast-filename-searches-locate-and-updatedb) |

---

## 3.1 Why Text Is Central to Linux

If you come from a Windows or macOS GUI background, this week might reshape how you think about an operating system. In Linux, almost everything is represented as text.

Configuration files are plain text. Log files are plain text. The `/proc` filesystem exposes kernel and process data as text. The output of nearly every command is text. And the primary way you connect commands together -- the **pipe** (`|`) -- streams text from one program to the next.

This is not an accident. It is a deliberate design choice inherited from Unix. When everything speaks the same language (lines of text), any tool can work with any data. You do not need special APIs or libraries. A tool that searches text can search a log file, a config file, or the output of another command equally well.

Here are some concrete examples:

```bash
# System configuration is text
cat /etc/hostname

# Logs are text
tail -5 /var/log/syslog          # Ubuntu
tail -5 /var/log/messages         # Rocky

# Process info from the kernel is text
cat /proc/cpuinfo

# Network configuration is text
cat /etc/resolv.conf

# User accounts are text
head -3 /etc/passwd
```

This week you will learn the core toolkit for reading, searching, filtering, and transforming text. These are not niche utilities -- they are the everyday tools of anyone who works with Linux servers. You will use them constantly.

---

## 3.2 Viewing Files: cat, less, more, head, tail

### cat -- Concatenate and Print

The simplest way to dump a file to your terminal is **`cat`** (short for concatenate). It reads one or more files and writes their contents to standard output.

```bash
cat /etc/hostname
```

For multiple files, `cat` concatenates them in order:

```bash
cat header.txt body.txt footer.txt
```

Useful flags:

| Flag | Purpose |
|------|---------|
| `-n` | Number all output lines |
| `-b` | Number non-blank lines only |
| `-s` | Squeeze consecutive blank lines into one |
| `-A` | Show invisible characters (tabs as `^I`, line endings as `$`) |

```bash
# Show a config file with line numbers -- helpful when discussing specific lines
cat -n /etc/ssh/sshd_config
```

A word of caution: `cat` dumps the entire file at once. For large files (logs can be gigabytes), this will flood your terminal. Use a pager instead.

### less -- The Pager You Will Use Most

**`less`** displays a file one screen at a time and lets you scroll, search, and navigate.

```bash
less /var/log/syslog
```

Essential `less` keybindings:

| Key | Action |
|-----|--------|
| `Space` or `f` | Forward one screen |
| `b` | Back one screen |
| `j` / `k` | Down / up one line |
| `G` | Jump to end of file |
| `g` | Jump to beginning |
| `/pattern` | Search forward for `pattern` |
| `?pattern` | Search backward |
| `n` / `N` | Next / previous search match |
| `q` | Quit |

`less` does not load the entire file into memory, so it handles enormous files efficiently. This is why the old saying exists: "less is more."

### more -- The Original Pager

**`more`** is the older, simpler pager. It can scroll forward but not backward. You will encounter it in documentation, but in practice, use `less`. It does everything `more` does and more.

```bash
more /etc/services
```

### head -- View the Beginning

**`head`** prints the first lines of a file (10 by default).

```bash
# Default: first 10 lines
head /etc/passwd

# First 3 lines
head -n 3 /etc/passwd
```

This is invaluable for inspecting file structure -- what columns does this CSV have? What format is this log in?

```bash
# See the header row of a data file
head -n 1 sales_data.csv
```

### tail -- View the End

**`tail`** prints the last lines (10 by default).

```bash
# Last 10 lines of a log
tail /var/log/syslog

# Last 20 lines
tail -n 20 /var/log/syslog
```

### tail -f -- Follow Live Logs

This is one of the most important commands for server administration. The `-f` flag tells `tail` to keep watching the file and print new lines as they are appended.

```bash
# Watch a log in real time -- press Ctrl+C to stop
tail -f /var/log/syslog           # Ubuntu
tail -f /var/log/messages          # Rocky
```

When you are troubleshooting a service, you will often have `tail -f` running in one terminal while you restart or test the service in another. New log entries appear immediately.

The `-F` variant (capital F) is even better for log files that may be rotated (renamed and recreated). It will re-open the file if it detects the file was replaced:

```bash
tail -F /var/log/syslog
```

You can also combine `tail -f` with `grep` to watch for specific patterns:

```bash
# Watch for errors in real time
tail -f /var/log/syslog | grep -i error
```

---

## 3.3 Searching with grep

**`grep`** (Global Regular Expression Print) searches for patterns in text. It is one of the most frequently used commands in Linux.

### Basic Usage

```bash
# Search for "root" in /etc/passwd
grep "root" /etc/passwd
```

Expected output:

```text
root:x:0:0:root:/root:/bin/bash
```

### Common Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `-i` | Case-insensitive | `grep -i "error" log.txt` |
| `-n` | Show line numbers | `grep -n "root" /etc/passwd` |
| `-c` | Count matching lines | `grep -c "404" access.log` |
| `-v` | Invert match (non-matching lines) | `grep -v "^#" config.txt` |
| `-r` | Recursive (search directories) | `grep -r "TODO" /home/user/project/` |
| `-l` | List filenames only | `grep -rl "password" /etc/` |
| `-w` | Match whole words only | `grep -w "in" file.txt` |
| `-E` | Extended regex (same as `egrep`) | `grep -E "(error|warn)" log.txt` |
| `-o` | Print only the matching part | `grep -oE "[0-9]+" data.txt` |
| `-A N` | Show N lines after match | `grep -A 3 "error" log.txt` |
| `-B N` | Show N lines before match | `grep -B 2 "error" log.txt` |
| `-C N` | Show N lines of context (before and after) | `grep -C 2 "error" log.txt` |

### Practical Examples

```bash
# Find all comment lines in a config file
grep "^#" /etc/ssh/sshd_config

# Find non-comment, non-empty lines (the actual configuration)
grep -v "^#" /etc/ssh/sshd_config | grep -v "^$"

# Count how many users have /bin/bash as their shell
grep -c "/bin/bash$" /etc/passwd

# Search for a pattern recursively, showing line numbers
grep -rn "PermitRootLogin" /etc/ssh/

# Find files containing a string (just filenames)
grep -rl "nameserver" /etc/

# Search for multiple patterns with extended regex
grep -E "(error|critical|fatal)" /var/log/syslog
```

### Piping Into grep

Because `grep` reads from standard input by default, it works naturally in pipelines:

```bash
# Find running sshd processes
ps aux | grep "sshd"

# Find which ports are listening
ss -tlnp | grep "LISTEN"

# Check environment for a variable
env | grep "PATH"
```

A common gotcha: when you `grep` for a process, `grep` itself shows up in the results. A classic workaround:

```bash
# The grep process matches too
ps aux | grep "sshd"

# Trick: the character class [s] matches "s" but not the literal string "[s]shd"
ps aux | grep "[s]shd"
```

---

## 3.4 Introduction to Regular Expressions

Regular expressions (often called **regex**) are patterns that describe sets of strings. They are used by `grep`, `sed`, `awk`, and many other tools. Learning even basic regex pays dividends across your entire career -- they appear in every programming language.

### Basic Regex Metacharacters

| Character | Meaning | Example | Matches |
|-----------|---------|---------|---------|
| `.` | Any single character | `h.t` | hat, hot, hit |
| `*` | Zero or more of the preceding | `ab*c` | ac, abc, abbc |
| `+` | One or more of the preceding (extended) | `ab+c` | abc, abbc (not ac) |
| `^` | Start of line | `^root` | Lines starting with "root" |
| `$` | End of line | `bash$` | Lines ending with "bash" |
| `[]` | Character class | `[aeiou]` | Any vowel |
| `[^]` | Negated character class | `[^0-9]` | Any non-digit |
| `\` | Escape metacharacter | `\.` | A literal dot |
| `\|` | Alternation (OR) | `cat\|dog` | "cat" or "dog" |
| `()` | Grouping | `(ab)+` | ab, abab, ababab |
| `{n,m}` | Repetition range (extended) | `[0-9]{2,4}` | 2 to 4 digits |

> **Basic vs. Extended Regex:** By default, `grep` uses Basic Regular Expressions (BRE), where `+`, `?`, `{`, `|`, and `(` are literal characters. To use them as metacharacters, either escape them (`\+`) or use `grep -E` for Extended Regular Expressions (ERE). In practice, just use `grep -E` whenever you need these features.

### Character Class Shortcuts

| Pattern | Meaning |
|---------|---------|
| `[0-9]` | Any digit |
| `[a-z]` | Any lowercase letter |
| `[A-Z]` | Any uppercase letter |
| `[a-zA-Z]` | Any letter |
| `[a-zA-Z0-9]` | Any alphanumeric character |

### Practical Regex Examples

```bash
# Lines that start with a digit
grep -E "^[0-9]" data.txt

# Valid-looking IP addresses (simplified -- matches each octet as 1-3 digits)
grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" access.log

# Lines containing an email-like pattern
grep -E "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}" contacts.txt

# Blank lines (nothing between start and end)
grep -E "^$" file.txt

# Lines that are NOT blank
grep -Ev "^$" file.txt

# Words ending in "ing"
grep -Ew "[a-zA-Z]+ing" document.txt
```

### Anchoring Matters

The difference between anchored and unanchored patterns is a frequent source of confusion:

```bash
# This matches "root" ANYWHERE in the line
grep "root" /etc/passwd

# This matches only lines that START with "root"
grep "^root" /etc/passwd

# This matches lines where "bash" is at the END
grep "bash$" /etc/passwd

# This matches ENTIRE lines that are exactly "root"
grep "^root$" /etc/passwd
```

Take time to practice. Regex is like a language -- fluency comes from use, not from memorizing tables.

---

## 3.5 Cutting and Rearranging: cut, sort, uniq, wc

These four utilities are the workhorses of text processing pipelines. They are almost always used in combination with pipes.

### cut -- Extract Columns

**`cut`** extracts specific fields or character positions from each line.

The key flags:

| Flag | Purpose |
|------|---------|
| `-d` | Set the field delimiter (default is tab) |
| `-f` | Select fields by number |
| `-c` | Select characters by position |

```bash
# /etc/passwd uses ":" as a delimiter. Extract username (field 1) and shell (field 7)
cut -d: -f1,7 /etc/passwd
```

Expected output (first few lines):

```text
root:/bin/bash
daemon:/usr/sbin/nologin
bin:/usr/sbin/nologin
```

More examples:

```bash
# Extract just usernames
cut -d: -f1 /etc/passwd

# Fields 1 through 3
cut -d: -f1-3 /etc/passwd

# Extract a CSV column (comma-delimited, field 2)
cut -d, -f2 data.csv

# Extract characters 1-8 from each line
cut -c1-8 /etc/passwd
```

A limitation of `cut`: it does not handle multiple consecutive delimiters well (for example, spaces in `ps` output). For that, use `awk` (covered in Section 3.7).

### sort -- Order Lines

**`sort`** arranges lines in order. By default it sorts lexicographically (dictionary order).

| Flag | Purpose |
|------|---------|
| `-n` | Numeric sort (so 9 comes before 10) |
| `-r` | Reverse order |
| `-k N` | Sort by field N |
| `-t` | Set field delimiter |
| `-u` | Remove duplicates (like piping through `uniq`) |
| `-h` | Human-readable numeric sort (1K, 2M, 3G) |

```bash
# Sort /etc/passwd by username (default: first field, alphabetical)
sort /etc/passwd

# Sort by UID (field 3, numeric, colon-delimited)
sort -t: -k3 -n /etc/passwd

# Sort by UID in reverse (highest first)
sort -t: -k3 -nr /etc/passwd

# Sort a file of numbers numerically
sort -n numbers.txt

# Sort and remove duplicates
sort -u names.txt
```

Why `-n` matters:

```bash
# Without -n, "9" sorts AFTER "10" (lexicographic: "1" < "9")
printf "9\n10\n2\n" | sort
# Output: 10, 2, 9

# With -n, proper numeric order
printf "9\n10\n2\n" | sort -n
# Output: 2, 9, 10
```

### uniq -- Deduplicate Adjacent Lines

**`uniq`** removes consecutive duplicate lines. This is why it is almost always paired with `sort` first -- you need duplicates to be adjacent before `uniq` can see them.

| Flag | Purpose |
|------|---------|
| `-c` | Prefix lines with count of occurrences |
| `-d` | Show only duplicated lines |
| `-u` | Show only unique (non-duplicated) lines |

The classic pattern for frequency analysis:

```bash
# Count how many users use each shell
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

Expected output (varies by system):

```text
     18 /usr/sbin/nologin
      1 /bin/sync
      1 /bin/false
      1 /bin/bash
```

This `sort | uniq -c | sort -rn` pattern is one you will use hundreds of times. It answers the question "how many of each thing are there, ranked by frequency?"

### wc -- Count Lines, Words, Characters

**`wc`** (word count) reports counts for the input.

| Flag | Purpose |
|------|---------|
| `-l` | Lines only |
| `-w` | Words only |
| `-c` | Bytes only |
| `-m` | Characters only |

```bash
# How many lines in /etc/passwd? (i.e., how many user accounts)
wc -l /etc/passwd

# How many files in /etc?
ls /etc | wc -l

# How many matches did grep find?
grep -c "error" /var/log/syslog
# Or equivalently:
grep "error" /var/log/syslog | wc -l
```

### Combining Everything in Pipelines

These tools become powerful when combined:

```bash
# Top 5 most common shells on the system
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn | head -5

# Count unique IPs in an access log (IP is typically field 1, space-delimited)
cut -d' ' -f1 access.log | sort -u | wc -l

# Find the 10 largest files in /var/log (human-readable sizes, sorted)
ls -lhS /var/log/ | head -10
```

---

## 3.6 Stream Editing with sed

**`sed`** (Stream Editor) reads input line by line, applies transformations, and writes the result. It is the standard tool for automated text substitution from the command line.

### Substitution: s/old/new/

The most common `sed` operation is substitution:

```bash
# Replace first occurrence of "old" with "new" on each line
sed 's/old/new/' file.txt

# Replace ALL occurrences on each line (global flag)
sed 's/old/new/g' file.txt
```

The `g` flag at the end means "global" -- replace every match on the line, not just the first.

```bash
# Replace "http" with "https" throughout a file
sed 's/http:/https:/g' urls.txt

# Case-insensitive substitution (GNU sed)
sed 's/error/WARNING/gi' log.txt
```

### Delimiters

The `/` character is conventional but not required. Any character works as a delimiter, which is helpful when your pattern contains slashes:

```bash
# Awkward: escaping slashes
sed 's/\/usr\/local\/bin/\/opt\/bin/g' file.txt

# Better: use a different delimiter
sed 's|/usr/local/bin|/opt/bin|g' file.txt
```

### Deleting Lines

```bash
# Delete lines matching a pattern
sed '/^#/d' config.txt          # Remove comment lines

# Delete blank lines
sed '/^$/d' file.txt

# Delete line 5
sed '5d' file.txt

# Delete lines 10 through 20
sed '10,20d' file.txt
```

### Printing Specific Lines

By default, `sed` prints every line. Use `-n` to suppress default output and `p` to print only what you want:

```bash
# Print only lines 5 through 10
sed -n '5,10p' file.txt

# Print lines matching a pattern
sed -n '/error/p' log.txt         # Equivalent to grep "error" log.txt
```

### In-Place Editing

The `-i` flag edits the file directly instead of printing to standard output. This is extremely useful but also dangerous -- there is no undo.

```bash
# Edit a file in place (GNU sed on Linux)
sed -i 's/old/new/g' file.txt
```

| Distro | In-place syntax |
|--------|----------------|
| Ubuntu | `sed -i 's/old/new/g' file.txt` |
| Rocky | `sed -i 's/old/new/g' file.txt` |
| macOS | `sed -i '' 's/old/new/g' file.txt` (empty string for backup suffix) |

Both Ubuntu and Rocky use GNU `sed`, so the syntax is identical. The macOS difference is noted because you may encounter it on your host machine.

A safer approach -- create a backup before editing:

```bash
# Create a .bak backup, then edit in place
sed -i.bak 's/old/new/g' file.txt
```

This creates `file.txt.bak` with the original content.

### Practical sed Examples

```bash
# Remove trailing whitespace from every line
sed 's/[[:space:]]*$//' file.txt

# Add a prefix to every line
sed 's/^/PREFIX: /' file.txt

# Replace only on lines matching a condition
sed '/^server/s/80/443/' nginx.conf     # Only on lines starting with "server"

# Insert a line before line 3
sed '3i\New line of text' file.txt

# Append a line after line 5
sed '5a\Appended line' file.txt
```

---

## 3.7 Field Processing with awk

**`awk`** is a pattern-scanning and processing language. While it can do everything `sed` does and much more, its sweet spot is working with columnar data -- files where each line has fields separated by whitespace or another delimiter.

### Basic Syntax

```bash
awk 'pattern { action }' file
```

If the pattern is omitted, the action applies to every line. If the action is omitted, matching lines are printed.

### Printing Columns

`awk` automatically splits each line into fields: `$1` is the first field, `$2` the second, and so on. `$0` is the entire line.

```bash
# Print the first and third columns (whitespace-delimited by default)
awk '{ print $1, $3 }' file.txt

# Print just the username from /etc/passwd (colon-delimited)
awk -F: '{ print $1 }' /etc/passwd

# Print username and home directory
awk -F: '{ print $1, $6 }' /etc/passwd
```

### Custom Field Separator

Use `-F` to set the field separator:

```bash
# Colon-delimited
awk -F: '{ print $1 }' /etc/passwd

# Comma-delimited (CSV)
awk -F, '{ print $2 }' data.csv

# Multiple characters as separator
awk -F'::' '{ print $1 }' file.txt
```

### Conditions

You can filter lines with conditions before the action block:

```bash
# Print lines where field 3 (UID) is 0
awk -F: '$3 == 0 { print $1 }' /etc/passwd

# Print users with UID >= 1000 (regular users)
awk -F: '$3 >= 1000 { print $1, $3 }' /etc/passwd

# Print lines containing "error" (like grep, but with column control)
awk '/error/ { print $1, $4 }' log.txt

# Print lines where the shell (field 7) is /bin/bash
awk -F: '$7 == "/bin/bash" { print $1 }' /etc/passwd
```

### Built-in Variables

| Variable | Meaning |
|----------|---------|
| `NR` | Current line number (record number) |
| `NF` | Number of fields in current line |
| `FS` | Field separator (same as `-F`) |
| `OFS` | Output field separator |

```bash
# Print line numbers alongside content
awk '{ print NR, $0 }' file.txt

# Print only lines with exactly 7 fields
awk -F: 'NF == 7 { print $0 }' /etc/passwd

# Print the last field on each line
awk '{ print $NF }' file.txt
```

### BEGIN and END Blocks

**`BEGIN`** runs before any input is processed. **`END`** runs after all input is processed. These are useful for headers, footers, and summaries.

```bash
# Sum the values in column 3
awk '{ sum += $3 } END { print "Total:", sum }' data.txt

# Count lines matching a pattern
awk '/error/ { count++ } END { print "Errors:", count }' log.txt

# Print a header, process lines, print a footer
awk 'BEGIN { print "Username\tShell" }
     { print $1, "\t", $7 }
     END { print "---\nTotal:", NR, "users" }' FS=: /etc/passwd
```

### Practical awk Examples

```bash
# Show processes using more than 1% CPU
ps aux | awk '$3 > 1.0 { print $1, $3, $11 }'

# Sum disk usage from df output (skip header line)
df -h | awk 'NR > 1 { print $1, $5 }'

# Calculate average of a column
awk '{ sum += $1; count++ } END { print "Average:", sum/count }' numbers.txt

# Print fields in a different order
awk -F: '{ print $3, $1 }' /etc/passwd      # UID then username

# Formatted output with printf
awk -F: '{ printf "%-15s UID=%-5s %s\n", $1, $3, $6 }' /etc/passwd
```

### awk vs. cut

A common question: when do you use `cut` versus `awk`?

| Feature | cut | awk |
|---------|-----|-----|
| Speed on simple tasks | Faster | Slightly slower |
| Handles multiple spaces | No | Yes (default separator) |
| Conditions/filtering | No | Yes |
| Arithmetic | No | Yes |
| Formatted output | No | Yes |

Rule of thumb: if you just need to extract a column from cleanly delimited data, `cut` is simpler. If you need filtering, calculations, or the input has variable whitespace (like `ps` output), use `awk`.

---

## 3.8 Comparing Files: diff and comm

### diff -- Find Differences

**`diff`** compares two files line by line and reports the differences. It is essential for reviewing configuration changes and understanding patches.

```bash
diff file1.txt file2.txt
```

The default output uses a terse notation:

```text
2c2
< old line in file1
---
> new line in file2
```

The **unified diff** format (`-u`) is much more readable and is the standard format for patches:

```bash
diff -u file1.txt file2.txt
```

```text
--- file1.txt   2026-02-20 10:00:00.000000000 -0500
+++ file2.txt   2026-02-20 10:05:00.000000000 -0500
@@ -1,3 +1,3 @@
 line one
-old line
+new line
 line three
```

Lines prefixed with `-` are only in the first file. Lines prefixed with `+` are only in the second. Context lines have a space prefix.

Useful flags:

| Flag | Purpose |
|------|---------|
| `-u` | Unified format (most readable) |
| `-y` | Side-by-side comparison |
| `-r` | Compare directories recursively |
| `-q` | Report only whether files differ, not how |
| `--color` | Colorize output (GNU diff) |

```bash
# Compare two config files with color
diff -u --color original.conf modified.conf

# Compare two directories
diff -rq /etc/nginx/sites-available/ /etc/nginx/sites-enabled/

# Side-by-side comparison
diff -y file1.txt file2.txt
```

### comm -- Compare Sorted Files

**`comm`** compares two sorted files and produces three columns: lines only in file 1, lines only in file 2, and lines in both.

```bash
# Files must be sorted first
sort file1.txt > sorted1.txt
sort file2.txt > sorted2.txt
comm sorted1.txt sorted2.txt
```

Output has three tab-separated columns:

```text
		common_line          (column 3: in both)
	only_in_file2            (column 2: only in file 2)
only_in_file1                (column 1: only in file 1)
```

You can suppress columns:

```bash
# Show only lines common to both files (suppress columns 1 and 2)
comm -12 sorted1.txt sorted2.txt

# Show only lines unique to file 1
comm -23 sorted1.txt sorted2.txt

# Show only lines unique to file 2
comm -13 sorted1.txt sorted2.txt
```

A practical use case:

```bash
# Which packages are installed on server A but not server B?
# (Get package lists, sort them, compare)
comm -23 <(sort packages_a.txt) <(sort packages_b.txt)
```

The `<()` syntax is **process substitution** -- it lets you use a command's output as if it were a file. We will cover this in more depth in a later week.

---

## 3.9 Finding Files with find

**`find`** recursively searches a directory tree for files matching specified criteria. Unlike `grep` (which searches file contents), `find` searches file metadata: names, types, sizes, timestamps, and permissions.

### Basic Syntax

```bash
find [starting-directory] [criteria] [action]
```

### Search by Name

```bash
# Find files named "passwd" starting from /etc
find /etc -name "passwd"

# Case-insensitive name search
find /home -iname "readme*"

# Find all .conf files in /etc
find /etc -name "*.conf"
```

### Search by Type

| Type | Meaning |
|------|---------|
| `f` | Regular file |
| `d` | Directory |
| `l` | Symbolic link |

```bash
# Find only directories named "log"
find / -type d -name "log" 2>/dev/null

# Find only regular files ending in .log
find /var/log -type f -name "*.log"
```

The `2>/dev/null` redirects "Permission denied" errors to nowhere, keeping the output clean.

### Search by Size

```bash
# Files larger than 100 MB
find /var -type f -size +100M

# Files smaller than 1 KB
find /tmp -type f -size -1k

# Files exactly 0 bytes (empty files)
find /tmp -type f -size 0
```

Size suffixes: `c` (bytes), `k` (kilobytes), `M` (megabytes), `G` (gigabytes).

### Search by Modification Time

```bash
# Modified in the last 24 hours
find /var/log -type f -mtime -1

# Modified more than 30 days ago
find /tmp -type f -mtime +30

# Modified in the last 60 minutes
find /var/log -type f -mmin -60
```

`-mtime` counts in 24-hour periods. `-mmin` counts in minutes.

### Combining Criteria

Criteria are ANDed together by default. Use `-o` for OR:

```bash
# .log files larger than 10MB
find /var/log -type f -name "*.log" -size +10M

# .conf OR .cfg files in /etc
find /etc -type f \( -name "*.conf" -o -name "*.cfg" \)
```

### Executing Commands on Results

The `-exec` flag runs a command on each matching file. The `{}` placeholder represents the current file, and `\;` terminates the command:

```bash
# Find .tmp files and delete them
find /tmp -type f -name "*.tmp" -exec rm {} \;

# Find large log files and show their sizes
find /var/log -type f -size +1M -exec ls -lh {} \;

# Find .conf files and search for a pattern in each
find /etc -name "*.conf" -exec grep -l "ssl" {} \;
```

For better performance with many files, use `+` instead of `\;` to batch arguments:

```bash
# This runs one "ls" command with all matching files as arguments
find /var/log -type f -name "*.log" -exec ls -lh {} +
```

### Practical find Examples

```bash
# Find files modified in the last hour in /etc (detect recent config changes)
find /etc -type f -mmin -60

# Find and list all empty directories
find /home -type d -empty

# Find files owned by a specific user
find /home -type f -user tim

# Find world-writable files (security audit)
find / -type f -perm -o+w 2>/dev/null

# Find setuid binaries (security audit)
find / -type f -perm -4000 2>/dev/null
```

---

## 3.10 Fast Filename Searches: locate and updatedb

`find` is thorough but can be slow on large filesystems because it traverses the directory tree in real time. **`locate`** provides near-instant filename searches by querying a pre-built database.

### Installation

`locate` is not always installed by default:

| Distro | Package | Install command |
|--------|---------|----------------|
| Ubuntu | `plocate` (or `mlocate`) | `sudo apt install plocate` |
| Rocky | `mlocate` (or `plocate`) | `sudo dnf install mlocate` |

### Building the Database

The database is typically updated once daily by a cron job. To update it manually:

```bash
sudo updatedb
```

### Using locate

```bash
# Find files with "nginx" in the path
locate nginx

# Case-insensitive search
locate -i readme

# Count matches instead of listing them
locate -c "*.conf"

# Limit output to 10 results
locate -l 10 "*.log"
```

### locate vs. find

| Feature | locate | find |
|---------|--------|------|
| Speed | Near-instant | Proportional to filesystem size |
| Freshness | Only as current as last `updatedb` | Always real-time |
| Search by content | No | No (but can `-exec grep`) |
| Search by size/time/permissions | No | Yes |
| New files (created since last updatedb) | Not found | Found |

Use `locate` when you need to quickly find where a file lives. Use `find` when you need real-time results or criteria beyond filename matching.

---

## Labs

Complete the labs in the the labs on this page directory:

- **[Lab 3.1: Log Analysis](./lab-01-log-analysis)** — Analyze a sample web server access log to find errors, count hits, and extract patterns
- **[Lab 3.2: Text Pipeline](./lab-02-text-pipeline)** — Build progressively complex pipelines combining grep, cut, sort, uniq, and awk

---

## Checklist

Before moving to Week 4, confirm you can:

- [ ] View files with cat, less, head, tail, and follow live logs with tail -f
- [ ] Search file contents with grep using basic patterns and common flags
- [ ] Write simple regular expressions for pattern matching
- [ ] Extract columns from structured text with cut and awk
- [ ] Sort and deduplicate data with sort and uniq
- [ ] Perform find-and-replace with sed
- [ ] Compare two files with diff
- [ ] Find files by name, type, size, or modification time with find
- [ ] Combine multiple text tools in a pipeline to answer questions about data

---

