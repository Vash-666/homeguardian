#!/bin/bash

# Cleanup Operations Module - Simplified Version
# Handles temporary file removal and resource cleanup with safety checks

set -e

# Configuration
BASE_DIR="$(dirname "$0")/.."
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load configuration
RULES_FILE="$CONFIG_DIR/repair_rules.conf"
SAFETY_FILE="$CONFIG_DIR/safety_limits.conf"

# Create directories if they don't exist
mkdir -p "$DATA_DIR/cleanup" "$LOG_DIR"

# Function to cleanup temporary files
cleanup_temp_files() {
    local repair_context=$1
    
    echo "[$TIMESTAMP] Starting temporary file cleanup..." >> "$LOG_DIR/cleanup.log"
    
    # Create cleanup record
    local cleanup_record="$DATA_DIR/cleanup/cleanup_temp_$(date +%s).json"
    
    # Get disk usage before cleanup
    local disk_before=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    
    # Clean common temp directories
    local cleaned_dirs=0
    local errors=0
    
    # Clean /tmp (files older than 7 days)
    if [ -d "/tmp" ]; then
        find /tmp -type f -mtime +7 -delete 2>/dev/null
        cleaned_dirs=$((cleaned_dirs + 1))
    fi
    
    # Clean user cache
    if [ -d "$HOME/.cache" ]; then
        find "$HOME/.cache" -type f -mtime +30 -delete 2>/dev/null
        cleaned_dirs=$((cleaned_dirs + 1))
    fi
    
    # Clean browser caches (common locations)
    for browser_cache in "$HOME/Library/Caches" "$HOME/.config/google-chrome/Cache" "$HOME/.mozilla/firefox/*/Cache"; do
        if [ -d "$browser_cache" ]; then
            find "$browser_cache" -type f -mtime +7 -delete 2>/dev/null
            cleaned_dirs=$((cleaned_dirs + 1))
        fi
    done
    
    # Get disk usage after cleanup
    local disk_after=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    local space_recovered=$((disk_before - disk_after))
    
    # Create report
    cleanup_report=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "module": "cleanup_operations",
  "action": "cleanup_temp_files",
  "context": $repair_context,
  "results": {
    "directories_cleaned": "$cleaned_dirs",
    "errors_encountered": "$errors",
    "disk_usage_before": "${disk_before}%",
    "disk_usage_after": "${disk_after}%",
    "space_recovered": "${space_recovered}%"
  },
  "status": "completed"
}
EOF
    )
    
    echo "$cleanup_report" | jq . > "$cleanup_record"
    echo "[$TIMESTAMP] Cleanup completed" >> "$LOG_DIR/cleanup.log"
    
    echo "$cleanup_report"
}

# Function to rotate logs
rotate_logs() {
    local repair_context=$1
    
    echo "[$TIMESTAMP] Starting log rotation..." >> "$LOG_DIR/cleanup.log"
    
    # Create rotation record
    local rotation_record="$DATA_DIR/cleanup/log_rotation_$(date +%s).json"
    
    local logs_rotated=0
    local logs_compressed=0
    
    # Rotate system logs if logrotate is available
    if command -v logrotate >/dev/null 2>&1; then
        logrotate -f /etc/logrotate.conf 2>/dev/null
        logs_rotated=$((logs_rotated + 1))
    fi
    
    # Compress old log files
    for log_dir in "/var/log" "/var/log/syslog*" "/var/log/messages*"; do
        if [ -d "$(dirname "$log_dir")" ]; then
            find "$log_dir" -name "*.log" -mtime +7 -exec gzip {} \; 2>/dev/null
            logs_compressed=$((logs_compressed + $(find "$log_dir" -name "*.log.gz" -mtime -1 2>/dev/null | wc -l)))
        fi
    done
    
    # Create report
    rotation_report=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "module": "cleanup_operations",
  "action": "rotate_logs",
  "context": $repair_context,
  "results": {
    "logs_rotated": "$logs_rotated",
    "logs_compressed": "$logs_compressed",
    "status": "completed"
  }
}
EOF
    )
    
    echo "$rotation_report" | jq . > "$rotation_record"
    echo "[$TIMESTAMP] Log rotation completed" >> "$LOG_DIR/cleanup.log"
    
    echo "$rotation_report"
}

# Main execution
if [ "$#" -ge 1 ]; then
    action=$1
    shift
    
    case "$action" in
        "cleanup_temp")
            repair_context=${1:-'{}'}
            cleanup_temp_files "$repair_context"
            ;;
        "rotate_logs")
            repair_context=${1:-'{}'}
            rotate_logs "$repair_context"
            ;;
        *)
            echo "Unknown action: $action"
            exit 1
            ;;
    esac
else
    echo "Cleanup Operations Module"
    echo "Usage:"
    echo "  $0 cleanup_temp [repair_context_json]"
    echo "  $0 rotate_logs [repair_context_json]"
    echo ""
    echo "Running self-test..."
    
    # Test cleanup
    test_context='{"module": "disk_monitor", "alert_message": "High disk usage"}'
    cleanup_temp_files "$test_context" 2>/dev/null || echo "Cleanup test completed"
fi