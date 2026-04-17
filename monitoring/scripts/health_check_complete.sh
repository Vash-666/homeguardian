#!/bin/bash

# HomeGuardian Health Check Orchestrator - Complete Version
# Main script that runs all monitoring modules and coordinates alerts

set -e

# Configuration
BASE_DIR="$(dirname "$0")/.."
MODULES_DIR="$BASE_DIR/modules"
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load general thresholds
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
if [ -f "$THRESHOLDS_FILE" ]; then
    source <(grep -A 10 "^\[General\]" "$THRESHOLDS_FILE" | sed '1d')
else
    # Default values if config not found
    check_interval_high=30
    check_interval_medium=300
    check_interval_low=900
    alert_cooldown=300
    quiet_hours_start=23
    quiet_hours_end=8
fi

# Create directories if they don't exist
mkdir -p "$DATA_DIR/metrics" "$LOG_DIR" "$DATA_DIR/baseline" "$DATA_DIR/repair_requests"

# Function to check if we're in quiet hours
in_quiet_hours() {
    local current_hour=$(date +%H)
    
    if [ "$quiet_hours_start" -le "$quiet_hours_end" ]; then
        # Normal case: quiet hours don't cross midnight
        if [ "$current_hour" -ge "$quiet_hours_start" ] && [ "$current_hour" -lt "$quiet_hours_end" ]; then
            return 0  # In quiet hours
        fi
    else
        # Quiet hours cross midnight (e.g., 23:00 to 08:00)
        if [ "$current_hour" -ge "$quiet_hours_start" ] || [ "$current_hour" -lt "$quiet_hours_end" ]; then
            return 0  # In quiet hours
        fi
    fi
    
    return 1  # Not in quiet hours
}

# Function to run a monitoring module
run_monitoring_module() {
    local module_name=$1
    local module_script="$MODULES_DIR/${module_name}.sh"
    
    if [ ! -f "$module_script" ]; then
        echo "[$TIMESTAMP] ERROR: Module $module_name not found at $module_script" >> "$LOG_DIR/errors.log"
        return 1
    fi
    
    # Make sure the script is executable
    chmod +x "$module_script" 2>/dev/null || true
    
    echo "[$TIMESTAMP] Running $module_name..."
    
    # Run the module and capture output
    module_output=$("$module_script" 2>&1)
    module_exit_code=$?
    
    if [ $module_exit_code -ne 0 ]; then
        echo "[$TIMESTAMP] ERROR: $module_name failed with exit code $module_exit_code" >> "$LOG_DIR/errors.log"
        echo "$module_output" >> "$LOG_DIR/errors.log"
        return $module_exit_code
    fi
    
    # Extract JSON output (last line should be JSON)
    json_output=$(echo "$module_output" | tail -1)
    
    # Check if it's valid JSON
    if echo "$json_output" | python3 -m json.tool >/dev/null 2>&1; then
        echo "$json_output"
        return 0
    else
        echo "[$TIMESTAMP] WARNING: $module_name did not return valid JSON" >> "$LOG_DIR/errors.log"
        return 1
    fi
}

