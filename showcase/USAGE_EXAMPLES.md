# HomeGuardian Usage Examples

## Quick Start Examples

### 1. Basic System Health Check

```bash
# Run a one-time comprehensive health check
./monitoring/scripts/health_check.sh single

# Output:
# ========================================
# HomeGuardian Health Check - 2026-04-17 16:45:23
# ========================================
# 
# CPU:        ✓ Normal (Load: 1.85/8.00)
# Memory:     ✓ Normal (Usage: 65%/85%)
# Disk:       ⚠ Warning (Usage: 88%/90%)
# Services:   ✓ All 5 services running
# Logs:       ✓ Normal (Error count: 2)
# Network:    ✓ Connected (Latency: 24ms)
# 
# Overall Status: HEALTHY (1 warning)
# ========================================
```

### 2. Continuous Monitoring Mode

```bash
# Start continuous monitoring (runs every 60 seconds)
./monitoring/scripts/health_check.sh continuous

# Run in background
nohup ./monitoring/scripts/health_check.sh continuous > monitoring.log 2>&1 &

# Check status
tail -f monitoring/logs/system.log
```

### 3. Check for Repair Requests

```bash
# Scan for repair requests from monitoring system
./repair/scripts/repair_orchestrator.sh check

# Output:
# ========================================
# Repair System Status - 2026-04-17 16:46:05
# ========================================
# 
# Repair requests directory: monitoring/data/repair_requests/
# Total requests: 1
# 
# Pending repairs:
# 1. cpu_high_2026-04-17_16:45:23 (CRITICAL)
#    - Type: CPU overload
#    - Metric: load_average = 9.85
#    - Threshold: 8.00
#    - Age: 42 seconds
# 
# ========================================
```

### 4. Process Repair Requests

```bash
# Execute repair actions for pending requests
./repair/scripts/repair_orchestrator.sh process

# Output:
# ========================================
# Repair Execution - 2026-04-17 16:46:30
# ========================================
# 
# Processing: cpu_high_2026-04-17_16:45:23
# 
# [1/5] Running diagnostics...
#   ✓ System snapshot created: snapshot_2026-04-17_16:46:30.json
#   ✓ Identified high-CPU process: chrome (PID: 12345, CPU: 87%)
# 
# [2/5] Safety checks...
#   ✓ Rollback plan created: rollback_2026-04-17_16:46:32.json
#   ✓ Service dependencies verified
# 
# [3/5] Executing repair: restart_procedures...
#   ✓ Gracefully stopping chrome (PID: 12345)
#   ✓ Process terminated successfully
#   ✓ Waiting 5 seconds for cleanup
#   ✓ Restarting chrome
#   ✓ New PID: 12346
# 
# [4/5] Post-repair validation...
#   ✓ Chrome responding (HTTP 200)
#   ✓ CPU load reduced to 2.15
#   ✓ Memory usage stable
# 
# [5/5] Cleanup...
#   ✓ Temporary files removed
#   ✓ Repair logged: repair_2026-04-17_16:46:45.json
#   ✓ Status updated for monitoring
# 
# Repair COMPLETE: SUCCESS
# ========================================
```

## Common Scenarios

### Scenario 1: High CPU Usage

**Detection:**
```bash
# Monitor detects high CPU
cat monitoring/data/alerts/cpu_high_2026-04-17_16:45:23.json
```

**Repair Request Generated:**
```json
{
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "alert_type": "CPU",
  "severity": "CRITICAL",
  "metric": "load_average",
  "value": 9.85,
  "threshold": 8.0,
  "repair_action": "restart_procedures",
  "target_process": "chrome"
}
```

**Manual Repair (if needed):**
```bash
# Check which process is using CPU
./monitoring/modules/cpu_monitor.sh --detailed

# Manual restart if auto-repair fails
./repair/modules/restart_procedures.sh --process chrome --graceful
```

### Scenario 2: Disk Space Warning

**Detection:**
```bash
# Check disk status
./monitoring/modules/disk_monitor.sh

# Output:
# Disk: /dev/sda1
# Usage: 88% (Warning threshold: 85%)
# Available: 12GB
# Top directories:
#   /var/log: 8GB
#   /tmp: 3GB
#   /home/user/cache: 2GB
```

