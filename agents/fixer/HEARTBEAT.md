# HEARTBEAT.md - @fixer's Proactive Maintenance

## Overview

This file defines what @fixer checks during heartbeat polls. Use heartbeats for preventive maintenance, tool updates, and knowledge refinement.

## Heartbeat Schedule

- **Frequency:** Every 60 minutes (approximate)
- **Duration:** 5-10 minutes per heartbeat
- **Quiet Hours:** 23:00-08:00 (reduce frequency to 120 minutes, skip non-critical maintenance)

## Check Rotation

Rotate through these check groups (do 1-2 per heartbeat):

### **Group A: Repair Queue & System Health**
1. **Active Repairs** - Any in-progress fixes needing attention
2. **Post-Repair Verification** - Recent fixes still working
3. **System Stability** - Any new issues emerging after repairs
4. **@monitor Alerts** - Any new alerts that might need fixing

### **Group B: Procedure & Knowledge Maintenance**
1. **Repair Documentation** - Update procedures based on recent fixes
2. **Pattern Recognition** - Identify recurring issues for permanent fixes
3. **Tool Updates** - Check for script improvements or new tools
4. **Knowledge Gaps** - Areas where repair procedures are missing

### **Group C: Safety & Preparedness**
1. **Backup Verification** - Recent backups successful and restorable
2. **Rollback Scripts** - Test rollback procedures still work
3. **Emergency Access** - Verify repair tools and access available
4. **Communication Channels** - @orchestrator and @monitor reachable

### **Group D: Preventive Maintenance**
1. **Log Rotation** - Application and system logs not filling disks
2. **Temporary Files** - Clean up /tmp and other temp areas
3. **Cache Management** - Application caches not causing issues
4. **Resource Leaks** - Check for memory leaks or file descriptor issues

## Maintenance Windows

### **Low-Impact Maintenance (Anytime):**
- Log cleanup and rotation
- Cache management
- Documentation updates
- Tool verification

### **Medium-Impact Maintenance (Business Hours):**
- Service restarts (with monitoring)
- Configuration updates (with rollback)
- Dependency updates (non-critical)
- Performance tuning

### **High-Impact Maintenance (Scheduled):**
- Database operations
- Filesystem changes
- Network reconfiguration
- Major version updates

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
  "maintenanceHistory": {
    "completed": [],
    "scheduled": [],
    "failed": []
  },
  "readinessState": {
    "backupsCurrent": true,
    "rollbackTested": true,
    "toolsAvailable": true,
    "proceduresUpdated": true
  }
}
```

## Proactive Work

During heartbeats, also:

### **1. Knowledge Refinement:**
- Review recent repairs for pattern extraction
- Update repair checklists with new learnings
- Document system quirks and workarounds
- Share insights with @monitor for better detection

### **2. Tool Improvement:**
- Test backup and restore procedures
- Verify rollback scripts still work
- Update repair scripts with new best practices
- Create new tools for common issues

### **3. Preparedness Drills:**
- Simulate common failure scenarios
- Test communication with @orchestrator and @monitor
- Verify emergency access procedures
- Practice rapid diagnosis and repair

## Quiet Hour Rules

**23:00-08:00 Local Time:**
- Reduce heartbeat frequency to 120 minutes
- Skip non-critical maintenance (documentation, tool updates)
- Only perform emergency repairs
- Queue preventive maintenance for business hours
- Focus on monitoring post-repair systems

## Safety Protocol

### **Before Any Maintenance:**
1. **Risk Assessment:** Low/medium/high impact classification
2. **Backup:** Current state captured
3. **Rollback Plan:** Clear steps to revert
4. **Monitoring:** @monitor alerted and watching
5. **Timing:** Appropriate maintenance window

### **During Maintenance:**
1. **Step-by-Step:** One change at a time
2. **Verification:** Check system after each step
3. **Communication:** Update @orchestrator on progress
4. **Abort Ready:** Rollback plan executable at any point

### **After Maintenance:**
1. **Verification:** System functioning correctly
2. **Documentation:** Update procedures with results
3. **Communication:** Notify @orchestrator of completion
4. **Monitoring:** @monitor watching for issues

## Quality Equation Integration

### **Maintenance Quality Score:**
```
Maintenance Quality = (Success Rate × 0.35) +
                      (Documentation × 0.25) +
                      (Preparedness × 0.20) +
                      (Prevention × 0.20)
```

### **Targets:**
- **Success Rate:** ≥95% of maintenance actions successful
- **Documentation:** 100% of actions documented
- **Preparedness:** All tools tested monthly
- **Prevention:** ≥1 preventive fix per week

## Memory Integration

### **What to Capture:**
- **Daily Log:** Maintenance actions, system responses, issues encountered
- **MEMORY.md:** Successful procedures, tool improvements, system knowledge

### **Flush Schedule:**
- **After each heartbeat:** Update daily log
- **Daily at 00:00:** Archive and create new log
- **Weekly on Sunday:** Review and update MEMORY.md

## Checklist Template

```
[ ] Group A: Repair Queue & System Health
    [ ] Active repairs status
    [ ] Post-repair verification
    [ ] System stability check
    [ ] @monitor alert review

[ ] Group B: Procedure & Knowledge Maintenance
    [ ] Repair documentation update
    [ ] Pattern recognition
    [ ] Tool updates check
    [ ] Knowledge gap identification

[ ] Group C: Safety & Preparedness
    [ ] Backup verification
    [ ] Rollback script test
    [ ] Emergency access check
    [ ] Communication channel test

[ ] Group D: Preventive Maintenance
    [ ] Log rotation status
    [ ] Temporary file cleanup
    [ ] Cache management
    [ ] Resource leak check

[ ] Proactive Work
    [ ] Knowledge refinement
    [ ] Tool improvement
    [ ] Preparedness drill
    [ ] Coordination with @monitor

[ ] Safety Check
    [ ] Risk assessment complete
    [ ] Backup performed
    [ ] Rollback plan ready
    [ ] @monitor notified

[ ] State Update
    [ ] Update heartbeat-state.json
    [ ] Log results to daily file
    [ ] Check for MEMORY.md updates
```

## Repair Priority Matrix

| Issue Type | Response Time | Action Required |
|------------|---------------|-----------------|
| **Critical** (System down) | <5 minutes | Immediate repair with @orchestrator approval |
| **High** (Service degraded) | <15 minutes | Repair in next maintenance window |
| **Medium** (Performance issue) | <60 minutes | Schedule repair, document workaround |
| **Low** (Cosmetic/minor) | <24 hours | Add to backlog, fix during quiet period |

## Notes

- Coordinate maintenance windows with @orchestrator
- Share preventive insights with @monitor for early detection
- Test all tools and procedures monthly
- Review and update this file quarterly

---

**Last Updated:** 2026-04-17  
**Next Review:** 2026-05-17