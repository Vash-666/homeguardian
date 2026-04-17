# HomeGuardian @Mention Routing System

## Overview
Automated routing system that connects @monitor's alerts to @fixer's repair actions with full context preservation.

## Architecture

```
@monitor (Monitoring) → Repair Request → @mention Router → @fixer (Repair)
      ↓                                       ↓               ↓
  Detects issue                          Routes request    Executes repair
  Creates JSON request                   Enriches context  Returns status
  Places in repair_requests/             Preserves state   Updates monitoring
```

## Repair Request Format (from @monitor)

```json
{
  "timestamp": "2026-04-17T16:52:00-04:00",
  "module": "cpu_monitor",
  "alert_level": "CRITICAL",
  "alert_message": "CPU usage exceeded 95% threshold",
  "alert_details": "Current: 96.2%, Threshold: 95%",
  "system_state": "needs_repair",
  "request_id": "req_1713387120",
  "priority": "high"
}
```

## Routing Logic

### **Alert Type → Repair Action Mapping:**

| Module | Alert Level | Repair Action | Priority |
|--------|-------------|---------------|----------|
| cpu_monitor | CRITICAL | optimize_processes, restart_services | high |
| memory_monitor | CRITICAL | clear_cache, restart_services | high |
| disk_monitor | CRITICAL | cleanup_temp, expand_disk | medium |
| service_monitor | CRITICAL | restart_service, rollback_update | high |
| log_monitor | CRITICAL | rotate_logs, cleanup_old | low |
| network_monitor | CRITICAL | restart_network, reset_connection | high |

### **Priority Handling:**
- **High:** Immediate @fixer invocation
- **Medium:** Queue for next available slot
- **Low:** Batch process during quiet hours

## Implementation

### **1. Directory Watcher (`routing/watch_repair_requests.sh`)**
- Monitors `monitoring/data/repair_requests/`
- Detects new JSON repair requests
- Triggers routing logic

### **2. Router (`routing/router.py`)**
- Parses repair request JSON
- Maps to appropriate repair action
- Enriches with system context
- Invokes @fixer with @mention

### **3. Context Enricher (`routing/enrich_context.py`)**
- Adds SESSION-CONTEXT.md summary
- Includes recent system metrics
- Provides repair history
- Preserves 100% context

### **4. Status Tracker (`routing/track_status.py`)**
- Monitors repair progress
- Updates monitoring system
- Logs outcomes
- Provides feedback to @monitor

## Integration Points

### **With @monitor:**
- Reads from `monitoring/data/repair_requests/`
- Updates repair status in monitoring logs
- Provides feedback on repair outcomes

### **With @fixer:**
- Invokes via @mention with enriched context
- Passes repair action specifications
- Receives status updates
- Handles repair outcomes

### **With Framework:**
- Updates SESSION-CONTEXT.md
- Logs to progress.md
- Prepares for @quality audit

## Safety Features

1. **Duplicate Detection:** Prevents processing same request twice
2. **Timeout Handling:** Aborts stuck repairs after timeout
3. **Rollback Ready:** Can revert failed repairs
4. **Audit Trail:** All routing decisions logged
5. **Manual Override:** Human intervention possible

## Quality Gates

1. **Context Preservation:** 100% target (verified by @quality)
2. **Routing Accuracy:** >95% correct repair action mapping
3. **Response Time:** <30 seconds from detection to @fixer invocation
4. **Reliability:** 99.9% uptime target

## Files

- `routing/README.md` - This documentation
- `routing/watch_repair_requests.sh` - Directory watcher
- `routing/router.py` - Main routing logic
- `routing/enrich_context.py` - Context enrichment
- `routing/track_status.py` - Status tracking
- `routing/config/routing_rules.json` - Alert→Repair mapping
- `routing/logs/` - Routing system logs

## Next Steps

1. Implement directory watcher
2. Create routing logic
3. Build context enrichment
4. Integrate with @fixer
5. Test with simulated alerts
6. @quality audit (Task 2.4)