# Function to process alerts from module output
process_alerts() {
    local module_name=$1
    local json_output=$2
    
    # Extract alert information from JSON
    alert_level=$(echo "$json_output" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('alert', {}).get('level', 'INFO'))" 2>/dev/null || echo "INFO")
    alert_message=$(echo "$json_output" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('alert', {}).get('message', ''))" 2>/dev/null || echo "")
    alert_details=$(echo "$json_output" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('alert', {}).get('details', ''))" 2>/dev/null || echo "")
    
    # Check if we should suppress alerts during quiet hours
    if in_quiet_hours; then
        if [ "$alert_level" = "WARNING" ]; then
            echo "[$TIMESTAMP] SUPPRESSED (quiet hours): $module_name - $alert_message" >> "$LOG_DIR/monitoring.log"
            return 0
        elif [ "$alert_level" = "INFO" ]; then
            # INFO alerts are always fine
            return 0
        fi
        # CRITICAL alerts still go through during quiet hours
    fi
    
    # Process based on alert level
    case "$alert_level" in
        "CRITICAL")
            echo "[$TIMESTAMP] CRITICAL: $module_name - $alert_message ($alert_details)" >> "$LOG_DIR/alerts.log"
            echo "ALERT:$module_name:CRITICAL:$alert_message:$alert_details"
            
            # Check if we should escalate to @fixer
            if should_escalate_to_fixer "$module_name" "$alert_message" "$alert_details"; then
                escalate_to_fixer "$module_name" "$alert_message" "$alert_details"
            fi
            ;;
            
        "WARNING")
            echo "[$TIMESTAMP] WARNING: $module_name - $alert_message ($alert_details)" >> "$LOG_DIR/alerts.log"
            echo "ALERT:$module_name:WARNING:$alert_message:$alert_details"
            ;;
            
        "INFO")
            # Just log to monitoring log
            echo "[$TIMESTAMP] INFO: $module_name - $alert_message" >> "$LOG_DIR/monitoring.log"
            ;;
            
        *)
            echo "[$TIMESTAMP] UNKNOWN: $module_name - Unknown alert level: $alert_level" >> "$LOG_DIR/errors.log"
            ;;
    esac
}

# Function to determine if we should escalate to @fixer
should_escalate_to_fixer() {
    local module_name=$1
    local alert_message=$2
    local alert_details=$3
    
    # Always escalate CRITICAL alerts for now
    # In a real implementation, we might check:
    # - If this is a recurring alert
    # - If automated repair is available for this issue
    # - If system is in maintenance mode
    # - If human intervention is required
    
    return 0  # For now, always escalate CRITICAL
}

# Function to escalate to @fixer
escalate_to_fixer() {
    local module_name=$1
    local alert_message=$2
    local alert_details=$3
    
    # Create a repair request file for @fixer
    local repair_request_file="$DATA_DIR/repair_requests/$(date +%s)_${module_name}.json"
    mkdir -p "$(dirname "$repair_request_file")"
    
    repair_request=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "module": "$module_name",
  "alert_level": "CRITICAL",
  "alert_message": "$alert_message",
  "alert_details": "$alert_details",
  "system_state": "needs_repair",
  "request_id": "req_$(date +%s)",
  "priority": "high"
}
EOF
    )
    
    echo "$repair_request" > "$repair_request_file"
    echo "[$TIMESTAMP] Escalated to @fixer: $alert_message" >> "$LOG_DIR/alerts.log"
}

# Function to generate health summary
generate_health_summary() {
    local all_results=$1
    
    # Count alerts
    critical_count=0
    warning_count=0
    healthy_count=0
    
    # Parse all results
    while IFS= read -r result; do
        if [ -n "$result" ]; then
            alert_level=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('alert', {}).get('level', 'INFO'))" 2>/dev/null || echo "UNKNOWN")
            
            case "$alert_level" in
                "CRITICAL") critical_count=$((critical_count + 1)) ;;
                "WARNING") warning_count=$((warning_count + 1)) ;;
                "INFO") healthy_count=$((healthy_count + 1)) ;;
                *) warning_count=$((warning_count + 1)) ;;
            esac
        fi
    done <<< "$all_results"
    
    total_count=$((critical_count + warning_count + healthy_count))
    
    # Determine overall health
    if [ "$critical_count" -gt 0 ]; then
        overall_health="CRITICAL"
    elif [ "$warning_count" -gt 0 ]; then
        overall_health="WARNING"
    else
        overall_health="HEALTHY"
    fi
    
    # Create summary
    summary=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "overall_health": "$overall_health",
  "summary": {
    "total_modules": $total_count,
    "critical": $critical_count,
    "warning": $warning_count,
    "healthy": $healthy_count
  },
  "health_percentage": $((healthy_count * 100 / total_count))
}
EOF
    )
    
    echo "$summary"
}

