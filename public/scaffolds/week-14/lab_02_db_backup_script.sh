#!/bin/bash
# =============================================================================
# Lab 14.2: Database Backup Script
# =============================================================================
#
# OBJECTIVE:
#   Build a database backup script that runs pg_dump, compresses the output,
#   rotates old backups, and logs results. This ties together concepts from
#   Weeks 8, 11, 13, and 14.
#
#   This is the backup script you'll later automate with a systemd timer
#   (Week 11 concepts) and eventually run inside a container (Week 17).
#
# CONCEPTS PRACTICED:
#   - Argument parsing (Week 14)
#   - pg_dump (Week 13)
#   - File locking (Week 14)
#   - Logging with logger/syslog (Week 14)
#   - trap for cleanup (Week 14)
#   - find for rotation (Week 3)
#   - Compression with gzip (Week 14)
#
# USAGE:
#   chmod +x lab_02_db_backup_script.sh
#   ./lab_02_db_backup_script.sh --database taskdb --output-dir /backups --retain-days 7
#   ./lab_02_db_backup_script.sh --database taskdb --output-dir /backups --compress
#
# HOW TO TEST:
#   The script includes built-in tests at the bottom.
#   Run with --test to execute the test suite:
#     ./lab_02_db_backup_script.sh --test
#   Tests mock pg_dump so you do NOT need a real database.
#   All tests pass when your implementation is correct.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================
readonly SCRIPT_NAME="$(basename "$0")"
LOCKFILE="/tmp/${SCRIPT_NAME}.lock"
LOCK_FD=9
TMPDIR=""

# =============================================================================
# Defaults
# =============================================================================
DATABASE=""
OUTPUT_DIR=""
RETAIN_DAYS=7
COMPRESS=false
DRY_RUN=false
VERBOSE=false

# For testing: set PGDUMP_CMD to override the pg_dump command
PGDUMP_CMD="${PGDUMP_CMD:-pg_dump}"

# =============================================================================
# TODO 1: log_message
# =============================================================================
# Write a function that logs messages with a timestamp and severity level,
# and also sends the message to syslog using the logger command.
#
# Parameters:
#   $1 — level (INFO, WARN, ERROR)
#   $2 — message text
#
# Requirements:
#   - Print to stderr: [YYYY-MM-DD HH:MM:SS] [LEVEL] message
#   - Send to syslog: logger -p local0.PRIORITY -t SCRIPT_NAME "message"
#     Map levels: INFO->info, WARN->warning, ERROR->err
#
# HINT: See Section 14.11 (Logging Patterns — Combining File Logging and Syslog).
#   Use a case statement to map level names to syslog priorities.
#   logger -p "local0.info" -t "$SCRIPT_NAME" "$message"
#
# Expected stderr output:
#   [2026-02-20 14:30:00] [INFO] Starting backup of taskdb
# =============================================================================
log_message() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED" >&2
}

# =============================================================================
# TODO 2: parse_args
# =============================================================================
# Parse command-line arguments using the while/case pattern.
#
# Supported arguments:
#   -d, --database NAME       Database name (required)
#   -o, --output-dir DIR      Output directory for backup files (required)
#   -r, --retain-days DAYS    Days to retain old backups (default: 7)
#   -c, --compress            Compress the backup with gzip
#   -n, --dry-run             Show what would be done without doing it
#   -v, --verbose             Enable verbose output
#   -h, --help                Show usage and exit
#
# HINT: See Section 14.5 (Parsing Arguments — while/case pattern).
#   Follow the same pattern as Lab 14.1.
#   Print a usage message in the -h|--help case, then exit 0.
# =============================================================================
parse_args() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# TODO 3: validate_args
# =============================================================================
# Validate that the parsed arguments are sane.
#
# Checks:
#   - DATABASE is non-empty
#   - OUTPUT_DIR is non-empty
#   - OUTPUT_DIR exists as a directory, OR create it with mkdir -p
#   - RETAIN_DAYS is a positive integer
#
# On failure, log an error and exit 1.
#
# HINT: See Section 14.12 (Configuration Files — validation).
#   If OUTPUT_DIR does not exist, try: mkdir -p "$OUTPUT_DIR"
#   Log the creation: log_message "INFO" "Created output directory: $OUTPUT_DIR"
# =============================================================================
validate_args() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# TODO 4: create_backup
# =============================================================================
# Run pg_dump to create a database backup file.
#
# Steps:
#   1. Generate a filename with timestamp:
#      "${OUTPUT_DIR}/${DATABASE}_$(date +%Y%m%d_%H%M%S).sql"
#   2. If DRY_RUN is true, log what would happen and return 0
#   3. Run $PGDUMP_CMD (not pg_dump directly — this allows test mocking)
#      to dump the database to the file:
#      $PGDUMP_CMD "$DATABASE" > "$backup_file"
#   4. If COMPRESS is true, compress with gzip:
#      gzip "$backup_file"
#      Update the filename to include .gz
#   5. Log the result (filename and size)
#   6. Echo the final backup filename to stdout (for the caller to capture)
#
# HINT: See Week 13 for pg_dump usage.
#   Use $(date +%Y%m%d_%H%M%S) for the timestamp.
#   Use $(stat -c '%s' "$file" 2>/dev/null || stat -f '%z' "$file") for size.
#   gzip replaces the original file with a .gz version.
#
# Expected output (to stdout): /backups/taskdb_20260220_143000.sql.gz
# =============================================================================
create_backup() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# TODO 5: rotate_backups
# =============================================================================
# Find and remove backup files older than RETAIN_DAYS.
#
# Steps:
#   1. Use find to locate files matching ${DATABASE}_*.sql* older than
#      RETAIN_DAYS in OUTPUT_DIR
#   2. For each file found:
#      a. If DRY_RUN, log what would be removed
#      b. Otherwise, remove it and log the action
#   3. Return the count of removed files (echo to stdout)
#
# HINT: See Week 3 for the find command.
#   find "$OUTPUT_DIR" -name "${DATABASE}_*.sql*" -type f -mtime +"$RETAIN_DAYS"
#   This matches both .sql and .sql.gz files.
#
# Expected log output:
#   [INFO] Removed old backup: /backups/taskdb_20260101_020000.sql.gz
# =============================================================================
rotate_backups() {
    # YOUR CODE HERE
    echo "0"
}

# =============================================================================
# TODO 6: send_summary
# =============================================================================
# Log a summary of the backup operation.
#
# Parameters:
#   $1 — backup file path (or "N/A" if dry run)
#   $2 — number of old backups removed
#
# Log a summary with:
#   - Database name
#   - Backup file path
#   - Number of old backups rotated
#   - Whether compression was used
#
# HINT: This is straightforward logging. Use log_message for each line,
#   or combine into a single summary message.
#
# Expected output:
#   [INFO] === Backup Summary ===
#   [INFO] Database:   taskdb
#   [INFO] Backup:     /backups/taskdb_20260220_143000.sql.gz
#   [INFO] Rotated:    3 old backup(s) removed
#   [INFO] Compressed: yes
# =============================================================================
send_summary() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# Cleanup (provided — same pattern as Lab 14.1)
# =============================================================================
cleanup() {
    local exit_code="$?"
    if [[ -n "$TMPDIR" && -d "$TMPDIR" ]]; then
        rm -rf "$TMPDIR"
    fi
    if [[ -f "$LOCKFILE" ]]; then
        rm -f "$LOCKFILE"
    fi
    if [[ "$exit_code" -ne 0 ]]; then
        log_message "ERROR" "$SCRIPT_NAME exited with code $exit_code" 2>/dev/null || true
    fi
    exit "$exit_code"
}
trap cleanup EXIT

