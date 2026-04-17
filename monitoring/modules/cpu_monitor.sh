#!/bin/bash

# CPU Monitoring Module for HomeGuardian
# Monitors CPU usage, load averages, and process analysis

set -e

# Configuration
CONFIG_DIR="$(dirname "$0")/../config"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
DATA_DIR="$(dirname "$0")/../data/metrics"
LOG_DIR="$(dirname "$0")/../logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load thresholds
if [ -f "$THRESHOLDS_FILE" ]; then
    # Parse thresholds from config file
    warning_threshold=$(grep -A 10 "^\[CPU\]" "$THRESHOLDS_FILE" | grep "warning_threshold" | cut -d= -f2 | tr -d ' ')
    critical_threshold=$(grep -A 10 "^\[CPU\]" "$THRESHOLDS_FILE" | grep "critical_threshold" | cut -d= -f2 | tr -d ' ')
    load_warning_1m=$(grep -A 10 "^\[CPU\]" "$THRESHOLDS_FILE" | grep "load_warning_1m" | cut -d= -f2 | tr -d ' ')
    load_critical_1m=$(grep -A 10 "^\[CPU\]" "$THRESHOLDS_FILE" | grep "load_critical_1m" | cut -d= -f2 | tr -d ' ')
    process_warning=$(grep -A 10 "^\[CPU\]" "$THRESHOLDS_FILE" | grep "process_warning" | cut -d= -f2 | tr -d ' ')
    process_critical=$(grep -A 10 "^\[CPU\]" "$THRESHOLDS_FILE" | grep "process_critical" | cut -d= -f2 | tr -d ' ')
else
    # Default values if config not found
    warning_threshold=80
    critical_threshold=95
    load_warning_1m=4.0
    load_critical_1m=8.0
    process_warning=100
    process_critical=200
fi

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Function to get CPU usage
get_cpu_usage() {
    # Get CPU usage from top command (macOS compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    else
        # Linux
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    fi
    echo "$cpu_usage"
}

# Function to get load averages
get_load_averages() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        load=$(sysctl -n vm.loadavg | awk '{print $2, $3, $4}')
    else
        # Linux
        load=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    fi
    echo "$load"
}

# Function to get process count
get_process_count() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        process_count=$(ps aux | wc -l)
    else
        # Linux
        process_count=$(ps -e --no-headers | wc -l)
    fi
    echo $((process_count - 1))  # Subtract header line
}

# Function to get top CPU processes
get_top_processes() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        top_processes=$(ps -eo pcpu,pid,user,comm -r | head -6)
    else
        # Linux
        top_processes=$(ps -eo pcpu,pid,user,comm --sort=-pcpu | head -6)
    fi
    echo "$top_processes"
}

# Function to check thresholds and generate alerts
check_thresholds() {
    local cpu_usage=$1
    local load_1m=$2
    local load_5m=$3
    local load_15m=$4
    local process_count=$5
    
    local alert_level="INFO"
    local alert_message=""
    local alert_details=""
    
    # Check CPU usage
    if (( $(echo "$cpu_usage > $critical_threshold" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="CPU usage critical: ${cpu_usage}%"
        alert_details="cpu_usage=${cpu_usage}%"
    elif (( $(echo "$cpu_usage > $warning_threshold" | bc -l) )); then
        alert_level="WARNING"
        alert_message="CPU usage warning: ${cpu_usage}%"
        alert_details="cpu_usage=${cpu_usage}%"
    fi
    
    # Check load averages
    if (( $(echo "$load_1m > $load_critical_1m" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }1m load critical: ${load_1m}"
        alert_details="${alert_details:+$alert_details, }load_1m=${load_1m}"
    elif (( $(echo "$load_1m > $load_warning_1m" | bc -l) )); then
        if [ "$alert_level" != "CRITICAL" ]; then
            alert_level="WARNING"
        fi
        alert_message="${alert_message:+$alert_message, }1m load warning: ${load_1m}"
        alert_details="${alert_details:+$alert_details, }load_1m=${load_1m}"
    fi
    
    # Check process count
    if [ "$process_count" -gt "$process_critical" ]; then
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }Process count critical: ${process_count}"
        alert_details="${alert_details:+$alert_details, }process_count=${process_count}"
    elif [ "$process_count" -gt "$process_warning" ]; then
        if [ "$alert_level" != "CRITICAL" ]; then
            alert_level="WARNING"
        fi
        alert_message="${alert_message:+$alert_message, }Process count warning: ${process_count}"
        alert_details="${alert_details:+$alert_details, }process_count=${process_count}"
    fi
    
    echo "$alert_level|$alert_message|$alert_details"
}

# Main monitoring function
monitor_cpu() {
    echo "[$TIMESTAMP] Starting CPU monitoring..."
    
    # Get metrics
    cpu_usage=$(get_cpu_usage)
    load_averages=$(get_load_averages)
    load_1m=$(echo "$load_averages" | awk '{print $1}')
    load_5m=$(echo "$load_averages" | awk '{print $2}')
    load_15m=$(echo "$load_averages" | awk '{print $3}')
    process_count=$(get_process_count)
    top_processes=$(get_top_processes)
    
    # Check thresholds
    alert_result=$(check_thresholds "$cpu_usage" "$load_1m" "$load_5m" "$load_15m" "$process_count")
    alert_level=$(echo "$alert_result" | cut -d'|' -f1)
    alert_message=$(echo "$alert_result" | cut -d'|' -f2)
    alert_details=$(echo "$alert_result" | cut -d'|' -f3)
    
    # Create JSON output
    json_output=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "module": "cpu_monitor",
  "metrics": {
    "cpu_usage_percent": $cpu_usage,
    "load_1m": $load_1m,
    "load_5m": $load_5m,
    "load_15m": $load_15m,
    "process_count": $process_count
  },
  "top_processes": "$(echo "$top_processes" | tr '\n' ';' | sed 's/"/\\"/g')",
  "alert": {
    "level": "$alert_level",
    "message": "$alert_message",
    "details": "$alert_details"
  },
  "thresholds": {
    "warning": $warning_threshold,
    "critical": $critical_threshold,
    "load_warning_1m": $load_warning_1m,
    "load_critical_1m": $load_critical_1m
  }
}
EOF
)
    
    # Save to file
    output_file="$DATA_DIR/cpu_${TIMESTAMP}.json"
    echo "$json_output" > "$output_file"
    
    # Log alert if not INFO
    if [ "$alert_level" != "INFO" ]; then
        echo "[$TIMESTAMP] [$alert_level] $alert_message" >> "$LOG_DIR/alerts.log"
        echo "[$TIMESTAMP] CPU Alert: $alert_message" >> "$LOG_DIR/monitoring.log"
        
        # Print alert to stdout for orchestration
        echo "ALERT:CPU:$alert_level:$alert_message:$alert_details"
    else
        echo "[$TIMESTAMP] CPU monitoring completed - All metrics normal" >> "$LOG_DIR/monitoring.log"
    fi
    
    echo "[$TIMESTAMP] CPU monitoring completed. Data saved to $output_file"
    
    # Return JSON for integration
    echo "$json_output"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_cpu
fi