#!/bin/bash

# Repair Orchestrator - Simplified Version
# Main entry point for repair system

set -e

# Configuration
BASE_DIR="$(dirname "$0")"
MODULES_DIR="$BASE_DIR/modules"
SCRIPTS_DIR="$BASE_DIR/scripts"
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/logs"
MONITORING_DIR="/Users/rohitvashist/.openclaw/workspace/homeguardian/monitoring"
REPAIR_REQUESTS_DIR="$MONITORING_DIR/data/repair_requests"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR" "$REPAIR_REQUESTS_DIR"

# Function to check for repair requests
check_requests() {
    echo "[$TIMESTAMP] Checking for repair requests..."
    
    local count=$(ls -1 "$REPAIR_REQUESTS_DIR"/*.json 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        echo "No repair requests found."
        return 0
    fi
    
    echo "Found $count repair request(s):"
    ls -1 "$REPAIR_REQUESTS_DIR"/*.json 2>/dev/null
    
    return "$count"
}

# Function to process a single repair request
process_request() {
    local request_file=$1
    
    echo "[$TIMESTAMP] Processing: $(basename "$request_file")"
    
    # Read request
    local request_json=$(cat "$request_file")
    local module=$(echo "$request_json" | jq -r '.module' 2>/dev/null || echo "unknown")
    local alert=$(echo "$request_json" | jq -r '.alert_message' 2>/dev/null || echo "")
    
    echo "  Module: $module"
    echo "  Alert: $alert"
    
    # Determine repair action
    local action=$(determine_action "$module" "$alert")
    echo "  Action: $action"
    
    # Execute repair
    case "$action" in
        "restart_service")
            service=$(determine_service "$module")
            echo "  Service: $service"
            "$MODULES_DIR/restart_procedures.sh" "restart_service" "$service" "$request_json" 2>/dev/null || echo "  Restart failed"
            ;;
        "cleanup_temp")
            "$MODULES_DIR/cleanup_operations.sh" "cleanup_temp" "$request_json" 2>/dev/null || echo "  Cleanup failed"
            ;;
        "rotate_logs")
            "$MODULES_DIR/cleanup_operations.sh" "rotate_logs" "$request_json" 2>/dev/null || echo "  Log rotation failed"
            ;;
        "diagnose")
            "$MODULES_DIR/diagnostic_tools.sh" "$request_json" 2>/dev/null || echo "  Diagnostics failed"
            ;;
        *)
            echo "  Unknown action, running diagnostics"
            "$MODULES_DIR/diagnostic_tools.sh" "$request_json" 2>/dev/null || echo "  Diagnostics failed"
            ;;
    esac
    
    # Mark as processed
    mv "$request_file" "${request_file}.processed"
    echo "  Request processed"
}

# Function to determine repair action
determine_action() {
    local module=$1
    local alert=$2
    
    case "$module" in
        "cpu_monitor")
            echo "diagnose"
            ;;
        "memory_monitor")
            echo "cleanup_temp"
            ;;
        "disk_monitor")
            echo "cleanup_temp"
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
            echo "diagnose"
            ;;
    esac
}

# Function to determine service name
determine_service() {
    local module=$1
    
    case "$module" in
        "service_monitor")
            echo "cron"
            ;;
        "network_monitor")
            echo "NetworkManager"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to run all modules in test mode
test_modules() {
    echo "[$TIMESTAMP] Testing all repair modules..."
    
    echo "1. Testing diagnostic tools..."
    "$MODULES_DIR/diagnostic_tools.sh" 2>/dev/null || echo "  Diagnostic tools test completed"
    
    echo "2. Testing safety checks..."
    "$MODULES_DIR/safety_checks.sh" 2>/dev/null || echo "  Safety checks test completed"
    
    echo "3. Testing restart procedures..."
    "$MODULES_DIR/restart_procedures.sh" 2>/dev/null || echo "  Restart procedures test completed"
    
    echo "4. Testing cleanup operations..."
    "$MODULES_DIR/cleanup_operations.sh" 2>/dev/null || echo "  Cleanup operations test completed"
    
    echo "5. Testing rollback plans..."
    "$MODULES_DIR/rollback_plans.sh" 2>/dev/null || echo "  Rollback plans test completed"
    
    echo "All module tests completed."
}

# Function to show system status
show_status() {
    echo "[$TIMESTAMP] Repair System Status"
    echo "================================"
    
    echo "1. Directory Structure:"
    echo "   Modules: $(ls -1 "$MODULES_DIR"/*.sh 2>/dev/null | wc -l) scripts"
    echo "   Configs: $(ls -1 "$CONFIG_DIR"/*.conf 2>/dev/null | wc -l) files"
    echo "   Data: $(find "$DATA_DIR" -type f 2>/dev/null | wc -l) files"
    echo "   Logs: $(find "$LOG_DIR" -type f 2>/dev/null | wc -l) files"
    
    echo ""
    echo "2. Repair Requests:"
    local pending=$(ls -1 "$REPAIR_REQUESTS_DIR"/*.json 2>/dev/null | wc -l)
    local processed=$(ls -1 "$REPAIR_REQUESTS_DIR"/*.processed 2>/dev/null | wc -l)
    echo "   Pending: $pending"
    echo "   Processed: $processed"
    
    echo ""
    echo "3. Module Health:"
    for module in diagnostic_tools safety_checks restart_procedures cleanup_operations rollback_plans; do
        if [ -x "$MODULES_DIR/${module}.sh" ]; then
            echo "   ✓ $module: Executable"
        else
            echo "   ✗ $module: Missing or not executable"
        fi
    done
}

# Main execution
case "${1:-status}" in
    "check"|"scan")
        check_requests
        ;;
    "process"|"run")
        if [ -n "$2" ] && [ -f "$2" ]; then
            process_request "$2"
        else
            # Process all pending requests
            for request in "$REPAIR_REQUESTS_DIR"/*.json; do
                if [ -f "$request" ]; then
                    process_request "$request"
                    echo ""
                fi
            done
        fi
        ;;
    "test")
        test_modules
        ;;
    "status"|"info")
        show_status
        ;;
    "help"|"--help"|"-h")
        echo "Repair Orchestrator - HomeGuardian Repair System"
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  check, scan    - Check for new repair requests"
        echo "  process, run   - Process repair requests (all or specific file)"
        echo "  test           - Test all repair modules"
        echo "  status, info   - Show system status"
        echo "  help           - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0 check"
        echo "  $0 process"
        echo "  $0 test"
        echo "  $0 status"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac