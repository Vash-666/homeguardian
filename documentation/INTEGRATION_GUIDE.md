# HomeGuardian Integration Guide

## Overview
This guide provides comprehensive integration specifications for connecting HomeGuardian components, external systems, and custom modules. It covers communication protocols, API integration, extension points, and interoperability.

## Table of Contents
1. [Component Integration](#component-integration)
2. [External System Integration](#external-system-integration)
3. [API Integration](#api-integration)
4. [Custom Module Development](#custom-module-development)
5. [Plugin System](#plugin-system)
6. [Interoperability Standards](#interoperability-standards)
7. [Migration Guide](#migration-guide)

## Component Integration

### Monitoring → Repair Integration

#### Integration Points

**1. Alert Generation → Repair Request Creation**
```
Monitoring System → Repair System
     ↓                    ↓
Alert Created → Repair Request → @fixer Invocation
```

**Implementation:**
```bash
# monitoring/modules/cpu_monitor.sh - Alert generation
generate_alert() {
    local severity=$1
    local message=$2
    local details=$3
    
    # Create alert JSON
    alert_json=$(cat << EOF
{
  "alert_id": "cpu_$(date +%Y-%m-%d_%H:%M:%S)",
  "alert_type": "CPU",
  "severity": "$severity",
  "module": "cpu_monitor",
  "metric": "load_average",
  "value": $current_value,
  "threshold": $threshold,
  "timestamp": "$(date -Iseconds)",
  "context": {
    "session_id": "$SESSION_ID",
    "progress_ref": "progress.md#task-2.1",
    "baseline": "cpu_baseline_$(date +%Y-%m-%d).json"
  }
}
EOF
    )
    
    # Save alert
    echo "$alert_json" > "$ALERT_DIR/cpu_$(date +%s).json"
    
    # If critical, create repair request
    if [ "$severity" = "CRITICAL" ] || [ "$severity" = "EMERGENCY" ]; then
        create_repair_request "$alert_json"
    fi
}

create_repair_request() {
    local alert_json=$1
    
    # Parse alert
    alert_id=$(echo "$alert_json" | jq -r '.alert_id')
    module=$(echo "$alert_json" | jq -r '.module')
    severity=$(echo "$alert_json" | jq -r '.severity')
    
    # Create repair request
    request_id="repair_$(date +%Y-%m-%d_%H:%M:%S)_$(uuidgen | cut -c1-8)"
    
    request_json=$(cat << EOF
{
  "request_id": "$request_id",
  "alert_id": "$alert_id",
  "module": "$module",
  "alert_level": "$severity",
  "alert_message": "CPU load critical: $current_value",
  "alert_details": "load_1m=$current_value",
  "priority": "high",
  "requested_actions": ["optimize_processes", "restart_services"],
  "timestamp": "$(date -Iseconds)",
  "context": $alert_json
}
EOF
    )
    
    # Save to repair requests directory
    echo "$request_json" > "$REPAIR_REQUEST_DIR/${request_id}.json"
    
    echo "Repair request created: $request_id"
}
```

**2. Repair Request → @fixer Invocation**

**Routing System Integration:**
```python
# routing/router.py - Repair request routing

def route_repair_request(request_file):
    """Route repair request to @fixer."""
    
    # Load repair request
    with open(request_file, 'r') as f:
        repair_request = json.load(f)
    
    # Determine repair actions
    routing_rules = load_routing_rules()
    repair_actions = determine_repair_actions(
        repair_request['module'],
        repair_request['alert_level'],
        routing_rules
    )
    
    # Enrich context
    enriched_request = enrich_context(repair_request)
    
    # Create @fixer invocation
    invocation = create_fixer_invocation(enriched_request, repair_actions)
    
    # Save invocation
    invocation_file = save_invocation(invocation)
    
    # Log routing decision
    log_routing_decision(repair_request, repair_actions)
    
    # Invoke @fixer (OpenClaw API)
    invoke_fixer_agent(invocation_file)
    
    return True
```

#### Data Flow Specifications

**Alert → Repair Request Flow:**
1. **Monitoring Module** detects threshold breach
2. **Alert Generator** creates alert JSON with context
3. **Alert Manager** determines if repair needed
4. **Repair Request Creator** generates repair request
5. **File System** stores request in `monitoring/data/repair_requests/`

**Repair Request → @fixer Flow:**
1. **Routing Watcher** detects new repair request
2. **Request Parser** validates and parses JSON
3. **Action Mapper** determines repair actions
4. **Context Enricher** adds additional context
5. **Invocation Creator** prepares @fixer invocation
6. **Agent Invoker** calls @fixer via OpenClaw API

### Repair → Monitoring Integration

#### Repair Status Updates

**Implementation:**
```bash
# repair/scripts/repair_orchestrator.sh - Status reporting

report_repair_status() {
    local request_id=$1
    local status=$2
    local result=$3
    local details=$4
    
    status_json=$(cat << EOF
{
  "request_id": "$request_id",
  "status": "$status",
  "result": "$result",
  "timestamp": "$(date -Iseconds)",
  "details": "$details",
  "agent": "@fixer",
  "execution_time_ms": $EXECUTION_TIME
}
EOF
    )
    
    # Save status to monitoring system
    echo "$status_json" > "$MONITORING_DATA_DIR/repair_status/${request_id}_status.json"
    
    # Also update repair request with status
    update_repair_request_status "$request_id" "$status" "$result"
}

update_repair_request_status() {
    local request_id=$1
    local status=$2
    local result=$3
    
    request_file="$REPAIR_REQUEST_DIR/${request_id}.json"
    
    if [ -f "$request_file" ]; then
        # Update JSON with status
        jq --arg status "$status" \
           --arg result "$result" \
           --arg timestamp "$(date -Iseconds)" \
           '.status = $status | .result = $result | .updated_at = $timestamp' \
           "$request_file" > "${request_file}.tmp"
        
        mv "${request_file}.tmp" "$request_file"
    fi
}
```

#### Repair Result Notification

**Integration Points:**
1. **Repair Completion → Alert Resolution**
2. **Rollback Execution → System Restoration Notification**
3. **Failed Repair → Escalation Notification**

### Quality Gateway Integration

#### @quality Agent Integration

**Audit Trigger Points:**
1. **Milestone Completion:** After each milestone
2. **Major Changes:** After significant system modifications
3. **Production Readiness:** Before deployment
4. **Periodic Audits:** Scheduled quality checks

**Implementation:**
```python
# quality/audit_trigger.py - Quality audit triggering

def trigger_quality_audit(audit_type, context):
    """Trigger @quality agent audit."""
    
    audit_request = {
        "audit_id": f"audit_{int(time.time())}",
        "audit_type": audit_type,
        "timestamp": datetime.now().isoformat(),
        "context": context,
        "components": {
            "monitoring": get_monitoring_status(),
            "repair": get_repair_status(),
            "routing": get_routing_status(),
            "documentation": get_documentation_status()
        },
        "quality_gates": {
            "vector_similarity": {"threshold": 0.92},
            "context_preservation": {"threshold": 0.85},
            "integration_score": {"threshold": 0.80},
            "production_readiness": {"required": True}
        }
    }
    
    # Save audit request
    audit_file = f"quality/audit_requests/{audit_request['audit_id']}.json"
    with open(audit_file, 'w') as f:
        json.dump(audit_request, f, indent=2)
    
    # Invoke @quality agent
    invoke_quality_agent(audit_file)
    
    return audit_request['audit_id']
```

#### Audit Result Integration

**Result Processing:**
```python
def process_audit_result(audit_result_file):
    """Process @quality audit results."""
    
    with open(audit_result_file, 'r') as f:
        audit_result = json.load(f)
    
    # Update progress.md with audit results
    update_progress_with_audit(audit_result)
    
    # Update SESSION-CONTEXT.md
    update_session_context_with_audit(audit_result)
    
    # Trigger actions based on audit score
    if audit_result['overall_score'] >= 8.5:
        # Passed - continue to next milestone
        print("Quality audit passed. Proceeding to next milestone.")
        trigger_next_milestone()
    elif audit_result['overall_score'] >= 8.0:
        # Warning - needs minor improvements
        print("Quality audit warning. Minor improvements needed.")
        schedule_improvements(audit_result['improvement_areas'])
    else:
        # Failed - needs rework
        print("Quality audit failed. Rework required.")
        trigger_rework(audit_result['failure_reasons'])
    
    return audit_result
```

## External System Integration

### Notification System Integration

#### Email Notifications

**Integration Configuration:**
```bash
# config/notifications.conf
[email]
enabled=true
smtp_server=smtp.gmail.com
smtp_port=587
username=your-email@gmail.com
password=${EMAIL_PASSWORD}
from_address=homeguardian@yourdomain.com
to_addresses=admin@yourdomain.com,backup@yourdomain.com

[alert_levels]
critical=true
emergency=true
warning=false
info=false

[quiet_hours]
enabled=true
start_time=23:00
end_time=08:00
```

**Implementation:**
```python
# integrations/email_notifier.py

class EmailNotifier:
    def __init__(self, config):
        self.config = config
        self.smtp_server = config['email']['smtp_server']
        self.smtp_port = config['email']['smtp_port']
        self.username = config['email']['username']
        self.password = os.getenv(config['email']['password_env'])
        
    def send_alert(self, alert):
        """Send alert via email."""
        
        # Check if notification should be sent
        if not self.should_send_notification(alert):
            return False
        
        # Create email message
        msg = MIMEMultipart()
        msg['From'] = self.config['email']['from_address']
        msg['To'] = ', '.join(self.config['email']['to_addresses'])
        msg['Subject'] = f"[HomeGuardian] {alert['severity']}: {alert['module']}"
        
        # Create HTML body
        html = self.create_alert_html(alert)
        msg.attach(MIMEText(html, 'html'))
        
        # Send email
        try:
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)
            
            log_notification_sent('email', alert)
            return True
            
        except Exception as e:
            log_notification_error('email', alert, str(e))
            return False
    
    def should_send_notification(self, alert):
        """Determine if notification should be sent."""
        
        # Check alert level
        alert_level = alert['severity'].lower()
        if not self.config['alert_levels'].get(alert_level, False):
            return False
        
        # Check quiet hours
        if self.config['quiet_hours']['enabled']:
            current_hour = datetime.now().hour
            start_hour = int(self.config['quiet_hours']['start_time'].split(':')[0])
            end_hour = int(self.config['quiet_hours']['end_time'].split(':')[0])
            
            if start_hour <= current_hour <= end_hour:
                return False
        
        return True
```

#### Slack/Webhook Integration

**Configuration:**
```bash
# config/notifications.conf
[slack]
enabled=true
webhook_url=${SLACK_WEBHOOK_URL}
channel="#server-alerts"
username="HomeGuardian"
icon_emoji=":robot_face:"

[webhook]
enabled=true
url=${CUSTOM_WEBHOOK_URL}
headers={"Content-Type": "application/json", "X-API-Key": "${API_KEY}"}
```

**Implementation:**
```python
# integrations/webhook_notifier.py

class WebhookNotifier:
    def __init__(self, config):
        self.config = config
        
    def send_alert(self, alert):
        """Send alert via webhook."""
        
        # Prepare payload
        payload = {
            "timestamp": datetime.now().isoformat(),
            "system": "HomeGuardian",
            "alert": alert,
            "metadata": {
                "version": "1.0.0",
                "environment": os.getenv('HOMEGUARDIAN_ENV', 'production')
            }
        }
        
        # Send to all configured webhooks
        results = []
        
        # Slack webhook
        if self.config['slack']['enabled']:
            slack_result = self.send_slack_webhook(alert, payload)
            results.append(('slack', slack_result))
        
        # Custom webhook
        if self.config['webhook']['enabled']:
            webhook_result = self.send_custom_webhook(alert, payload)
            results.append(('webhook', webhook_result))
        
        return results
    
    def send_slack_webhook(self, alert, payload):
        """Send to Slack webhook."""
        
        slack_payload = {
            "channel": self.config['slack']['channel'],
            "username": self.config['slack']['username'],
            "icon_emoji": self.config['slack']['icon_emoji'],
            "attachments": [{
                "color": self.get_slack_color(alert['severity']),
                "title": f"{alert['severity']}: {alert['module']}",
                "text": alert['alert_message'],
                "fields": [
                    {"title": "Metric", "value": alert['metric'], "short": True},
                    {"title": "Value", "value": str(alert['value']), "short": True},
                    {"title": "Threshold", "value": str(alert['threshold']), "short": True},
                    {"title": "Host", "value": alert.get('hostname', 'unknown'), "short": True}
                ],
                "ts": datetime.now().timestamp()
            }]
        }
        
        try:
            response = requests.post(
                self.config['slack']['webhook_url'],
                json=slack_payload,
                timeout=10
            )
            response.raise_for_status()
            return True
        except Exception as e:
            log_notification_error('slack', alert, str(e))
            return False
```

### Monitoring System Integration

#### Prometheus Integration

**Metrics Exposition:**
```python
# integrations/prometheus_exporter.py

class PrometheusExporter:
    def __init__(self, port=9091):
        self.port = port
        self.metrics = {}
        
    def start_server(self):
        """Start Prometheus metrics server."""
        
        # Define metrics
        self.define_metrics()
        
        # Start HTTP server
        start_http_server(self.port)
        print(f"Prometheus exporter started on port {self.port}")
        
    def define_metrics(self):
        """Define Prometheus metrics."""
        
        # System metrics
        self.metrics['cpu_usage'] = Gauge(
            'homeguardian_cpu_usage_percent',
            'CPU usage percentage',
            ['hostname', 'module']
        )
        
        self.metrics['memory_usage'] = Gauge(
            'homeguardian_memory_usage_percent',
            'Memory usage percentage',
            ['hostname', 'module']
        )
        
        self.metrics['disk_usage'] = Gauge(
            'homeguardian_disk_usage_percent',
            'Disk usage percentage',
            ['hostname', 'mount_point', 'module']
        )
        
        # Alert metrics
        self.metrics['alerts_total'] = Counter(
            'homeguardian_alerts_total',
            'Total number of alerts',
            ['severity', 'module', 'hostname']
        )
        
        self.metrics['repairs_total'] = Counter(
            'homeguardian_repairs_total',
            'Total number of repairs',
            ['status', 'module', 'hostname']
        )
        
        # Performance metrics
        self.metrics['monitoring_duration'] = Histogram(
            'homeguardian_monitoring_duration_seconds',
            'Monitoring execution duration',
            ['module', 'hostname']
        )
        
        self.metrics['repair_duration'] = Histogram(
            'homeguardian_repair_duration_seconds',
            'Repair execution duration',
            ['module', 'action', 'hostname']
        )
    
    def update_metrics(self, metric_data):
        """Update metrics with new data."""
        
        for metric_name, value in metric_data.items():
            if metric_name in self.metrics:
                # Update metric based on type
                if isinstance(self.metrics[metric_name], Gauge):
                    self.metrics[metric_name].set(value)
                elif isinstance(self.metrics[metric_name], Counter):
                    self.metrics[metric_name].inc(value)
```

**Prometheus Configuration:**
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'homeguardian'
    static_configs:
      - targets: ['localhost:9091']
    scrape_interval: 15s
    metrics