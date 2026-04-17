#!/bin/bash

# Memory Monitoring Module for HomeGuardian
# Monitors memory usage, swap usage, and memory pressure

set -e

# Configuration
CONFIG_DIR="$(dirname "$0")/../config"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
DATA_DIR="$(dirname "$0")/../data/metrics"
LOG_DIR="$(dirname "$0")/../logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load thresholds
source <(grep -A 10 "^\[Memory\]" "$THRESHOLDS_FILE" | sed '1d')

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Function to get memory usage (macOS compatible)
get_memory_usage() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - using vm_stat
        page_size=$(pagesize)
        stats=$(vm_stat)
        
        free_pages=$(echo "$stats" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        active_pages=$(echo "$stats" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        inactive_pages=$(echo "$stats" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
        speculative_pages=$(echo "$stats" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
        wired_pages=$(echo "$stats" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
        compressed_pages=$(echo "$stats" | grep "Pages occupied by compressor" | awk '{print $5}' | sed 's/\.//')
        
        free_mb=$((free_pages * page_size / 1024 / 1024))
        active_mb=$((active_pages * page_size / 1024 / 1024))
        inactive_mb=$((inactive_pages * page_size / 1024 / 1024))
        speculative_mb=$((speculative_pages * page_size / 1024 / 1024))
        wired_mb=$((wired_pages * page_size / 1024 / 1024))
        compressed_mb=$((compressed_pages * page_size / 1024 / 1024))
        
        total_mb=$(( (free_pages + active_pages + inactive_pages + speculative_pages + wired_pages + compressed_pages) * page_size / 1024 / 1024 ))
        used_mb=$((total_mb - free_mb))
        usage_percent=$((used_mb * 100 / total_mb))
        
        echo "$usage_percent|$used_mb|$total_mb|$free_mb"
    else
        # Linux
        mem_info=$(free -m | grep Mem)
        total_mb=$(echo "$mem_info" | awk '{print $2}')
        used_mb=$(echo "$mem_info" | awk '{print $3}')
        free_mb=$(echo "$mem_info" | awk '{print $4}')
        usage_percent=$((used_mb * 100 / total_mb))
        
        echo "$usage_percent|$used_mb|$total_mb|$free_mb"
    fi
}

# Function to get swap usage
get_swap_usage() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        swap_info=$(sysctl vm.swapusage | awk '{print $4, $7, $10}')
        swap_used=$(echo "$swap_info" | awk '{print $1}' | sed 's/M//')
        swap_total=$(echo "$swap_info" | awk '{print $2}' | sed 's/M//')
        
        if [ "$swap_total" -gt 0 ]; then
            swap_percent=$((swap_used * 100 / swap_total))
        else
            swap_percent=0
        fi
        
        echo "$swap_percent|$swap_used|$swap_total"
    else
        # Linux
        swap_info=$(free -m | grep Swap)
        swap_total=$(echo "$swap_info" | awk '{print $2}')
        swap_used=$(echo "$swap_info" | awk '{print $3}')
        
        if [ "$swap_total" -gt 0 ]; then
            swap_percent=$((swap_used * 100 / swap_total))
        else
            swap_percent=0
        fi
        
        echo "$swap_percent|$swap_used|$swap_total"
    fi
}

# Function to get memory pressure (macOS only, Linux alternative)
get_memory_pressure() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS memory pressure
        pressure=$(memory_pressure | grep "System-wide memory free percentage:" | awk '{print $5}' | sed 's/%//')
        # Convert free percentage to pressure percentage
        pressure_percent=$((100 - pressure))
        echo "$pressure_percent"
    else
        # Linux - use /proc/meminfo for memory pressure approximation
        mem_info=$(cat /proc/meminfo)
        mem_available=$(echo "$mem_info" | grep MemAvailable | awk '{print $2}')
        mem_total=$(echo "$mem_info" | grep MemTotal | awk '{print $2}')
        
        if [ "$mem_total" -gt 0 ]; then
            available_percent=$((mem_available * 100 / mem_total))
            pressure_percent=$((100 - available_percent))
            echo "$pressure_percent"
        else
            echo "0"
        fi
    fi
}

# Function to get top memory processes
get_top_memory_processes() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        top_processes=$(ps -eo pmem,pid,user,comm -m | head -6)
    else
        # Linux
        top_processes=$(ps -eo pmem,pid,user,comm --sort=-pmem | head -6)
    fi
    echo "$top_processes"
}

# Function to check thresholds and generate alerts
check_thresholds() {
    local mem_usage=$1
    local swap_usage=$2
    local memory_pressure=$3
    
    local alert_level="INFO"
    local alert_message=""
    local alert_details=""
    
    # Check memory usage
    if (( $(echo "$mem_usage > $critical_threshold" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="Memory usage critical: ${mem_usage}%"
        alert_details="memory_usage=${mem_usage}%"
    elif (( $(echo "$mem_usage > $warning_threshold" | bc -l) )); then
        alert_level="WARNING"
        alert_message="Memory usage warning: ${mem_usage}%"
        alert_details="memory_usage=${mem_usage}%"
    fi
    
    # Check swap usage
    if [ "$swap_usage" != "0" ]; then
        if (( $(echo "$swap_usage > $swap_critical" | bc -l) )); then
            alert_level="CRITICAL"
            alert_message="${alert_message:+$alert_message, }Swap usage critical: ${swap_usage}%"
            alert_details="${alert_details:+$alert_details, }swap_usage=${swap_usage}%"
        elif (( $(echo "$swap_usage > $swap_warning" | bc -l) )); then
            if [ "$alert_level" != "CRITICAL" ]; then
                alert_level="WARNING"
            fi
            alert_message="${alert_message:+$alert_message, }Swap usage warning: ${swap_usage}%"
            alert_details="${alert_details:+$alert_details, }swap_usage=${swap_usage}%"
        fi
    fi
    
    # Check memory pressure
    if (( $(echo "$memory_pressure > $memory_pressure_critical" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }Memory pressure critical: ${memory_pressure}%"
        alert_details="${alert_details:+$alert_details, }memory_pressure=${memory_pressure}%"
    elif (( $(echo "$memory_pressure > $memory_pressure_warning" | bc -l) )); then
        if [ "$alert_level" != "CRITICAL" ]; then
            alert_level="WARNING"
        fi
        alert_message="${alert_message:+$alert_message, }Memory pressure warning: ${memory_pressure}%"
        alert_details="${alert_details:+$alert_details, }memory_pressure=${memory_pressure}%"
    fi
    
    echo "$alert_level|$alert_message|$alert_details"
}

# Main monitoring function
monitor_memory() {
    echo "[$TIMESTAMP] Starting memory monitoring..."
    
    # Get metrics
    mem_metrics=$(get_memory_usage)
    mem_usage=$(echo "$mem_metrics" | cut -d'|' -f1)
    mem_used_mb=$(echo "$mem_metrics" | cut -d'|' -f2)
    mem_total_mb=$(echo "$mem_metrics" | cut -d'|' -f3)
    mem_free_mb=$(echo "$mem_metrics" | cut -d'|' -f4)
    
    swap_metrics=$(get_swap_usage)
    swap_usage=$(echo "$swap_metrics" | cut -d'|' -f1)
    swap_used_mb=$(echo "$swap_metrics" | cut -d'|' -f2)
    swap_total_mb=$(echo "$swap_metrics" | cut -d'|' -f3)
    
    memory_pressure=$(get_memory_pressure)
    top_processes=$(get_top_memory_processes)
    
    # Check thresholds
    alert_result=$(check_thresholds "$mem_usage" "$swap_usage" "$memory_pressure")
    alert_level=$(echo "$alert_result" | cut -d'|' -f1)
    alert_message=$(echo "$alert_result" | cut -d'|' -f2)
    alert_details=$(echo "$alert_result" | cut -d'|' -f3)
    
    # Create JSON output
    json_output=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "module": "memory_monitor",
  "metrics": {
    "memory_usage_percent": $mem_usage,
    "memory_used_mb": $mem_used_mb,
    "memory_total_mb": $mem_total_mb,
    "memory_free_mb": $mem_free_mb,
    "swap_usage_percent": $swap_usage,
    "swap_used_mb": $swap_used_mb,
    "swap_total_mb": $swap_total_mb,
    "memory_pressure_percent": $memory_pressure
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
    "swap_warning": $swap_warning,
    "swap_critical": $swap_critical,
    "memory_pressure_warning": $memory_pressure_warning,
    "memory_pressure_critical": $memory_pressure_critical
  }
}
EOF
)
    
    # Save to file
    output_file="$DATA_DIR/memory_${TIMESTAMP}.json"
    echo "$json_output" > "$output_file"
    
    # Log alert if not INFO
    if [ "$alert_level" != "INFO" ]; then
        echo "[$TIMESTAMP] [$alert_level] $alert_message" >> "$LOG_DIR/alerts.log"
        echo "[$TIMESTAMP] Memory Alert: $alert_message" >> "$LOG_DIR/monitoring.log"
        
        # Print alert to stdout for orchestration
        echo "ALERT:MEMORY:$alert_level:$alert_message:$alert_details"
    else
        echo "[$TIMESTAMP] Memory monitoring completed - All metrics normal" >> "$LOG_DIR/monitoring.log"
    fi
    
    echo "[$TIMESTAMP] Memory monitoring completed. Data saved to $output_file"
    
    # Return JSON for integration
    echo "$json_output"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_memory
fi