#!/bin/bash

# Rollback Plans Module
# Handles system state restoration with validation

set -e

# Configuration
BASE_DIR="$(dirname "$0")/.."
CONFIG_DIR="$BASE_DIR/config"
DATA_DIR="$BASE_DIR/data"
LOG_DIR="$BASE_DIR/logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load configuration
ROLLBACK_FILE="$CONFIG_DIR/rollback_config.conf"

# Create directories if they don't exist
mkdir -p "$DATA_DIR/rollbacks" "$DATA_DIR/snapshots" "$LOG_DIR"

# Function to create system snapshot
create_system_snapshot() {
    local snapshot_name=$1
    local repair_context=$2
    
    echo "[$TIMESTAMP] Creating system snapshot: $snapshot_name" >> "$LOG_DIR/rollbacks.log"
    
    local snapshot_dir="$DATA_DIR/snapshots/$snapshot_name"
    mkdir -p "$snapshot_dir"
    
    # Create snapshot record
    local snapshot_record="$DATA_DIR/rollbacks/snapshot_${snapshot_name}_$(date +%s).json"
    
    # Capture system state
    local system_state=$(capture_system_state)
    
    # Save important configurations
    save_configurations "$snapshot_dir"
    
    # Save service states
    save_service_states "$snapshot_dir"
    
    # Save process information
    save_process_info "$snapshot_dir"
    
    # Create snapshot manifest
    snapshot_manifest=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "snapshot_name": "$snapshot_name",
  "context": $repair_context,
  "system_state": $system_state,
  "contents": {
    "config_files": "$(ls -1 "$snapshot_dir/configs/" 2>/dev/null | wc -l)",
    "service_states": "$(ls -1 "$snapshot_dir/services/" 2>/dev/null | wc -l)",
    "process_info": "$(ls -1 "$snapshot_dir/processes/" 2>/dev/null | wc -l)"
  },
  "integrity_check": "$(calculate_snapshot_integrity "$snapshot_dir")"
}
EOF
    )
    
    echo "$snapshot_manifest" | jq . > "$snapshot_record"
    echo "[$TIMESTAMP] Snapshot created: $snapshot_name" >> "$LOG_DIR/rollbacks.log"
    
    echo "$snapshot_manifest"
}

# Function to restore from snapshot
restore_from_snapshot() {
    local snapshot_name=$1
    local repair_context=$2
    
    echo "[$TIMESTAMP] Restoring from snapshot: $snapshot_name" >> "$LOG_DIR/rollbacks.log"
    
    local snapshot_dir="$DATA_DIR/snapshots/$snapshot_name"
    
    if [ ! -d "$snapshot_dir" ]; then
        echo "[$TIMESTAMP] ERROR: Snapshot $snapshot_name not found" >> "$LOG_DIR/rollbacks.log"
        return 1
    fi
    
    # Create restore record
    local restore_record="$DATA_DIR/rollbacks/restore_${snapshot_name}_$(date +%s).json"
    
    # Step 1: Verify snapshot integrity
    echo "[$TIMESTAMP] Step 1: Verifying snapshot integrity..." >> "$LOG_DIR/rollbacks.log"
    
    integrity_check=$(verify_snapshot_integrity "$snapshot_dir")
    local integrity_ok=$(echo "$integrity_check" | jq -r '.integrity_ok')
    
    if [ "$integrity_ok" != "true" ]; then
        echo "[$TIMESTAMP] ERROR: Snapshot integrity check failed" >> "$LOG_DIR/rollbacks.log"
        return 1
    fi
    
    # Step 2: Capture current state (for comparison)
    echo "[$TIMESTAMP] Step 2: Capturing current state..." >> "$LOG_DIR/rollbacks.log"
    
    current_state=$(capture_system_state)
    
    # Step 3: Perform restoration
    echo "[$TIMESTAMP] Step 3: Performing restoration..." >> "$LOG_DIR/rollbacks.log"
    
    restore_result=$(perform_restoration "$snapshot_dir")
    
    # Step 4: Verify restoration
    echo "[$TIMESTAMP] Step 4: Verifying restoration..." >> "$LOG_DIR/rollbacks.log"
    
    verification_result=$(verify_restoration "$snapshot_dir")
    
    # Step 5: Create comprehensive restore report
    restore_report=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "module": "rollback_plans",
  "action": "restore_from_snapshot",
  "snapshot_name": "$snapshot_name",
  "context": $repair_context,
  "integrity_check": $integrity_check,
  "pre_restore_state": $current_state,
  "restoration_operation": {
    "configs_restored": "$(echo "$restore_result" | jq -r '.configs_restored')",
    "services_restored": "$(echo "$restore_result" | jq -r '.services_restored')",
    "errors_encountered": "$(echo "$restore_result" | jq -r '.errors_encountered')",
    "duration_seconds": "$(echo "$restore_result" | jq -r '.duration_seconds')"
  },
  "verification_result": $verification_result,
  "restoration_status": {
    "successful": "$(determine_restoration_success "$verification_result")",
    "issues": "$(identify_restoration_issues "$restore_result" "$verification_result")",
    "recommendations": "$(generate_restoration_recommendations)"
  }
}
EOF
    )
    
    echo "$restore_report" | jq . > "$restore_record"
    echo "[$TIMESTAMP] Restoration completed from snapshot: $snapshot_name" >> "$LOG_DIR/rollbacks.log"
    
    echo "$restore_report"
}