# =============================================================================
# TODO 7: main
# =============================================================================
# Tie everything together in the correct order:
#   1. Parse arguments
#   2. Validate arguments
#   3. Acquire lock (use flock pattern from Lab 14.1)
#   4. Create a temp directory with mktemp -d
#   5. Log the start of backup
#   6. Create the backup (capture the filename)
#   7. Rotate old backups (capture the count)
#   8. Send the summary
#   9. Log completion
#
# HINT: See Section 14.16 (Script Structure Template).
#   backup_file="$(create_backup)"
#   rotated_count="$(rotate_backups)"
#   send_summary "$backup_file" "$rotated_count"
# =============================================================================
main() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# Built-in Tests
# =============================================================================
run_tests() {
    local pass=0
    local fail=0
    local test_dir
    local test_output_dir

    echo "Running Lab 14.2 tests..."
    echo ""

    test_dir="$(mktemp -d /tmp/lab14-dbtest-XXXXXX)"
    test_output_dir="$test_dir/backups"
    mkdir -p "$test_output_dir"

    # Create a mock pg_dump that produces a fake SQL dump
    mock_pgdump="$test_dir/mock_pgdump.sh"
    cat > "$mock_pgdump" <<'MOCK'
#!/bin/bash
echo "-- Mock pg_dump output"
echo "-- Database: $1"
echo "CREATE TABLE test (id serial PRIMARY KEY);"
echo "INSERT INTO test VALUES (1);"
MOCK
    chmod +x "$mock_pgdump"

    # Test 1: log_message outputs correct format
    result="$(log_message "INFO" "test backup" 2>&1)"
    if [[ "$result" =~ \[.*\]\ \[INFO\]\ test\ backup ]]; then
        echo "  ✓ log_message produces correct format"
        (( pass++ ))
    else
        echo "  ✗ log_message should output [timestamp] [INFO] test backup, got: $result"
        (( fail++ ))
    fi

    # Test 2: parse_args sets DATABASE and OUTPUT_DIR
    DATABASE="" OUTPUT_DIR="" RETAIN_DAYS=7 COMPRESS=false DRY_RUN=false
    parse_args --database testdb --output-dir "$test_output_dir"
    if [[ "$DATABASE" == "testdb" && "$OUTPUT_DIR" == "$test_output_dir" ]]; then
        echo "  ✓ parse_args sets DATABASE and OUTPUT_DIR correctly"
        (( pass++ ))
    else
        echo "  ✗ parse_args: DATABASE=$DATABASE (expected testdb), OUTPUT_DIR=$OUTPUT_DIR (expected $test_output_dir)"
        (( fail++ ))
    fi

    # Test 3: parse_args sets optional flags
    DATABASE="" OUTPUT_DIR="" RETAIN_DAYS=7 COMPRESS=false DRY_RUN=false
    parse_args --database testdb --output-dir "$test_output_dir" --compress --retain-days 14 --dry-run
    if [[ "$COMPRESS" == "true" && "$DRY_RUN" == "true" && "$RETAIN_DAYS" == "14" ]]; then
        echo "  ✓ parse_args sets COMPRESS, DRY_RUN, and RETAIN_DAYS"
        (( pass++ ))
    else
        echo "  ✗ parse_args: COMPRESS=$COMPRESS DRY_RUN=$DRY_RUN RETAIN_DAYS=$RETAIN_DAYS"
        (( fail++ ))
    fi

    # Test 4: validate_args rejects missing database
    DATABASE="" OUTPUT_DIR="$test_output_dir" RETAIN_DAYS=7
    if ! validate_args 2>/dev/null; then
        echo "  ✓ validate_args rejects empty DATABASE"
        (( pass++ ))
    else
        echo "  ✗ validate_args should fail when DATABASE is empty"
        (( fail++ ))
    fi

    # Test 5: validate_args creates output directory if missing
    DATABASE="testdb" OUTPUT_DIR="$test_dir/new_backups" RETAIN_DAYS=7
    validate_args 2>/dev/null || true
    if [[ -d "$test_dir/new_backups" ]]; then
        echo "  ✓ validate_args creates missing output directory"
        (( pass++ ))
    else
        echo "  ✗ validate_args should create OUTPUT_DIR if it does not exist"
        (( fail++ ))
    fi

    # Test 6: create_backup produces a backup file (using mock pg_dump)
    DATABASE="testdb" OUTPUT_DIR="$test_output_dir" COMPRESS=false DRY_RUN=false
    PGDUMP_CMD="$mock_pgdump"
    backup_file="$(create_backup 2>/dev/null)"
    if [[ -f "$backup_file" && "$backup_file" =~ testdb.*\.sql$ ]]; then
        echo "  ✓ create_backup produces a .sql file: $(basename "$backup_file")"
        (( pass++ ))
    else
        echo "  ✗ create_backup should produce a .sql file, got: $backup_file"
        (( fail++ ))
    fi

    # Test 7: create_backup with --compress produces a .sql.gz file
    DATABASE="testdb" OUTPUT_DIR="$test_output_dir" COMPRESS=true DRY_RUN=false
    PGDUMP_CMD="$mock_pgdump"
    backup_file="$(create_backup 2>/dev/null)"
    if [[ -f "$backup_file" && "$backup_file" =~ testdb.*\.sql\.gz$ ]]; then
        echo "  ✓ create_backup with --compress produces .sql.gz: $(basename "$backup_file")"
        (( pass++ ))
    else
        echo "  ✗ create_backup --compress should produce .sql.gz, got: $backup_file"
        (( fail++ ))
    fi

    # Test 8: create_backup dry-run does NOT create a file
    old_file_count="$(find "$test_output_dir" -name "testdb_*" -type f | wc -l | tr -d ' ')"
    DATABASE="testdb" OUTPUT_DIR="$test_output_dir" COMPRESS=false DRY_RUN=true
    PGDUMP_CMD="$mock_pgdump"
    create_backup > /dev/null 2>&1 || true
    new_file_count="$(find "$test_output_dir" -name "testdb_*" -type f | wc -l | tr -d ' ')"
    if [[ "$new_file_count" -eq "$old_file_count" ]]; then
        echo "  ✓ create_backup dry-run does not create files"
        (( pass++ ))
    else
        echo "  ✗ create_backup dry-run should not create files (before=$old_file_count, after=$new_file_count)"
        (( fail++ ))
    fi

    # Test 9: rotate_backups removes old files
    # Create old backup files
    for i in 1 2 3; do
        echo "old backup $i" > "$test_output_dir/testdb_old_${i}.sql"
        touch -d "30 days ago" "$test_output_dir/testdb_old_${i}.sql"
    done
    DATABASE="testdb" OUTPUT_DIR="$test_output_dir" RETAIN_DAYS=7 DRY_RUN=false
    rotated="$(rotate_backups 2>/dev/null)"
    old_remaining="$(find "$test_output_dir" -name "testdb_old_*.sql" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$old_remaining" -eq 0 ]]; then
        echo "  ✓ rotate_backups removes old backup files (rotated: $rotated)"
        (( pass++ ))
    else
        echo "  ✗ rotate_backups should remove old files, $old_remaining still remain"
        (( fail++ ))
    fi

    # Test 10: rotate_backups preserves recent files
    recent_remaining="$(find "$test_output_dir" -name "testdb_*.sql*" -type f -mtime -7 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$recent_remaining" -ge 1 ]]; then
        echo "  ✓ rotate_backups preserves recent backup files ($recent_remaining remain)"
        (( pass++ ))
    else
        echo "  ✗ rotate_backups should preserve recent files, found $recent_remaining"
        (( fail++ ))
    fi

    # Test 11: send_summary runs without error
    if send_summary "/backups/testdb_20260220.sql.gz" "3" 2>/dev/null; then
        echo "  ✓ send_summary completes without error"
        (( pass++ ))
    else
        echo "  ✗ send_summary should complete without error"
        (( fail++ ))
    fi

    # Cleanup test directory
    rm -rf "$test_dir"

    echo ""
    echo "Results: $pass passed, $fail failed out of $(( pass + fail )) tests"

    if [[ "$fail" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# =============================================================================
# Entry Point
# =============================================================================
if [[ "${1:-}" == "--test" ]]; then
    run_tests
else
    main "$@"
fi
