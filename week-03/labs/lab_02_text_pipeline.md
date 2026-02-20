# Lab 3.2: Text Pipeline

> **Objective:** Build progressively complex pipelines combining grep, cut, sort, uniq, awk, sed, wc to answer questions about /etc/passwd, process lists, and structured data.
>
> **Concepts practiced:** grep, cut, sort, uniq, awk, sed, wc, pipes, /etc/passwd format
>
> **Time estimate:** 35 minutes
>
> **VM(s) needed:** Both Ubuntu and Rocky

---

## Background: The /etc/passwd Format

Before building pipelines, understand the data. Each line in `/etc/passwd` has 7 colon-delimited fields:

```text
username:password:UID:GID:comment:home_directory:shell
```

For example:

```text
root:x:0:0:root:/root:/bin/bash
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
```

The `x` in the password field means the actual password hash is in `/etc/shadow`. Every field has meaning, and because the format is consistent and text-based, our pipeline tools work perfectly on it.

---

## Part A: Exploring /etc/passwd

### Challenge 1: Count Total User Accounts

How many user accounts exist on the system?

```bash
wc -l /etc/passwd
```

This counts every line, and each line is one account. The number will differ between your Ubuntu and Rocky VMs because they install different default service accounts.

### Challenge 2: List Users with a Real Login Shell

System accounts typically have `/usr/sbin/nologin` or `/bin/false` as their shell. Find users who can actually log in:

```bash
grep -v "nologin\|false" /etc/passwd | cut -d: -f1
```

Or equivalently with `awk`:

```bash
awk -F: '$7 !~ /nologin|false/ { print $1 }' /etc/passwd
```

### Challenge 3: Find All Unique Shells

What login shells are configured across all accounts?

```bash
cut -d: -f7 /etc/passwd | sort -u
```

Now count them:

```bash
cut -d: -f7 /etc/passwd | sort -u | wc -l
```

### Challenge 4: Rank Shells by Popularity

```bash
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

This is the `sort | uniq -c | sort -rn` pattern from the lecture. You will use it constantly.

### Challenge 5: List Regular Users (UID >= 1000)

On modern Linux systems, regular (human) users start at UID 1000. System accounts are below 1000.

```bash
awk -F: '$3 >= 1000 { print $1, $3 }' /etc/passwd
```

Try this on both VMs. You should see your own user account and possibly a `nobody` user (UID 65534 on Ubuntu).

### Challenge 6: Find the User with the Highest UID

```bash
sort -t: -k3 -n /etc/passwd | tail -1 | cut -d: -f1,3
```

Or with `awk`:

```bash
awk -F: '{ if ($3 > max) { max = $3; user = $1 } } END { print user, max }' /etc/passwd
```

---

## Part B: Analyzing Process Lists

### Setup

Capture a snapshot of running processes to work with (live process lists change between commands, so we freeze one):

```bash
ps aux > /tmp/processes.txt
```

### Challenge 7: Count Running Processes

```bash
wc -l /tmp/processes.txt
```

Remember the first line is a header, so the actual process count is one fewer. Subtract it:

```bash
tail -n +2 /tmp/processes.txt | wc -l
```

The `tail -n +2` means "start from line 2" -- a handy idiom for skipping headers.

### Challenge 8: Find All Processes Run by Root

```bash
awk '$1 == "root" { print $0 }' /tmp/processes.txt
```

Count them:

```bash
awk '$1 == "root"' /tmp/processes.txt | wc -l
```

### Challenge 9: Top 5 Memory Consumers

In `ps aux` output, column 4 is `%MEM` and column 11 is the command:

```bash
tail -n +2 /tmp/processes.txt | sort -k4 -rn | head -5 | awk '{ print $4"%", $11 }'
```

### Challenge 10: List Unique Users Running Processes

```bash
tail -n +2 /tmp/processes.txt | awk '{ print $1 }' | sort -u
```

Count them:

```bash
tail -n +2 /tmp/processes.txt | awk '{ print $1 }' | sort -u | wc -l
```

### Challenge 11: Count Processes per User

```bash
tail -n +2 /tmp/processes.txt | awk '{ print $1 }' | sort | uniq -c | sort -rn
```

---

## Part C: Working with Structured Data

### Setup: Create a Sample CSV Dataset

```bash
cat << 'EOF' > /tmp/employees.csv
id,name,department,salary,city
101,Alice Chen,Engineering,95000,Toronto
102,Bob Kumar,Marketing,72000,Vancouver
103,Carol White,Engineering,105000,Toronto
104,David Park,Sales,68000,Montreal
105,Eve Santos,Engineering,98000,Vancouver
106,Frank Li,Marketing,75000,Toronto
107,Grace Kim,Sales,71000,Calgary
108,Henry Brown,Engineering,110000,Toronto
109,Ivy Patel,Marketing,69000,Vancouver
110,Jack Wilson,Sales,73000,Montreal
111,Karen Lee,Engineering,102000,Calgary
112,Leo Martin,Marketing,78000,Toronto
113,Maria Gomez,Sales,67000,Vancouver
114,Nick Zhang,Engineering,115000,Toronto
115,Olivia Tan,Marketing,71000,Montreal
EOF
```

Verify:

```bash
head -3 /tmp/employees.csv
```

Expected output:

```text
id,name,department,salary,city
101,Alice Chen,Engineering,95000,Toronto
102,Bob Kumar,Marketing,72000,Vancouver
```

### Challenge 12: List All Departments

```bash
tail -n +2 /tmp/employees.csv | cut -d, -f3 | sort -u
```

Expected output:

```text
Engineering
Marketing
Sales
```

### Challenge 13: Count Employees per Department

```bash
tail -n +2 /tmp/employees.csv | cut -d, -f3 | sort | uniq -c | sort -rn
```

Expected output:

```text
      5 Engineering
      5 Marketing
      5 Sales
