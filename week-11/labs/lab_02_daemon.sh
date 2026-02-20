#!/bin/bash
# Simple daemon script for Lab 11.2
# This script runs in a loop, writing timestamps to a log file.
# It's designed to be managed by a systemd service unit.

LOG_FILE="/var/log/my-daemon.log"

echo "Daemon starting at $(date)" >> "$LOG_FILE"

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daemon is running (PID: $$)" >> "$LOG_FILE"
    sleep 10
done
