#!/bin/bash

# Safety Checks Module
# Performs pre and post repair validation to ensure system stability

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
    source <(grep -A 10 "^\[FileSystemSafety\]" "$SAFETY_FILE" | sed '1d')
    source <(grep -A 10 "^\[ServiceSafety\]" "$SAFETY_FILE" | sed '1d')
fi

# Create directories if they don't exist
mkdir -p "$DATA_DIR/safety_checks" "$LOG_DIR"

# Function to perform pre-repair safety checks
pre_repair_safety_check() {
    local repair_plan=$1
    local diagnostic_report=$2
    
    echo "[$TIMESTAMP] Starting pre-repair safety checks..." >> "$LOG_DIR/safety.log"
    
    # Extract repair information
    local repair_action=$(echo "$repair_plan" | jq -r '.repair_action' 2>/dev/null || echo "unknown")
    local safety_level=$(echo "$repair_plan" | jq -r '.safety_level' 2>/dev/null || echo "unknown")
    
    # Create safety check report
    local safety_report="$DATA_DIR/safety_checks/pre_repair_$(date +%s).json"
    
    # Perform comprehensive safety checks
    safety_data=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "check_type": "pre_repair",
  "repair_action": "$repair_action",
  "safety_level": "$safety_level",
  "checks_performed": {
    "system_stability": "$(check_system_stability)",
    "resource_availability": "$(check_resource_availability)",
    "protected_entities": "$(check_protected_entities)",
    "backup_status": "$(check_backup_status "$repair_action")",
    "rollback_readiness": "$(check_rollback_readiness "$repair_action")"
  },
  "check_results": {
    "all_checks_passed": "$(evaluate_all_checks)",
    "blocking_issues": "$(identify_blocking_issues)",
    "warnings": "$(identify_warnings)",
    "recommendations": "$(generate_recommendations "$repair_action")"
  },
  "safety_verdict": {
    "proceed_with_repair": "$(determine_safety_verdict)",
    "required_approvals": "$(determine_required_approvals "$repair_action")",
    "estimated_risk": "$(estimate_risk_level "$repair_action")",
    "contingency_plan": "$(create_contingency_plan "$repair_action")"
  }
}
EOF
    )
    
    echo "$safety_data" | jq . > "$safety_report"
    echo "[$TIMESTAMP] Pre-repair safety report saved to $safety_report" >> "$LOG_DIR/safety.log"
    
    # Check if we should proceed
    local proceed=$(echo "$safety_data" | jq -r '.safety_verdict.proceed_with_repair')
    
    if [ "$proceed" = "true" ]; then
        echo "[$TIMESTAMP] Safety checks PASSED - Repair can proceed" >> "$LOG_DIR/safety.log"
        echo "$safety_data"
        return 0
    else
        echo "[$TIMESTAMP] Safety checks FAILED - Repair blocked" >> "$LOG_DIR/safety.log"
        echo "$safety_data"
        return 1
    fi
}

# Function to perform post-repair safety checks
post_repair_safety_check() {
    local repair_result=$1
    local pre_repair_state=$2
    
    echo "[$TIMESTAMP] Starting post-repair safety checks..." >> "$LOG_DIR/safety.log"
    
    # Extract repair information
    local repair_action=$(echo "$repair_result" | jq -r '.repair_action' 2>/dev/null || echo "unknown")
    local repair_status=$(echo "$repair_result" | jq -r '.status' 2>/dev/null || echo "unknown")
    
    # Create safety check report
    local safety_report="$DATA_DIR/safety_checks/post_repair_$(date +%s).json"
    
    # Perform comprehensive safety checks
    safety_data=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "check_type": "post_repair",
  "repair_action": "$repair_action",
  "repair_status": "$repair_status",
  "checks_performed": {
    "system_functionality": "$(check_system_functionality "$repair_action")",
    "service_health": "$(check_service_health "$repair_action")",
    "performance_impact": "$(check_performance_impact "$pre_repair_state")",
    "error_analysis": "$(check_for_errors "$repair_action")",
    "resource_consumption": "$(check_resource_consumption)"
  },
  "check_results": {
    "all_checks_passed": "$(evaluate_post_repair_checks)",
    "new_issues": "$(identify_new_issues "$pre_repair_state")",
    "improvements": "$(identify_improvements "$pre_repair_state")",
    "residual_risks": "$(identify_residual_risks "$repair_action")"
  },
  "safety_verdict": {
    "repair_successful": "$(determine_repair_success "$repair_result")",
    "followup_required": "$(determine_followup_required)",
    "monitoring_recommendations": "$(generate_monitoring_recommendations "$repair_action")",
    "lessons_learned": "$(capture_lessons_learned "$repair_action")"
  }
}
EOF
    )
    
    echo "$safety_data" | jq . > "$safety_report"
    echo "[$TIMESTAMP] Post-repair safety report saved to $safety_report" >> "$LOG_DIR/safety.log"
    
    echo "$safety_data"
}