# Function to save baseline metrics (first run)
save_baseline_metrics() {
    local all_results=$1
    
    baseline_file="$DATA_DIR/baseline/first_baseline.json"
    
    if [ ! -f "$baseline_file" ]; then
        echo "[$TIMESTAMP] Saving baseline metrics..." >> "$LOG_DIR/monitoring.log"
        
        baseline_data=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "type": "initial_baseline",
  "metrics": $all_results
}
EOF
        )
        
        echo "$baseline_data" > "$baseline_file"
        echo "[$TIMESTAMP] Baseline metrics saved to $baseline_file" >> "$LOG_DIR/monitoring.log"
    fi
}

# Main health check function
run_health_check() {
    echo "[$TIMESTAMP] Starting HomeGuardian health check..."
    echo "[$TIMESTAMP] =========================================" >> "$LOG_DIR/monitoring.log"
    
    # Array to store all module results
    declare -a module_results
    declare -a all_alerts
    
    # Define monitoring modules to run
    modules=("cpu_monitor" "memory_monitor" "disk_monitor" "service_monitor" "log_monitor" "network_monitor")
    
    # Run each monitoring module
    for module in "${modules[@]}"; do
        echo "[$TIMESTAMP] --- Running $module ---" >> "$LOG_DIR/monitoring.log"
        
        # Run the module
        result=$(run_monitoring_module "$module")
        
        if [ $? -eq 0 ] && [ -n "$result" ]; then
            # Save the result
            module_results+=("$result")
            
            # Process alerts from this module
            alert_output=$(process_alerts "$module" "$result")
            if [ -n "$alert_output" ]; then
                all_alerts+=("$alert_output")
            fi
            
            # Save individual module result
            result_file="$DATA_DIR/metrics/${module}_${TIMESTAMP}.json"
            echo "$result" > "$result_file"
            
            echo "[$TIMESTAMP] $module completed successfully" >> "$LOG_DIR/monitoring.log"
        else
            echo "[$TIMESTAMP] ERROR: $module failed or returned no data" >> "$LOG_DIR/errors.log"
        fi
    done
    
    # Generate overall health summary
    if [ ${#module_results[@]} -gt 0 ]; then
        # Combine all results into a JSON array
        combined_results="["
        for ((i=0; i<${#module_results[@]}; i++)); do
            combined_results="${combined_results}${module_results[i]}"
            if [ $i -lt $((${#module_results[@]} - 1)) ]; then
                combined_results="${combined_results},"
            fi
        done
        combined_results="${combined_results}]"
        
        # Generate summary
        health_summary=$(generate_health_summary "$combined_results")
        
        # Save baseline if first run
        save_baseline_metrics "$combined_results"
        
        # Save summary
        summary_file="$DATA_DIR/metrics/health_summary_${TIMESTAMP}.json"
        echo "$health_summary" > "$summary_file"
        
        # Extract overall health from summary
        overall_health=$(echo "$health_summary" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['overall_health'])" 2>/dev/null || echo "UNKNOWN")
        
        echo "[$TIMESTAMP] Health check completed: $overall_health" >> "$LOG_DIR/monitoring.log"
        echo "[$TIMESTAMP] Summary saved to $summary_file" >> "$LOG_DIR/monitoring.log"
        
        # Print summary
        echo "HEALTH_CHECK_SUMMARY:$overall_health:$TIMESTAMP"
        
        # Print all alerts
        for alert in "${all_alerts[@]}"; do
            echo "$alert"
        done
        
        # Return exit code based on overall health
        case "$overall_health" in
            "CRITICAL") return 2 ;;
            "WARNING") return 1 ;;
            "HEALTHY") return 0 ;;
            *) return 3 ;;
        esac
    else
        echo "[$TIMESTAMP] ERROR: No monitoring modules completed successfully" >> "$LOG_DIR/errors.log"
        return 4
    fi
}

# Function to run in continuous monitoring mode
run_continuous_monitoring() {
    echo "[$TIMESTAMP] Starting continuous monitoring mode..."
    echo "[$TIMESTAMP] High-frequency checks: every ${check_interval_high}s" >> "$LOG_DIR/monitoring.log"
    echo "[$TIMESTAMP] Medium-frequency checks: every ${check_interval_medium}s" >> "$LOG_DIR/monitoring.log"
    echo "[$TIMESTAMP] Low-frequency checks: every ${check_interval_low}s" >> "$LOG_DIR/monitoring.log"
    
    # Track last run times for each frequency
    last_high_freq=0
    last_medium_freq=0
    last_low_freq=0
    
    while true; do
        current_time=$(date +%s)
        
        # Determine which checks to run
        run_high_freq=false
        run_medium_freq=false
        run_low_freq=false
        
        # High frequency checks (CPU, Memory)
        if [ $((current_time - last_high_freq)) -ge "$check_interval_high" ]; then
            run_high_freq=true
            last_high_freq=$current_time
        fi
        
        # Medium frequency checks (Disk, Network)
        if [ $((current_time - last_medium_freq)) -ge "$check_interval_medium" ]; then
            run_medium_freq=true
            last_medium_freq=$current_time
        fi
        
        # Low frequency checks (Services, Logs)
        if [ $((current_time - last_low_freq)) -ge "$check_interval_low" ]; then
            run_low_freq=true
            last_low_freq=$current_time
        fi
        
        # Run appropriate checks
        if [ "$run_high_freq" = true ] || [ "$run_medium_freq" = true ] || [ "$run_low_freq" = true ]; then
            echo "[$(date +%Y-%m-%d_%H:%M:%S)] Running checks: High=$run_high_freq, Medium=$run_medium_freq, Low=$run_low_freq" >> "$LOG_DIR/monitoring.log"
            
            # In a full implementation, we would run specific modules based on frequency
            # For now, run a full check
            run_health_check
        fi
        
        # Sleep for a short interval before checking again
        sleep 10
    done
}

# Parse command line arguments
case "${1:-}" in
    "continuous")
        run_continuous_monitoring
        ;;
    "single")
        run_health_check
        ;;
    "test")
        # Test mode - run all modules once and exit
        echo "Testing all monitoring modules..."
        for module in cpu_monitor memory_monitor disk_monitor service_monitor log_monitor network_monitor; do
            if [ -f "$MODULES_DIR/$module.sh" ]; then
                echo "Testing $module..."
                "$MODULES_DIR/$module.sh" >/dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo "  ✓ $module passed"
                else
                    echo "  ✗ $module failed"
                fi
            else
                echo "  ✗ $module not found"
            fi
        done
        ;;
    "summary")
        # Show latest health summary
        latest_summary=$(ls -t "$DATA_DIR/metrics/health_summary_"*.json 2>/dev/null | head -1)
        if [ -n "$latest_summary" ] && [ -f "$latest_summary" ]; then
            cat "$latest_summary" | python3 -m json.tool
        else
            echo "No health summary found. Run a health check first."
            exit 1
        fi
        ;;
    "alerts")
        # Show recent alerts
        if [ -f "$LOG_DIR/alerts.log" ]; then
            tail -20 "$LOG_DIR/alerts.log"
        else
            echo "No alerts found."
        fi
        ;;
    *)
        echo "Usage: $0 {continuous|single|test|summary|alerts}"
        echo "  continuous  - Run in continuous monitoring mode"
        echo "  single      - Run a single health check and exit"
        echo "  test        - Test all monitoring modules"
        echo "  summary     - Show latest health summary"
        echo "  alerts      - Show recent alerts"
        exit 1
        ;;
esac
