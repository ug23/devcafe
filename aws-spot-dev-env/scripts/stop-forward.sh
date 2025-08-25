#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_ROOT/.port-forward.pid"
INFO_FILE="$PROJECT_ROOT/.port-forward.info"
LOG_FILE="$PROJECT_ROOT/.port-forward.log"

echo "========================================="
echo "Stopping SSM Port Forwarding"
echo "========================================="

if [ ! -f "$PID_FILE" ]; then
    echo "No port forwarding session found."
    exit 0
fi

PID=$(cat "$PID_FILE")

# Check if process is running
if ps -p "$PID" > /dev/null 2>&1; then
    echo "Found port forwarding process (PID: $PID)"
    
    # Show current forwarding info if available
    if [ -f "$INFO_FILE" ]; then
        echo ""
        echo "Current forwarding details:"
        cat "$INFO_FILE" | while IFS='=' read -r key value; do
            echo "  $key: $value"
        done
        echo ""
    fi
    
    echo "Stopping process..."
    kill "$PID"
    
    # Wait for process to terminate
    sleep 1
    
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Process didn't stop gracefully. Force killing..."
        kill -9 "$PID"
    fi
    
    echo "Port forwarding stopped."
else
    echo "Process $PID is not running."
fi

# Clean up files
rm -f "$PID_FILE"
rm -f "$INFO_FILE"

echo ""
echo "========================================="
echo "Cleanup completed."
echo "========================================="

# Option to clean up log file
if [ -f "$LOG_FILE" ]; then
    echo ""
    read -p "Do you want to delete the log file? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$LOG_FILE"
        echo "Log file deleted."
    else
        echo "Log file kept at: $LOG_FILE"
    fi
fi