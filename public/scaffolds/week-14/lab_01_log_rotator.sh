#!/bin/bash
# =============================================================================
# Lab 14.1: Log Rotator
# =============================================================================
#
# OBJECTIVE:
#   Build a log rotation script that finds old log files, compresses or
#   deletes them based on age, uses file locking to prevent concurrent
#   runs, and logs all actions with timestamps.
#
# CONCEPTS PRACTICED:
#   - Argument parsing with while/case (Week 14)
#   - trap for cleanup (Week 14)
#   - File locking with flock (Week 14)
#   - Logging function (Week 14)
#   - find command (Week 3)
#   - Conditionals and loops (Week 8)
#
# USAGE:
#   chmod +x lab_01_log_rotator.sh
#   ./lab_01_log_rotator.sh --directory /var/log/myapp --max-age 30 --compress
#   ./lab_01_log_rotator.sh --directory /tmp/test-logs --max-age 7 --dry-run
#
# HOW TO TEST:
#   The script includes built-in tests at the bottom.
#   Run with --test to execute the test suite:
#     ./lab_01_log_rotator.sh --test
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
DIRECTORY=""
MAX_AGE=30
COMPRESS=false
DRY_RUN=false
VERBOSE=false

# =============================================================================
# TODO 1: log_message
# =============================================================================
# Write a function that logs messages with a timestamp and severity level.
#
# Parameters:
#   $1 — level (INFO, WARN, ERROR)
#   $2 — message text
#
# Format: [YYYY-MM-DD HH:MM:SS] [LEVEL] message
# Output should go to stderr so stdout remains clean.
#
# HINT: See Section 14.11 (Logging Patterns).
#   Use $(date '+%Y-%m-%d %H:%M:%S') for the timestamp.
#   echo "..." >&2 writes to stderr.
#
# Expected output example:
#   [2026-02-20 14:30:00] [INFO] Starting log rotation
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
#   -d, --directory DIR    Directory containing log files (required)
#   -a, --max-age DAYS     Maximum age in days before rotation (default: 30)
#   -c, --compress         Compress old logs with gzip instead of deleting
#   -n, --dry-run          Show what would be done without doing it
#   -v, --verbose          Enable verbose output
#   -h, --help             Show usage and exit
#
# HINT: See Section 14.5 (Parsing Arguments — while/case pattern).
#   Remember to shift after consuming each option.
#   Options with arguments (like --directory) need shift 2.
#   Validate that required arguments have values: ${2:?--directory requires a value}
#
# After parsing, the global variables DIRECTORY, MAX_AGE, COMPRESS,
# DRY_RUN, and VERBOSE should be set.
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
#   - DIRECTORY is non-empty (was provided)
#   - DIRECTORY exists and is a directory
#   - MAX_AGE is a positive integer
#
# On failure, print an error with log_message and exit 1.
#
# HINT: See Section 14.12 (Configuration Files — validation).
#   Use [[ -z "$DIRECTORY" ]] to check if empty.
#   Use [[ -d "$DIRECTORY" ]] to check if it is a directory.
#   Use a regex test [[ "$MAX_AGE" =~ ^[0-9]+$ ]] for numeric validation.
# =============================================================================
validate_args() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# TODO 4: acquire_lock
# =============================================================================
# Use flock to prevent concurrent runs of this script.
#
# Steps:
#   1. Open LOCKFILE on file descriptor LOCK_FD (use exec)
#   2. Attempt a non-blocking exclusive lock with flock -n
#   3. If the lock fails, log an error and exit 1
#   4. Write the current PID to the lock file for diagnostics
#
# HINT: See Section 14.10 (File Locking with flock).
#   exec 9>"$LOCKFILE" opens fd 9 for writing to the lock file.
#   flock -n 9 tries a non-blocking lock on fd 9.
#   echo "$$" writes the PID.
# =============================================================================
acquire_lock() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# TODO 5: rotate_logs
# =============================================================================
# Find and process log files older than MAX_AGE days.
#
# Steps:
#   1. Use find to locate *.log files older than MAX_AGE days in DIRECTORY
#   2. For each file found:
#      a. If DRY_RUN is true, log what WOULD happen and skip the action
#      b. If COMPRESS is true, compress the file with gzip
#      c. If COMPRESS is false, delete the file with rm
#      d. Log each action (compression or deletion)
#   3. Track and return the count of processed files
#
# HINT: See Week 3 for the find command.
#   find "$DIRECTORY" -name "*.log" -type f -mtime +"$MAX_AGE"
#   Use a while read loop with process substitution to iterate results.
#   gzip "$file" compresses in place (creates file.gz, removes original).
#
# Expected behavior:
#   --dry-run:    [INFO] [DRY RUN] Would compress: /tmp/logs/old.log
#   --compress:   [INFO] Compressed: /tmp/logs/old.log
#   (default):    [INFO] Deleted: /tmp/logs/old.log
# =============================================================================
rotate_logs() {
    # YOUR CODE HERE
    echo "0"
}

