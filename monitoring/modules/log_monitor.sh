#!/bin/bash

# Log Monitoring Module for HomeGuardian
# Monitors log file sizes, error patterns, and rotation status

set -e

# Configuration
CONFIG_DIR="$(dirname "$0")/../config"
LOGS_FILE="$CONFIG_DIR/logs.conf"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
DATA_DIR="$(dirname "$0")/../data/metrics"
LOG_DIR="$(dirname "$0")/../logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load thresholds from thresholds.conf
source <(grep -A 10 "^\[Logs\]" "$THRESHOLDS_FILE" | sed '1d')

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Function to parse logs configuration
parse_logs_config() {
    local logs_file=$1
    local section=""
    
    declare -A logs_config
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check for section headers
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Parse log entry line (format: path,size_limit,error_patterns,rotation_pattern)
        if [[ "$line" =~ ^([^,]+),([^,]+),([^,]+),([^,]+)$ ]]; then
            log_path="${BASH_REMATCH[1]}"
            size_limit="${BASH_REMATCH[2]}"
            error_patterns="${BASH_REMATCH[3]}"
            rotation_pattern="${BASH_REMATCH[4]}"
            
            logs_config["${section}:${log_path}"]="$size_limit|$error_patterns|$rotation_pattern"
        fi
    done < "$logs_file"
    
    # Return config as associative array
    for key in "${!logs_config[@]}"; do
        echo "$key=${logs_config[$key]}"
    done
}

# Function to check log file size
check_log_size() {
    local log_path=$1
    local size_limit_mb=$2
    
    if [ -f "$log_path" ]; then
        # Get file size in MB
        size_bytes=$(stat -f%z "$log_path" 2>/dev/null || stat -c%s "$log_path" 2>/dev/null)
        size_mb=$((size_bytes / 1024 / 1024))
        
        # Check against threshold
        if [ "$size_mb" -gt "$size_critical_mb" ]; then
            echo "CRITICAL|Log size critical: ${log_path} is ${size_mb}MB (>${size_critical_mb}MB)|size=${size_mb}MB"
        elif [ "$size_mb" -gt "$size_warning_mb" ]; then
            echo "WARNING|Log size warning: ${log_path} is ${size_mb}MB (>${size_warning_mb}MB)|size=${size_mb}MB"
        else
            echo "INFO|Log size normal: ${log_path} is ${size_mb}MB|size=${size_mb}MB"
        fi
    else
        echo "INFO|Log file not found: ${log_path}|status=not_found"
    fi
}

# Function to check log rotation
check_log_rotation() {
    local log_path=$1
    local rotation_pattern=$2
    
    local rotation_status="unknown"
    local last_modified_hours=0
    
    if [ -f "$log_path" ]; then
        # Get last modified time
        if [[ "$OSTYPE" == "darwin"* ]]; then
            last_modified=$(stat -f%m "$log_path")
        else
            last_modified=$(stat -c%Y "$log_path")
        fi
        
        current_time=$(date +%s)
        last_modified_hours=$(((current_time - last_modified) / 3600))
        
        # Check rotation pattern
        if [ "$rotation_pattern" != "none" ] && [ "$rotation_pattern" != "" ]; then
            # Check if rotated files exist
            rotated_files=$(ls "${log_path}".* 2>/dev/null || true)
            
            if [ -n "$rotated_files" ]; then
                rotation_status="rotating"
            else
                rotation_status="not_rotated"
            fi
        else
            rotation_status="no_rotation"
        fi
        
        # Check against thresholds
        if [ "$rotation_status" = "not_rotated" ] && [ "$last_modified_hours" -gt "$rotation_critical_hours" ]; then
            echo "CRITICAL|Log rotation critical: ${log_path} not rotated in ${last_modified_hours}h|hours=${last_modified_hours}"
        elif [ "$rotation_status" = "not_rotated" ] && [ "$last_modified_hours" -gt "$rotation_warning_hours" ]; then
            echo "WARNING|Log rotation warning: ${log_path} not rotated in ${last_modified_hours}h|hours=${last_modified_hours}"
        else
            echo "INFO|Log rotation normal: ${log_path}|status=${rotation_status},hours=${last_modified_hours}"
        fi
    else
        echo "INFO|Log file not found for rotation check: ${log_path}|status=not_found"
    fi
}

