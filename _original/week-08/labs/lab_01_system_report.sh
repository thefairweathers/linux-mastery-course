#!/bin/bash
# =============================================================================
# Lab 8.1: System Report Generator
# =============================================================================
#
# OBJECTIVE:
#   Write a script that generates a system health report including:
#   hostname, distro, uptime, CPU count, memory usage, disk usage,
#   top 5 processes by memory, logged-in users, and listening ports.
#
# CONCEPTS PRACTICED:
#   - Variables and quoting (Week 8)
#   - Command substitution (Week 4)
#   - Functions (Week 8)
#   - Text processing (Week 3)
#   - System monitoring commands (Week 7)
#
# HOW TO RUN:
#   chmod +x lab_01_system_report.sh
#   ./lab_01_system_report.sh
#
# HOW TO TEST:
#   The script includes built-in tests at the bottom.
#   Run with --test to execute the test suite:
#     ./lab_01_system_report.sh --test
#   All tests pass when your implementation is correct.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# TODO 1: get_hostname
# =============================================================================
# Return the system hostname (fully qualified if available).
#
# HINT: See Section 8.14 (Functions) — capture command output with stdout.
#   The 'hostname' command returns the system hostname.
#   Try 'hostname -f' for the FQDN; fall back to 'hostname' if it fails.
#
# Expected output example: "web-server-01.example.com" or "web-server-01"
# =============================================================================
get_hostname() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# TODO 2: get_distro
# =============================================================================
# Return the distribution name and version from /etc/os-release.
#
# HINT: See Section 8.4 (Variables) — use 'source' to load /etc/os-release,
#   then access the PRETTY_NAME variable. Remember to check if the file
#   exists first (Section 8.10 — File Tests).
#
# Expected output example: "Ubuntu 24.04.1 LTS" or "Rocky Linux 9.5"
# =============================================================================
get_distro() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# TODO 3: get_uptime
# =============================================================================
# Return the system uptime in a human-readable format.
#
# HINT: See Section 8.14 (Functions) — print to stdout for the caller to capture.
#   The 'uptime -p' command returns a pretty-printed uptime string.
#   If 'uptime -p' is not available (some systems), parse 'uptime' output.
#
# Expected output example: "up 3 days, 7 hours, 22 minutes"
# =============================================================================
get_uptime() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# TODO 4: get_cpu_count
# =============================================================================
# Return the number of CPU cores available.
#
# HINT: See Section 8.4 (Variables) — use command substitution $() to capture
#   output. The 'nproc' command returns the number of processing units.
#   Alternatively, parse /proc/cpuinfo with grep and wc.
#
# Expected output example: "4"
# =============================================================================
get_cpu_count() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# TODO 5: get_memory_usage
# =============================================================================
# Return memory usage as "used/total MB (XX% used)".
#
# HINT: See Section 8.16 (Arithmetic) for calculating the percentage.
#   Use 'free -m' to get memory in MB. The second line (Mem:) has columns:
#   total, used, free, shared, buff/cache, available.
#   Use awk to extract fields (Section 8.4 for command substitution).
#   For percentage: $(( (used * 100) / total ))
#
# Expected output example: "7534/16384 MB (45% used)"
# =============================================================================
get_memory_usage() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# TODO 6: get_disk_usage
# =============================================================================
# Return disk usage for / as "used/total (XX% used)".
#
# HINT: See Section 8.17 (String Manipulation) for cleaning up output.
#   Use 'df -h /' to get human-readable disk usage. Parse the second line
#   with awk. Fields: filesystem, size, used, available, use%, mount.
#   You can use awk to extract and format the fields in one step.
#
# Expected output example: "12G/50G (24% used)"
# =============================================================================
get_disk_usage() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# Report Generator (provided — calls your functions above)
# =============================================================================
generate_report() {
    local divider
    divider="$(printf '=%.0s' {1..60})"

    echo "$divider"
    echo "  SYSTEM HEALTH REPORT"
    echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "$divider"
    echo ""
    echo "  Hostname:      $(get_hostname)"
    echo "  Distribution:  $(get_distro)"
    echo "  Uptime:        $(get_uptime)"
    echo "  CPU Cores:     $(get_cpu_count)"
    echo "  Memory:        $(get_memory_usage)"
    echo "  Disk (/):      $(get_disk_usage)"
    echo ""

    echo "$divider"
    echo "  TOP 5 PROCESSES BY MEMORY"
    echo "$divider"
    echo ""
    ps aux --sort=-%mem 2>/dev/null | head -6 || ps aux | head -6
    echo ""

    echo "$divider"
    echo "  LOGGED-IN USERS"
    echo "$divider"
    echo ""
    who 2>/dev/null || echo "  (unable to determine)"
    echo ""

    echo "$divider"
    echo "  LISTENING PORTS"
    echo "$divider"
    echo ""
    if command -v ss > /dev/null 2>&1; then
        ss -tlnp 2>/dev/null || echo "  (requires elevated privileges for process info)"
    else
        netstat -tlnp 2>/dev/null || echo "  (requires net-tools or elevated privileges)"
    fi
    echo ""
    echo "$divider"
    echo "  END OF REPORT"
    echo "$divider"
}

