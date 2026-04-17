# HomeGuardian Developer Guide

## Overview
This guide provides comprehensive instructions for developers working with the HomeGuardian self-healing home server system. It covers setup, testing, debugging, optimization, and security considerations.

## Table of Contents
1. [Development Environment Setup](#development-environment-setup)
2. [Project Structure](#project-structure)
3. [Building from Source](#building-from-source)
4. [Testing Framework](#testing-framework)
5. [Debugging Guide](#debugging-guide)
6. [Performance Tuning](#performance-tuning)
7. [Security Considerations](#security-considerations)
8. [Contributing Guidelines](#contributing-guidelines)
9. [Release Process](#release-process)

## Development Environment Setup

### Prerequisites

#### System Requirements
- **Operating System:** macOS 12+, Ubuntu 20.04+, or compatible Linux distribution
- **CPU:** 2+ cores recommended
- **Memory:** 4GB RAM minimum, 8GB recommended
- **Disk Space:** 2GB free space
- **Shell:** Bash 4.0+ or Zsh

#### Required Software
1. **OpenClaw:** Multi-agent execution platform
   ```bash
   npm install -g openclaw
   ```

2. **Python 3.8+:** For routing system
   ```bash
   # macOS
   brew install python@3.9
   
   # Ubuntu
   sudo apt update
   sudo apt install python3 python3-pip
   ```

3. **jq:** JSON processor for shell scripts
   ```bash
   # macOS
   brew install jq
   
   # Ubuntu
   sudo apt install jq
   ```

4. **Git:** Version control
   ```bash
   # macOS
   brew install git
   
   # Ubuntu
   sudo apt install git
   ```

### Initial Setup

#### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/homeguardian.git
cd homeguardian
```

#### 2. Set Up Python Virtual Environment
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

#### 3. Configure Environment Variables
Create `.env` file in project root:
```bash
# HomeGuardian Configuration
HOMEGUARDIAN_ENV=development
HOMEGUARDIAN_LOG_LEVEL=INFO
HOMEGUARDIAN_DATA_DIR=/var/lib/homeguardian
HOMEGUARDIAN_LOG_DIR=/var/log/homeguardian

# Agent Configuration
AGENT_MONITOR_ENABLED=true
AGENT_FIXER_ENABLED=true
AGENT_ORCHESTRATOR_ENABLED=true

# Safety Settings
SAFETY_MAX_CPU_USAGE=95
SAFETY_MAX_MEMORY_USAGE=90
SAFETY_REQUIRE_ROLLBACK=true
```

#### 4. Initialize Data Directories
```bash
# Create necessary directories
mkdir -p data/{metrics,alerts,baseline,diagnostics,repair_logs}
mkdir -p logs/{monitoring,repair,routing}
mkdir -p config/{monitoring,repair,routing}

# Set appropriate permissions
chmod 755 data logs config
chmod 644 config/*.conf
```

#### 5. Verify Installation
```bash
# Run health check
./monitoring/scripts/health_check.sh test

# Test repair system
./repair/scripts/repair_orchestrator.sh test

# Verify routing system
python3 routing/router.py --test
```

### IDE Configuration

#### Visual Studio Code
Create `.vscode/settings.json`:
```json
{
  "editor.formatOnSave": true,
  "editor.tabSize": 2,
  "files.associations": {
    "*.sh": "shellscript",
    "*.conf": "properties",
    "*.json": "json"
  },
  "shellcheck.enable": true,
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black",
  "python.formatting.blackArgs": ["--line-length", "100"]
}
```

#### Recommended Extensions
- **ShellCheck:** Shell script linting
- **Python:** Python language support
- **JSON Tools:** JSON formatting and validation
- **GitLens:** Git integration
- **Docker:** Docker container support

## Project Structure

### Core Components

```
homeguardian/
├── agents/                    # Agent definitions
│   ├── monitor/              # @monitor agent
│   │   ├── SOUL.md           # Agent personality
│   │   ├── IDENTITY.md       # Agent identity
│   │   ├── AGENTS.md         # Agent capabilities
│   │   └── HEARTBEAT.md      # Periodic checks
│   ├── fixer/                # @fixer agent
│   └── orchestrator/         # @orchestrator agent
├── monitoring/               # Monitoring system
│   ├── modules/              # Monitoring modules
│   ├── config/               # Configuration
│   ├── scripts/              # Orchestration
│   ├── data/                 # Metrics storage
│   └── logs/                 # System logs
├── repair/                   # Repair system
│   ├── modules/              # Repair modules
│   ├── config/               # Configuration
│   ├── scripts/              # Orchestration
│   ├── data/                 # Repair data
│   └── logs/                 # System logs
├── routing/                  # Routing system
│   ├── config/               # Routing configuration
│   ├── scripts/              # Routing scripts
│   └── logs/                 # Routing logs
├── tests/                    # Test suite
│   ├── unit/                 # Unit tests
│   ├── integration/          # Integration tests
│   └── e2e/                  # End-to-end tests
├── docs/                     # Documentation
├── scripts/                  # Build and utility scripts
└── tools/                    # Development tools
```

### Key Files

| File | Purpose | Location |
|------|---------|----------|
| `progress.md` | Real-time progress tracking | Project root |
| `SESSION-CONTEXT.md` | Session context preservation | Project root |
| `health_check.sh` | Main monitoring orchestrator | `monitoring/scripts/` |
| `repair_orchestrator.sh` | Main repair orchestrator | `repair/scripts/` |
| `router.py` | Routing logic | `routing/` |
| `thresholds.conf` | Alert thresholds | `monitoring/config/` |
| `safety_limits.conf` | Safety boundaries | `repair/config/` |
| `routing_rules.json` | Alert→Repair mapping | `routing/config/` |

## Building from Source

### Build Process

#### 1. Clone and Prepare
```bash
git clone https://github.com/yourusername/homeguardian.git
cd homeguardian
git checkout develop  # or specific branch
```

#### 2. Install Dependencies
```bash
# Install system dependencies
./scripts/install-dependencies.sh

# Install Python dependencies
pip install -r requirements.txt

# Install development dependencies
pip install -r requirements-dev.txt
```

#### 3. Build Documentation
```bash
# Generate API documentation
./scripts/generate-docs.sh

# Build man pages
./scripts/build-man-pages.sh
```

#### 4. Run Build Verification
```bash
# Run all verification steps
./scripts/verify-build.sh

# Check code quality
./scripts/check-quality.sh
```

### Build Scripts

#### `scripts/install-dependencies.sh`
```bash
#!/bin/bash
# Install system dependencies for HomeGuardian

set -e

echo "Installing HomeGuardian dependencies..."

# Check OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    brew update
    brew install jq python@3.9 git curl wget
elif [[ -f /etc/debian_version ]]; then
    # Debian/Ubuntu
    sudo apt update
    sudo apt install -y jq python3 python3-pip git curl wget
elif [[ -f /etc/redhat-release ]]; then
    # RHEL/CentOS
    sudo yum install -y jq python3 python3-pip git curl wget
else
    echo "Unsupported OS. Please install dependencies manually."
    exit 1
fi

echo "Dependencies installed successfully."
```

#### `scripts/verify-build.sh`
```bash
#!/bin/bash
# Verify HomeGuardian build

set -e

echo "Verifying HomeGuardian build..."

# Check required files exist
required_files=(
    "monitoring/scripts/health_check.sh"
    "repair/scripts/repair_orchestrator.sh"
    "routing/router.py"
    "progress.md"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: Required file $file not found"
        exit 1
    fi
done

# Check file permissions
executable_files=(
    "monitoring/scripts/health_check.sh"
    "repair/scripts/repair_orchestrator.sh"
    "monitoring/modules/*.sh"
    "repair/modules/*.sh"
)

for file in ${executable_files[@]}; do
    if [ -f "$file" ] && [ ! -x "$file" ]; then
        chmod +x "$file"
        echo "Fixed permissions for $file"
    fi
done

# Run syntax checks
echo "Running syntax checks..."
bash -n monitoring/scripts/health_check.sh
bash -n repair/scripts/repair_orchestrator.sh
python3 -m py_compile routing/router.py

# Run quick tests
echo "Running quick tests..."
./monitoring/scripts/health_check.sh test
./repair/scripts/repair_orchestrator.sh test

echo "Build verification completed successfully."
```

## Testing Framework

### Test Structure

```
tests/
├── unit/                    # Unit tests
│   ├── monitoring/         # Monitoring module tests
│   ├── repair/            # Repair module tests
│   └── routing/           # Routing system tests
├── integration/            # Integration tests
│   ├── monitor_fixer/     # Monitor→Fixer integration
│   ├── routing_integration/ # Routing integration
│   └── end_to_end/        # End-to-end workflows
├── e2e/                    # End-to-end tests
│   ├── scenarios/         # Test scenarios
│   └── performance/       # Performance tests
└── fixtures/              # Test data and fixtures
```

### Running Tests

#### Unit Tests
```bash
# Run all unit tests
./tests/run-unit-tests.sh

# Run specific test suite
./tests/unit/monitoring/test_cpu_monitor.sh
./tests/unit/repair/test_diagnostic_tools.sh
```

#### Integration Tests
```bash
# Run integration tests
./tests/run-integration-tests.sh

# Test specific integration
./tests/integration/monitor_fixer/test_alert_routing.sh
```

#### End-to-End Tests
```bash
# Run complete end-to-end tests
./tests/run-e2e-tests.sh

# Run with specific scenario
./tests/e2e/scenarios/test_cpu_overload_recovery.sh
```

### Writing Tests

#### Example Unit Test
```bash
#!/bin/bash
# tests/unit/monitoring/test_cpu_monitor.sh

set -e

source "$(dirname "$0")/../../monitoring/modules/common_functions.sh"

test_cpu_usage_parsing() {
    echo "Testing CPU usage parsing..."
    
    # Mock top output for macOS
    local mock_output="CPU usage: 45.2% user, 12.3% sys, 42.5% idle"
    local expected=45.2
    
    local result=$(echo "$mock_output" | extract_cpu_usage)
    
    if [ "$(echo "$result == $expected" | bc)" -eq 1 ]; then
        echo "✓ CPU usage parsing test passed"
        return 0
    else
        echo "✗ CPU usage parsing test failed: got $result, expected $expected"
        return 1
    fi
}

test_load_average_parsing() {
    echo "Testing load average parsing..."
    
    # Mock sysctl output
    local mock_output="vm.loadavg: { 2.34 1.89 1.45 }"
    local expected_1m=2.34
    local expected_5m=1.89
    local expected_15m=1.45
    
    local result=$(echo "$mock_output" | extract_load_averages)
    local load_1m=$(echo "$result" | awk '{print $1}')
    local load_5m=$(echo "$result" | awk '{print $2}')
    local load_15m=$(echo "$result" | awk '{print $3}')
    
    if [ "$(echo "$load_1m == $expected_1m" | bc)" -eq 1 ] && \
       [ "$(echo "$load_5m == $expected_5m" | bc)" -eq 1 ] && \
       [ "$(echo "$load_15m == $expected_15m" | bc)" -eq 1 ]; then
        echo "✓ Load average parsing test passed"
        return 0
    else
        echo "✗ Load average parsing test failed"
        return 1
    fi
}

# Run tests
test_cpu_usage_parsing
test_load_average_parsing

echo "All CPU monitor unit tests passed"
```

#### Example Python Test
```python
# tests/unit/routing/test_router.py

import unittest
import json
import tempfile
from pathlib import Path
from routing.router import load_routing_rules, determine_repair_actions

class TestRouter(unittest.TestCase):
    
    def setUp(self):
        # Create temporary config directory
        self.temp_dir = tempfile.mkdtemp()
        self.config_dir = Path(self.temp_dir) / "config"
        self.config_dir.mkdir()
        
    def test_load_default_routing_rules(self):
        """Test loading default routing rules when no config exists."""
        rules = load_routing_rules(str(self.config_dir))
        
        # Check that default rules are loaded
        self.assertIn("cpu_monitor", rules)
        self.assertIn("memory_monitor", rules)
        self.assertIn("CRITICAL", rules["cpu_monitor"])
        self.assertIn("WARNING", rules["cpu_monitor"])
        
    def test_determine_repair_actions(self):
        """Test determining repair actions based on module and alert level."""
        rules = {
            "cpu_monitor": {
                "CRITICAL": ["optimize_processes", "restart_services"],
                "WARNING": ["optimize_processes"]
            }
        }
        
        # Test CRITICAL alert
        actions = determine_repair_actions("cpu_monitor", "CRITICAL", rules)
        self.assertEqual(actions, ["optimize_processes", "restart_services"])
        
        # Test WARNING alert
        actions = determine_repair_actions("cpu_monitor", "WARNING", rules)
        self.assertEqual(actions, ["optimize_processes"])
        
        # Test unknown module (should return default)
        actions = determine_repair_actions("unknown_module", "CRITICAL", rules)
        self.assertEqual(actions, ["diagnose_issue", "manual_intervention_needed"])
    
    def tearDown(self):
        # Clean up temporary directory
        import shutil
        shutil.rmtree(self.temp_dir)

if __name__ == "__main__":
    unittest.main()
```

### Test Automation

#### Continuous Integration
Create `.github/workflows/tests.yml`:
```yaml
name: Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        python-version: [3.8, 3.9, "3.10"]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install -r requirements-dev.txt
    
    - name: Run unit tests
      run: |
        ./tests/run-unit-tests.sh
    
    - name: Run integration tests
      run: |
        ./tests/run-integration-tests.sh
    
    - name: Run Python tests
      run: |
        python -m pytest tests/unit/routing/ -v
    
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results-${{ matrix.python-version }}
        path: |
          test-reports/
          coverage.xml
```

## Debugging Guide

### Common Issues and Solutions

#### 1. Monitoring System Not Starting

**Symptoms:**
- `health_check.sh` returns error
- No metrics being collected
- Alert system not working

**Debugging Steps:**
```bash
# Check script permissions
ls -la monitoring/scripts/health_check.sh

# Run with verbose output
bash -x monitoring/scripts/health_check.sh single

# Check configuration files
cat monitoring/config/thresholds.conf

# Check for syntax errors
bash -n monitoring/scripts/health_check.sh
bash -n monitoring/modules/*.sh

# Check system dependencies
which jq
which python3
```

**Common Solutions:**
- Fix file permissions: `chmod +x monitoring/scripts/health_check.sh`
- Install missing dependencies: `brew install jq` or `apt install jq`
- Fix configuration syntax errors

#### 2. Repair System Not Responding

**Symptoms:**
- Repair requests not being processed
- No repair actions executed
- Error messages in repair logs