# HomeGuardian Architecture Deep Dive

## Overview
This document provides detailed technical architecture specifications for the HomeGuardian self-healing home server system. It covers system architecture, data structures, communication protocols, error handling, and logging systems.

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Data Structures](#data-structures)
3. [Communication Protocols](#communication-protocols)
4. [Error Handling System](#error-handling-system)
5. [Logging System](#logging-system)
6. [Performance Characteristics](#performance-characteristics)
7. [Scalability Considerations](#scalability-considerations)
8. [Security Architecture](#security-architecture)

## System Architecture

### Architectural Principles

#### 1. Safety-First Design
- **Pre-action validation:** All repairs validated before execution
- **Rollback readiness:** System state snapshots before changes
- **One change at a time:** Isolated repairs with validation between steps
- **Post-action verification:** Functional testing after repairs

#### 2. Parallel Execution Strategy
- **Simultaneous agent operation:** @monitor and @fixer work concurrently
- **Intelligent routing:** Context-aware request distribution
- **Resource isolation:** Separate execution contexts per agent
- **Result aggregation:** Combined outcomes from parallel work

#### 3. Context Preservation
- **SESSION-CONTEXT.md:** Session-specific context tracking
- **progress.md:** Real-time progress updates
- **Memory-flush protocol:** Agent memory management
- **Context enrichment:** Additional context added during routing

#### 4. Quality Gates
- **Vector similarity audit:** 0.95/1.00 minimum threshold
- **Quality Equation scoring:** 8.5/10 minimum target
- **Integration validation:** 80% minimum workflow completeness
- **Production readiness:** Modular, extensible, cross-platform

### Component Architecture

#### @monitor Agent Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      @monitor Agent                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Scheduler │    │   Collector │    │   Analyzer  │    │
│  │  (Cron/     │    │  (Metric    │    │  (Threshold │    │
│  │   Timer)    │───▶│   Gathering)│───▶│   Checking) │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Reporter  │    │   Notifier  │    │   Storage   │    │
│  │  (Report    │◀───│  (Alert     │◀───│  (Metric    │    │
│  │   Generation)│    │   Routing)  │    │   Persistence)│   │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Component Details:**

1. **Scheduler:**
   - Timer-based execution
   - Configurable intervals (default: 5 minutes)
   - Quiet hours respect (23:00-08:00)
   - Priority-based scheduling

2. **Collector:**
   - Modular metric gathering
   - Cross-platform compatibility (macOS/Linux)
   - Resource-efficient data collection
   - Error handling and retry logic

3. **Analyzer:**
   - Threshold-based analysis
   - Trend detection
   - Baseline comparison
   - Anomaly detection

4. **Notifier:**
   - Multi-level alerting (INFO, WARNING, CRITICAL, EMERGENCY)
   - Alert cooldown to prevent spam
   - Context enrichment
   - Integration with routing system

5. **Storage:**
   - Time-series metric storage (JSON format)
   - 30-day data retention
   - Compression for historical data
   - Backup and recovery mechanisms

6. **Reporter:**
   - Report generation (daily, weekly, monthly)
   - Visualization data preparation
   - Export capabilities (CSV, JSON, PDF)

#### @fixer Agent Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      @fixer Agent                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Receiver  │    │   Diagnoser │    │   Planner   │    │
│  │  (Request   │    │  (Problem   │    │  (Action    │    │
│  │   Handler)  │───▶│   Analysis) │───▶│   Sequence) │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Executor  │    │   Validator │    │   Rollback  │    │
│  │  (Safe      │◀───│  (Post-     │◀───│   Manager   │    │
│  │   Execution)│    │   Repair    │    │  (State     │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│               │      Verification)│      Restoration)│     │
│               └───────────────────┴───────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Component Details:**

1. **Receiver:**
   - Repair request parsing
   - Priority-based queueing
   - Duplicate detection
   - Context validation

2. **Diagnoser:**
   - System state analysis
   - Root cause identification
   - Impact assessment
   - Safety level determination

3. **Planner:**
   - Action sequence planning
   - Dependency resolution
   - Resource allocation
   - Timeout estimation

4. **Executor:**
   - Safe action execution
   - Progress monitoring
   - Resource limiting
   - Timeout enforcement

5. **Validator:**
   - Post-repair verification
   - Functional testing
   - Performance validation
   - Safety compliance check

6. **Rollback Manager:**
   - System state snapshots
   - Rollback plan generation
   - State restoration
   - Rollback verification

#### Routing System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Routing System                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Watcher   │    │   Parser    │    │   Mapper    │    │
│  │  (Directory │    │  (Request   │    │  (Alert→    │    │
│  │   Monitor)  │───▶│   Parsing)  │───▶│   Action    │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Enricher  │    │   Invoker   │    │   Logger    │    │
│  │  (Context   │◀───│  (Agent     │◀───│  (Audit     │    │
│  │   Addition) │    │   Calling)  │    │   Trail)    │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**Component Details:**

1. **Watcher:**
   - Directory monitoring (inotify/polling)
   - File change detection
   - Event queuing
   - Debouncing

2. **Parser:**
   - JSON validation
   - Schema compliance checking
   - Data extraction
   - Error handling

3. **Mapper:**
   - Rule-based mapping (routing_rules.json)
   - Priority calculation
   - Action selection
   - Fallback handling

4. **Enricher:**
   - Context addition (SESSION-CONTEXT.md, progress.md)
   - Metadata injection
   - History attachment
   - Environment context

5. **Invoker:**
   - Agent invocation (@fixer calls)
   - Parameter passing
   - Response handling
   - Timeout management

6. **Logger:**
   - Audit trail maintenance
   - Decision logging
   - Performance metrics
   - Error tracking

### Data Flow Architecture

#### Monitoring Data Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   System    │    │   Metric    │    │   Alert     │    │   Storage   │
│   Metrics   │───▶│   Collector │───▶│   Generator │───▶│   & Routing │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Baseline  │    │   Trend     │    │   Context   │    │   @fixer    │
│   Comparison│    │   Analysis  │    │   Enrichment│    │   Invocation│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**Flow Details:**

1. **Metric Collection Phase:**
   - System metrics gathered from OS APIs
   - Cross-platform abstraction layer
   - Resource-efficient collection
   - Error handling and fallbacks

2. **Analysis Phase:**
   - Threshold comparison
   - Trend detection (moving averages)
   - Baseline deviation calculation
   - Anomaly scoring

3. **Alert Generation Phase:**
   - Severity level determination
   - Alert message formatting
   - Context attachment
   - Priority calculation

4. **Storage & Routing Phase:**
   - Time-series storage (JSON format)
   - Alert persistence
   - Routing decision making
   - @fixer invocation preparation

#### Repair Data Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Repair    │    │   System    │    │   Action    │    │   Repair    │
│   Request   │───▶│   Diagnosis │───▶│   Planning  │───▶│   Execution │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Context   │    │   Safety    │    │   Rollback  │    │   Post-     │
│   Validation│    │   Checks    │    │   Planning  │    │   Repair    │
│             │    │             │    │             │    │   Validation│
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**Flow Details:**

1. **Request Processing Phase:**
   - Request validation and parsing
   - Context verification
   - Priority assessment
   - Queue management

2. **Diagnosis Phase:**
   - System state analysis
   - Root cause identification
   - Impact assessment
   - Safety level determination

3. **Planning Phase:**
   - Action sequence generation
   - Dependency resolution
   - Resource allocation
   - Rollback plan creation

4. **Execution Phase:**
   - Safe action execution
   - Progress monitoring
   - Error handling
   - State persistence

5. **Validation Phase:**
   - Post-repair verification
   - Functional testing
   - Performance validation
   - Result reporting

## Data Structures

### Core Data Models

#### Metric Data Model

```json
{
  "metric_id": "cpu_usage_2026-04-17_16:45:23",
  "timestamp": "2026-04-17T16:45:23Z",
  "module": "cpu_monitor",
  "hostname": "server-01",
  "values": {
    "cpu_usage_percent": 92.5,
    "load_1m": 9.85,
    "load_5m": 7.2,
    "load_15m": 5.8,
    "process_count": 187
  },
  "metadata": {
    "collection_duration_ms": 125,
    "memory_usage_mb": 12.5,
    "version": "1.0.0",
    "checksum": "a1b2c3d4e5f6"
  },
  "tags": {
    "environment": "production",
    "region": "us-east-1",
    "instance_type": "t3.medium"
  }
}
```

**Field Specifications:**

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `metric_id` | string | Unique metric identifier | Pattern: `module_timestamp` |
| `timestamp` | ISO 8601 | Metric collection time | Required, UTC timezone |
| `module` | string | Source monitoring module | Enum: cpu, memory, disk, service, log, network |
| `hostname` | string | Source host identifier | Required, max 255 chars |
| `values` | object | Metric values | Required, module-specific schema |
| `metadata` | object | Collection metadata | Optional |
| `tags` | object | Contextual tags | Optional, key-value pairs |

#### Alert Data Model

```json
{
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "timestamp": "2026-04-17T16:45:23Z",
  "module": "cpu_monitor",
  "severity": "CRITICAL",
  "status": "active",
  "metric": {
    "name": "load_average",
    "value": 9.85,
    "threshold": 8.0,
    "unit": "load"
  },
  "context": {
    "hostname": "server-01",
    "baseline_id": "baseline_cpu_2026-04-17",
    "previous_alerts": ["cpu_warning_2026-04-17_16:30:12"],
    "environment": "production"
  },
  "actions": {
    "auto_remediation": true,
    "scheduled_actions": ["optimize_processes", "restart_services"],
    "manual_intervention_required": false
  },
  "history": [
    {
      "timestamp": "2026-04-17T16:45:23Z",
      "event": "alert_created",
      "details": "Threshold exceeded: load_average > 8.0"
    }
  ]
}
```

**Field Specifications:**

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `alert_id` | string | Unique alert identifier | Pattern: `module_severity_timestamp` |
| `timestamp` | ISO 8601 | Alert creation time | Required, UTC timezone |
| `module` | string | Source monitoring module | Enum: cpu, memory, disk, service, log, network |
| `severity` | string | Alert severity level | Enum: INFO, WARNING, CRITICAL, EMERGENCY |
| `status` | string | Current alert status | Enum: active, acknowledged, resolved, suppressed |
| `metric` | object | Metric details | Required |
| `context` | object | Alert context | Optional |
| `actions` | object | Remediation actions | Optional |
| `history` | array | Alert history | Optional, chronological order |

#### Repair Request Data Model

```json
{
  "request_id": "repair_2026-04-17_16:46:00_abc123",
  "timestamp": "2026-04-17T16:46:00Z",
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "priority": "high",
  "status": "pending",
  "module": "cpu_monitor",
  "alert_details": {
    "severity": "CRITICAL",
    "message": "CPU load critical: 9.85",
    "metric": "load_average",
    "value": 9.85,
    "threshold": 8.0
  },
  "system_state": {
    "pre_repair_snapshot": {
      "cpu_usage_percent": 92.5,
      "load_1m": 9.85,
      "process_count": 187,
      "timestamp": "2026-04-17T16:45:45Z"
    },
    "resource_availability": {
      "cpu_idle_percent": 7.5,
      "memory_free_mb": 2048,
      "disk_free_gb": 50.2
    }
  },
  "requested_actions": [
    {
      "action": "