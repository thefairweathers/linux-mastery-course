#!/bin/bash
# Cleanup script for Lab 11.2 systemd timer exercise
# This script removes old log entries and temporary files.

LOG_FILE="/var/log/cleanup.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup started" >> "$LOG_FILE"

# Remove temporary files older than 7 days
if [[ -d /tmp ]]; then
    find /tmp -type f -mtime +7 -name "*.tmp" -delete 2>/dev/null
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleaned old .tmp files from /tmp" >> "$LOG_FILE"
fi

# Truncate the daemon log if it's larger than 1MB
DAEMON_LOG="/var/log/my-daemon.log"
if [[ -f "$DAEMON_LOG" ]]; then
    SIZE=$(stat -c%s "$DAEMON_LOG" 2>/dev/null || stat -f%z "$DAEMON_LOG" 2>/dev/null)
    if [[ "$SIZE" -gt 1048576 ]]; then
        tail -100 "$DAEMON_LOG" > "${DAEMON_LOG}.tmp"
        mv "${DAEMON_LOG}.tmp" "$DAEMON_LOG"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Truncated daemon log (was ${SIZE} bytes)" >> "$LOG_FILE"
    fi
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup finished" >> "$LOG_FILE"