# Function to check system stability
check_system_stability() {
    # Check load average
    local load1=$(uptime | awk -F'load average: ' '{print $2}' | awk -F, '{print $1}' | tr -d ' ')
    local load5=$(uptime | awk -F'load average: ' '{print $2}' | awk -F, '{print $2}' | tr -d ' ')
    
    # Check for kernel errors
    local kernel_errors=$(dmesg -T | tail -50 | grep -i "error\|warning" | wc -l)
    
    if [ "$(echo "$load1 > 10" | bc 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "unstable_high_load"
    elif [ "$kernel_errors" -gt 5 ]; then
        echo "unstable_kernel_errors"
    else
        echo "stable"
    fi
}

# Function to check resource availability
check_resource_availability() {
    local disk_space=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
    local memory_free=$(free | awk '/Mem:/ {printf "%.0f", $4/$2 * 100}')
    
    if [ "$disk_space" -gt 95 ]; then
        echo "critical_disk_space"
    elif [ "$disk_space" -gt 90 ]; then
        echo "low_disk_space"
    elif [ "$memory_free" -lt 5 ]; then
        echo "low_memory"
    else
        echo "adequate"
    fi
}

# Function to check protected entities
check_protected_entities() {
    local violations=0
    
    # Check protected processes
    for process in $protected_processes; do
        if ! pgrep -x "$process" >/dev/null; then
            violations=$((violations + 1))
        fi
    done
    
    # Check protected services
    for service in $protected_services; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            : # Service is running
        else
            violations=$((violations + 1))
        fi
    done
    
    if [ $violations -eq 0 ]; then
        echo "all_protected"
    else
        echo "violations_detected:$violations"
    fi
}

# Function to check backup status
check_backup_status() {
    local repair_action=$1
    
    if [ "$backup_config_files" = "true" ] && [ "$repair_action" = "modify_config" ]; then
        # Check if recent backup exists
        local backup_age=$(find "$DATA_DIR/backups" -name "*.backup" -mtime -1 2>/dev/null | wc -l)
        if [ "$backup_age" -gt 0 ]; then
            echo "recent_backup_exists"
        else
            echo "backup_required"
        fi
    else
        echo "not_required"
    fi
}

# Function to check rollback readiness
check_rollback_readiness() {
    local repair_action=$1
    
    if [ "$create_snapshot_before_repair" = "true" ]; then
        # Check if we can create snapshots
        local snapshot_dir="$DATA_DIR/rollbacks"
        if [ -d "$snapshot_dir" ] && [ "$(df "$snapshot_dir" | awk 'NR==2 {print $4}')" -gt 100000 ]; then
            echo "ready"
        else
            echo "insufficient_space"
        fi
    else
        echo "disabled"
    fi
}

# Function to evaluate all checks
evaluate_all_checks() {
    # This would evaluate all the individual checks
    # For now, return a simple evaluation
    echo "pending_manual_review"
}

# Function to identify blocking issues
identify_blocking_issues() {
    local issues=""
    
    # Check for critical issues that would block repair
    if [ "$(check_system_stability)" = "unstable_high_load" ]; then
        issues="${issues}system_unstable;"
    fi
    
    if [ "$(check_resource_availability)" = "critical_disk_space" ]; then
        issues="${issues}critical_disk_space;"
    fi
    
    if [ "$(check_protected_entities)" = "violations_detected" ]; then
        issues="${issues}protected_entities_down;"
    fi
    
    if [ -z "$issues" ]; then
        echo "none"
    else
        echo "$issues"
    fi
}

# Function to identify warnings
identify_warnings() {
    local warnings=""
    
    if [ "$(check_resource_availability)" = "low_disk_space" ]; then
        warnings="${warnings}low_disk_space;"
    fi
    
    if [ "$(check_resource_availability)" = "low_memory" ]; then
        warnings="${warnings}low_memory;"
    fi
    
    if [ -z "$warnings" ]; then
        echo "none"
    else
        echo "$warnings"
    fi
}

# Function to generate recommendations
generate_recommendations() {
    local repair_action=$1
    
    case "$repair_action" in
        "restart_service")
            echo "schedule_downtime;notify_users;verify_dependencies"
            ;;
        "cleanup_temp_files")
            echo "backup_important_files;verify_file_ownership;check_disk_space_after"
            ;;
        "modify_config")
            echo "create_backup;test_config_changes;document_changes"
            ;;
        *)
            echo "proceed_cautiously;monitor_closely;have_rollback_plan"
            ;;
    esac
}

