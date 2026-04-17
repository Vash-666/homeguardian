#!/bin/bash

# HomeGuardian Repair Request Watcher
# Monitors repair requests from @monitor and triggers routing to @fixer

set -e

# Configuration
REPAIR_REQUEST_DIR="../monitoring/data/repair_requests"
ROUTING_DIR="$(dirname "$0")"
LOG_DIR="$ROUTING_DIR/logs"
CONFIG_DIR="$ROUTING_DIR/config"
PROCESSED_DIR="$REPAIR_REQUEST_DIR/processed"
FAILED_DIR="$REPAIR_REQUEST_DIR/failed"

# Create directories if they don't exist
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$PROCESSED_DIR" "$FAILED_DIR"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_DIR/routing.log"
}

# Process a repair request
process_repair_request() {
    local request_file="$1"
    local request_id=$(basename "$request_file" .json)
    
    log_message "INFO" "Processing repair request: $request_id"
    
    # Parse the JSON request
    if ! python3 "$ROUTING_DIR/router.py" "$request_file"; then
        log_message "ERROR" "Failed to route request: $request_id"
        mv "$request_file" "$FAILED_DIR/"
        return 1
    fi
    
    # Move to processed directory
    mv "$request_file" "$PROCESSED_DIR/"
    log_message "SUCCESS" "Successfully routed request: $request_id"
    return 0
}

# Main watch loop
main() {
    log_message "INFO" "Starting Repair Request Watcher"
    log_message "INFO" "Watching directory: $REPAIR_REQUEST_DIR"
    log_message "INFO" "Routing directory: $ROUTING_DIR"
    
    # Initial scan of existing requests
    log_message "INFO" "Performing initial scan of repair requests"
    for request_file in "$REPAIR_REQUEST_DIR"/*.json 2>/dev/null; do
        if [ -f "$request_file" ]; then
            process_repair_request "$request_file"
        fi
    done
    
    # Continuous monitoring with inotifywait (Linux) or fswatch (macOS)
    log_message "INFO" "Starting continuous monitoring"
    
    if command -v inotifywait >/dev/null 2>&1; then
        # Linux: inotifywait
        inotifywait -m "$REPAIR_REQUEST_DIR" -e create -e moved_to --format '%w%f' |
        while read -r new_file; do
            if [[ "$new_file" == *.json ]]; then
                process_repair_request "$new_file"
            fi
        done
    elif command -v fswatch >/dev/null 2>&1; then
        # macOS: fswatch
        fswatch -0 "$REPAIR_REQUEST_DIR" --event Created --event MovedTo |
        while read -d "" new_file; do
            if [[ "$new_file" == *.json ]]; then
                process_repair_request "$new_file"
            fi
        done
    else
        # Fallback: polling every 5 seconds
        log_message "WARNING" "inotifywait/fswatch not found, using polling (5s interval)"
        while true; do
            for request_file in "$REPAIR_REQUEST_DIR"/*.json 2>/dev/null; do
                if [ -f "$request_file" ]; then
                    process_repair_request "$request_file"
                fi
            done
            sleep 5
        done
    fi
}

# Error handling
trap 'log_message "ERROR" "Watcher terminated unexpectedly"; exit 1' ERR
trap 'log_message "INFO" "Watcher shutting down gracefully"; exit 0' INT TERM

# Run main function
main "$@"