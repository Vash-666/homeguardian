# HomeGuardian Technical Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         HomeGuardian Multi-Agent System                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐ │
│  │    @monitor     │      │     @fixer      │      │  @orchestrator  │ │
│  │  (Watchful Owl) │      │  (Steady Beaver)│      │    (Switch)     │ │
│  │                 │      │                 │      │                 │ │
│  │  • CPU Monitor  │◄────►│• Diagnostic     │◄────►│• Alert Routing  │ │
│  │  • Memory       │      │  Tools          │      │• Context        │ │
│  │  • Disk         │      │• Safety Checks  │      │  Enrichment     │ │
│  │  • Service      │      │• Restart        │      │• Priority       │ │
│  │  • Log          │      │  Procedures     │      │  Handling       │ │
│  │  • Network      │      │• Cleanup        │      │• Duplicate      │ │
│  │                 │      │  Operations     │      │  Detection      │ │
│  │  Thresholds:    │      │• Rollback Plans │      │                 │ │
│  │  - INFO         │      │                 │      │ Routing Rules:  │ │
│  │  - WARNING      │      │ Safety:         │      │ - CPU → Restart │ │
│  │  - CRITICAL     │      │ - Pre-validation│      │ - Memory →      │ │
│  │  - EMERGENCY    │      │ - One change    │      │   Cleanup       │ │
│  │                 │      │ - Rollback ready│      │ - Disk →        │ │
│  │  Data: JSON     │      │ - Post-verify   │      │   Log rotate    │ │
│  │  Storage: TSDB  │      │ - Cleanup       │      │ - Service →     │ │
│  │  Retention: 30d │      │                 │      │   Restart       │ │
│  └─────────────────┘      └─────────────────┘      └─────────────────┘ │
│         │                         │                         │           │
│         ▼                         ▼                         ▼           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Quality Gateway (@quality)                   │   │
│  │                                                                 │   │
│  │  • Vector Audit (0.95/1.00 similarity)                         │   │
│  │  • Quality Equation (8.8/10 score)                             │   │
│  │  • Context Preservation (92.5%)                                │   │
│  │  • Integration Validation (92.5%)                              │   │
│  │  • Production Readiness Assessment                             │   │
│  │                                                                 │   │
│  │  Validation Gates:                                              │   │
│  │  - Cosine similarity ≥ 0.92                                    │   │
│  │  - Quality score ≥ 8.5/10                                      │   │
│  │  - Context preservation ≥ 85%                                  │   │
│  │  - Integration score ≥ 80%                                     │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Dashboard & Visualization                    │   │
│  │                                                                 │   │
│  │  • Real-time metrics display                                    │   │
│  │  • Repair status monitoring                                     │   │
│  │  • Alert history and trends                                     │   │
│  │  • System health overview                                       │   │
│  │  • Performance baselines                                        │   │
│  │                                                                 │   │
│  │  Access: http://localhost:18789                                 │   │
│  │  Data: JSON API endpoints                                       │   │
│  │  Updates: Real-time WebSocket                                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   System    │    │  @monitor   │    │ @orchestrator│   │    @fixer   │
│   Metrics   │───▶│   Agent     │───▶│   Agent      │───▶│   Agent     │
│             │    │             │    │              │   │             │
│ - CPU load  │    │ • Collect   │    │ • Route      │   │ • Diagnose  │
│ - Memory    │    │ • Analyze   │    │ • Enrich     │   │ • Validate  │
│ - Disk      │    │ • Threshold │    │ • Prioritize │   │ • Execute   │
│ - Services  │    │ • Alert     │    │ • Log        │   │ • Verify    │
│ - Logs      │    │ • Store     │    │              │   │ • Cleanup   │
│ - Network   │    └─────────────┘    └─────────────┘   └─────────────┘
└─────────────┘           │                    │                │
                          ▼                    ▼                ▼
                   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                   │   Metrics   │    │   Routing   │    │   Repair    │
                   │   Storage   │    │    Logs     │    │    Logs     │
                   │             │    │             │    │             │
                   │ • JSON files│    │ • Decisions │    │ • Actions   │
                   │ • 30d reten.│    │ • Context   │    │ • Outcomes  │
                   │ • Baselines │    │ • Timestamp │    │ • Rollbacks │
                   └─────────────┘    └─────────────┘    └─────────────┘
                          │                    │                │
                          ▼                    ▼                ▼
                   ┌────────────────────────────────────────────────────┐
                   │               @quality Agent                      │
                   │                                                    │
                   │ • Vector similarity analysis (0.95)               │
                   │ • Quality Equation scoring (8.8/10)               │
                   │ • Context preservation validation (92.5%)         │
                   │ • Integration workflow testing (92.5%)            │
                   │ • Production readiness assessment                 │
                   └────────────────────────────────────────────────────┘