# Function to check for error patterns
check_error_patterns() {
    local log_path=$1
    local error_patterns=$2
    
    local error_count=0
    local high_severity_count=0
    local medium_severity_count=0
    local low_severity_count=0
    
    # Load error pattern thresholds
    source <(grep -A 10 "^\[ErrorPatterns\]" "$LOGS_FILE" | sed '1d')
    source <(grep -A 10 "^\[AlertThresholds\]" "$LOGS_FILE" | sed '1d')
    
    if [ -f "$log_path" ] && [ -n "$error_patterns" ]; then
        # Get current time and calculate time window
        current_time=$(date +%s)
        window_start=$((current_time - 3600))  # Last hour
        
        # Check if log has timestamps we can parse (simplified check)
        # For now, check entire file for patterns
        
        # Count high severity errors
        if [ -n "$high_severity" ]; then
            high_severity_count=$(grep -i -E "$high_severity" "$log_path" 2>/dev/null | wc -l || echo "0")
        fi
        
        # Count medium severity errors
        if [ -n "$medium_severity" ]; then
            medium_severity_count=$(grep -i -E "$medium_severity" "$log_path" 2>/dev/null | wc -l || echo "0")
        fi
        
        # Count low severity errors
        if [ -n "$low_severity" ]; then
            low_severity_count=$(grep -i -E "$low_severity" "$log_path" 2>/dev/null | wc -l || echo "0")
        fi
        
        # Count custom error patterns
        if [ "$error_patterns" != "none" ] && [ "$error_patterns" != "" ]; then
            error_count=$(grep -i -E "$error_patterns" "$log_path" 2>/dev/null | wc -l || echo "0")
        fi
        
        total_errors=$((high_severity_count + medium_severity_count + low_severity_count + error_count))
        
        # Check against thresholds
        if [ "$high_severity_count" -ge "$high_severity_per_hour" ] && [ "$high_severity_per_hour" -gt 0 ]; then
            echo "CRITICAL|High severity errors in ${log_path}: ${high_severity_count}|high=${high_severity_count}"
        elif [ "$medium_severity_count" -gt "$medium_severity_per_hour" ]; then
            echo "WARNING|Medium severity errors in ${log_path}: ${medium_severity_count}|medium=${medium_severity_count}"
        elif [ "$low_severity_count" -gt "$low_severity_per_hour" ]; then
            echo "WARNING|Low severity errors in ${log_path}: ${low_severity_count}|low=${low_severity_count}"
        elif [ "$total_errors" -gt "$total_errors_per_hour" ]; then
            echo "WARNING|Total errors in ${log_path}: ${total_errors}|total=${total_errors}"
        else
            echo "INFO|Error check normal for ${log_path}|high=${high_severity_count},medium=${medium_severity_count},low=${low_severity_count},custom=${error_count}"
        fi
    else
        if [ ! -f "$log_path" ]; then
            echo "INFO|Log file not found for error check: ${log_path}|status=not_found"
        else
            echo "INFO|No error patterns defined for ${log_path}|status=no_patterns"
        fi
    fi
}

# Function to handle glob patterns in log paths
expand_log_path() {
    local log_path=$1
    
    # Check if path contains wildcards
    if [[ "$log_path" == *"*"* ]]; then
        expanded_paths=$(ls $log_path 2>/dev/null || echo "")
        if [ -n "$expanded_paths" ]; then
            echo "$expanded_paths"
        else
            echo ""
        fi
    else
        echo "$log_path"
    fi
}

