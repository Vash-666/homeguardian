#!/bin/bash

# Diagnostic Tools Module
# Performs problem analysis before repair to ensure safe and appropriate actions

set -e

# Configuration
BASE_DIR="$(dirname "$0")/.."
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load configuration
SAFETY_FILE="$CONFIG_DIR/safety_limits.conf"
if [ -f "$SAFETY_FILE" ]; then
    source <(grep -A 10 "^\[General\]" "$SAFETY_FILE" | sed '1d')
    source <(grep -A 10 "^\[ResourceLimits\]" "$SAFETY_FILE" | sed '1d')
    source <(grep -A 10 "^\[ProcessSafety\]" "$SAFETY_FILE" | sed '1d')
fi

# Create directories if they don't exist
mkdir -p "$DATA_DIR/diagnostics" "$LOG_DIR"

# Function to analyze system state before repair
analyze_system_state() {
    local repair_request=$1
    
    echo "[$TIMESTAMP] Starting system state analysis..." >> "$LOG_DIR/diagnostics.log"
    
    # Extract information from repair request
    local module=$(echo "$repair_request" | jq -r '.module' 2>/dev/null || echo "unknown")
    local alert_message=$(echo "$repair_request" | jq -r '.alert_message' 2>/dev/null || echo "")
    local alert_details=$(echo "$repair_request" | jq -r '.alert_details' 2>/dev/null || echo "")
    
    # Create diagnostic report
    local diagnostic_report="$DATA_DIR/diagnostics/diagnostic_$(date +%s).json"
    
    # Gather comprehensive system information
    diagnostic_data=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "repair_request": $repair_request,
  "system_analysis": {
    "cpu": {
      "load_average": "$(uptime | awk -F'load average: ' '{print $2}')",
      "cpu_count": "$(nproc)",
      "top_processes": "$(ps aux --sort=-%cpu | head -6 | tail -5 | awk '{print $1","$2","$3","$4","$11}' | tr '\n' ';')"
    },
    "memory": {
      "total_mb": "$(free -m | awk '/^Mem:/ {print $2}')",
      "used_mb": "$(free -m | awk '/^Mem:/ {print $3}')",
      "free_mb": "$(free -m | awk '/^Mem:/ {print $4}')",
      "swap_used_mb": "$(free -m | awk '/^Swap:/ {print $3}')"
    },
    "disk": {
      "root_usage": "$(df -h / | awk 'NR==2 {print $5}')",
      "home_usage": "$(df -h /home 2>/dev/null | awk 'NR==2 {print $5}' || echo 'N/A')",
      "inodes_usage": "$(df -i / | awk 'NR==2 {print $5}')"
    },
    "processes": {
      "total_processes": "$(ps aux | wc -l)",
      "zombie_processes": "$(ps aux | awk '$8=="Z" {print $0}' | wc -l)",
      "defunct_processes": "$(ps aux | grep defunct | grep -v grep | wc -l)"
    },
    "services": {
      "failed_services": "$(systemctl list-units --state=failed 2>/dev/null | wc -l || echo 'N/A')",
      "critical_services": "$(systemctl list-units --state=running 2>/dev/null | grep -E '(ssh|cron|network|dbus)' | wc -l || echo 'N/A')"
    },
    "network": {
      "interfaces_up": "$(ip link show | grep 'state UP' | wc -l || ifconfig -a | grep 'status: active' | wc -l || echo 'N/A')",
      "default_gateway": "$(ip route | grep default | head -1 | awk '{print $3}' || route -n | grep '^0.0.0.0' | awk '{print $2}' || echo 'N/A')"
    }
  },
  "safety_checks": {
    "protected_processes_running": "$(check_protected_processes)",
    "resource_limits_ok": "$(check_resource_limits)",
    "system_stability": "$(check_system_stability)"
  },
  "repair_recommendations": {
    "recommended_action": "$(determine_recommended_action "$module" "$alert_message")",
    "safety_level": "$(determine_safety_level "$module" "$alert_message")",
    "estimated_downtime": "$(estimate_downtime "$module")",
    "rollback_required": "$(determine_rollback_requirement "$module")"
  }
}
EOF
    )
    
    echo "$diagnostic_data" | jq . > "$diagnostic_report"
    echo "[$TIMESTAMP] Diagnostic report saved to $diagnostic_report" >> "$LOG_DIR/diagnostics.log"
    
    echo "$diagnostic_data"
}