# =============================================================================
# Built-in Tests
# =============================================================================
run_tests() {
    local pass=0
    local fail=0

    echo "Running Lab 8.1 tests..."
    echo ""

    # Test 1: get_hostname returns non-empty output
    result="$(get_hostname)"
    if [[ -n "$result" && "$result" != "NOT_IMPLEMENTED" ]]; then
        echo "  ✓ get_hostname returns: $result"
        (( pass++ ))
    else
        echo "  ✗ get_hostname returned empty or NOT_IMPLEMENTED"
        (( fail++ ))
    fi

    # Test 2: get_distro returns non-empty output
    result="$(get_distro)"
    if [[ -n "$result" && "$result" != "NOT_IMPLEMENTED" ]]; then
        echo "  ✓ get_distro returns: $result"
        (( pass++ ))
    else
        echo "  ✗ get_distro returned empty or NOT_IMPLEMENTED"
        (( fail++ ))
    fi

    # Test 3: get_uptime returns non-empty output
    result="$(get_uptime)"
    if [[ -n "$result" && "$result" != "NOT_IMPLEMENTED" ]]; then
        echo "  ✓ get_uptime returns: $result"
        (( pass++ ))
    else
        echo "  ✗ get_uptime returned empty or NOT_IMPLEMENTED"
        (( fail++ ))
    fi

    # Test 4: get_cpu_count returns a number
    result="$(get_cpu_count)"
    if [[ "$result" =~ ^[0-9]+$ && "$result" -gt 0 ]]; then
        echo "  ✓ get_cpu_count returns: $result"
        (( pass++ ))
    else
        echo "  ✗ get_cpu_count should return a positive integer, got: $result"
        (( fail++ ))
    fi

    # Test 5: get_memory_usage contains expected format
    result="$(get_memory_usage)"
    if [[ "$result" =~ [0-9]+/[0-9]+ && "$result" =~ % ]]; then
        echo "  ✓ get_memory_usage returns: $result"
        (( pass++ ))
    else
        echo "  ✗ get_memory_usage should match 'used/total (XX% used)', got: $result"
        (( fail++ ))
    fi

    # Test 6: get_disk_usage contains expected format
    result="$(get_disk_usage)"
    if [[ "$result" =~ / && "$result" =~ % ]]; then
        echo "  ✓ get_disk_usage returns: $result"
        (( pass++ ))
    else
        echo "  ✗ get_disk_usage should match 'used/total (XX% used)', got: $result"
        (( fail++ ))
    fi

    # Test 7: generate_report contains expected sections
    report="$(generate_report 2>/dev/null)"
    local sections_found=0
    for section in "SYSTEM HEALTH REPORT" "Hostname:" "Distribution:" "Uptime:" \
                   "CPU Cores:" "Memory:" "Disk" "TOP 5 PROCESSES" "LOGGED-IN USERS" \
                   "LISTENING PORTS"; do
        if echo "$report" | grep -q "$section"; then
            (( sections_found++ ))
        fi
    done
    if [[ "$sections_found" -ge 8 ]]; then
        echo "  ✓ generate_report contains all expected sections ($sections_found/10)"
        (( pass++ ))
    else
        echo "  ✗ generate_report missing sections (found $sections_found/10)"
        (( fail++ ))
    fi

    echo ""
    echo "Results: $pass passed, $fail failed out of $(( pass + fail )) tests"

    if [[ "$fail" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# =============================================================================
# Main
# =============================================================================
if [[ "${1:-}" == "--test" ]]; then
    run_tests
else
    generate_report
fi
