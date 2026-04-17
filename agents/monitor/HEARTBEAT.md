# HEARTBEAT.md - @monitor's Proactive Checks

## Overview

This file defines what @monitor checks during heartbeat polls. Use heartbeats productively to catch issues early and maintain system awareness.

## Heartbeat Schedule

- **Frequency:** Every 30 minutes (approximate)
- **Duration:** 2-5 minutes per heartbeat
- **Quiet Hours:** 23:00-08:00 (reduce frequency to 60 minutes, skip non-critical checks)

## Check Rotation

Rotate through these check groups (do 2-3 per heartbeat):

### **Group A: Core System Health**
1. **CPU Load** - 1/5/15 minute averages
2. **Memory Usage** - Used vs available, swap usage
3. **Disk Space** - Root and critical mounts (>80% warning, >90% critical)
4. **Network Connectivity** - Basic ping tests to gateway and DNS

### **Group B: Service Status**
1. **Docker** - All containers running, no restarts
2. **Systemd Services** - Critical services (nginx, postgres, redis, etc.)
3. **Process Counts** - Expected processes running
4. **Port Listening** - Critical ports (80, 443, 22, etc.)

### **Group C: Performance & Trends**
1. **Response Times** - Key endpoint latency
2. **Error Rates** - Application error logs
3. **Resource Trends** - 24-hour patterns
4. **Anomaly Detection** - Statistical outliers

### **Group D: Capacity & Logs**
1. **Log Rotation** - Log file sizes, rotation status
2. **Backup Status** - Last successful backup
3. **Certificate Expiry** - SSL certificates (>30 days warning)
4. **Security Updates** - Pending updates count

## Alert Thresholds

### **Critical (Immediate Notification):**
- CPU load > 90% for 5 minutes
- Memory usage > 95%
- Disk usage > 95%
- Service down > 2 minutes
- Security incident detected

### **Warning (Next Summary/5-minute check):**
- CPU load > 80% for 10 minutes
- Memory usage > 85%
- Disk usage > 85%
- Service restart detected
- Error rate > 1%

### **Informational (Log Only):**
- CPU load > 70% for 15 minutes
- Memory usage > 75%
- Disk usage > 75%
- Performance degradation < 10%

## Heartbeat State Tracking

Track in `memory/heartbeat-state.json`:

```json
{
  "lastHeartbeat": 1703275200,
  "lastChecks": {
    "group_a": 1703275200,
    "group_b": 1703269800,
    "group_c": 1703264400,
    "group_d": 1703259000
  },
  "alertHistory": {
    "critical": [],
    "warning": [],
    "informational": []
  },
  "systemState": {
    "overallHealth": "healthy",
    "lastIncident": null,
    "uptimeDays": 45
  }
}
```

## Proactive Work

During heartbeats, also:

### **1. Cleanup Tasks:**
- Archive old alert logs (>7 days)
- Rotate monitoring data (>30 days)
- Update performance baselines

### **2. Optimization:**
- Review and adjust thresholds
- Identify monitoring gaps
- Update check frequencies based on patterns

### **3. Reporting:**
- Prepare data for daily summary
- Update trend visualizations
- Document any pattern changes

## Quiet Hour Rules

**23:00-08:00 Local Time:**
- Reduce heartbeat frequency to 60 minutes
- Skip non-critical checks (performance trends, capacity planning)
- Critical alerts still fire immediately
- Warning alerts queue until 08:00
- Informational alerts log only

## Escalation Protocol

### **When to Escalate:**
1. **Self:** Detect and analyze (immediate)
2. **@orchestrator:** Provide context and routing (within 1 minute)
3. **@fixer:** Initiate repair (within 5 minutes)
4. **@quality:** Post-mortem validation (after resolution)

### **Escalation Triggers:**
- Critical threshold breached > 5 minutes
- Multiple related warnings
- Security incident detected
- System unresponsive

## Quality Equation Integration

### **Heartbeat Quality Score:**
```
Heartbeat Quality = (Check Completeness × 0.35) +
                    (Alert Accuracy × 0.30) +
                    (Response Time × 0.20) +
                    (Proactive Work × 0.15)
```

### **Targets:**
- **Check Completeness:** ≥90% of scheduled checks
- **Alert Accuracy:** ≥95% correct classification
- **Response Time:** <2 minutes for critical detection
- **Proactive Work:** ≥1 optimization per week

## Memory Integration

### **What to Capture:**
- **Daily Log:** Raw check results, threshold breaches
- **MEMORY.md:** Pattern recognition, threshold optimizations, incident learnings

### **Flush Schedule:**
- **After each heartbeat:** Update daily log
- **Daily at 00:00:** Archive and create new log
- **Weekly on Sunday:** Review and update MEMORY.md

## Checklist Template

```
[ ] Group A: Core System Health
    [ ] CPU load (1/5/15 min)
    [ ] Memory usage
    [ ] Disk space
    [ ] Network connectivity

[ ] Group B: Service Status
    [ ] Docker containers
    [ ] Systemd services
    [ ] Process counts
    [ ] Port listening

[ ] Group C: Performance & Trends
    [ ] Response times
    [ ] Error rates
    [ ] Resource trends
    [ ] Anomaly detection

[ ] Group D: Capacity & Logs
    [ ] Log rotation
    [ ] Backup status
    [ ] Certificate expiry
    [ ] Security updates

[ ] Proactive Work
    [ ] Cleanup tasks
    [ ] Threshold optimization
    [ ] Reporting preparation

[ ] State Update
    [ ] Update heartbeat-state.json
    [ ] Log results to daily file
    [ ] Check for MEMORY.md updates
```

## Notes

- Adjust check frequencies based on system criticality
- Add system-specific checks as needed
- Review and update this file monthly
- Coordinate with @fixer on maintenance windows

---

**Last Updated:** 2026-04-17  
**Next Review:** 2026-05-17