**Auto-Repair Actions:**
1. Log rotation (if log files are large)
2. Temporary file cleanup
3. Cache clearance

**Manual Cleanup:**
```bash
# Run disk cleanup manually
./repair/modules/cleanup_operations.sh --target logs --rotate
./repair/modules/cleanup_operations.sh --target tmp --clean
```

### Scenario 3: Service Down

**Detection:**
```bash
# Check service status
./monitoring/modules/service_monitor.sh

# Output:
# Services:
#   ✓ nginx: RUNNING (port 80)
#   ✗ mysql: DOWN (port 3306)
#   ✓ redis: RUNNING (port 6379)
```

**Auto-Repair:**
```bash
# Repair system will attempt restart
./repair/modules/restart_procedures.sh --service mysql

# If restart fails, check logs
tail -n 50 /var/log/mysql/error.log
```

## Configuration Examples

### 1. Custom Alert Thresholds

Edit `monitoring/config/thresholds.conf`:
```ini
# CPU thresholds
cpu.load_average.warning = 6.0
cpu.load_average.critical = 8.0
cpu.load_average.emergency = 10.0

# Memory thresholds
memory.usage.warning = 75%
memory.usage.critical = 85%
memory.usage.emergency = 95%

# Disk thresholds
disk.usage.warning = 80%
disk.usage.critical = 90%
disk.usage.emergency = 95%

# Service response time
service.response_time.warning = 1000ms
service.response_time.critical = 5000ms
```

### 2. Service Monitoring Configuration

Edit `monitoring/config/services.conf`:
```ini
# Critical services to monitor
[services]
nginx = http://localhost:80
mysql = tcp://localhost:3306
redis = tcp://localhost:6379
postgres = tcp://localhost:5432
docker = unix:///var/run/docker.sock

# Check intervals (seconds)
check_interval = 60
timeout = 10

# Alert settings
max_failures = 3
cooldown_period = 300
```

### 3. Repair Rules Configuration

Edit `repair/config/repair_rules.conf`:
```ini
# CPU-related repairs
[cpu]
high_load = restart_procedures --priority high
high_load.process_threshold = 80%
high_load.action = restart
high_load.timeout = 30

# Memory-related repairs
[memory]
high_usage = cleanup_operations --target cache
high_usage.threshold = 85%
high_usage.action = clear_cache
high_usage.reserved_mb = 1024

# Disk-related repairs
[disk]
low_space = cleanup_operations --target logs,tmp
low_space.threshold = 85%
low_space.action = rotate_logs,clean_tmp
low_space.min_free_gb = 10

# Service-related repairs
[service]
down = restart_procedures --service
down.max_attempts = 3
down.wait_between = 10
down.escalate_after = 2
```

## Advanced Usage

### 1. Custom Monitoring Module

Create `monitoring/modules/custom_monitor.sh`:
```bash
#!/bin/bash

# Custom monitoring module template
source monitoring/config/thresholds.conf

check_custom_metric() {
    local metric_value=$(get_custom_metric)
    local threshold=$CUSTOM_THRESHOLD
    
    if (( $(echo "$metric_value > $threshold" | bc -l) )); then
        generate_alert "CUSTOM" "CRITICAL" "custom_metric" "$metric_value" "$threshold"
    fi
}

get_custom_metric() {
    # Your custom metric collection logic here
    echo "42.5"
}

# Main execution
case "$1" in
    "check")
        check_custom_metric
        ;;
    "test")
        echo "Testing custom monitor..."
        check_custom_metric
        ;;
    *)
        echo "Usage: $0 {check|test}"
        exit 1
        ;;
esac
```

### 2. Custom Repair Module