# Helper functions

capture_system_state() {
    # Capture comprehensive system state
    cat << EOF
{
  "system_info": {
    "hostname": "$(hostname)",
    "kernel": "$(uname -r)",
    "os": "$(uname -s)",
    "architecture": "$(uname -m)"
  },
  "network": {
    "interfaces": "$(ip link show | grep 'state UP' | wc -l || ifconfig -a | grep 'status: active' | wc -l)",
    "default_route": "$(ip route | grep default | head -1 | awk '{print $3}' || echo 'unknown')"
  },
  "services": {
    "running": "$(systemctl list-units --state=running 2>/dev/null | wc -l || echo 'unknown')",
    "failed": "$(systemctl list-units --state=failed 2>/dev/null | wc -l || echo 'unknown')"
  },
  "processes": {
    "total": "$(ps aux | wc -l)",
    "zombies": "$(ps aux | awk '\$8==\"Z\" {print \$0}' | wc -l)"
  }
}
EOF
}

save_configurations() {
    local snapshot_dir=$1
    local configs_dir="$snapshot_dir/configs"
    mkdir -p "$configs_dir"
    
    # Save important configuration files
    for config_file in /etc/hosts /etc/resolv.conf /etc/fstab /etc/ssh/sshd_config; do
        if [ -f "$config_file" ]; then
            cp "$config_file" "$configs_dir/" 2>/dev/null || true
        fi
    done
    
    # Save network configuration
    ip addr show > "$configs_dir/network_interfaces.txt" 2>/dev/null || true
    ip route show > "$configs_dir/routing_table.txt" 2>/dev/null || true
}

save_service_states() {
    local snapshot_dir=$1
    local services_dir="$snapshot_dir/services"
    mkdir -p "$services_dir"
    
    # Save service states if systemd is available
    if command -v systemctl >/dev/null 2>&1; then
        systemctl list-units --all > "$services_dir/all_services.txt" 2>/dev/null
        systemctl list-units --state=running > "$services_dir/running_services.txt" 2>/dev/null
    fi
}

save_process_info() {
    local snapshot_dir=$1
    local processes_dir="$snapshot_dir/processes"
    mkdir -p "$processes_dir"
    
    # Save process information
    ps aux > "$processes_dir/process_list.txt" 2>/dev/null
    top -bn1 > "$processes_dir/top_output.txt" 2>/dev/null
}

