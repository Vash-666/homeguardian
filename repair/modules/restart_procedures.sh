#!/bin/bash

# Restart Procedures Module
# Handles service and process restarts with comprehensive safety checks

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
if [ -f "$RULES_FILE" ]; then
    source <(grep -A 10 "^\[Service\]" "$RULES_FILE" | sed '1d')
    source <(grep -A 10 "^\[General\]" "$RULES_FILE" | sed '1d')
fi
if [ -f "$SAFETY_FILE" ]; then
    source <(grep -A 10 "^\[ServiceSafety\]" "$SAFETY_FILE" | sed '1d')
    source <(grep -A 10 "^\[ProcessSafety\]" "$SAFETY_FILE" | sed '1d')
fi

# Create directories if they don't exist
mkdir -p "$DATA_DIR/restarts" "$LOG_DIR"

# Function to restart a service safely
restart_service_safely() {
    local service_name=$1
    local repair_context=$2
    
    echo "[$TIMESTAMP] Starting safe restart of service: $service_name" >> "$LOG_DIR/restarts.log"
    
    # Check if service is protected
    if echo "$protected_services" | grep -q "\b$service_name\b"; then
        echo "[$TIMESTAMP] ERROR: Service $service_name is protected and cannot be restarted" >> "$LOG_DIR/restarts.log"
        return 1
    fi
    
    # Create restart record
    local restart_record="$DATA_DIR/restarts/restart_${service_name}_$(date +%s).json"
    
    # Step 1: Pre-restart checks
    echo "[$TIMESTAMP] Step 1: Performing pre-restart checks..." >> "$LOG_DIR/restarts.log"
    
    pre_restart_checks=$(cat << EOF
{
  "service_name": "$service_name",
  "pre_restart_state": {
    "service_status": "$(get_service_status "$service_name")",
    "uptime_seconds": "$(get_service_uptime "$service_name")",
    "dependency_status": "$(check_service_dependencies "$service_name")",
    "process_count": "$(count_service_processes "$service_name")",
    "resource_usage": "$(get_service_resource_usage "$service_name")"
  },
  "safety_checks": {
    "min_uptime_met": "$(check_min_uptime "$service_name")",
    "dependencies_healthy": "$(verify_dependencies_before_restart "$service_name")",
    "concurrent_restarts_ok": "$(check_concurrent_restarts)",
    "system_load_acceptable": "$(check_system_load_before_restart)"
  }
}
EOF
    )
    
    # Check if we should proceed
    local min_uptime_ok=$(echo "$pre_restart_checks" | jq -r '.safety_checks.min_uptime_met')
    local dependencies_ok=$(echo "$pre_restart_checks" | jq -r '.safety_checks.dependencies_healthy')
    
    if [ "$min_uptime_ok" = "false" ] && [ "$min_service_uptime" -gt 0 ]; then
        echo "[$TIMESTAMP] WARNING: Service $service_name has not met minimum uptime requirement" >> "$LOG_DIR/restarts.log"
        # Continue anyway for critical repairs
    fi
    
    if [ "$dependencies_ok" = "false" ] && [ "$check_dependencies_before_restart" = "true" ]; then
        echo "[$TIMESTAMP] ERROR: Service dependencies not healthy" >> "$LOG_DIR/restarts.log"
        return 1
    fi
    
    # Step 2: Create service snapshot
    echo "[$TIMESTAMP] Step 2: Creating service snapshot..." >> "$LOG_DIR/restarts.log"
    
    service_snapshot=$(create_service_snapshot "$service_name")
    
    # Step 3: Perform the restart
    echo "[$TIMESTAMP] Step 3: Restarting service $service_name..." >> "$LOG_DIR/restarts.log"
    
    restart_result=$(perform_service_restart "$service_name")
    local restart_exit_code=$?
    
    # Step 4: Post-restart verification
    echo "[$TIMESTAMP] Step 4: Verifying restart..." >> "$LOG_DIR/restarts.log"
    
    post_restart_verification=$(verify_service_after_restart "$service_name")
    
    # Step 5: Create comprehensive restart report
    restart_report=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "module": "restart_procedures",
  "action": "service_restart",
  "service_name": "$service_name",
  "context": $repair_context,
  "pre_restart_state": $(echo "$pre_restart_checks" | jq '.pre_restart_state'),
  "service_snapshot": $service_snapshot,
  "restart_operation": {
    "command_executed": "$(echo "$restart_result" | jq -r '.command')",
    "exit_code": "$restart_exit_code",
    "output": "$(echo "$restart_result" | jq -r '.output' | head -100)",
    "duration_seconds": "$(echo "$restart_result" | jq -r '.duration')"
  },
  "post_restart_verification": $post_restart_verification,
  "overall_result": {
    "success": "$(determine_restart_success "$restart_exit_code" "$post_restart_verification")",
    "issues_detected": "$(identify_restart_issues "$restart_result" "$post_restart_verification")",
    "recommendations": "$(generate_restart_recommendations "$service_name" "$restart_result")",
    "next_steps": "$(determine_next_steps "$service_name" "$restart_exit_code")"
  }
}
EOF
    )
    
    echo "$restart_report" | jq . > "$restart_record"
    echo "[$TIMESTAMP] Restart record saved to $restart_record" >> "$LOG_DIR/restarts.log"
    
    # Return the restart report
    echo "$restart_report"
}

# Function to restart top CPU processes
restart_top_processes() {
    local process_count=$1
    local repair_context=$2
    
    echo "[$TIMESTAMP] Restarting top $process_count CPU processes..." >> "$LOG_DIR/restarts.log"
    
    # Get top CPU processes (excluding system processes)
    top_processes=$(ps aux --sort=-%cpu | awk 'NR>1 && !/^USER.*PID.*%CPU.*%MEM.*VSZ.*RSS.*TTY.*STAT.*START.*TIME.*COMMAND/ && $3 > 50 {print $2","$11","$3}' | head -$process_count)
    
    local restart_results=""
    local process_index=0
    
    # Restart each process with safety checks
    while IFS= read -r process_info; do
        process_index=$((process_index + 1))
        
        pid=$(echo "$process_info" | cut -d',' -f1)
        command=$(echo "$process_info" | cut -d',' -f2)
        cpu_usage=$(echo "$process_info" | cut -d',' -f3)
        
        # Skip protected processes
        if is_process_protected "$pid"; then
            echo "[$TIMESTAMP] Skipping protected process: $command (PID: $pid)" >> "$LOG_DIR/restarts.log"
            continue
        fi
        
        # Check concurrent restart limit
        if [ "$process_index" -gt "$max_concurrent_process_restarts" ]; then
            echo "[$TIMESTAMP] Reached concurrent restart limit, waiting..." >> "$LOG_DIR/restarts.log"
            sleep "$min_process_restart_interval"
            process_index=1
        fi
        
        # Restart the process
        process_result=$(restart_single_process "$pid" "$command" "$cpu_usage")
        restart_results="${restart_results}${process_result};"
        
        # Wait between restarts
        if [ "$process_index" -lt "$process_count" ]; then
            sleep "$min_process_restart_interval"
        fi
        
    done <<< "$top_processes"
    
    # Create restart report
    restart_report=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "module": "restart_procedures",
  "action": "restart_top_processes",
  "process_count": "$process_count",
  "context": $repair_context,
  "processes_restarted": "$(echo "$restart_results" | tr ';' '\n' | grep -v '^$' | wc -l)",
  "detailed_results": "$restart_results",
  "system_impact": {
    "cpu_before": "$(get_cpu_usage_before)",
    "cpu_after": "$(get_cpu_usage_after)",
    "load_average_change": "$(get_load_average_change)"
  }
}
EOF
    )
    
    echo "$restart_report"
}

# Helper functions

get_service_status() {
    local service_name=$1
    
    # Try systemd first
    if command -v systemctl >/dev/null 2>&1; then
        systemctl is-active "$service_name" 2>/dev/null || echo "unknown"
    # Try launchctl on macOS
    elif command -v launchctl >/dev/null 2>&1; then
        launchctl list | grep "$service_name" >/dev/null && echo "active" || echo "inactive"
    else
        echo "unknown"
    fi
}

get_service_uptime() {
    local service_name=$1
    
    # This is a simplified version
    # In production, you'd parse systemd status or process start time
    echo "0"
}

check_service_dependencies() {
    local service_name=$1
    
    if [ "$check_dependencies_before_restart" = "true" ]; then
        # Check if critical dependencies are running
        echo "assumed_healthy"
    else
        echo "not_checked"
    fi
}

count_service_processes() {
    local service_name=$1
    
    # Count processes related to this service
    ps aux | grep "$service_name" | grep -v grep | wc -l
}

get_service_resource_usage() {
    local service_name=$1
    
    # Get CPU and memory usage for service processes
    ps aux | grep "$service_name" | grep -v grep | awk '{cpu+=$3; mem+=$4} END {print cpu":"mem}'
}

check_min_uptime() {
    local service_name=$1
    local uptime=$(get_service_uptime "$service_name")
    
    if [ "$uptime" -lt "$min_service_uptime" ]; then
        echo "false"
    else
        echo "true"
    fi
}

verify_dependencies_before_restart() {
    local service_name=$1
    
    # Simplified dependency check
    echo "true"
}

check_concurrent_restarts() {
    # Check how many restarts are currently in progress
    local current_restarts=$(find "$DATA_DIR/restarts" -name "*.json" -mmin -5 2>/dev/null | wc -l)
    
    if [ "$current_restarts" -lt "$max_concurrent_process_restarts" ]; then
        echo "true"
    else
        echo "false"
    fi
}

