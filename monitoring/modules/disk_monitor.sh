#!/bin/bash

# Disk Monitoring Module for HomeGuardian
# Monitors disk usage, I/O performance, and SMART status

set -e

# Configuration
CONFIG_DIR="$(dirname "$0")/../config"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
DATA_DIR="$(dirname "$0")/../data/metrics"
LOG_DIR="$(dirname "$0")/../logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load thresholds
source <(grep -A 10 "^\[Disk\]" "$THRESHOLDS_FILE" | sed '1d')

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Function to get disk usage
get_disk_usage() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - using df with human readable output
        df_output=$(df -H / /System/Volumes/Data /Users 2>/dev/null | grep -v "Filesystem")
    else
        # Linux
        df_output=$(df -h / /home /var /tmp 2>/dev/null | grep -v "Filesystem")
    fi
    
    echo "$df_output"
}

# Function to get disk I/O statistics
get_disk_io() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - using iostat
        iostat_output=$(iostat -d -w 1 2 2>/dev/null | tail -n +3)
        echo "$iostat_output"
    else
        # Linux - using iostat
        iostat_output=$(iostat -d -y 1 1 2>/dev/null | tail -n +3)
        echo "$iostat_output"
    fi
}

# Function to get SMART status (if available)
get_smart_status() {
    local status="UNKNOWN"
    
    # Check if smartctl is available
    if command -v smartctl &> /dev/null; then
        # Try to get SMART status for the primary disk
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS - disk0 is typically the main disk
            smart_output=$(smartctl -a /dev/disk0 2>/dev/null || true)
        else
            # Linux - try common disk names
            for disk in /dev/sda /dev/nvme0n1 /dev/mmcblk0; do
                if [ -b "$disk" ]; then
                    smart_output=$(smartctl -a "$disk" 2>/dev/null || true)
                    break
                fi
            done
        fi
        
        # Extract SMART overall health status
        if echo "$smart_output" | grep -q "SMART overall-health self-assessment test result: PASSED"; then
            status="HEALTHY"
        elif echo "$smart_output" | grep -q "SMART overall-health self-assessment test result: FAILED"; then
            status="FAILED"
        elif echo "$smart_output" | grep -q "SMART Health Status: OK"; then
            status="HEALTHY"
        fi
    fi
    
    echo "$status"
}

# Function to get inode usage
get_inode_usage() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - using df -i
        df_output=$(df -i / /System/Volumes/Data /Users 2>/dev/null | grep -v "Filesystem")
    else
        # Linux
        df_output=$(df -i / /home /var /tmp 2>/dev/null | grep -v "Filesystem")
    fi
    
    echo "$df_output"
}

# Function to parse disk usage and check thresholds
check_disk_thresholds() {
    local df_output=$1
    local inode_output=$2
    
    local alert_level="INFO"
    local alert_message=""
    local alert_details=""
    
    # Parse df output line by line
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            # Extract disk information
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS df format
                filesystem=$(echo "$line" | awk '{print $1}')
                size=$(echo "$line" | awk '{print $2}')
                used=$(echo "$line" | awk '{print $3}')
                avail=$(echo "$line" | awk '{print $4}')
                capacity=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                mounted=$(echo "$line" | awk '{print $9}')
            else
                # Linux df format
                filesystem=$(echo "$line" | awk '{print $1}')
                size=$(echo "$line" | awk '{print $2}')
                used=$(echo "$line" | awk '{print $3}')
                avail=$(echo "$line" | awk '{print $4}')
                capacity=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                mounted=$(echo "$line" | awk '{print $6}')
            fi
            
            # Check disk usage threshold
            if [ "$capacity" -gt "$critical_threshold" ]; then
                alert_level="CRITICAL"
                alert_message="${alert_message:+$alert_message, }Disk critical: ${mounted} at ${capacity}%"
                alert_details="${alert_details:+$alert_details, }${mounted}=${capacity}%"
            elif [ "$capacity" -gt "$warning_threshold" ]; then
                if [ "$alert_level" != "CRITICAL" ]; then
                    alert_level="WARNING"
                fi
                alert_message="${alert_message:+$alert_message, }Disk warning: ${mounted} at ${capacity}%"
                alert_details="${alert_details:+$alert_details, }${mounted}=${capacity}%"
            fi
        fi
    done <<< "$df_output"
    
    # Check inode usage if output provided
    if [ -n "$inode_output" ]; then
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                # Extract inode information
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    filesystem=$(echo "$line" | awk '{print $1}')
                    inode_used=$(echo "$line" | awk '{print $3}')
                    inode_free=$(echo "$line" | awk '{print $4}')
                    inode_capacity=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                    mounted=$(echo "$line" | awk '{print $9}')
                else
                    filesystem=$(echo "$line" | awk '{print $1}')
                    inode_used=$(echo "$line" | awk '{print $3}')
                    inode_free=$(echo "$line" | awk '{print $4}')
                    inode_capacity=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                    mounted=$(echo "$line" | awk '{print $6}')
                fi
                
                # Check inode threshold
                if [ "$inode_capacity" -gt "$inode_critical" ]; then
                    alert_level="CRITICAL"
                    alert_message="${alert_message:+$alert_message, }Inodes critical: ${mounted} at ${inode_capacity}%"
                    alert_details="${alert_details:+$alert_details, }inodes_${mounted}=${inode_capacity}%"
                elif [ "$inode_capacity" -gt "$inode_warning" ]; then
                    if [ "$alert_level" != "CRITICAL" ]; then
                        alert_level="WARNING"
                    fi
                    alert_message="${alert_message:+$alert_message, }Inodes warning: ${mounted} at ${inode_capacity}%"
                    alert_details="${alert_details:+$alert_details, }inodes_${mounted}=${inode_capacity}%"
                fi
            fi
        done <<< "$inode_output"
    fi
    
    echo "$alert_level|$alert_message|$alert_details"
}

