# HomeGuardian Monitoring System Architecture

## Overview
Modular monitoring system for the HomeGuardian self-healing home server. Designed for extensibility, reliability, and integration with the @fixer repair agent.

## Core Components

### 1. **Monitoring Modules** (`modules/`)
Individual monitoring components with specific responsibilities:

- **cpu_monitor.sh** - CPU usage, load averages, process analysis
- **memory_monitor.sh** - Memory usage, swap, memory pressure
- **disk_monitor.sh** - Disk usage, I/O, SMART status
- **service_monitor.sh** - Service uptime, response times
- **log_monitor.sh** - Log sizes, error patterns, rotation
- **network_monitor.sh** - Connectivity, bandwidth, latency

### 2. **Orchestration Script** (`scripts/`)
- **health_check.sh** - Main orchestrator that runs all modules
- **alert_manager.sh** - Handles alert thresholds and notifications
- **report_generator.sh** - Creates daily/weekly reports

### 3. **Configuration** (`config/`)
- **thresholds.conf** - Alert thresholds for each metric
- **services.conf** - List of critical services to monitor
- **logs.conf** - Log files to monitor with size limits
- **schedule.conf** - Monitoring frequency settings

### 4. **Data Storage** (`data/`)
- **metrics/`** - Time-series metrics in JSON format
- **alerts/`** - Alert history and status
- **baseline/`** - Baseline metrics for comparison

### 5. **Logs** (`logs/`)
- **monitoring.log** - System monitoring activity
- **alerts.log** - All alerts generated
- **errors.log** - Monitoring system errors

## Data Flow

```
[Monitoring Modules] → [Health Check Orchestrator] → [Alert Manager]
        ↓                          ↓                        ↓
  [Metrics Storage]         [Report Generator]       [@fixer Notification]
        ↓                          ↓                        ↓
  [Trend Analysis]          [Daily Reports]          [Repair Actions]
```

## Alert Levels

### **INFO** (Level 1)
- System information, normal operations
- No action required
- Logged for historical reference

### **WARNING** (Level 2)
- Thresholds approaching limits
- Performance degradation detected
- Monitor closely, prepare for action

### **CRITICAL** (Level 3)
- Thresholds breached
- System stability at risk
- Immediate @fixer intervention required

### **EMERGENCY** (Level 4)
- System failure imminent or occurred
- Requires immediate human attention
- Highest priority escalation

## Integration Points

### **With @fixer:**
- Alert routing via structured JSON messages
- Repair action status tracking
- Rollback coordination

### **With @orchestrator:**
- Task scheduling and coordination
- Context preservation
- Escalation management

### **With Dashboard:**
- Real-time metrics display
- Alert visualization
- Historical trend charts

## Quality Metrics

### **Monitoring Accuracy:**
- False positive rate: < 5%
- False negative rate: < 1%
- Alert latency: < 30 seconds

### **System Impact:**
- CPU overhead: < 2%
- Memory overhead: < 50MB
- Disk I/O: < 1MB/s

### **Reliability:**
- Uptime: 99.9%
- Data retention: 30 days minimum
- Backup frequency: Daily

## Security Considerations

1. **Least Privilege:** Monitoring runs with minimal required permissions
2. **Data Encryption:** Sensitive metrics encrypted at rest
3. **Access Control:** Role-based access to monitoring data
4. **Audit Trail:** All monitoring actions logged and traceable

## Extensibility

### **Plugin System:**
- New monitoring modules can be added without modifying core
- Custom thresholds per environment
- Service-specific monitoring plugins

### **Custom Metrics:**
- User-defined metric collection
- Application-specific health checks
- Business logic monitoring

## Deployment

### **Local Development:**
- Direct script execution
- Manual testing and validation

### **Production:**
- Systemd service for automatic startup
- Log rotation and management
- Resource limits and isolation

---

**Version:** 1.0  
**Created:** 2026-04-17  
**Last Updated:** 2026-04-17  
**Maintainer:** @monitor (Watchful Owl 🦉)