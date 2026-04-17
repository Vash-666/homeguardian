#!/bin/bash

# HomeGuardian Health Check - Main Entry Point
# Simplified version that calls the complete orchestrator

SCRIPT_DIR="$(dirname "$0")"
ORCHESTRATOR_SCRIPT="$SCRIPT_DIR/scripts/health_check_complete.sh"

if [ ! -f "$ORCHESTRATOR_SCRIPT" ]; then
    echo "ERROR: Orchestrator script not found at $ORCHESTRATOR_SCRIPT"
    echo "Please check the monitoring installation."
    exit 1
fi

# Make sure it's executable
chmod +x "$ORCHESTRATOR_SCRIPT" 2>/dev/null || true

# Pass all arguments to the orchestrator
exec "$ORCHESTRATOR_SCRIPT" "$@"