# =============================================================================
# TODO 6: cleanup
# =============================================================================
# Clean up temporary resources when the script exits.
#
# Steps:
#   1. Capture the exit code ($?) as the first action
#   2. Remove TMPDIR if it exists and is non-empty
#   3. Remove LOCKFILE if it exists
#   4. Log whether the script succeeded or failed
#   5. Exit with the original exit code
#
# HINT: See Section 14.3 (Trap for Cleanup).
#   Check [[ -n "$TMPDIR" && -d "$TMPDIR" ]] before rm -rf.
#   Check [[ -f "$LOCKFILE" ]] before rm -f.
# =============================================================================
cleanup() {
    # YOUR CODE HERE
    :
}
trap cleanup EXIT

# =============================================================================
# TODO 7: main
# =============================================================================
# Tie everything together in the correct order:
#   1. Parse arguments (pass "$@" to parse_args)
#   2. Validate arguments
#   3. Acquire the lock
#   4. Create a temp directory with mktemp -d
#   5. Log the start of rotation with parameters
#   6. Call rotate_logs and capture the count
#   7. Log the summary (how many files were processed)
#
# HINT: See Section 14.16 (Script Structure Template).
#   TMPDIR="$(mktemp -d /tmp/${SCRIPT_NAME}-XXXXXX)"
#   Store rotate_logs output: count="$(rotate_logs)"
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

    echo "Running Lab 14.1 tests..."
    echo ""

    test_dir="$(mktemp -d /tmp/lab14-test-XXXXXX)"

    # --- Setup: create test log files with old timestamps ---
    for i in 1 2 3; do
        echo "old log content $i" > "$test_dir/old_${i}.log"
        touch -d "60 days ago" "$test_dir/old_${i}.log"
    done
    for i in 1 2; do
        echo "recent log content $i" > "$test_dir/recent_${i}.log"
    done

    # Test 1: log_message outputs to stderr with correct format
    result="$(log_message "INFO" "test message" 2>&1)"
    if [[ "$result" =~ \[.*\]\ \[INFO\]\ test\ message ]]; then
        echo "  ✓ log_message produces correct format"
        (( pass++ ))
    else
        echo "  ✗ log_message should output [timestamp] [INFO] test message, got: $result"
        (( fail++ ))
    fi

    # Test 2: parse_args sets DIRECTORY
    DIRECTORY="" MAX_AGE=30 COMPRESS=false DRY_RUN=false VERBOSE=false
    parse_args --directory "$test_dir" --max-age 10
    if [[ "$DIRECTORY" == "$test_dir" ]]; then
        echo "  ✓ parse_args sets DIRECTORY correctly"
        (( pass++ ))
    else
        echo "  ✗ parse_args should set DIRECTORY to $test_dir, got: $DIRECTORY"
        (( fail++ ))
    fi

    # Test 3: parse_args sets COMPRESS and DRY_RUN flags
    DIRECTORY="" MAX_AGE=30 COMPRESS=false DRY_RUN=false VERBOSE=false
    parse_args --directory "$test_dir" --compress --dry-run
    if [[ "$COMPRESS" == "true" && "$DRY_RUN" == "true" ]]; then
        echo "  ✓ parse_args sets COMPRESS and DRY_RUN flags"
        (( pass++ ))
    else
        echo "  ✗ parse_args should set COMPRESS=true DRY_RUN=true, got: COMPRESS=$COMPRESS DRY_RUN=$DRY_RUN"
        (( fail++ ))
    fi

    # Test 4: validate_args rejects missing directory
    DIRECTORY="" MAX_AGE=30
    if ! validate_args 2>/dev/null; then
        echo "  ✓ validate_args rejects empty DIRECTORY"
        (( pass++ ))
    else
        echo "  ✗ validate_args should fail when DIRECTORY is empty"
        (( fail++ ))
    fi

    # Test 5: validate_args rejects non-numeric max-age
    DIRECTORY="$test_dir" MAX_AGE="abc"
    if ! validate_args 2>/dev/null; then
        echo "  ✓ validate_args rejects non-numeric MAX_AGE"
        (( pass++ ))
    else
        echo "  ✗ validate_args should fail when MAX_AGE is not numeric"
        (( fail++ ))
    fi

    # Test 6: validate_args accepts valid inputs
    DIRECTORY="$test_dir" MAX_AGE=30
    if validate_args 2>/dev/null; then
        echo "  ✓ validate_args accepts valid inputs"
        (( pass++ ))
    else
        echo "  ✗ validate_args should succeed with valid DIRECTORY and MAX_AGE"
        (( fail++ ))
    fi

    # Test 7: rotate_logs in dry-run mode does not delete files
    DIRECTORY="$test_dir" MAX_AGE=30 DRY_RUN=true COMPRESS=false
    count="$(rotate_logs 2>/dev/null)"
    old_count="$(find "$test_dir" -name "old_*.log" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$old_count" -eq 3 ]]; then
        echo "  ✓ rotate_logs dry-run does not delete files (found $old_count old files)"
        (( pass++ ))
    else
        echo "  ✗ rotate_logs dry-run should not delete files, found $old_count old files (expected 3)"
        (( fail++ ))
    fi

    # Test 8: rotate_logs with --compress compresses old files
    DIRECTORY="$test_dir" MAX_AGE=30 DRY_RUN=false COMPRESS=true
    rotate_logs > /dev/null 2>&1 || true
    gz_count="$(find "$test_dir" -name "old_*.log.gz" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$gz_count" -eq 3 ]]; then
        echo "  ✓ rotate_logs compresses old files ($gz_count .gz files created)"
        (( pass++ ))
    else
        echo "  ✗ rotate_logs should compress old files, found $gz_count .gz files (expected 3)"
        (( fail++ ))
    fi

    # Test 9: rotate_logs preserves recent files
    recent_count="$(find "$test_dir" -name "recent_*.log" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$recent_count" -eq 2 ]]; then
        echo "  ✓ rotate_logs preserves recent files ($recent_count recent files remain)"
        (( pass++ ))
    else
        echo "  ✗ rotate_logs should preserve recent files, found $recent_count (expected 2)"
        (( fail++ ))
    fi

    # Test 10: rotate_logs without --compress deletes old files
    # Reset: create new old files for deletion test
    for i in 4 5; do
        echo "old content $i" > "$test_dir/delete_${i}.log"
        touch -d "60 days ago" "$test_dir/delete_${i}.log"
    done
    DIRECTORY="$test_dir" MAX_AGE=30 DRY_RUN=false COMPRESS=false
    rotate_logs > /dev/null 2>&1 || true
    delete_count="$(find "$test_dir" -name "delete_*.log" -type f 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$delete_count" -eq 0 ]]; then
        echo "  ✓ rotate_logs deletes old files when --compress is not set"
        (( pass++ ))
    else
        echo "  ✗ rotate_logs should delete old files, found $delete_count (expected 0)"
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
