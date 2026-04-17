#!/bin/bash

# Service Monitoring Module for HomeGuardian
# Monitors critical service uptime, response times, and health

set -e

# Configuration
CONFIG_DIR="$(dirname "$0")/../config"
SERVICES_FILE="$CONFIG_DIR/services.conf"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
DATA_DIR="$(dirname "$0")/../data/metrics"
LOG_DIR="$(dirname "$0")/../logs"
STATUS_DIR="$(dirname "$0")/../data/service_status"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load thresholds
source <(grep -A 10 "^\[Services\]" "$THRESHOLDS_FILE" | sed '1d')

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR" "$STATUS_DIR"

# Function to check systemd service
check_systemd_service() {
    local service_name=$1
    local expected_status=$2
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses launchctl instead of systemd
        if launchctl list | grep -q "$service_name"; then
            status=$(launchctl list "$service_name" 2>/dev/null | awk '{print $2}')
            if [ "$status" = "0" ]; then
                echo "active"
            else
                echo "inactive"
            fi
        else
            echo "not-found"
        fi
    else
        # Linux systemd
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            echo "active"
        elif systemctl is-failed --quiet "$service_name" 2>/dev/null; then
            echo "failed"
        else
            echo "inactive"
        fi
    fi
}

# Function to check Docker container
check_docker_service() {
    local container_name=$1
    local expected_status=$2
    
    if command -v docker &> /dev/null; then
        container_status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not-found")
        echo "$container_status"
    else
        echo "docker-not-available"
    fi
}

# Function to check HTTP service
check_http_service() {
    local url=$1
    local expected_code=$2
    
    # Use curl with timeout
    if command -v curl &> /dev/null; then
        http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")
        
        if [ "$http_code" = "$expected_code" ]; then
            echo "healthy"
        elif [ "$http_code" = "000" ]; then
            echo "timeout"
        else
            echo "unexpected:$http_code"
        fi
    else
        echo "curl-not-available"
    fi
}

# Function to check TCP port
check_tcp_service() {
    local host_port=$1
    local expected_status=$2
    
    # Extract host and port
    host=$(echo "$host_port" | cut -d: -f1)
    port=$(echo "$host_port" | cut -d: -f2)
    
    if command -v nc &> /dev/null; then
        if nc -z -w 3 "$host" "$port" 2>/dev/null; then
            echo "open"
        else
            echo "closed"
        fi
    else
        # Fallback using bash built-in
        if timeout 3 bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
            echo "open"
        else
            echo "closed"
        fi
    fi
}

# Function to get service uptime
get_service_uptime() {
    local service_name=$1
    local check_type=$2
    
    local uptime_seconds=0
    
    if [[ "$check_type" == "systemd" ]] && [[ "$OSTYPE" != "darwin"* ]]; then
        # Linux systemd uptime
        if systemctl is-active --quiet "$service_name" 2>/dev/null; then
            # Get active timestamp and calculate uptime
            active_since=$(systemctl show "$service_name" --property=ActiveEnterTimestamp 2>/dev/null | cut -d= -f2)
            if [ -n "$active_since" ]; then
                active_epoch=$(date -d "$active_since" +%s 2>/dev/null || echo "0")
                current_epoch=$(date +%s)
                uptime_seconds=$((current_epoch - active_epoch))
            fi
        fi
    elif [[ "$check_type" == "docker" ]]; then
        # Docker container uptime
        if command -v docker &> /dev/null; then
            started_at=$(docker inspect --format='{{.State.StartedAt}}' "$service_name" 2>/dev/null || echo "")
            if [ -n "$started_at" ]; then
                started_epoch=$(date -d "$started_at" +%s 2>/dev/null || echo "0")
                current_epoch=$(date +%s)
                uptime_seconds=$((current_epoch - started_epoch))
            fi
        fi
    fi
    
    echo "$uptime_seconds"
}

