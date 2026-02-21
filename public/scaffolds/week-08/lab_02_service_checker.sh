#!/bin/bash
# =============================================================================
# Lab 8.2: Service Checker
# =============================================================================
#
# OBJECTIVE:
#   Write a script that takes service names as arguments, checks if each
#   is active using systemctl, reports status, and optionally restarts
#   failed services when called with --restart.
#
# CONCEPTS PRACTICED:
#   - Command-line arguments and $@ (Week 8)
#   - Conditionals and exit codes (Week 8)
#   - Loops (Week 8)
#   - Functions (Week 8)
#   - case statements (Week 8)
#   - systemctl (preview of Week 11)
#
# HOW TO RUN:
#   chmod +x lab_02_service_checker.sh
#   ./lab_02_service_checker.sh sshd cron nginx
#   ./lab_02_service_checker.sh --restart sshd cron nginx
#
# HOW TO TEST:
#   The script includes built-in tests at the bottom.
#   Run with --test to execute the test suite:
#     ./lab_02_service_checker.sh --test
#   All tests pass when your implementation is correct.
#
# =============================================================================

set -euo pipefail

# Global state
RESTART_MODE=false
SERVICES=()
TOTAL_CHECKED=0
TOTAL_ACTIVE=0
TOTAL_FAILED=0
TOTAL_RESTARTED=0

# =============================================================================
# TODO 1: usage
# =============================================================================
# Print a usage message to stderr and exit with code 1.
#
# HINT: See Section 8.6 (User Input) for how $0 gives the script name,
#   and Section 8.15 (Exit Codes) for directing error output to stderr
#   with >&2.
#
# Expected output:
#   Usage: ./lab_02_service_checker.sh [--restart] service1 [service2 ...]
#
#   Options:
#     --restart    Attempt to restart failed services (requires sudo)
#     --test       Run the built-in test suite
#     --help       Show this help message
# =============================================================================
usage() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED" >&2
    exit 1
}

# =============================================================================
# TODO 2: parse_args
# =============================================================================
# Parse command-line arguments. Detect the --restart flag and separate it
# from the list of service names. Store results in the global variables
# RESTART_MODE (true/false) and SERVICES (array of service names).
#
# HINT: See Section 8.6 (User Input) for the 'shift' command and
#   Section 8.12 (Loops) for 'while [[ "$#" -gt 0 ]]'. Use a case
#   statement (Section 8.13) to handle --restart, --help, --test, and
#   default (service names).
#
# After parsing:
#   - RESTART_MODE should be true or false
#   - SERVICES should contain the service names
#   - If no services are provided, call usage
#
# Examples:
#   parse_args --restart sshd cron   -> RESTART_MODE=true, SERVICES=(sshd cron)
#   parse_args sshd nginx            -> RESTART_MODE=false, SERVICES=(sshd nginx)
# =============================================================================
parse_args() {
    # YOUR CODE HERE
    :
}

# =============================================================================
# TODO 3: check_service
# =============================================================================
# Check if a single service is active using systemctl.
# Return 0 if the service is active, 1 if not.
#
# HINT: See Section 8.15 (Exit Codes) — 'systemctl is-active --quiet <service>'
#   returns 0 if the service is active and non-zero otherwise.
#   Use the return code directly; do not compare strings.
#   Remember: with set -e, a failing command exits the script. To safely
#   check a command that might fail, use 'if command; then' or
#   'command || return 1'.
#
# Arguments:
#   $1 — the service name to check
#
# Returns:
#   0 if active, 1 if inactive/failed/not-found
# =============================================================================
check_service() {
    local service_name="$1"
    # YOUR CODE HERE
    return 1
}

# =============================================================================
# TODO 4: report_status
# =============================================================================
# Print a formatted status line for one service.
#
# HINT: See Section 8.7 (Conditionals) for if/else structure.
#   Call check_service and use the result to print either:
#     "  [ ACTIVE ] sshd"
#   or:
#     "  [ FAILED ] nginx"
#   Also increment the global counters: TOTAL_CHECKED, TOTAL_ACTIVE,
#   TOTAL_FAILED. See Section 8.16 (Arithmetic) for (( counter++ )).
#
# Arguments:
#   $1 — the service name to report on
# =============================================================================
report_status() {
    local service_name="$1"
    # YOUR CODE HERE
    echo "  NOT_IMPLEMENTED: $service_name"
}

# =============================================================================
# TODO 5: restart_service
# =============================================================================
# Attempt to restart a failed service using sudo systemctl restart.
#
# HINT: See Section 8.15 (Exit Codes) for checking whether a command
#   succeeded. Use 'sudo systemctl restart "$service_name"' and check
#   the result. Print a message indicating success or failure.
#   Increment TOTAL_RESTARTED on success.
#
# Arguments:
#   $1 — the service name to restart
#
# Expected output on success:
#   "  -> Restarted sshd successfully"
# Expected output on failure:
#   "  -> Failed to restart nginx"
# =============================================================================
restart_service() {
    local service_name="$1"
    # YOUR CODE HERE
    echo "  NOT_IMPLEMENTED: restart $service_name"
}