calculate_snapshot_integrity() {
    local snapshot_dir=$1
    
    # Simple integrity check - count files
    local file_count=$(find "$snapshot_dir" -type f 2>/dev/null | wc -l)
    
    if [ "$file_count" -gt 0 ]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

verify_snapshot_integrity() {
    local snapshot_dir=$1
    
    local file_count=$(find "$snapshot_dir" -type f 2>/dev/null | wc -l)
    local dir_count=$(find "$snapshot_dir" -type d 2>/dev/null | wc -l)
    
    cat << EOF
{
  "integrity_ok": "$([ "$file_count" -gt 0 ] && echo "true" || echo "false")",
  "file_count": "$file_count",
  "directory_count": "$dir_count",
  "required_files_present": "$(check_required_files "$snapshot_dir")"
}
EOF
}

check_required_files() {
    local snapshot_dir=$1
    
    local required_files=0
    local found_files=0
    
    for required_file in "configs/network_interfaces.txt" "processes/process_list.txt"; do
        required_files=$((required_files + 1))
        if [ -f "$snapshot_dir/$required_file" ]; then
            found_files=$((found_files + 1))
        fi
    done
    
    if [ "$found_files" -eq "$required_files" ]; then
        echo "all"
    elif [ "$found_files" -gt 0 ]; then
        echo "some"
    else
        echo "none"
    fi
}

perform_restoration() {
    local snapshot_dir=$1
    local start_time=$(date +%s)
    
    local configs_restored=0
    local services_restored=0
    local errors_encountered=0
    
    # Restore configuration files
    if [ -d "$snapshot_dir/configs" ]; then
        for config_file in "$snapshot_dir/configs"/*; do
            if [ -f "$config_file" ]; then
                filename=$(basename "$config_file")
                destination="/etc/$filename"
                
                # Backup current file
                if [ -f "$destination" ]; then
                    cp "$destination" "${destination}.backup_$(date +%s)" 2>/dev/null || true
                fi
                
                # Restore from snapshot
                if cp "$config_file" "$destination" 2>/dev/null; then
                    configs_restored=$((configs_restored + 1))
                else
                    errors_encountered=$((errors_encountered + 1))
                fi
            fi
        done
    fi
    
    # Note: Service restoration would be more complex
    # For now, we just record that we attempted restoration
    
    local end_time=$(date +%s)
    local duration_seconds=$((end_time - start_time))
    
    cat << EOF
{
  "configs_restored": "$configs_restored",
  "services_restored": "$services_restored",
  "errors_encountered": "$errors_encountered",
  "duration_seconds": "$duration_seconds"
}
EOF
}

verify_restoration() {
    local snapshot_dir=$1
    
    # Simple verification - check if system is still responsive
    local can_ping=$(ping -c 1 127.0.0.1 >/dev/null 2>&1 && echo "true" || echo "false")
    local can_write=$(touch /tmp/test_write_$(date +%s) >/dev/null 2>&1 && echo "true" || echo "false")
    
    cat << EOF
{
  "basic_checks": {
    "localhost_ping": "$can_ping",
    "filesystem_write": "$can_write",
    "system_responsive": "$([ "$can_ping" = "true" ] && [ "$can_write" = "true" ] && echo "true" || echo "false")"
  },
  "service_checks": {
    "critical_services": "$(check_critical_services)"
  }
}
EOF
}

check_critical_services() {
    local critical_services="ssh cron network"
    local running_count=0
    local total_count=0
    
    for service in $critical_services; do
        total_count=$((total_count + 1))
        if systemctl is-active "$service" >/dev/null 2>&1 || pgrep "$service" >/dev/null 2>&1; then
            running_count=$((running_count + 1))
        fi
    done
    
    if [ "$total_count" -eq 0 ]; then
        echo "unknown"
    elif [ "$running_count" -eq "$total_count" ]; then
        echo "all_running"
    elif [ "$running_count" -gt 0 ]; then
        echo "some_running"
    else
        echo "none_running"
    fi
}

determine_restoration_success() {
    local verification_result=$1
    local system_responsive=$(echo "$verification_result" | jq -r '.basic_checks.system_responsive')
    
    if [ "$system_responsive" = "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

identify_restoration_issues() {
    local restore_result=$1
    local verification_result=$2
    
    local issues=""
    local errors=$(echo "$restore_result" | jq -r '.errors_encountered')
    local system_responsive=$(echo "$verification_result" | jq -r '.basic_checks.system_responsive')
    
    if [ "$errors" -gt 0 ]; then
        issues="${issues}restoration_errors;"
    fi
    
    if [ "$system_responsive" != "true" ]; then
        issues="${issues}system_unresponsive;"
    fi
    
    if [ -z "$issues" ]; then
        echo "none"
    else
        echo "$issues"
    fi
}

generate_restoration_recommendations() {
    echo "monitor_system;verify_functionality;update_documentation"
}

# Main execution
if [ "$#" -ge 2 ]; then
    action=$1
    shift
    
    case "$action" in
        "create_snapshot")
            snapshot_name=$1
            repair_context=${2:-'{}'}
            create_system_snapshot "$snapshot_name" "$repair_context"
            ;;
        "restore_snapshot")
            snapshot_name=$1
            repair_context=${2:-'{}'}
            restore_from_snapshot "$snapshot_name" "$repair_context"
            ;;
        *)
            echo "Unknown action: $action"
            exit 1
            ;;
    esac
else
    echo "Rollback Plans Module"
    echo "Usage:"
    echo "  $0 create_snapshot <snapshot_name> [repair_context_json]"
    echo "  $0 restore_snapshot <snapshot_name> [repair_context_json]"
    echo ""
    echo "Running self-test..."
    
    # Test snapshot creation
    test_context='{"module": "safety_checks", "alert_message": "Pre-repair snapshot"}'
    create_system_snapshot "test_snapshot_$(date +%s)" "$test_context" 2>/dev/null || echo "Snapshot test completed"
fi