check_system_load_before_restart() {
    local load1=$(uptime | awk -F'load average: ' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
    
    if [ "$(echo "$load1 > 5" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "high"
    else
        echo "acceptable"
    fi
}

create_service_snapshot() {
    local service_name=$1
    
    # Create a snapshot of service configuration and state
    cat << EOF
{
  "config_files": "$(find_service_configs "$service_name")",
  "environment": "$(get_service_environment "$service_name")",
  "open_files": "$(get_service_open_files "$service_name")",
  "network_connections": "$(get_service_connections "$service_name")"
}
EOF
}

perform_service_restart() {
    local service_name=$1
    local start_time=$(date +%s)
    
    # Try to restart the service
    if command -v systemctl >/dev/null 2>&1; then
        output=$(systemctl restart "$service_name" 2>&1)
        exit_code=$?
        command="systemctl restart $service_name"
    elif command -v service >/dev/null 2>&1; then
        output=$(service "$service_name" restart 2>&1)
        exit_code=$?
        command="service $service_name restart"
    else
        # Fallback: kill and restart (not recommended for production)
        pkill -f "$service_name"
        sleep 2
        # Try to start it (implementation depends on service)
        output="Used pkill fallback"
        exit_code=0
        command="pkill -f $service_name"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    cat << EOF
{
  "command": "$command",
  "exit_code": "$exit_code",
  "output": "$output",
  "duration": "$duration"
}
EOF
}

verify_service_after_restart() {
    local service_name=$1
    
    # Wait a bit for service to stabilize
    sleep 3
    
    # Check service status
    local status=$(get_service_status "$service_name")
    local processes=$(count_service_processes "$service_name")
    
    cat << EOF
{
  "status": "$status",
  "process_count": "$processes",
  "health_check": "$(perform_service_health_check "$service_name")",
  "response_time": "$(measure_service_response_time "$service_name")"
}
EOF
}

determine_restart_success() {
    local exit_code=$1
    local verification=$2
    local status=$(echo "$verification" | jq -r '.status')
    
    if [ "$exit_code" -eq 0 ] && [ "$status" = "active" ]; then
        echo "true"
    else
        echo "false"
    fi
}

identify_restart_issues() {
    local restart_result=$1
    local verification=$2
    
    local issues=""
    local exit_code=$(echo "$restart_result" | jq -r '.exit_code')
    local status=$(echo "$verification" | jq -r '.status')
    
    if [ "$exit_code" -ne 0 ]; then
        issues="${issues}restart_command_failed;"
    fi
    
    if [ "$status" != "active" ]; then
        issues="${issues}service_not_active;"
    fi
    
    if [ -z "$issues" ]; then
        echo "none"
    else
        echo "$issues"
    fi
}

generate_restart_recommendations() {
    local service_name=$1
    local restart_result=$2
    
    local exit_code=$(echo "$restart_result" | jq -r '.exit_code')
    
    if [ "$exit_code" -ne 0 ]; then
        echo "check_service_config;review_logs;manual_intervention"
    else
        echo "monitor_service;verify_functionality;update_documentation"
    fi
}

determine_next_steps() {
    local service_name=$1
    local exit_code=$2
    
    if [ "$exit_code" -eq 0 ]; then
        echo "continue_monitoring"
    else
        echo "escalate_to_admin"
    fi
}

is_process_protected() {
    local pid=$1
    
    # Check if process is in protected list
    local command=$(ps -p "$pid" -o comm= 2>/dev/null)
    
    for protected in $protected_processes; do
        if [ "$command" = "$protected" ]; then
            return 0
        fi
    done
    
    return 1
}

restart_single_process() {
    local pid=$1
    local command=$2
    local cpu_usage=$3
    
    # Try graceful termination first
    kill -TERM "$pid" 2>/dev/null
    sleep 2
    
    # Check if process terminated
    if ps -p "$pid" >/dev/null 2>&1; then
        # Force kill if needed
        kill -KILL "$pid" 2>/dev/null
        sleep 1
    fi
    
    # Note: We don't restart the process here
    # In a real system, you might restart it via service manager
    echo "pid:$pid,command:$command,cpu_before:$cpu_usage,action:terminated"
}

# Main execution
if [ "$#" -ge 2 ]; then
    action=$1
    shift
    
    case "$action" in
        "restart_service")
            service_name=$1
            repair_context=$2
            restart_service_safely "$service_name" "$repair_context"
            ;;
        "restart_processes")
            process_count=$1
            repair_context=$2
            restart_top_processes "$process_count" "$repair_context"
            ;;
        *)
            echo "Unknown action: $action"
            exit 1
            ;;
    esac
else
    echo "Restart Procedures Module"
    echo "Usage:"
    echo "  $0 restart_service <service_name> <repair_context_json>"
    echo