# =============================================================================
# TODO 6: main
# =============================================================================
# The main function that ties everything together.
#
# HINT: See Section 8.12 (Loops) for iterating over an array with
#   'for service in "${SERVICES[@]}"'. Call report_status for each
#   service. If RESTART_MODE is true and the service is not active,
#   call restart_service. After the loop, print a summary.
#
# Steps:
#   1. Print a header with the current date/time
#   2. If RESTART_MODE is true, note it in the header
#   3. Loop through SERVICES, calling report_status for each
#   4. If RESTART_MODE is true, attempt to restart failed services
#   5. Print a summary line: "Summary: X checked, Y active, Z failed"
#   6. Exit with code 0 if all services are active, 1 if any failed
# =============================================================================
main() {
    # YOUR CODE HERE
    echo "NOT_IMPLEMENTED"
}

# =============================================================================
# Built-in Tests
# =============================================================================
run_tests() {
    local pass=0
    local fail=0

    echo "Running Lab 8.2 tests..."
    echo ""

    # Test 1: usage function outputs to stderr
    if usage_output="$(usage 2>&1)"; then
        # usage should exit 1, so this branch means failure
        echo "  ✗ usage should exit with code 1"
        (( fail++ ))
    else
        if [[ "$usage_output" =~ [Uu]sage ]]; then
            echo "  ✓ usage prints a usage message and exits with code 1"
            (( pass++ ))
        else
            echo "  ✗ usage should print a message containing 'Usage'"
            (( fail++ ))
        fi
    fi

    # Test 2: parse_args detects --restart flag
    RESTART_MODE=false
    SERVICES=()
    parse_args --restart sshd cron
    if [[ "$RESTART_MODE" == "true" ]] && [[ "${#SERVICES[@]}" -eq 2 ]]; then
        echo "  ✓ parse_args detects --restart and captures 2 services"
        (( pass++ ))
    else
        echo "  ✗ parse_args should set RESTART_MODE=true and SERVICES=(sshd cron)"
        echo "    Got: RESTART_MODE=$RESTART_MODE, SERVICES=(${SERVICES[*]:-})"
        (( fail++ ))
    fi

    # Test 3: parse_args works without --restart
    RESTART_MODE=false
    SERVICES=()
    parse_args sshd nginx
    if [[ "$RESTART_MODE" == "false" ]] && [[ "${#SERVICES[@]}" -eq 2 ]]; then
        echo "  ✓ parse_args works without --restart flag"
        (( pass++ ))
    else
        echo "  ✗ parse_args without --restart should set RESTART_MODE=false"
        echo "    Got: RESTART_MODE=$RESTART_MODE, SERVICES=(${SERVICES[*]:-})"
        (( fail++ ))
    fi

    # Test 4: check_service returns 0 for an active service
    # We test with a service likely to be running; skip if systemctl is not available
    if command -v systemctl > /dev/null 2>&1; then
        # Find a service that is actually active on this system
        local test_service=""
        for candidate in sshd ssh cron crond systemd-journald; do
            if systemctl is-active --quiet "$candidate" 2>/dev/null; then
                test_service="$candidate"
                break
            fi
        done

        if [[ -n "$test_service" ]]; then
            if check_service "$test_service"; then
                echo "  ✓ check_service returns 0 for active service: $test_service"
                (( pass++ ))
            else
                echo "  ✗ check_service should return 0 for active service: $test_service"
                (( fail++ ))
            fi
        else
            echo "  - check_service: skipped (no active test service found)"
        fi

        # Test 5: check_service returns 1 for a fake service
        if check_service "this-service-definitely-does-not-exist-12345"; then
            echo "  ✗ check_service should return 1 for nonexistent service"
            (( fail++ ))
        else
            echo "  ✓ check_service returns 1 for nonexistent service"
            (( pass++ ))
        fi
    else
        echo "  - check_service: skipped (systemctl not available)"
        echo "  - check_service (nonexistent): skipped (systemctl not available)"
    fi

    # Test 6: report_status outputs formatted status
    TOTAL_CHECKED=0
    TOTAL_ACTIVE=0
    TOTAL_FAILED=0
    local status_output
    status_output="$(report_status "this-service-definitely-does-not-exist-12345" 2>/dev/null)"
    if [[ "$status_output" =~ FAILED ]] || [[ "$status_output" =~ failed ]]; then
        echo "  ✓ report_status shows FAILED for nonexistent service"
        (( pass++ ))
    else
        echo "  ✗ report_status should show FAILED for nonexistent service"
        echo "    Got: $status_output"
        (( fail++ ))
    fi

    # Test 7: report_status increments counters
    if [[ "$TOTAL_CHECKED" -ge 1 && "$TOTAL_FAILED" -ge 1 ]]; then
        echo "  ✓ report_status increments TOTAL_CHECKED and TOTAL_FAILED counters"
        (( pass++ ))
    else
        echo "  ✗ report_status should increment TOTAL_CHECKED=$TOTAL_CHECKED and TOTAL_FAILED=$TOTAL_FAILED"
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
# Entry Point
# =============================================================================
case "${1:-}" in
    --test)
        run_tests
        ;;
    --help|-h)
        usage
        ;;
    "")
        usage
        ;;
    *)
        parse_args "$@"
        main
        ;;
esac