Create `repair/modules/custom_repair.sh`:
```bash
#!/bin/bash

# Custom repair module template
source repair/config/safety_limits.conf

custom_repair_action() {
    local alert_id="$1"
    local parameters="$2"
    
    # Pre-repair validation
    create_system_snapshot "$alert_id"
    create_rollback_plan "$alert_id"
    
    # Execute custom repair
    execute_custom_logic "$parameters"
    
    # Post-repair validation
    validate_repair_outcome "$alert_id"
    
    # Cleanup
    cleanup_temporary_files "$alert_id"
    log_repair_action "$alert_id" "SUCCESS"
}

execute_custom_logic() {
    # Your custom repair logic here
    echo "Executing custom repair with parameters: $1"
    # Implement repair logic
}

# Main execution
case "$1" in
    "execute")
        if [ -z "$2" ]; then
            echo "Error: Alert ID required"
            exit 1
        fi
        custom_repair_action "$2" "$3"
        ;;
    "test")
        echo "Testing custom repair module..."
        # Add test logic
        ;;
    *)
        echo "Usage: $0 {execute <alert_id> [parameters]|test}"
        exit 1
        ;;
esac
```

### 3. Integration with External Systems

**Send alerts to Slack:**
```bash
# Add to monitoring/scripts/alert_processor.sh
send_to_slack() {
    local alert_data="$1"
    local webhook_url="https://hooks.slack.com/services/..."
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"HomeGuardian Alert: $alert_data\"}" \
        "$webhook_url"
}
```

**Log to Elasticsearch:**
```bash
# Add to any module for centralized logging
log_to_elasticsearch() {
    local log_entry="$1"
    local index="homeguardian-$(date +%Y.%m.%d)"
    
    curl -X POST "http://localhost:9200/$index/_doc" \
        -H 'Content-Type: application/json' \
        -d "$log_entry"
}
```

## Troubleshooting Examples

### 1. Repair Not Executing

```bash
# Check repair request directory
ls -la monitoring/data/repair_requests/

# Check repair system logs
tail -f repair/logs/repair.log

# Test repair orchestrator manually
./repair/scripts/repair_orchestrator.sh test
```

### 2. False Positive Alerts

```bash
# Adjust thresholds temporarily
./monitoring/scripts/health_check.sh single --threshold-multiplier 1.2

# Check baseline metrics
cat monitoring/data/baselines/cpu_baseline_2026-04-17.json

# Recalculate baselines
./monitoring/scripts/health_check.sh single --recalculate-baselines
```

### 3. Rollback Execution

```bash
# List available rollback plans
ls -la repair/data/rollbacks/

# Execute rollback manually
./repair/modules/rollback_plans.sh --execute rollback_2026-04-17_16:46:32.json

# Check rollback status
tail -f repair/logs/rollback.log
```

## Performance Monitoring

### 1. System Resource Usage

```bash
# Monitor HomeGuardian's own resource usage
./monitoring/modules/cpu_monitor.sh --process "health_check\|repair_orchestrator"

# Check log file sizes
find . -name "*.log" -type f -exec du -h {} \; | sort -hr
```

### 2. Response Time Metrics

```bash
# Time health check execution
time ./monitoring/scripts/health_check.sh single

# Check repair response times
grep "Repair duration" repair/logs/repair.log | tail -10
```

### 3. Alert Frequency Analysis

```bash
# Count alerts by type
find monitoring/data/alerts/ -name "*.json" -exec jq -r '.alert_type' {} \; | sort | uniq -c

# Alert timeline
find monitoring/data/alerts/ -name "*.json" -exec jq -r '.timestamp + " " + .alert_type + " " + .severity' {} \; | sort
```

## Maintenance Tasks

### 1. Log Rotation

```bash
# Rotate HomeGuardian logs
./repair/modules/cleanup_operations.sh --target logs --rotate --keep 7

# Archive old metrics
find monitoring/data/metrics/ -name "*.json" -mtime +30 -exec gzip {} \;
```

### 2. Database Maintenance

```bash
# Optimize JSON storage
find . -name "*.json" -size +1M -exec jq -c '.' {} > {}.tmp \; -exec mv {}.tmp {} \;

# Remove temporary files
./repair/modules/cleanup_operations.sh --target all --clean
```

### 3. System Updates

```bash
# Backup configuration
tar -czf homeguardian-backup-$(date +%Y%m%d).tar.gz monitoring/config/ repair/config/

# Update from repository
git pull origin main

# Test after update
./monitoring/scripts/health_check.sh test
./repair/scripts/repair_orchestrator.sh test
```

These examples demonstrate the practical usage of HomeGuardian for automated server maintenance. The system is designed to handle common scenarios automatically while providing manual override capabilities for edge cases.