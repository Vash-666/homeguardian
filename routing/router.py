#!/usr/bin/env python3
"""
HomeGuardian Repair Request Router
Routes repair requests from @monitor to appropriate @fixer actions
"""

import json
import sys
import os
import uuid
from datetime import datetime
from pathlib import Path

# Configuration
ROUTING_DIR = Path(__file__).parent
CONFIG_DIR = ROUTING_DIR / "config"
LOG_DIR = ROUTING_DIR / "logs"
SESSION_CONTEXT = Path.home() / ".openclaw" / "workspace" / "SESSION-CONTEXT.md"
PROGRESS_MD = Path.home() / ".openclaw" / "workspace" / "homeguardian" / "progress.md"

def load_routing_rules():
    """Load alert to repair action mapping rules."""
    rules_file = CONFIG_DIR / "routing_rules.json"
    
    # Default routing rules if config doesn't exist
    default_rules = {
        "cpu_monitor": {
            "CRITICAL": ["optimize_processes", "restart_services"],
            "WARNING": ["optimize_processes"]
        },
        "memory_monitor": {
            "CRITICAL": ["clear_cache", "restart_services"],
            "WARNING": ["clear_cache"]
        },
        "disk_monitor": {
            "CRITICAL": ["cleanup_temp", "expand_disk"],
            "WARNING": ["cleanup_temp"]
        },
        "service_monitor": {
            "CRITICAL": ["restart_service", "rollback_update"],
            "WARNING": ["restart_service"]
        },
        "log_monitor": {
            "CRITICAL": ["rotate_logs", "cleanup_old"],
            "WARNING": ["rotate_logs"]
        },
        "network_monitor": {
            "CRITICAL": ["restart_network", "reset_connection"],
            "WARNING": ["restart_network"]
        }
    }
    
    if rules_file.exists():
        try:
            with open(rules_file, 'r') as f:
                return json.load(f)
        except json.JSONDecodeError:
            print(f"Warning: Invalid JSON in {rules_file}, using default rules")
    
    # Save default rules
    with open(rules_file, 'w') as f:
        json.dump(default_rules, f, indent=2)
    
    return default_rules

def enrich_context(repair_request):
    """Enrich repair request with system context."""
    enriched = repair_request.copy()
    
    # Add routing metadata
    enriched["routed_at"] = datetime.now().isoformat()
    enriched["router_version"] = "1.0.0"
    enriched["routing_id"] = str(uuid.uuid4())
    
    # Add session context if available
    if SESSION_CONTEXT.exists():
        try:
            with open(SESSION_CONTEXT, 'r') as f:
                # Read first 1000 chars for context summary
                context_summary = f.read(1000)
                enriched["session_context_summary"] = context_summary
        except Exception as e:
            enriched["session_context_error"] = str(e)
    
    # Add project progress context
    if PROGRESS_MD.exists():
        try:
            with open(PROGRESS_MD, 'r') as f:
                # Get last 10 lines for recent progress
                lines = f.readlines()
                enriched["recent_progress"] = "".join(lines[-10:]) if len(lines) >= 10 else "".join(lines)
        except Exception as e:
            enriched["progress_context_error"] = str(e)
    
    return enriched

def determine_repair_actions(module, alert_level, routing_rules):
    """Determine appropriate repair actions based on module and alert level."""
    if module in routing_rules:
        module_rules = routing_rules[module]
        if alert_level in module_rules:
            return module_rules[alert_level]
    
    # Default fallback actions
    return ["diagnose_issue", "manual_intervention_needed"]

def create_fixer_invocation(enriched_request, repair_actions):
    """Create @fixer invocation command with enriched context."""
    invocation = {
        "invocation_id": str(uuid.uuid4()),
        "invoked_at": datetime.now().isoformat(),
        "target_agent": "@fixer",
        "repair_actions": repair_actions,
        "request_context": enriched_request,
        "priority": enriched_request.get("priority", "medium"),
        "expected_timeout": 300,  # 5 minutes default timeout
        "rollback_available": True,
        "safety_checks_required": True
    }
    
    return invocation

def log_routing_decision(request_id, module, alert_level, repair_actions, success=True):
    """Log routing decision for audit trail."""
    log_entry = {
        "timestamp": datetime.now().isoformat(),
        "request_id": request_id,
        "module": module,
        "alert_level": alert_level,
        "repair_actions": repair_actions,
        "success": success,
        "router": "homeguardian_routing_system"
    }
    
    log_file = LOG_DIR / "routing_decisions.jsonl"
    with open(log_file, 'a') as f:
        f.write(json.dumps(log_entry) + '\n')
    
    # Also print to console for immediate feedback
    print(f"Routing decision: {module} {alert_level} → {repair_actions}")

def route_repair_request(request_file):
    """Main routing function."""
    try:
        # Load repair request
        with open(request_file, 'r') as f:
            repair_request = json.load(f)
        
        request_id = repair_request.get("request_id", "unknown")
        module = repair_request.get("module", "unknown")
        alert_level = repair_request.get("alert_level", "WARNING")
        
        print(f"Routing request: {request_id} ({module} - {alert_level})")
        
        # Load routing rules
        routing_rules = load_routing_rules()
        
        # Determine repair actions
        repair_actions = determine_repair_actions(module, alert_level, routing_rules)
        
        # Enrich context
        enriched_request = enrich_context(repair_request)
        
        # Create @fixer invocation
        fixer_invocation = create_fixer_invocation(enriched_request, repair_actions)
        
        # Save invocation for @fixer
        invocation_file = ROUTING_DIR / "invocations" / f"{request_id}_invocation.json"
        invocation_file.parent.mkdir(exist_ok=True)
        
        with open(invocation_file, 'w') as f:
            json.dump(fixer_invocation, f, indent=2)
        
        # Log successful routing
        log_routing_decision(request_id, module, alert_level, repair_actions, success=True)
        
        print(f"Successfully routed to @fixer with actions: {repair_actions}")
        print(f"Invocation saved to: {invocation_file}")
        
        # TODO: Actually invoke @fixer via OpenClaw API
        # For now, we just create the invocation file
        # In production, this would call sessions_spawn or sessions_send
        
        return True
        
    except Exception as e:
        print(f"Error routing request: {e}")
        log_routing_decision(
            repair_request.get("request_id", "unknown"),
            repair_request.get("module", "unknown"),
            repair_request.get("alert_level", "WARNING"),
            [],
            success=False
        )
        return False

def main():
    """Main entry point."""
    if len(sys.argv) != 2:
        print("Usage: router.py <repair_request.json>")
        sys.exit(1)
    
    request_file = Path(sys.argv[1])
    if not request_file.exists():
        print(f"Error: Request file not found: {request_file}")
        sys.exit(1)
    
    success = route_repair_request(request_file)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()