# Main monitoring function
monitor_logs() {
    echo "[$TIMESTAMP] Starting log monitoring..."
    
    # Parse logs configuration
    declare -A logs_config
    while IFS='=' read -r key value; do
        logs_config["$key"]="$value"
    done < <(parse_logs_config "$LOGS_FILE")
    
    # Arrays to store results
    declare -a log_entries
    declare -a size_alerts
    declare -a rotation_alerts
    declare -a error_alerts
    
    # Track overall status
    local overall_alert_level="INFO"
    local overall_alert_message=""
    local overall_alert_details=""
    
    # Check each log file
    for log_key in "${!logs_config[@]}"; do
        IFS='|' read -r size_limit error_patterns rotation_pattern <<< "${logs_config[$log_key]}"
        section=$(echo "$log_key" | cut -d: -f1)
        log_path=$(echo "$log_key" | cut -d: -f2)
        
        # Skip monitoring settings section
        if [ "$section" = "MonitoringSettings" ] || [ "$section" = "ErrorPatterns" ] || [ "$section" = "AlertThresholds" ]; then
            continue
        fi
        
        # Expand glob patterns
        expanded_paths=$(expand_log_path "$log_path")
        
        if [ -z "$expanded_paths" ]; then
            # Single file or no matches
            actual_paths="$log_path"
        else
            # Multiple files from glob
            actual_paths="$expanded_paths"
        fi
        
        # Check each actual file
        for actual_path in $actual_paths; do
            # Check file size
            size_result=$(check_log_size "$actual_path" "$size_limit")
            size_alert_level=$(echo "$size_result" | cut -d'|' -f1)
            size_alert_message=$(echo "$size_result" | cut -d'|' -f2)
            size_alert_details=$(echo "$size_result" | cut -d'|' -f3)
            
            # Check log rotation
            rotation_result=$(check_log_rotation "$actual_path" "$rotation_pattern")
            rotation_alert_level=$(echo "$rotation_result" | cut -d'|' -f1)
            rotation_alert_message=$(echo "$rotation_result" | cut -d'|' -f2)
            rotation_alert_details=$(echo "$rotation_result" | cut -d'|' -f3)
            
            # Check error patterns
            error_result=$(check_error_patterns "$actual_path" "$error_patterns")
            error_alert_level=$(echo "$error_result" | cut -d'|' -f1)
            error_alert_message=$(echo "$error_result" | cut -d'|' -f2)
            error_alert_details=$(echo "$error_result" | cut -d'|' -f3)
            
            # Store log entry
            log_entry=$(cat << EOF
{
  "path": "$actual_path",
  "section": "$section",
  "size_check": {
    "level": "$size_alert_level",
    "message": "$size_alert_message",
    "details": "$size_alert_details"
  },
  "rotation_check": {
    "level": "$rotation_alert_level",
    "message": "$rotation_alert_message",
    "details": "$rotation_alert_details"
  },
  "error_check": {
    "level": "$error_alert_level",
    "message": "$error_alert_message",
    "details": "$error_alert_details"
  }
}
EOF
            )
            
            log_entries+=("$log_entry")
            
            # Track alerts
            if [ "$size_alert_level" = "CRITICAL" ] || [ "$rotation_alert_level" = "CRITICAL" ] || [ "$error_alert_level" = "CRITICAL" ]; then
                size_alerts+=("$size_alert_message")
                rotation_alerts+=("$rotation_alert_message")
                error_alerts+=("$error_alert_message")
                
                if [ "$overall_alert_level" != "CRITICAL" ]; then
                    overall_alert_level="CRITICAL"
                fi
            elif [ "$size_alert_level" = "WARNING" ] || [ "$rotation_alert_level" = "WARNING" ] || [ "$error_alert_level" = "WARNING" ]; then
                if [ "$overall_alert_level" = "INFO" ]; then
                    overall_alert_level="WARNING"
                fi
            fi
        done
    done
    
    # Build overall alert message
    if [ ${#size_alerts[@]} -gt 0 ]; then
        overall_alert_message="${overall_alert_message:+$overall_alert_message, }Size issues: ${#size_alerts[@]}"
    fi
    if [ ${#rotation_alerts[@]} -gt 0 ]; then
        overall_alert_message="${overall_alert_message:+$overall_alert_message, }Rotation issues: ${#rotation_alerts[@]}"
    fi
    if [ ${#error_alerts[@]} -gt 0 ]; then
        overall_alert_message="${overall_alert_message:+$overall_alert_message, }Error issues: ${#error_alerts[@]}"
    fi
    
    # Create JSON output
    json_output=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "module": "log_monitor",
  "summary": {
    "total_logs_monitored": ${#log_entries[@]},
    "size_alerts": ${#size_alerts[@]},
    "rotation_alerts": ${#rotation_alerts[@]},
    "error_alerts": ${#error_alerts[@]}
  },
  "logs": [$(IFS=,; echo "${log_entries[*]}")],
  "alert": {
    "level": "$overall_alert_level",
    "message": "$overall_alert_message",
    "details": "size_alerts=${#size_alerts[@]},rotation_alerts=${#rotation_alerts[@]},error_alerts=${#error_alerts[@]}"
  },
  "thresholds": {
    "size_warning_mb": $size_warning_mb,
    "size_critical_mb": $size_critical_mb,
    "rotation_warning_hours": $rotation_warning_hours,
    "rotation_critical_hours": $rotation_critical_hours,
    "error_warning_hour": $error_warning_hour,
    "error_critical_hour": $error_critical_hour
  }
}
EOF
)
    
    # Save to file
    output_file="$DATA_DIR/logs_${TIMESTAMP}.json"
    echo "$json_output" > "$output_file"
    
    # Log overall alert if not INFO
    if [ "$overall_alert_level" != "INFO" ]; then
        echo "[$TIMESTAMP] [$overall_alert_level] $overall_alert_message" >> "$LOG_DIR/alerts.log"
        echo "[$TIMESTAMP] Log Alert: $overall_alert_message" >> "$LOG_DIR/monitoring.log"
        
        # Print alert to stdout for orchestration
        echo "ALERT:LOGS:$overall_alert_level:$overall_alert_message:size_alerts=${#size_alerts[@]},rotation_alerts=${#rotation_alerts[@]},error_alerts=${#error_alerts[@]}"
    else
        echo "[$TIMESTAMP] Log monitoring completed - All logs normal" >> "$LOG_DIR/monitoring.log"
    fi
    
    echo "[$TIMESTAMP] Log monitoring completed. Data saved to $output_file"
    
    # Return JSON for integration
    echo "$json_output"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_logs
fi