# Function to determine safety verdict
determine_safety_verdict() {
    local blocking_issues=$(identify_blocking_issues)
    
    if [ "$blocking_issues" = "none" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to determine required approvals
determine_required_approvals() {
    local repair_action=$1
    
    case "$repair_action" in
        "modify_config"|"restart_critical_service")
            if [ "$require_approval_for_destructive" = "true" ]; then
                echo "manual_approval_required"
            else
                echo "automatic_approval"
            fi
            ;;
        *)
            echo "automatic_approval"
            ;;
    esac
}

# Function to estimate risk level
estimate_risk_level() {
    local repair_action=$1
    
    case "$repair_action" in
        "cleanup_temp_files")
            echo "low"
            ;;
        "restart_service")
            echo "medium"
            ;;
        "modify_config"|"disk_repair")
            echo "high"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to create contingency plan
create_contingency_plan() {
    local repair_action=$1
    
    case "$repair_action" in
        "restart_service")
            echo "rollback_config;start_backup_service;notify_admin"
            ;;
        "modify_config")
            echo "restore_backup;revert_changes;escalate_to_admin"
            ;;
        "disk_repair")
            echo "stop_io_operations;boot_rescue_mode;contact_support"
            ;;
        *)
            echo "monitor_system;collect_logs;prepare_rollback"
            ;;
    esac
}

# Function to check system functionality after repair
check_system_functionality() {
    local repair_action=$1
    
    # Basic system checks
    local can_ping=$(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "true" || echo "false")
    local can_resolve=$(nslookup google.com >/dev/null 2>&1 && echo "true" || echo "false")
    local can_write=$(touch /tmp/test_write_$(date +%s) >/dev/null 2>&1 && echo "true" || echo "false")
    
    if [ "$can_ping" = "true" ] && [ "$can_resolve" = "true" ] && [ "$can_write" = "true" ]; then
        echo "fully_functional"
    elif [ "$can_ping" = "true" ] && [ "$can_write" = "true" ]; then
        echo "mostly_functional"
    else
        echo "impaired"
    fi
}

# Function to check service health
check_service_health() {
    local repair_action=$1
    
    # Count running vs failed services
    local running_services=$(systemctl list-units --state=running 2>/dev/null | wc -l || echo "0")
    local failed_services=$(systemctl list-units --state=failed 2>/dev/null | wc -l || echo "0")
    
    if [ "$failed_services" -eq 0 ]; then
        echo "all_services_healthy"
    elif [ "$failed_services" -lt 3 ]; then
        echo "minor_service_issues"
    else
        echo "significant_service_issues"
    fi
}

# Main execution
if [ "$#" -eq 2 ]; then
    # If called with repair plan and diagnostic report
    repair_plan="$1"
    diagnostic_report="$2"
    
    # Determine check type based on arguments
    if echo "$repair_plan" | grep -q "repair_result"; then
        # Post-repair check
        post_repair_safety_check "$repair_plan" "$diagnostic_report"
    else
        # Pre-repair check
        pre_repair_safety_check "$repair_plan" "$diagnostic_report"
    fi
else
    # Interactive mode or test mode
    echo "Safety Checks Module"
    echo "Usage: $0 [repair_plan_json] [diagnostic_report_json]"
    echo ""
    echo "Running self-test..."
    
    # Create a test repair plan
    test_plan='{"repair_action": "restart_service", "safety_level": "medium_risk"}'
    test_diagnostic='{"system_analysis": {"cpu": {"load_average": "1.5"}}}'
    
    pre_repair_safety_check "$test_plan" "$test_diagnostic"
fi