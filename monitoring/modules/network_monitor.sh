#!/bin/bash

# Network Monitoring Module for HomeGuardian
# Monitors connectivity, bandwidth usage, and latency

set -e

# Configuration
CONFIG_DIR="$(dirname "$0")/../config"
THRESHOLDS_FILE="$CONFIG_DIR/thresholds.conf"
DATA_DIR="$(dirname "$0")/../data/metrics"
LOG_DIR="$(dirname "$0")/../logs"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Load thresholds
source <(grep -A 10 "^\[Network\]" "$THRESHOLDS_FILE" | sed '1d')

# Create directories if they don't exist
mkdir -p "$DATA_DIR" "$LOG_DIR"

# Function to get network interfaces
get_network_interfaces() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        interfaces=$(networksetup -listallnetworkservices | grep -v "An asterisk" | grep -v "disabled")
        echo "$interfaces"
    else
        # Linux
        interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
        echo "$interfaces"
    fi
}

# Function to get interface statistics
get_interface_stats() {
    local interface=$1
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use netstat
        stats=$(netstat -I "$interface" -b 2>/dev/null | grep "$interface" | tail -1)
        rx_bytes=$(echo "$stats" | awk '{print $7}')
        tx_bytes=$(echo "$stats" | awk '{print $10}')
        echo "$rx_bytes|$tx_bytes"
    else
        # Linux - use /sys/class/net
        rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes" 2>/dev/null || echo "0")
        tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes" 2>/dev/null || echo "0")
        echo "$rx_bytes|$tx_bytes"
    fi
}

# Function to calculate bandwidth usage
calculate_bandwidth() {
    local interface=$1
    local prev_rx=$2
    local prev_tx=$3
    local interval=$4
    
    # Get current stats
    current_stats=$(get_interface_stats "$interface")
    current_rx=$(echo "$current_stats" | cut -d'|' -f1)
    current_tx=$(echo "$current_stats" | cut -d'|' -f2)
    
    # Calculate bytes transferred
    if [ "$prev_rx" != "0" ] && [ "$prev_tx" != "0" ]; then
        rx_diff=$((current_rx - prev_rx))
        tx_diff=$((current_tx - prev_tx))
        
        # Convert to bits per second
        rx_bps=$((rx_diff * 8 / interval))
        tx_bps=$((tx_diff * 8 / interval))
        
        # Convert to Mbps
        rx_mbps=$(echo "scale=2; $rx_bps / 1000000" | bc)
        tx_mbps=$(echo "scale=2; $tx_bps / 1000000" | bc)
        
        echo "$rx_mbps|$tx_mbps|$current_rx|$current_tx"
    else
        echo "0|0|$current_rx|$current_tx"
    fi
}