```

## Directory Structure

```
homeguardian/
├── agents/                          # Agent definitions and configurations
│   ├── monitor/                     # @monitor agent files
│   │   ├── SOUL.md                  # Personality and behavior
│   │   ├── IDENTITY.md              # Role definition
│   │   ├── AGENTS.md                # Operational guidelines
│   │   └── HEARTBEAT.md             # Proactive checks
│   ├── fixer/                       # @fixer agent files
│   │   ├── SOUL.md                  # Safety-focused personality
│   │   ├── IDENTITY.md              # Repair specialist role
│   │   ├── AGENTS.md                # Safety protocols
│   │   └── HEARTBEAT.md             # System health checks
│   └── quality/                     # @quality agent files
│       ├── SOUL.md                  # Validation-focused personality
│       ├── IDENTITY.md              # Quality guardian role
│       ├── AGENTS.md                # Audit procedures
│       └── HEARTBEAT.md             # Periodic validation
│
├── monitoring/                      # Monitoring system (6 modules)
│   ├── modules/                     # Individual monitoring scripts
│   │   ├── cpu_monitor.sh           # CPU usage and load averages
│   │   ├── memory_monitor.sh        # Memory usage and swap
│   │   ├── disk_monitor.sh          # Disk usage and I/O
│   │   ├── service_monitor.sh       # Service uptime and response
│   │   ├── log_monitor.sh           # Log file sizes and errors
│   │   └── network_monitor.sh       # Connectivity and latency
│   ├── config/                      # Configuration files
│   │   ├── thresholds.conf          # Alert thresholds
│   │   ├── services.conf            # Critical services list
│   │   └── logs.conf                # Log files to monitor
│   ├── scripts/                     # Orchestration scripts
│   │   ├── health_check.sh          # Main orchestrator
│   │   ├── continuous_monitor.sh    # Continuous monitoring
│   │   └── alert_processor.sh       # Alert generation
│   ├── data/                        # Metrics storage
│   │   ├── metrics/                 # Time-series metrics
│   │   ├── alerts/                  # Alert history
│   │   ├── baselines/               # System baselines
│   │   └── repair_requests/         # Repair requests for @fixer
│   └── logs/                        # System logs
│       ├── system.log               # Main system log
│       ├── error.log                # Error log
│       └── audit.log                # Audit trail
│
├── repair/                          # Repair system (5 modules)
│   ├── modules/                     # Individual repair scripts
│   │   ├── diagnostic_tools.sh      # Problem analysis
│   │   ├── safety_checks.sh         # Pre/post validation
│   │   ├── restart_procedures.sh    # Service restart
│   │   ├── cleanup_operations.sh    # Resource cleanup
│   │   └── rollback_plans.sh        # State restoration
│   ├── config/                      # Configuration files
│   │   ├── repair_rules.conf        # Repair action rules
│   │   ├── safety_limits.conf       # Safety constraints
│   │   └── rollback_config.conf     # Rollback configuration
│   ├── scripts/                     # Orchestration scripts
│   │   ├── repair_orchestrator.sh   # Main orchestrator
│   │   ├── repair_processor.sh      # Request processing
│   │   └── status_monitor.sh        # Repair status
│   ├── data/                        # Repair logs and state
│   │   ├── repairs/                 # Repair history
│   │   ├── snapshots/               # System snapshots
│   │   ├── rollbacks/               # Rollback plans
│   │   └── status/                  # Current status
│   └── logs/                        # System logs
│       ├── repair.log               # Repair actions log
│       ├── safety.log               # Safety checks log
│       └── rollback.log             # Rollback operations log
│
├── routing/                         # @mention routing system
│   ├── config/                      # Configuration files
│   │   └── routing_rules.json       # Alert→Repair mapping rules
│   ├── scripts/                     # Routing scripts
│   │   ├── router.py                # Main routing logic
│   │   └── watch_repair_requests.sh # Directory watcher
│   └── logs/                        # Routing logs
│       ├── routing.log              # Routing decisions
│       └── context.log              # Context enrichment
│
├── showcase/                        # Documentation and examples
│   ├── README.md                    # Main project documentation
│   ├── SHOWCASE_POST.md             # Technical showcase (875 words)
│   ├── ARCHITECTURE.md              # This architecture document
│   ├── USAGE_EXAMPLES.md            # Usage examples
│   └── CONTRIBUTING.md              # Contributing guidelines
│
├── SESSION-CONTEXT.md               # Current session context
├── progress.md                      # Real-time progress tracking
└── README.md                        # Project overview
```

## Communication Protocols

### Alert Format (JSON)
```json
{
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "alert_type": "CPU",
  "severity": "CRITICAL",
  "metric": "load_average",
  "value": 9.85,
  "threshold": 8.0,
  "timestamp": "2026-04-17T16:45:23Z",
  "context": {
    "session_id": "monitor_2026-04-17",
    "progress_ref": "progress.md#task-2.1",
    "baseline": "cpu_baseline_2026-04-17.json",
    "previous_alerts": ["cpu_high_2026-04-17_15:30:12"],
    "system_state": {
      "process_count": 187,
      "uptime": "12:34:56",
      "last_reboot": "2026-04-15T08:00:00Z"
    }
  }
}
```

### Repair Request Format (JSON)
```json
{
  "repair_id": "repair_2026-04-17_16:46:05",
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "repair_type": "restart_procedures",
  "target": "high_cpu_process",
  "parameters": {
    "process_name": "chrome",
    "process_id": 12345,
    "action": "restart",
    "timeout_seconds": 30
  },
  "safety_checks": {
    "pre_snapshot": "snapshot_2026-04-17_16:46:00.json",
    "rollback_plan": "rollback_2026-04-17_16:46:02.json",
    "validation_script": "validate_service_restart.sh"
  },
  "context": {
    "routing_decision": "cpu_critical_to_restart",
    "quality_gate": "8.5/10 minimum",
    "parallel_tasks": ["diagnostics", "safety_check"]
  }
}
```

### Quality Audit Format (JSON)
```json
{
  "audit_id": "audit_2026-04-17_17:30:00",
  "component": "monitoring_system",
  "quality_score": 9.0,
  "similarity_score": 0.95,
  "context_preservation": 0.925,
  "integration_score": 0.925,
  "validation_gates": {
    "vector_similarity": {
      "passed": true,
      "score": 0.95,
      "threshold": 0.92
    },
    "quality_equation": {
      "passed": true,
      "score": 8.8,
      "threshold": 8.5
    },
    "context_preservation": {
      "passed": true,
      "score": 0.925,
      "threshold": 0.85
    },
    "integration": {
      "passed": true,
      "score": 0.925,
      "threshold": 0.80
    }
  },
  "recommendations": [
    "Add more detailed error handling in disk_monitor.sh",
    "Increase test coverage for rollback procedures"
  ]
}
```

## Parallel Execution Timeline

```
Time     @monitor              @fixer                @orchestrator          @quality
------   -------------------   -------------------   -------------------   -------------------
T+0:00   Detect CPU spike      Idle                  Idle                  Idle
T+0:05   Generate alert        Start diagnostics     Route alert           Prepare validation
T+0:10   Continue monitoring   Run safety checks     Enrich context        Set quality gates
T+0:15   Log metrics           Create repair plan    Update routing log    Monitor progress
T+0:20   Check other systems   Execute repair        Coordinate handoff    Validate outcomes
T+0:25   Update baselines      Verify repair         Log completion        Final audit
T+0:30   Next monitoring cycle Cleanup               Update status         Report results

Key: 
• Sequential approach would take ~42 minutes (monitor→diagnose→repair→validate)
• Parallel approach takes ~25 minutes (40% time savings)
• All agents work simultaneously after initial detection
```

## Safety Protocol Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Pre-Repair │    │   Repair    │    │ Post-Repair │    │   Cleanup   │
│  Validation │───▶│  Execution  │───▶│  Validation │───▶│  & Logging  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
        │                  │                  │                  │
        ▼                  ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ System      │    │ One Change  │    │ Functional  │    │ Remove      │
│ Snapshot    │    │ at a Time   │    │ Testing     │    │ Temp Files  │
├─────────────┤    ├─────────────┤    ├─────────────┤    ├─────────────┤
│ • Process   │    │ • Isolated  │    │ • Service   │    │ • Logs      │
│   list      │    │   actions   │    │   response  │    │ • Configs   │
