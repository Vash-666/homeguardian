#!/bin/bash

# Repair Orchestrator - Main Script
# Processes repair requests from monitoring system and executes safe repair actions

set -e

# Configuration
BASE_DIR="$(dirname "$0")/.."
MODULES_DIR="$BASE_DIR/modules"
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/logs"
MONITORING_DIR="/Users/rohitvashist/.openclaw/workspace/homeguardian/monitoring"
REPAIR_REQUESTS_DIR="$MONITORING_DIR/data/repair_requests"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load configuration
RULES_FILE="$CONFIG_DIR/repair_rules.conf"
if [ -f "$RULES_FILE" ]; then
    source <(grep -A 10 "^\[General\]" "$RULES_FILE" | sed '1d')
fi

# Create directories if they don't exist
mkdir -p "$DATA_DIR/repairs" "$DATA_DIR/status" "$LOG_DIR" "$REPAIR_REQUESTS_DIR"

# Function to check for new repair requests
check_for_repair_requests() {
    echo "[$TIMESTAMP] Checking for new repair requests..." >> "$LOG_DIR/orchestrator.log"
    
    local request_count=0
    local new_requests=""
    
    # Find all repair request files
    for request_file in "$REPAIR_REQUESTS_DIR"/*.json; do
        if [ -f "$request_file" ]; then
            request_count=$((request_count + 1))
            new_requests="${new_requests}$request_file;"
        fi
    done
    
    if [ "$request_count" -eq 0 ]; then
        echo "[$TIMESTAMP] No new repair requests found" >> "$LOG_DIR/orchestrator.log"
        echo ""
        return 0
    fi
    
    echo "[$TIMESTAMP] Found $request_count repair request(s)" >> "$LOG_DIR/orchestrator.log"
    echo "$new_requests"
}

# Function to process a repair request
process_repair_request() {
    local request_file=$1
    
    echo "[$TIMESTAMP] Processing repair request: $request_file" >> "$LOG_DIR/orchestrator.log"
    
    # Read the repair request
    local repair_request=$(cat "$request_file")
    local request_id=$(echo "$repair_request" | jq -r '.request_id' 2>/dev/null || echo "unknown")
    local module=$(echo "$repair_request" | jq -r '.module' 2>/dev/null || echo "unknown")
    local alert_message=$(echo "$repair_request" | jq -r '.alert_message' 2>/dev/null || echo "")
    
    # Create repair record
    local repair_record="$DATA_DIR/repairs/repair_${request_id}_$(date +%s).json"
    
    # Step 1: Run diagnostics
    echo "[$TIMESTAMP] Step 1: Running diagnostics..." >> "$LOG_DIR/orchestrator.log"
    
    diagnostic_result=$(run_diagnostics "$repair_request")
    
    # Step 2: Create repair plan
    echo "[$TIMESTAMP] Step 2: Creating repair plan..." >> "$LOG_DIR/orchestrator.log"
    
    repair_plan=$(create_repair_plan "$repair_request" "$diagnostic_result")
    
    # Step 3: Perform safety checks
    echo "[$TIMESTAMP] Step 3: Performing safety checks..." >> "$LOG_DIR/orchestrator.log"
    
    safety_check_result=$(run_safety_checks "$repair_plan" "$diagnostic_result")
    local safety_ok=$(echo "$safety_check_result" | jq -r '.safety_verdict.proceed_with_repair' 2>/dev/null || echo "false")
    
    if [ "$safety_ok" != "true" ]; then
        echo "[$TIMESTAMP] ERROR: Safety checks failed, aborting repair" >> "$LOG_DIR/orchestrator.log"
        
        # Create failure report
        failure_report=$(create_failure_report "$repair_request" "$diagnostic_result" "$safety_check_result")
        echo "$failure_report" | jq . > "$repair_record"
        
        # Move request to processed
        mv "$request_file" "${request_file}.failed"
        
        echo "$failure_report"
        return 1
    fi
    
    # Step 4: Create system snapshot (if required)
    echo "[$TIMESTAMP] Step 4: Creating system snapshot..." >> "$LOG_DIR/orchestrator.log"
    
    local snapshot_name="snapshot_${request_id}_$(date +%s)"
    snapshot_result=$(create_system_snapshot "$snapshot_name" "$repair_request")
    
    # Step 5: Execute repair
    echo "[$TIMESTAMP] Step 5: Executing repair..." >> "$LOG_DIR/orchestrator.log"
    
    repair_result=$(execute_repair "$repair_plan")
    
    # Step 6: Verify repair
    echo "[$TIMESTAMP] Step 6: Verifying repair..." >> "$LOG_DIR/orchestrator.log"
    
    verification_result=$(verify_repair "$repair_result" "$diagnostic_result")
    
    # Step 7: Perform post-repair safety checks
    echo "[$TIMESTAMP] Step 7: Performing post-repair safety checks..." >> "$LOG_DIR/orchestrator.log"
    
    post_repair_safety=$(run_post_repair_safety_checks "$repair_result" "$diagnostic_result")
    
    # Step 8: Cleanup
    echo "[$TIMESTAMP] Step 8: Cleaning up..." >> "$LOG_DIR/orchestrator.log"
    
    cleanup_result=$(perform_cleanup "$repair_result")
    
    # Step 9: Create comprehensive repair report
    echo "[$TIMESTAMP] Step 9: Creating repair report..." >> "$LOG_DIR/orchestrator.log"
    
    repair_report=$(create_repair_report "$repair_request" "$repair_plan" "$repair_result" "$verification_result")
    
    # Save the report
    echo "$repair_report" | jq . > "$repair_record"
    
    # Step 10: Update repair status
    echo "[$TIMESTAMP] Step 10: Updating repair status..." >> "$LOG_DIR/orchestrator.log"
    
    update_repair_status "$request_id" "$repair_report"
    
    # Move request to processed
    mv "$request_file" "${request_file}.processed"
    
    echo "[$TIMESTAMP] Repair completed for request: $request_id" >> "$LOG_DIR/orchestrator.log"
    
    echo "$repair_report"
}

# Function to run diagnostics
run_diagnostics() {
    local repair_request=$1
    
    # Run diagnostic tools module
    "$MODULES_DIR/diagnostic_tools.sh" "$repair_request" 2>/dev/null || echo '{"error": "diagnostics_failed"}'
}

# Function to create repair plan
create_repair_plan() {
    local repair_request=$1
    local diagnostic_result=$2
    
    local module=$(echo "$repair_request" | jq -r '.module')
    local alert_message=$(echo "$repair_request" | jq -r '.alert_message')
    
    # Determine repair action based on module and alert
    local repair_action=$(determine_repair_action "$module" "$alert_message")
    
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "request_id": "$(echo "$repair_request" | jq -r '.request_id')",
  "module": "$module",
  "alert_message": "$alert_message",
  "repair_action": "$repair_action",
  "diagnostic_summary": $(echo "$diagnostic_result" | jq '.repair_recommendations'),
  "estimated_downtime": "$(estimate_downtime_for_action "$repair_action")",
  "risk_level": "$(estimate_risk_level "$repair_action")"
}
EOF
}

# Function to run safety checks
run_safety_checks() {
    local repair_plan=$1
    local diagnostic_result=$2
    
    # Run safety checks module
    "$MODULES_DIR/safety_checks.sh" "$repair_plan" "$diagnostic_result" 2>/dev/null || echo '{"error": "safety_checks_failed"}'
}

# Function to create system snapshot
create_system_snapshot() {
    local snapshot_name=$1
    local repair_request=$2
    
    # Run rollback plans module
    "$MODULES_DIR/rollback_plans.sh" "create_snapshot" "$snapshot_name" "$repair_request" 2>/dev/null || echo '{"error": "snapshot_failed"}'
}

# Function to execute repair
execute_repair() {
    local repair_plan=$1
    
    local repair_action=$(echo "$repair_plan" | jq -r '.repair_action')
    local module=$(echo "$repair_plan" | jq -r '.module')
    
    # Execute appropriate repair action
    case "$repair_action" in
        "restart_service")
            # Determine which service to restart
            local service_name=$(determine_service_name "$module")
            "$MODULES_DIR/restart_procedures.sh" "restart_service" "$service_name" "$repair_plan" 2>/dev/null || echo '{"error": "restart_failed"}'
            ;;
        "restart_top_processes")
            "$MODULES_DIR/restart_procedures.sh" "restart_processes" "3" "$repair_plan" 2>/dev/null || echo '{"error": "process_restart_failed"}'
            ;;
        "cleanup_temp_files")
            "$MODULES_DIR/cleanup_operations.sh" "cleanup_temp" "$repair_plan" 2>/dev/null || echo '{"error": "cleanup_failed"}'
            ;;
        "rotate_logs")
            "$MODULES_DIR/cleanup_operations.sh" "rotate_logs" "$repair_plan" 2>/dev/null || echo '{"error": "log_rotation_failed"}'
            ;;
        *)
            echo '{"error": "unknown_repair_action", "action": "'"$repair_action"'"}'
            ;;
    esac
}

# Function to verify repair
verify_repair() {
    local repair_result=$1
    local diagnostic_result=$2
    
    # Run post-repair diagnostics
    "$MODULES_DIR/diagnostic_tools.sh" "$repair_result" 2>/dev/null || echo '{"error": "verification_failed"}'
}

# Function to run post-repair safety checks
run_post_repair_safety_checks() {
    local repair_result=$1
    local diagnostic_result=$2
    
    # Run safety checks module in post-repair mode
    "$MODULES_DIR/safety_checks.sh" "$repair_result" "$diagnostic_result" 2>/dev/null || echo '{"error": "post_repair_safety_failed"}'
}

# Function to perform cleanup
perform_cleanup() {
    local repair_result=$1
    
    # Simple cleanup - remove temporary files created during repair
    find /tmp -name "repair_*" -mtime -1 -delete 2>/dev/null || true
    
    cat << EOF
{
  "cleanup_performed": "true",
  "temporary_files_removed": "$(find /tmp -name "repair_*" -mtime -1 2>/dev/null | wc -l)"
}
EOF
}

# Function to create repair report
create_repair_report() {
    local repair_request=$1
    local repair_plan=$2
    local repair_result=$3
    local verification_result=$4
    
    local success=$(determine_repair_success "$repair_result" "$verification_result")
    
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "request_id": "$(echo "$repair_request" | jq -r '.request_id')",
  "module": "$(echo "$repair_request" | jq -r '.module')",
  "alert_message": "$(echo "$repair_request" | jq -r '.alert_message')",
  "repair_plan": $repair_plan,
  "repair_result": $repair_result,
  "verification_result": $verification_result,
  "overall_result": {
    "success": "$success",
    "completion_time": "$(date +%s)",
    "issues_encountered": "$(identify_repair_issues "$repair_result")",
    "recommendations": "$(generate_final_recommendations "$success")"
  }
}
EOF
}

# Function to update repair status
update_repair_status() {
    local request_id=$1
    local repair_report=$2
    
    local status_file="$DATA_DIR/status/${request_id}.json"
    echo "$repair_report" | jq '.overall_result' > "$status_file"
    
    # Also update monitoring system status
    local monitoring_status_file="$MONITORING_DIR/data/repair_status/${request_id}.json"
    mkdir -p "$(dirname "$monitoring_status_file")"
    echo "$repair_report" | jq '{timestamp: .timestamp, request_id: .request_id, success: .overall_result.success}' > "$monitoring_status_file"
}

# Function to create failure report
create_failure_report() {
    local repair_request=$1
    local diagnostic_result=$2
    local safety_check_result=$3
    
    cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "request_id": "$(echo "$repair_request" | jq -r '.request_id')",
  "module": "$(echo "$repair_request" | jq -r '.module')",
  "alert_message": "$(echo "$repair_request" | jq -r '.alert_message')",
  "status": "failed",
  "failure_reason": "safety_checks_failed",
  "diagnostic_result": $diagnostic_result,
  "safety_check_result": $safety_check_result,
  "recommendations": "manual_intervention_required"
}
EOF
}

# Helper functions

determine_repair_action() {
    local module=$1
    local alert_message=$2
    
    case "$module" in
        "cpu_monitor")
            if echo "$alert_message" | grep -qi "load"; then
                echo "restart_top_processes"
            else
                echo "investigate_further"
            fi
            ;;
        "memory_monitor")
            echo "cleanup_temp_files"
            ;;
        "disk_monitor")
            if echo "$alert_message" | grep -qi "full\|usage"; then
                echo "cleanup_temp_files"
            else
                echo "rotate_logs"
            fi
            ;;
        "service_monitor")
            echo "restart_service"
            ;;
        "log_monitor")
            echo "rotate_logs"
            ;;
        "network_monitor")
            echo "restart_service"
            ;;
        *)
            echo "investigate_further"
            ;;
    esac
}

determine_service_name() {
    local module=$1
    
    case "$module" in
        "service_monitor")
            echo "cron"  # Default service
            ;;
        "network_monitor")
            echo "NetworkManager"  # Default network service
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

estimate_downtime_for_action() {
    local repair_action=$1
    
    case "$repair_action" in
        "restart_service")
            echo "10"
            ;;
        "restart_top_processes")
            echo "5"
            ;;
        "cleanup_temp_files")
            echo "2"
            ;;
        "rotate_logs")
            echo "3"
            ;;
        *)
            echo "15"
            ;;
    esac
}

estimate_risk_level() {
    local repair_action=$1
    
    case "$repair_action" in
        "cleanup_temp_files"|"rotate_logs")
            echo "low"
            ;;
        "restart_top_processes")
            echo "medium"
            ;;
        "restart_service")
            echo "high"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

determine_repair_success() {
    local repair_result=$1
    local verification_result=$2
    
    local repair_error=$(echo "$repair_result" | jq -r '.error' 2>/dev/null)
    local verification_error=$(echo "$verification_result" | jq -r '.error' 2>/dev/null)
    
    if [ -n "$repair_error" ] && [ "$repair_error" != "null" ]; then
        echo "false"
    elif [ -n "$verification_error" ] && [ "$verification_error" != "null" ]; then
        echo "false"
    else
        echo "true"
    fi
}

identify_repair_issues() {
    local repair_result=$1
    
    local error=$(echo "$repair_result" | jq -r '.error' 2>/dev/null)
    
    if [ -n "$error" ] && [ "$error" != "null" ]; then
        echo "repair_error:$error"
    else
        echo "none"
    fi
}

generate_final_recommendations() {
    local success=$1
    
    if [ "$success" = "true" ]; then
        echo "monitor_system;verify_functionality;update_documentation"
    else
        echo "manual_intervention;review_logs;escalate_to_admin"
    fi
}

# Main execution modes

# Mode 1: Process all pending repair requests
process_all_requests() {
    echo "Repair Orchestrator - Processing all pending requests"
    echo "====================================================="
    
    local requests=$(check_for_repair_requests)
    
    if [ -z "$requests" ]; then
        echo "No repair requests to process."
        return 0
    fi
    
    local processed_count=0
    local failed_count=0
    
    # Process each request
    while IFS=';' read -r request_file; do
        if [ -n "$request_file" ] && [ -f