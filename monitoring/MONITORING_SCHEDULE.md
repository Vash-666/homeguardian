# HomeGuardian Monitoring Schedule

## Overview
This document defines the monitoring schedule for the HomeGuardian self-healing system. The schedule is designed to balance system impact with timely detection of issues.

## Monitoring Frequencies

### **High-Frequency Monitoring (Every 30 seconds)**
**Modules:** CPU, Memory
**Rationale:** These metrics can change rapidly and indicate immediate system stress.
**Impact:** Low (CPU < 1%, Memory < 10MB)

### **Medium-Frequency Monitoring (Every 5 minutes)**
**Modules:** Disk, Network
**Rationale:** Disk I/O and network usage change more slowly but can indicate developing issues.
**Impact:** Low (minimal I/O, network checks are lightweight)

### **Low-Frequency Monitoring (Every 15 minutes)**
**Modules:** Services, Logs
**Rationale:** Service status and log patterns change relatively slowly.
**Impact:** Medium (service checks may involve network calls, log parsing)

### **Daily Reports (09:00 daily)**
**Content:** Full system health summary, trend analysis, capacity planning
**Rationale:** Provides overview for human review and long-term planning.

## Quiet Hours
**Time:** 23:00 - 08:00 (local time)
**Policy:** 
- WARNING alerts are suppressed
- CRITICAL alerts still trigger (safety override)
- Monitoring continues at reduced frequency (double the normal intervals)

## Alert Cooldown
**Duration:** 5 minutes (300 seconds)
**Purpose:** Prevents alert spam for transient issues
**Implementation:** Same alert won't fire twice within cooldown period

## Data Retention
- **Metrics:** 30 days minimum
- **Alerts:** 90 days minimum
- **Logs:** 7 days (rotated), 30 days (compressed), 90 days (deleted)

## Continuous Monitoring Mode
When running in continuous mode (`./health_check.sh continuous`):
1. Checks run according to the defined frequencies
2. Alerts are processed in real-time
3. Metrics are saved to time-series database
4. System automatically escalates to @fixer when needed

## Manual Health Check
For one-time checks: `./health_check.sh single`
- Runs all modules once
- Returns exit code: 0=HEALTHY, 1=WARNING, 2=CRITICAL
- Prints health summary and any alerts

## Testing Mode
For module testing: `./health_check.sh test`
- Tests each monitoring module individually
- Reports success/failure for each
- Useful for debugging and validation

## Integration with System Scheduler
For production deployment, the monitoring system can be integrated with:
1. **Systemd timers** (Linux) or **launchd** (macOS) for scheduled checks
2. **Cron jobs** for daily reports
3. **Docker health checks** for containerized services

## Performance Considerations
- **CPU overhead:** < 2% during monitoring cycles
- **Memory overhead:** < 50MB sustained
- **Disk I/O:** < 1MB/s during active monitoring
- **Network:** Minimal (ping checks, service status)

## Emergency Override
In case of system stress, monitoring can be temporarily reduced:
1. **Manual override:** `touch /tmp/homeguardian_quiet_mode`
2. **Automatic:** If system load > 15, monitoring frequency is halved
3. **Critical alerts:** Always enabled regardless of system state

## Maintenance Windows
To schedule maintenance without false alerts:
1. Create file: `touch /tmp/homeguardian_maintenance`
2. During maintenance: Only CRITICAL alerts fire
3. After maintenance: Remove file, system resumes normal operation

---

**Last Updated:** 2026-04-17  
**Maintainer:** @monitor (Watchful Owl 🦉)  
**Version:** 1.0