# Function to track service restarts
track_service_restarts() {
    local service_name=$1
    local current_status=$2
    local status_file="$STATUS_DIR/${service_name}.status"
    
    local restart_count=0
    local last_status=""
    
    # Read previous status
    if [ -f "$status_file" ]; then
        last_status=$(cat "$status_file")
    fi
    
    # Save current status
    echo "$current_status" > "$status_file"
    
    # Check if service was restarted (went from inactive to active)
    if [ "$last_status" = "inactive" ] && [ "$current_status" = "active" ]; then
        restart_count=1
    elif [ "$last_status" = "not-found" ] && [ "$current_status" = "active" ]; then
        restart_count=1
    elif [ "$last_status" = "failed" ] && [ "$current_status" = "active" ]; then
        restart_count=1
    fi
    
    echo "$restart_count"
}

# Function to check response time
check_response_time() {
    local check_command=$1
    local check_type=$2
    
    local start_time
    local end_time
    local response_time_ms=0
    
    start_time=$(date +%s%3N)
    
    case "$check_type" in
        "http")
            url=$(echo "$check_command" | sed 's/^http://')
            curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$url" >/dev/null 2>&1
            ;;
        "tcp")
            host_port=$(echo "$check_command" | sed 's/^tcp://')
            host=$(echo "$host_port" | cut -d: -f1)
            port=$(echo "$host_port" | cut -d: -f2)
            timeout 3 bash -c "echo > /dev/tcp/$host/$port" >/dev/null 2>&1
            ;;
        *)
            # For systemd/docker, just check status
            true
            ;;
    esac
    
    end_time=$(date +%s%3N)
    response_time_ms=$((end_time - start_time))
    
    echo "$response_time_ms"
}

# Function to parse services configuration
parse_services_config() {
    local services_file=$1
    local section=""
    
    declare -A services
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check for section headers
        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Parse service line
        if [[ "$line" =~ ^([^,]+),([^,]+),([^,]+),([^,]+)$ ]]; then
            service_name="${BASH_REMATCH[1]}"
            check_type="${BASH_REMATCH[2]}"
            check_command="${BASH_REMATCH[3]}"
            expected_status="${BASH_REMATCH[4]}"
            
            services["${section}:${service_name}"]="$check_type|$check_command|$expected_status"
        fi
    done < "$services_file"
    
    # Return services as associative array (by printing and using declare -A in caller)
    for key in "${!services[@]}"; do
        echo "$key=${services[$key]}"
    done
}