# Function to check disk I/O performance
check_disk_io() {
    local io_output=$1
    
    local alert_level="INFO"
    local alert_message=""
    local alert_details=""
    
    if [ -n "$io_output" ]; then
        # Parse iostat output (simplified - just check if there's high wait time)
        # This is a simplified check; real implementation would parse iostat metrics
        if echo "$io_output" | grep -q "wait" && [[ "$OSTYPE" != "darwin"* ]]; then
            # Extract average wait time (Linux iostat format)
            avg_wait=$(echo "$io_output" | tail -1 | awk '{print $10}')
            
            if [ -n "$avg_wait" ] && [ "$avg_wait" != "0.00" ]; then
                # Convert to integer for comparison
                avg_wait_ms=$(echo "$avg_wait * 1000" | bc | awk '{print int($1)}')
                
                if [ "$avg_wait_ms" -gt "$io_critical_ms" ]; then
                    alert_level="CRITICAL"
                    alert_message="Disk I/O critical: ${avg_wait_ms}ms wait time"
                    alert_details="io_wait=${avg_wait_ms}ms"
                elif [ "$avg_wait_ms" -gt "$io_warning_ms" ]; then
                    alert_level="WARNING"
                    alert_message="Disk I/O warning: ${avg_wait_ms}ms wait time"
                    alert_details="io_wait=${avg_wait_ms}ms"
                fi
            fi
        fi
    fi
    
    echo "$alert_level|$alert_message|$alert_details"
}

# Main monitoring function
monitor_disk() {
    echo "[$TIMESTAMP] Starting disk monitoring..."
    
    # Get metrics
    disk_usage=$(get_disk_usage)
    disk_io=$(get_disk_io)
    smart_status=$(get_smart_status)
    inode_usage=$(get_inode_usage)
    
    # Check disk usage thresholds
    disk_alert_result=$(check_disk_thresholds "$disk_usage" "$inode_usage")
    disk_alert_level=$(echo "$disk_alert_result" | cut -d'|' -f1)
    disk_alert_message=$(echo "$disk_alert_result" | cut -d'|' -f2)
    disk_alert_details=$(echo "$disk_alert_result" | cut -d'|' -f3)
    
    # Check disk I/O thresholds
    io_alert_result=$(check_disk_io "$disk_io")
    io_alert_level=$(echo "$io_alert_result" | cut -d'|' -f1)
    io_alert_message=$(echo "$io_alert_result" | cut -d'|' -f2)
    io_alert_details=$(echo "$io_alert_result" | cut -d'|' -f3)
    
    # Determine overall alert level
    alert_level="INFO"
    alert_message=""
    alert_details=""
    
    # Combine alerts, taking the highest severity
    if [ "$disk_alert_level" = "CRITICAL" ] || [ "$io_alert_level" = "CRITICAL" ]; then
        alert_level="CRITICAL"
    elif [ "$disk_alert_level" = "WARNING" ] || [ "$io_alert_level" = "WARNING" ]; then
        alert_level="WARNING"
    fi
    
    # Combine messages
    if [ -n "$disk_alert_message" ]; then
        alert_message="$disk_alert_message"
        alert_details="$disk_alert_details"
    fi
    
    if [ -n "$io_alert_message" ]; then
        alert_message="${alert_message:+$alert_message, }$io_alert_message"
        alert_details="${alert_details:+$alert_details, }$io_alert_details"
    fi
    
    # Check SMART status
    if [ "$smart_status" = "FAILED" ]; then
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }SMART status: FAILED"
        alert_details="${alert_details:+$alert_details, }smart_status=failed"
    elif [ "$smart_status" = "UNKNOWN" ]; then
        # Don't alert for unknown, just note in details
        alert_details="${alert_details:+$alert_details, }smart_status=unknown"
    fi
    
    # Create JSON output
    json_output=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "module": "disk_monitor",
  "metrics": {
    "disk_usage": "$(echo "$disk_usage" | tr '\n' ';' | sed 's/"/\\"/g')",
    "disk_io": "$(echo "$disk_io" | tr '\n' ';' | sed 's/"/\\"/g')",
    "inode_usage": "$(echo "$inode_usage" | tr '\n' ';' | sed 's/"/\\"/g')",
    "smart_status": "$smart_status"
  },
  "alert": {
    "level": "$alert_level",
    "message": "$alert_message",
    "details": "$alert_details"
  },
  "thresholds": {
    "warning": $warning_threshold,
    "critical": $critical_threshold,
    "io_warning_ms": $io_warning_ms,
    "io_critical_ms": $io_critical_ms,
    "inode_warning": $inode_warning,
    "inode_critical": $inode_critical
  }
}
EOF
)
    
    # Save to file
    output_file="$DATA_DIR/disk_${TIMESTAMP}.json"
    echo "$json_output" > "$output_file"
    
    # Log alert if not INFO
    if [ "$alert_level" != "INFO" ]; then
        echo "[$TIMESTAMP] [$alert_level] $alert_message" >> "$LOG_DIR/alerts.log"
        echo "[$TIMESTAMP] Disk Alert: $alert_message" >> "$LOG_DIR/monitoring.log"
        
        # Print alert to stdout for orchestration
        echo "ALERT:DISK:$alert_level:$alert_message:$alert_details"
    else
        echo "[$TIMESTAMP] Disk monitoring completed - All metrics normal" >> "$LOG_DIR/monitoring.log"
    fi
    
    echo "[$TIMESTAMP] Disk monitoring completed. Data saved to $output_file"
    
    # Return JSON for integration
    echo "$json_output"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_disk
fi