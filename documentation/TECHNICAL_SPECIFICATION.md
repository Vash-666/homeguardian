# HomeGuardian Technical Specification

## Overview
This document provides comprehensive technical specifications for the HomeGuardian self-healing home server multi-agent system. It covers API schemas, module specifications, configuration references, and integration details.

## Table of Contents
1. [System Architecture](#system-architecture)
2. [API Documentation](#api-documentation)
3. [Module Specifications](#module-specifications)
4. [Configuration Reference](#configuration-reference)
5. [Data Flow Diagrams](#data-flow-diagrams)
6. [Integration Specifications](#integration-specifications)
7. [Communication Protocols](#communication-protocols)
8. [Error Handling](#error-handling)
9. [Security Specifications](#security-specifications)

## System Architecture

### High-Level Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    HomeGuardian System                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   @monitor  │    │   @fixer    │    │ @orchestrator│   │
│  │  (Watchful  │    │  (Steady    │    │   (Switch)   │   │
│  │     Owl)    │◄──►│    Beaver)  │◄──►│              │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│        │                       │               │           │
│        ▼                       ▼               ▼           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Quality Gateway (@quality)             │   │
│  │         Vector Audit • Context Preservation         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               Dashboard & Visualization             │   │
│  │         Real-time metrics • Repair status           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Role | Key Responsibilities |
|-----------|------|----------------------|
| **@monitor** | Monitoring Agent | System health checks, metric collection, alert generation |
| **@fixer** | Repair Agent | Safe repair execution, rollback management, safety validation |
| **@orchestrator** | Coordination Agent | Workflow coordination, context enrichment, task scheduling |
| **@quality** | Quality Agent | Vector audits, quality gates, compliance validation |
| **Dashboard** | Visualization | Real-time metrics, alert visualization, historical trends |

### Directory Structure
```
homeguardian/
├── agents/                    # Agent definitions and configurations
│   ├── monitor/              # @monitor agent files
│   │   ├── SOUL.md           # Agent personality and behavior
│   │   ├── IDENTITY.md       # Agent identity and metadata
│   │   ├── AGENTS.md         # Agent capabilities and rules
│   │   └── HEARTBEAT.md      # Periodic check configuration
│   ├── fixer/                # @fixer agent files
│   │   ├── SOUL.md           # Agent personality and behavior
│   │   ├── IDENTITY.md       # Agent identity and metadata
│   │   ├── AGENTS.md         # Agent capabilities and rules
│   │   └── HEARTBEAT.md      # Periodic check configuration
│   └── orchestrator/         # @orchestrator agent files
├── monitoring/               # Monitoring system implementation
│   ├── modules/              # 6 monitoring modules
│   │   ├── cpu_monitor.sh    # CPU monitoring
│   │   ├── memory_monitor.sh # Memory monitoring
│   │   ├── disk_monitor.sh   # Disk monitoring
│   │   ├── service_monitor.sh # Service monitoring
│   │   ├── log_monitor.sh    # Log monitoring
│   │   └── network_monitor.sh # Network monitoring
│   ├── config/               # Configuration files
│   │   ├── thresholds.conf   # Alert thresholds
│   │   ├── services.conf     # Critical services
│   │   └── logs.conf         # Log monitoring configuration
│   ├── scripts/              # Orchestration scripts
│   │   ├── health_check.sh   # Main orchestrator
│   │   └── health_check_complete.sh # Complete health check
│   ├── data/                 # Metrics and data storage
│   │   ├── metrics/          # Time-series metrics
│   │   ├── alerts/           # Alert history
│   │   └── baseline/         # Baseline metrics
│   └── logs/                 # System logs
├── repair/                   # Repair system implementation
│   ├── modules/              # 5 repair modules
│   │   ├── diagnostic_tools.sh      # Problem analysis
│   │   ├── safety_checks.sh         # Pre/post validation
│   │   ├── restart_procedures.sh    # Service restart
│   │   ├── cleanup_operations.sh    # Resource cleanup
│   │   └── rollback_plans.sh        # System restoration
│   ├── config/               # Configuration files
│   │   ├── safety_limits.conf       # Safety boundaries
│   │   ├── repair_rules.conf        # Repair logic
│   │   └── rollback_config.conf     # Rollback configuration
│   ├── scripts/              # Orchestration scripts
│   │   └── repair_orchestrator.sh   # Main orchestrator
│   ├── data/                 # Repair logs and state
│   │   ├── diagnostics/      # Diagnostic reports
│   │   ├── repair_logs/      # Repair execution logs
│   │   └── rollback_states/  # System snapshots
│   └── logs/                 # System logs
├── routing/                  # @mention routing system
│   ├── config/               # Routing configuration
│   │   └── routing_rules.json # Alert→Repair mapping
│   ├── scripts/              # Routing scripts
│   │   └── watch_repair_requests.sh # Directory watcher
│   └── logs/                 # Routing logs
├── documentation/            # Technical documentation
├── showcase/                 # GitHub showcase materials
└── progress.md              # Real-time progress tracking
```

## API Documentation

### Alert API Schema

#### Alert Object
```json
{
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "alert_type": "CPU",
  "severity": "CRITICAL",
  "module": "cpu_monitor",
  "metric": "load_average",
  "value": 9.85,
  "threshold": 8.0,
  "timestamp": "2026-04-17T16:45:23Z",
  "hostname": "server-01",
  "context": {
    "session_id": "monitor_2026-04-17",
    "progress_ref": "progress.md#task-2.1",
    "baseline": "cpu_baseline_2026-04-17.json",
    "previous_alerts": ["cpu_warning_2026-04-17_16:30:12"]
  },
  "metadata": {
    "generated_by": "cpu_monitor.sh",
    "version": "1.0.0",
    "checksum": "a1b2c3d4e5f6"
  }
}
```

#### Field Specifications

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `alert_id` | string | Yes | Unique identifier for the alert | `cpu_high_2026-04-17_16:45:23` |
| `alert_type` | string | Yes | Type of alert (CPU, MEMORY, DISK, etc.) | `CPU` |
| `severity` | string | Yes | Alert severity level | `CRITICAL` |
| `module` | string | Yes | Source monitoring module | `cpu_monitor` |
| `metric` | string | Yes | Specific metric that triggered alert | `load_average` |
| `value` | number | Yes | Current metric value | `9.85` |
| `threshold` | number | Yes | Threshold that was breached | `8.0` |
| `timestamp` | ISO 8601 | Yes | Alert generation timestamp | `2026-04-17T16:45:23Z` |
| `hostname` | string | No | Hostname where alert originated | `server-01` |
| `context` | object | No | Additional context information | See context schema |
| `metadata` | object | No | Technical metadata | See metadata schema |

#### Context Schema
```json
{
  "session_id": "string",
  "progress_ref": "string",
  "baseline": "string",
  "previous_alerts": ["string"],
  "environment": "production|staging|development",
  "tags": ["string"]
}
```

#### Metadata Schema
```json
{
  "generated_by": "string",
  "version": "string",
  "checksum": "string",
  "execution_time_ms": 123,
  "memory_usage_mb": 45
}
```

### Repair Request API Schema

#### Repair Request Object
```json
{
  "request_id": "repair_2026-04-17_16:46:00_abc123",
  "alert_id": "cpu_high_2026-04-17_16:45:23",
  "module": "cpu_monitor",
  "alert_level": "CRITICAL",
  "alert_message": "CPU load critical: 9.85",
  "alert_details": "load_1m=9.85",
  "priority": "high",
  "requested_actions": ["optimize_processes", "restart_services"],
  "timestamp": "2026-04-17T16:46:00Z",
  "context": {
    "session_id": "monitor_2026-04-17",
    "progress_ref": "progress.md#task-2.1",
    "baseline": "cpu_baseline_2026-04-17.json",
    "system_state": {
      "cpu_usage_percent": 92.5,
      "load_1m": 9.85,
      "process_count": 187
    }
  },
  "routing": {
    "routed_at": "2026-04-17T16:46:05Z",
    "router_version": "1.0.0",
    "routing_id": "route_xyz789"
  }
}
```

#### Field Specifications

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `request_id` | string | Yes | Unique repair request identifier | `repair_2026-04-17_16:46:00_abc123` |
| `alert_id` | string | Yes | Reference to original alert | `cpu_high_2026-04-17_16:45:23` |
| `module` | string | Yes | Source monitoring module | `cpu_monitor` |
| `alert_level` | string | Yes | Alert severity level | `CRITICAL` |
| `alert_message` | string | Yes | Human-readable alert message | `CPU load critical: 9.85` |
| `alert_details` | string | Yes | Technical details of the alert | `load_1m=9.85` |
| `priority` | string | Yes | Repair priority level | `high` |
| `requested_actions` | array | Yes | List of repair actions to perform | `["optimize_processes", "restart_services"]` |
| `timestamp` | ISO 8601 | Yes | Request creation timestamp | `2026-04-17T16:46:00Z` |
| `context` | object | Yes | System context and state | See context schema |
| `routing` | object | No | Routing metadata | See routing schema |

### Repair Response API Schema

#### Repair Response Object
```json
{
  "response_id": "response_2026-04-17_16:48:00_def456",
  "request_id": "repair_2026-04-17_16:46:00_abc123",
  "status": "completed",
  "result": "success",
  "executed_actions": [
    {
      "action": "optimize_processes",
      "status": "completed",
      "start_time": "2026-04-17T16:47:00Z",
      "end_time": "2026-04-17T16:47:30Z",
      "duration_ms": 30000,
      "output": "Process optimization completed successfully",
      "metrics": {
        "cpu_usage_before": 92.5,
        "cpu_usage_after": 65.2,
        "load_1m_before": 9.85,
        "load_1m_after": 4.2
      }
    }
  ],
  "rollback_available": true,
  "rollback_snapshot_id": "snapshot_2026-04-17_16:46:45",
  "timestamp": "2026-04-17T16:48:00Z",
  "diagnostics": {
    "pre_repair_state": {...},
    "post_repair_state": {...},
    "safety_checks_passed": true
  }
}
```

#### Field Specifications

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `response_id` | string | Yes | Unique response identifier | `response_2026-04-17_16:48:00_def456` |
| `request_id` | string | Yes | Reference to repair request | `repair_2026-04-17_16:46:00_abc123` |
| `status` | string | Yes | Overall repair status | `completed` |
| `result` | string | Yes | Repair result | `success` |
| `executed_actions` | array | Yes | Details of executed actions | See action schema |
| `rollback_available` | boolean | Yes | Whether rollback is available | `true` |
| `rollback_snapshot_id` | string | No | ID of system snapshot | `snapshot_2026-04-17_16:46:45` |
| `timestamp` | ISO 8601 | Yes | Response creation timestamp | `2026-04-17T16:48:00Z` |
| `diagnostics` | object | No | Diagnostic information | See diagnostics schema |

#### Action Schema
```json
{
  "action": "string",
  "status": "pending|running|completed|failed|skipped",
  "start_time": "ISO 8601",
  "end_time": "ISO 8601",
  "duration_ms": 12345,
  "output": "string",
  "metrics": {
    "metric_before": 123,
    "metric_after": 456
  },
  "error": {
    "code": "string",
    "message": "string",
    "details": "string"
  }
}
```

## Module Specifications

### Monitoring Modules

#### 1. CPU Monitor (`cpu_monitor.sh`)

**Purpose:** Monitors CPU usage, load averages, and process analysis.

**Metrics Collected:**
- CPU usage percentage
- Load averages (1m, 5m, 15m)
- Process count
- Top CPU-consuming processes

**Alert Thresholds:**
- Warning: CPU usage > 80%
- Critical: CPU usage > 95%
- Warning load (1m): > 4.0
- Critical load (1m): > 8.0

**Output Format:**
```json
{
  "timestamp": "2026-04-17_16:45:23",
  "module": "cpu_monitor",
  "metrics": {
    "cpu_usage_percent": 92.5,
    "load_1m": 9.85,
    "load_5m": 7.2,
    "load_15m": 5.8,
    "process_count": 187
  },
  "top_processes": "92.5,1234,user,chrome;85.2,5678,root,java;...",
  "alert": {
    "level": "CRITICAL",
    "message": "CPU load critical: 9.85",
    "details": "load_1m=9.85"
  }
}
```

#### 2. Memory Monitor (`memory_monitor.sh`)

**Purpose:** Monitors memory usage patterns, swap usage, and memory pressure.

**Metrics Collected:**
- Total memory (MB)
- Used memory (MB)
- Free memory (MB)
- Swap usage (MB)
- Memory pressure score

**Alert Thresholds:**
- Warning: Memory usage > 85%
- Critical: Memory usage > 95%
- Warning swap: > 50%
- Critical swap: > 80%

#### 3. Disk Monitor (`disk_monitor.sh`)

**Purpose:** Monitors disk usage percentages, I/O performance, and SMART status.

**Metrics Collected:**
- Disk usage percentage per mount point
- I/O operations per second
- Read/write throughput
- SMART health status (if available)
- Inode usage

**Alert Thresholds:**
- Warning: Disk usage > 85%
- Critical: Disk usage > 95%
- Warning I/O wait: > 20%
- Critical I/O wait: > 40%

#### 4. Service Monitor (`service_monitor.sh`)

**Purpose:** Monitors critical service uptime and response times.

**Metrics Collected:**
- Service status (running/stopped)
- Uptime duration
- Response time (if applicable)
- Process ID
- Memory usage per service

**Alert Thresholds:**
- Warning: Service restart within 5 minutes
- Critical: Service stopped