# Function to check connectivity
check_connectivity() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com")
    local successful_pings=0
    local total_latency=0
    local packet_loss=0
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 2 "$host" >/dev/null 2>&1; then
            successful_pings=$((successful_pings + 1))
            
            # Get latency (simplified - just check if ping succeeds)
            latency_output=$(ping -c 1 -W 2 "$host" 2>/dev/null | grep "time=" || echo "")
            if [ -n "$latency_output" ]; then
                latency_ms=$(echo "$latency_output" | grep -o "time=[0-9.]*" | cut -d= -f2)
                total_latency=$(echo "$total_latency + $latency_ms" | bc)
            fi
        else
            packet_loss=$((packet_loss + 1))
        fi
    done
    
    # Calculate averages
    if [ "$successful_pings" -gt 0 ]; then
        avg_latency=$(echo "scale=2; $total_latency / $successful_pings" | bc)
        connectivity_percent=$((successful_pings * 100 / ${#test_hosts[@]}))
        packet_loss_percent=$((packet_loss * 100 / ${#test_hosts[@]}))
    else
        avg_latency=999.99
        connectivity_percent=0
        packet_loss_percent=100
    fi
    
    echo "$connectivity_percent|$avg_latency|$packet_loss_percent"
}

# Function to check DNS resolution
check_dns_resolution() {
    local test_domains=("google.com" "github.com" "openclaw.io")
    local successful_resolutions=0
    
    for domain in "${test_domains[@]}"; do
        if dig +short "$domain" >/dev/null 2>&1; then
            successful_resolutions=$((successful_resolutions + 1))
        fi
    done
    
    dns_success_percent=$((successful_resolutions * 100 / ${#test_domains[@]}))
    echo "$dns_success_percent"
}

# Function to check port connectivity
check_port_connectivity() {
    local test_ports=("80" "443" "22")
    local successful_ports=0
    
    for port in "${test_ports[@]}"; do
        # Test localhost first
        if nc -z -w 2 localhost "$port" >/dev/null 2>&1; then
            successful_ports=$((successful_ports + 1))
        fi
    done
    
    port_success_percent=$((successful_ports * 100 / ${#test_ports[@]}))
    echo "$port_success_percent"
}

# Function to check thresholds and generate alerts
check_thresholds() {
    local bandwidth_usage=$1
    local latency=$2
    local packet_loss=$3
    local connectivity=$4
    
    local alert_level="INFO"
    local alert_message=""
    local alert_details=""
    
    # Check bandwidth usage
    if (( $(echo "$bandwidth_usage > $bandwidth_critical" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="Bandwidth usage critical: ${bandwidth_usage}%"
        alert_details="bandwidth=${bandwidth_usage}%"
    elif (( $(echo "$bandwidth_usage > $bandwidth_warning" | bc -l) )); then
        alert_level="WARNING"
        alert_message="Bandwidth usage warning: ${bandwidth_usage}%"
        alert_details="bandwidth=${bandwidth_usage}%"
    fi
    
    # Check latency
    if (( $(echo "$latency > $latency_critical_ms" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }Latency critical: ${latency}ms"
        alert_details="${alert_details:+$alert_details, }latency=${latency}ms"
    elif (( $(echo "$latency > $latency_warning_ms" | bc -l) )); then
        if [ "$alert_level" != "CRITICAL" ]; then
            alert_level="WARNING"
        fi
        alert_message="${alert_message:+$alert_message, }Latency warning: ${latency}ms"
        alert_details="${alert_details:+$alert_details, }latency=${latency}ms"
    fi
    
    # Check packet loss
    if (( $(echo "$packet_loss > $packet_loss_critical" | bc -l) )); then
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }Packet loss critical: ${packet_loss}%"
        alert_details="${alert_details:+$alert_details, }packet_loss=${packet_loss}%"
    elif (( $(echo "$packet_loss > $packet_loss_warning" | bc -l) )); then
        if [ "$alert_level" != "CRITICAL" ]; then
            alert_level="WARNING"
        fi
        alert_message="${alert_message:+$alert_message, }Packet loss warning: ${packet_loss}%"
        alert_details="${alert_details:+$alert_details, }packet_loss=${packet_loss}%"
    fi
    
    # Check connectivity
    if (( $(echo "$connectivity < 50" | bc -l) )); then  # Less than 50% connectivity
        alert_level="CRITICAL"
        alert_message="${alert_message:+$alert_message, }Connectivity critical: ${connectivity}%"
        alert_details="${alert_details:+$alert_details, }connectivity=${connectivity}%"
    elif (( $(echo "$connectivity < 80" | bc -l) )); then  # Less than 80% connectivity
        if [ "$alert_level" != "CRITICAL" ]; then
            alert_level="WARNING"
        fi
        alert_message="${alert_message:+$alert_message, }Connectivity warning: ${connectivity}%"
        alert_details="${alert_details:+$alert_details, }connectivity=${connectivity}%"
    fi
    
    echo "$alert_level|$alert_message|$alert_details"
}

# Function to get previous stats for bandwidth calculation
get_previous_stats() {
    local interface=$1
    local stats_file="$DATA_DIR/network_${interface}_stats.txt"
    
    if [ -f "$stats_file" ]; then
        cat "$stats_file"
    else
        echo "0|0"
    fi
}

# Function to save current stats for next calculation
save_current_stats() {
    local interface=$1
    local rx_bytes=$2
    local tx_bytes=$3
    local stats_file="$DATA_DIR/network_${interface}_stats.txt"
    
    echo "$rx_bytes|$tx_bytes" > "$stats_file"
}

# Main monitoring function
monitor_network() {
    echo "[$TIMESTAMP] Starting network monitoring..."
    
    # Get network interfaces
    interfaces=$(get_network_interfaces)
    
    # Arrays to store results
    declare -a interface_details
    declare -a bandwidth_alerts
    declare -a connectivity_alerts
    
    # Track overall status
    local overall_alert_level="INFO"
    local overall_alert_message=""
    local overall_alert_details=""
    
    # Monitoring interval for bandwidth calculation (seconds)
    local monitor_interval=5
    
    # Check each interface
    for interface in $interfaces; do
        # Skip empty lines and certain interfaces
        if [ -z "$interface" ] || [[ "$interface" == *"*"* ]] || [[ "$interface" == "Thunderbolt"* ]]; then
            continue
        fi
        
        # Get previous stats for bandwidth calculation
        previous_stats=$(get_previous_stats "$interface")
        prev_rx=$(echo "$previous_stats" | cut -d'|' -f1)
        prev_tx=$(echo "$previous_stats" | cut -d'|' -f2)
        
        # Wait briefly for interval
        sleep "$monitor_interval"
        
        # Calculate bandwidth
        bandwidth_result=$(calculate_bandwidth "$interface" "$prev_rx" "$prev_tx" "$monitor_interval")
        rx_mbps=$(echo "$bandwidth_result" | cut -d'|' -f1)
        tx_mbps=$(echo "$bandwidth_result" | cut -d'|' -f2)
        current_rx=$(echo "$bandwidth_result" | cut -d'|' -f3)
        current_tx=$(echo "$bandwidth_result" | cut -d'|' -f4)
        
        # Save current stats for next calculation
        save_current_stats "$interface" "$current_rx" "$current_tx"
        
        # Check connectivity (only on primary interface)
        if [[ "$interface" == "Wi-Fi" ]] || [[ "$interface" == "en0" ]] || [[ "$interface" == "eth0" ]]; then
            connectivity_result=$(check_connectivity)
            connectivity_percent=$(echo "$connectivity_result" | cut -d'|' -f1)
            avg_latency=$(echo "$connectivity_result" | cut -d'|' -f2)
            packet_loss_percent=$(echo "$connectivity_result" | cut -d'|' -f3)
            
            dns_success=$(check_dns_resolution)
            port_success=$(check_port_connectivity)
            
            # Calculate overall bandwidth usage percentage (simplified)
            # Assuming 1Gbps connection = 1000 Mbps
            max_bandwidth=1000
            total_bandwidth=$(echo "$rx_mbps + $tx_mbps" | bc)
            bandwidth_usage=$(echo "scale=2; ($total_bandwidth / $max_bandwidth) * 100" | bc)
            
            # Check thresholds
            alert_result=$(check_thresholds "$bandwidth_usage" "$avg_latency" "$packet_loss_percent" "$connectivity_percent")
            alert_level=$(echo "$alert_result" | cut -d'|' -f1)
            alert_message=$(echo "$alert_result" | cut -d'|' -f2)
            alert_details=$(echo "$alert_result" | cut -d'|' -f3)
            
            # Track alerts
            if [ "$alert_level" = "CRITICAL" ]; then
                bandwidth_alerts+=("$alert_message")
                if [ "$overall_alert_level" != "CRITICAL" ]; then
                    overall_alert_level="CRITICAL"
                fi
            elif [ "$alert_level" = "WARNING" ]; then
                if [ "$overall_alert_level" = "INFO" ]; then
                    overall_alert_level="WARNING"
                fi
            fi
        else
            # For non-primary interfaces, just collect stats
            alert_level="INFO"
            alert_message=""
            alert_details=""
            connectivity_percent=0
            avg_latency=0
            packet_loss_percent=0
            dns_success=0
            port_success=0
            bandwidth_usage=0
        fi
        
        # Store interface details
        interface_detail=$(cat << EOF
{
  "name": "$interface",
  "bandwidth_rx_mbps": $rx_mbps,
  "bandwidth_tx_mbps": $tx_mbps,
  "bandwidth_usage_percent": $bandwidth_usage,
  "connectivity_percent": $connectivity_percent,
  "latency_ms": $avg_latency,
  "packet_loss_percent": $packet_loss_percent,
  "dns_success_percent": $dns_success,
  "port_success_percent": $port_success,
  "alert_level": "$alert_level",
  "alert_message": "$alert_message"
}
EOF
        )
        
        interface_details+=("$interface_detail")
    done
    
    # Build overall alert message
    if [ ${#bandwidth_alerts[@]} -gt 0 ]; then
        overall_alert_message="Network issues: ${bandwidth_alerts[0]}"
        overall_alert_details="bandwidth_alerts=${#bandwidth_alerts[@]}"
    fi
    
    # If no primary interface was found, check connectivity anyway
    if [ ${#interface_details[@]} -eq 0 ]; then
        connectivity_result=$(check_connectivity)
        connectivity_percent=$(echo "$connectivity_result" | cut -d'|' -f1)
        avg_latency=$(echo "$connectivity_result" | cut -d'|' -f2)
        packet_loss_percent=$(echo "$connectivity_result" | cut -d'|' -f3)
        
        if (( $(echo "$connectivity_percent < 50" | bc -l) )); then
            overall_alert_level="CRITICAL"
            overall_alert_message="No network connectivity detected"
            overall_alert_details="connectivity=${connectivity_percent}%"
        fi
        
        # Add a default interface entry
        interface_detail=$(cat << EOF
{
  "name": "default",
  "bandwidth_rx_mbps": 0,
  "bandwidth_tx_mbps": 0,
  "bandwidth_usage_percent": 0,
  "connectivity_percent": $connectivity_percent,
  "latency_ms": $avg_latency,
  "packet_loss_percent": $packet_loss_percent,
  "dns_success_percent": 0,
  "port_success_percent": 0,
  "alert_level": "$overall_alert_level",
  "alert_message": "$overall_alert_message"
}
EOF
        )
        
        interface_details+=("$interface_detail")
    fi
    
    # Create JSON output
    json_output=$(cat << EOF
{
  "timestamp": "$TIMESTAMP",
  "module": "network_monitor",
  "summary": {
    "interfaces_monitored": ${#interface_details[@]},
    "bandwidth_alerts": ${#bandwidth_alerts[@]}
  },
  "interfaces": [$(IFS=,; echo "${interface_details[*]}")],
  "alert": {
    "level": "$overall_alert_level",
    "message": "$overall_alert_message",
    "details": "$overall_alert_details"
  },
  "thresholds": {
    "bandwidth_warning": $bandwidth_warning,
    "bandwidth_critical": $bandwidth_critical,
    "latency_warning_ms": $latency_warning_ms,
    "latency_critical_ms": $latency_critical_ms,
    "packet_loss_warning": $packet_loss_warning,
    "packet_loss_critical": $packet_loss_critical,
    "connectivity_timeout": $connectivity_timeout
  }
}
EOF
    )
    
    # Save to file
    output_file="$DATA_DIR/network_${TIMESTAMP}.json"
    echo "$json_output" > "$output_file"
    
    # Log overall alert if not INFO
    if [ "$overall_alert_level" != "INFO" ]; then
        echo "[$TIMESTAMP] [$overall_alert_level] $overall_alert_message" >> "$LOG_DIR/alerts.log"
        echo "[$TIMESTAMP] Network Alert: $overall_alert_message" >> "$LOG_DIR/monitoring.log"
        
        # Print alert to stdout for orchestration
        echo "ALERT:NETWORK:$overall_alert_level:$overall_alert_message:$overall_alert_details"
    else
        echo "[$TIMESTAMP] Network monitoring completed - All metrics normal" >> "$LOG_DIR/monitoring.log"
    fi
    
    echo "[$TIMESTAMP] Network monitoring completed. Data saved to $output_file"
    
    # Return JSON for integration
    echo "$json_output"
}

# Execute if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    monitor_network
fi