# Function to check if protected processes are running
check_protected_processes() {
    local protected_count=0
    local running_count=0
    
    # Check each protected process
    for process in $protected_processes; do
        if pgrep -x "$process" >/dev/null; then
            running_count=$((running_count + 1))
        fi
        protected_count=$((protected_count + 1))
    done
    
    if [ $protected_count -eq 0 ]; then
        echo "unknown"
    elif [ $running_count -eq $protected_count ]; then
        echo "all_running"
    elif [ $running_count -gt 0 ]; then
        echo "some_running"
    else
        echo "none_running"
    fi
}

# Function to check resource limits
check_resource_limits() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    
    if [ -z "$cpu_usage" ] || [ -z "$mem_usage" ]; then
        echo "unknown"
    elif [ "$cpu_usage" -gt "$max_cpu_usage_during_repair" ] || [ "$mem_usage" -gt "$max_memory_usage_during_repair" ]; then
        echo "exceeded"
    else
        echo "within_limits"
    fi
}

# Function to check system stability
check_system_stability() {
    # Check for recent crashes or panics
    local recent_errors=$(dmesg -T | grep -i "error\|panic\|crash\|failed" | tail -5 | wc -l)
    local load_average=$(uptime | awk -F'load average: ' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
    
    if [ "$recent_errors" -gt 3 ]; then
        echo "unstable"
    elif [ "$(echo "$load_average > 5" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "high_load"
    else
        echo "stable"
    fi
}

# Function to determine recommended action
determine_recommended_action() {
    local module=$1
    local alert_message=$2
    
    case "$module" in
        "cpu_monitor")
            if echo "$alert_message" | grep -qi "load"; then
                echo "restart_top_processes"
            else
                echo "adjust_process_priorities"
            fi
            ;;
        "memory_monitor")
            if echo "$alert_message" | grep -qi "swap"; then
                echo "adjust_swappiness"
            else
                echo "clear_memory_caches"
            fi
            ;;
        "disk_monitor")
            if echo "$alert_message" | grep -qi "full\|usage"; then
                echo "cleanup_temp_files"
            else
                echo "check_filesystem"
            fi
            ;;
        "service_monitor")
            echo "restart_service"
            ;;
        "log_monitor")
            echo "rotate_logs"
            ;;
        "network_monitor")
            echo "restart_network_services"
            ;;
        *)
            echo "investigate_further"
            ;;
    esac
}

# Function to determine safety level
determine_safety_level() {
    local module=$1
    local alert_message=$2
    
    case "$module" in
        "service_monitor"|"log_monitor")
            echo "low_risk"
            ;;
        "cpu_monitor"|"memory_monitor")
            echo "medium_risk"
            ;;
        "disk_monitor")
            echo "high_risk"
            ;;
        *)
            echo "unknown_risk"
            ;;
    esac
}

# Function to estimate downtime
estimate_downtime() {
    local module=$1
    
    case "$module" in
        "service_monitor")
            echo "10"
            ;;
        "log_monitor"|"network_monitor")
            echo "5"
            ;;
        "cpu_monitor"|"memory_monitor")
            echo "2"
            ;;
        "disk_monitor")
            echo "30"
            ;;
        *)
            echo "15"
            ;;
    esac
}

# Function to determine rollback requirement
determine_rollback_requirement() {
    local module=$1
    
    case "$module" in
        "disk_monitor")
            echo "true"
            ;;
        "service_monitor")
            if [ "$require_rollback_for_destructive" = "true" ]; then
                echo "true"
            else
                echo "false"
            fi
            ;;
        *)
            echo "false"
            ;;
    esac
}

# Main execution
if [ "$#" -eq 1 ]; then
    # If a repair request is provided as argument
    repair_request="$1"
    analyze_system_state "$repair_request"
else
    # Interactive mode or test mode
    echo "Diagnostic Tools Module"
    echo "Usage: $0 [repair_request_json]"
    echo ""
    echo "Running self-test..."
    
    # Create a test repair request
    test_request='{"module": "cpu_monitor", "alert_message": "High CPU load detected", "alert_details": "Load average: 9.85"}'
    analyze_system_state "$test_request"
fi