# Main monitoring function
monitor_services() {
    echo "[$TIMESTAMP] Starting service monitoring..."
    
    # Parse services configuration
    declare -A services_config
    while IFS='=' read -r key value; do
        services_config["$key"]="$value"
    done < <(parse_services_config "$SERVICES_FILE")
    
    # Arrays to store results
    declare -a healthy_services
    declare -a warning_services
    declare -a critical_services
    declare -a service_details
    
    # Track total restarts in last hour
    local total_restarts_last_hour=0
    
    # Check each service
    for service_key in "${!services_config[@]}"; do
        IFS='|' read -r check_type check_command expected_status <<< "${services_config[$service_key]}"
        section=$(echo "$service_key" | cut -d: -f1)
        service_name=$(echo "$service_key" | cut -d: -f2)
        
        # Determine current status based on check type
        current_status="unknown"
        response_time_ms=0
        
        case "$check_type" in
            "systemd")
                current_status=$(check_systemd_service "$check_command" "$expected_status")
                ;;
            "docker")
                current_status=$(check_docker_service "$check_command" "$expected_status")
                ;;
            "http")
                current_status=$(check_http_service "$check_command" "$expected_status")
                response_time_ms=$(check_response_time "$check_command" "http")
                ;;
            "tcp")
                current_status=$(check_tcp_service "$check_command" "$expected_status")
                response_time_ms=$(check_response_time "$check_command" "tcp")
                ;;
            *)
                current_status="unknown-check-type"
                ;;
        esac
        
        # Get uptime
        uptime_seconds=$(get_service_uptime "$check_command" "$check_type")
        uptime_hours=$((uptime_seconds / 3600))
        
        # Track restarts
        restart_count=$(track_service_restarts "$service_name" "$current_status")
        total_restarts_last_hour=$((total_restarts_last_hour + restart_count))
        
        # Determine service health
        service_health="healthy"
        alert_level="INFO"
        alert_message=""
        
        # Check if service matches expected status
        if [ "$current_status" != "$expected_status" ]; then
            service_health="critical"
            alert_level="CRITICAL"
            alert_message="Service $service_name is $current_status (expected: $expected_status)"
        elif [ "$uptime_hours" -lt "$uptime_critical_hours" ]; then
            service_health="warning"
            alert_level="WARNING"
            alert_message="Service $service_name uptime only ${uptime_hours}h (frequent restarts)"
        elif [ "$response_time_ms" -gt "$response_critical_ms" ]; then
            service_health="warning"
            alert_level="WARNING"
            alert_message="Service $service_name response time ${response_time_ms}ms (slow)"
        elif [ "$response_time_ms" -gt "$response_warning_ms" ]; then
            service_health="warning"
            alert_level="WARNING"
            alert_message="Service $service_name response time ${response_time_ms}ms (degraded)"
        fi
        
        # Store service details
        service_detail=$(cat << EOF
{
  "name": "$service_name",
  "section": "$section",
  "check_type": "$check_type",
  "current_status": "$current_status",
  "expected_status": "$expected_status",
  "uptime_hours": $uptime_hours,
  "response_time_ms": $response_time_ms,
  "restart_count": $restart_count,
  "health": "$service_health",
  "alert_level": "$alert_level",
  "alert_message": "$alert_message"
}
EOF
        )
        
        service_details+=("$service_detail")
        
        # Categorize service
        case "$service_health" in
            "healthy")
                healthy_services+=("$service_name")
                ;;
            "warning")
                warning_services+=("$service_name")
                ;;
            "critical")
                critical_services+=("$service_name")
                ;;
        esac
        
        # Log alert if not healthy
        if [ "$service_health" != "healthy" ]; then
            echo "[$TIMESTAMP] [$alert_level] $alert_message" >> "$LOG_DIR/alerts.log"
        fi
    done
    
    # Check overall restart rate
    overall_alert_level="INFO"
    overall_alert_message=""
    overall_alert_details=""
    
    if [ "$total_restarts_last_hour" -gt "$restart_critical_hour" ]; then
        overall_alert_level="CRITICAL"
        overall_alert_message="Critical: $total_restarts_last_hour service restarts in last hour"
        overall_alert_details="restarts=$total_restarts_last_hour"
    elif [ "$total_restarts_last_hour" -gt "$restart_warning_hour" ]; then
        overall_alert_level="WARNING"
        overall_alert_message="Warning: $total_restarts_last_hour service restarts in last hour"
        overall_alert_details="restarts=$total_restarts_last_hour"
    fi
    
    # Create JSON output
    json_output=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "module": "service_monitor",
  "summary": {
    "total_services": ${#services_config[@]},
    "healthy": ${#healthy_services[@]},
    "warning": ${#warning_services[@]},
    "critical": ${#critical_services[@]},
    "restarts_last_hour": $total_restarts_last_hour
  },
  "services": [$(IFS=,; echo "${service_details[*]}")],
  "alert": {
    "level": "$overall_alert_level",
    "message": "$overall_alert_message",
    "details": "$overall_alert_details"
  },
  "thresholds": {
    "restart_warning_hour": $restart_warning_hour,
    "restart_critical_hour": $restart_critical_hour,
    "response_warning_ms": $response_warning_ms,
    "response_critical_ms": $response_critical_ms,
    "uptime_warning_hours": $uptime_warning_hours,
    "uptime_critical_hours": $uptime_critical_hours
  }
}
EOF
)
    
    # Save to file
    output_file="$DATA_DIR/services_${TIMESTAMP}.json"
    echo "$json_output" > "$output_file"
    
    # Log overall alert if not INFO
    if [ "$overall_alert_level" != "INFO" ]; then
        echo "[$TIMESTAMP] Service Alert: $overall_alert_message" >> "$LOG_DIR/monitoring.log"
        echo "ALERT:SERVICES:$overall_alert_level:$overall_alert_message:$overall_alert_details"
    else
        echo "[$TIMESTAMP] Service monitoring completed - ${#healthy_services[@]}/${#services_config[@]} services healthy" >> "$LOG_DIR/monitoring.log"
    fi
    
    echo "[$TIMESTAMP] Service monitoring completed. Data saved to $output_file"
    
    # Return JSON for integration
    echo "$json_output"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_services
fi