```

### Challenge 14: Find the Highest-Paid Employee

```bash
tail -n +2 /tmp/employees.csv | sort -t, -k4 -rn | head -1
```

Expected output:

```text
114,Nick Zhang,Engineering,115000,Toronto
```

### Challenge 15: Calculate Average Salary by Department

This requires `awk` for arithmetic:

```bash
tail -n +2 /tmp/employees.csv | awk -F, '
{
    dept_total[$3] += $4
    dept_count[$3]++
}
END {
    for (dept in dept_total) {
        printf "%s: $%.0f\n", dept, dept_total[dept] / dept_count[dept]
    }
}' | sort
```

Expected output:

```text
Engineering: $105000
Marketing: $73000
Sales: $69800
```

### Challenge 16: List Toronto Employees Earning Over $90,000

Combine `grep` for city filtering with `awk` for salary filtering:

```bash
tail -n +2 /tmp/employees.csv | awk -F, '$5 == "Toronto" && $4 > 90000 { print $2, "$"$4 }'
```

Expected output:

```text
Alice Chen $95000
Carol White $105000
Henry Brown $110000
Nick Zhang $115000
```

### Challenge 17: Replace Department Names with sed

Create a version with abbreviated department names:

```bash
sed 's/Engineering/ENG/g; s/Marketing/MKT/g; s/Sales/SLS/g' /tmp/employees.csv | head -5
```

Expected output:

```text
id,name,department,salary,city
101,Alice Chen,ENG,95000,Toronto
102,Bob Kumar,MKT,72000,Vancouver
103,Carol White,ENG,105000,Toronto
104,David Park,SLS,68000,Montreal
```

### Challenge 18: Generate a Summary Report

Combine everything into a single pipeline that produces a formatted report:

```bash
echo "=== Employee Summary Report ==="
echo ""
echo "Total employees:"
tail -n +2 /tmp/employees.csv | wc -l
echo ""
echo "Employees per department:"
tail -n +2 /tmp/employees.csv | cut -d, -f3 | sort | uniq -c | sort -rn
echo ""
echo "Employees per city:"
tail -n +2 /tmp/employees.csv | cut -d, -f5 | sort | uniq -c | sort -rn
echo ""
echo "Top 3 salaries:"
tail -n +2 /tmp/employees.csv | sort -t, -k4 -rn | head -3 | awk -F, '{ printf "  %s (%s) - $%s\n", $2, $3, $4 }'
echo ""
echo "Department averages:"
tail -n +2 /tmp/employees.csv | awk -F, '{ t[$3]+=$4; c[$3]++ } END { for(d in t) printf "  %s: $%.0f\n", d, t[d]/c[d] }' | sort
```

---

## Try Breaking It

Understanding failure modes makes you a better pipeline builder:

1. **Forget to skip the header row.** Run Challenge 13 without `tail -n +2` and see how the header row pollutes the department count.

2. **Use `cut` on variable-width data.** Try `cut -d' ' -f1` on the `ps aux` output instead of `awk '{ print $1 }'`. Notice how `cut` fails because `ps` uses variable-width spacing while `awk` handles it correctly.

3. **Use `uniq` without `sort` first.** Run this and compare results:

```bash
# Wrong: uniq only removes ADJACENT duplicates
cut -d, -f3 /tmp/employees.csv | uniq -c

# Right: sort first so duplicates are adjacent
cut -d, -f3 /tmp/employees.csv | sort | uniq -c
```

4. **Wrong field delimiter with sort.** Try sorting the CSV numerically without specifying the comma delimiter:

```bash
# Wrong: sort does not know about commas, treats whole line as one field
tail -n +2 /tmp/employees.csv | sort -k4 -rn

# Right: specify the delimiter
tail -n +2 /tmp/employees.csv | sort -t, -k4 -rn
```

---

## Verification

Run these checks to confirm your understanding:

```bash
echo "=== Verification ==="
echo -n "Unique shells on system: "
cut -d: -f7 /etc/passwd | sort -u | wc -l
echo -n "Departments in CSV: "
tail -n +2 /tmp/employees.csv | cut -d, -f3 | sort -u | wc -l
echo -n "Highest salary: "
tail -n +2 /tmp/employees.csv | sort -t, -k4 -rn | head -1 | cut -d, -f2,4
echo -n "Toronto employees: "
tail -n +2 /tmp/employees.csv | awk -F, '$5 == "Toronto"' | wc -l
```

Expected output (CSV portion):

```text
=== Verification ===
Unique shells on system: <varies by system>
Departments in CSV: 3
Highest salary: Nick Zhang,115000
Toronto employees: 5
```

---

## Cleanup

```bash
rm -f /tmp/processes.txt /tmp/employees.csv
```
