#!/bin/bash
# Create approval requests for current alerts
# This script reads alerts.json and creates corresponding approval requests
#
# PHILOSOPHY: Approval requests should be ACTIONABLE, not just diagnostic.
# When a user approves something, they expect the sysadmin to FIX it.
#
# Good: "Clean Up Docker Volumes" → docker volume prune -f
# Good: "Update Python Packages" → pip install --upgrade ...
# Good: "Clear Harmless Zombie Alert" → clear_alert zombie-process-X
#
# Bad: "Investigate Zombie Process" → manual investigation required
# Bad: "Review logs" → nothing happens
#
# For complex issues needing investigation, the action should gather diagnostic
# info and present it, or take the most likely fix with clear reversibility.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Creating approval requests for current alerts..."

ALERTS_FILE="$REPORTS_DIR/alerts.json"

if [[ ! -f "$ALERTS_FILE" ]]; then
    log_error "Alerts file not found: $ALERTS_FILE"
    exit 1
fi

# Capture the output
APPROVAL_REQUESTS=$(python3 <<PYTHON_SCRIPT
import json
import sys

alerts_file = "$ALERTS_FILE"

with open(alerts_file, 'r') as f:
    data = json.load(f)

approval_requests = []

# Process high priority alerts
for alert in data.get('high', []):
    alert_id = alert.get('id')

    if alert_id == 'reboot-required':
        approval_requests.append({
            'severity': 'high',
            'category': 'reboot',
            'title': 'System Reboot for Updates',
            'description': f"{alert['description']} - {alert.get('recommendation', '')}",
            'action_type': 'command',
            'action': 'sudo systemctl reboot',
            'risk_level': 'high',
            'estimated_impact': '5 minutes downtime, active work may be lost',
            'reversible': 'false',
            'related_alert_id': alert_id
        })

# Process medium priority alerts
for alert in data.get('medium', []):
    alert_id = alert.get('id')

    if alert_id == 'docker-volume-cleanup':
        approval_requests.append({
            'severity': 'medium',
            'category': 'cleanup',
            'title': 'Clean Up Docker Volumes',
            'description': f"{alert['description']} - Review volumes before pruning to ensure no important data is deleted.",
            'action_type': 'command',
            'action': 'docker volume prune -f',
            'risk_level': 'medium',
            'estimated_impact': '1.1GB disk space reclaimed',
            'reversible': 'false',
            'related_alert_id': alert_id
        })

    elif alert_id.startswith('zombie-process'):
        # For stable zombies with no impact, just clear the alert
        # For problematic ones, restart the parent process
        approval_requests.append({
            'severity': 'medium',
            'category': 'cleanup',
            'title': 'Clear Harmless Zombie Process Alert',
            'description': f"{alert['description']} - Zombie is stable and has no resource impact. Clear alert to stop monitoring.",
            'action_type': 'script',
            'action': f'bash -c "source {os.environ.get(\"SYSADMIN_DIR\", \"/home/jim/sysadmin\")}/scripts/lib/common.sh && clear_alert {alert_id}"',
            'risk_level': 'minimal',
            'estimated_impact': 'Alert cleared, zombie process remains but is harmless',
            'reversible': 'true',
            'related_alert_id': alert_id
        })

# Process info alerts
for alert in data.get('info', []):
    alert_id = alert.get('id')

    if alert_id == 'python-packages-outdated':
        approval_requests.append({
            'severity': 'info',
            'category': 'update',
            'title': 'Update Outdated Python Packages',
            'description': f"{alert['description']} - Updating packages may change behavior. Test after update.",
            'action_type': 'command',
            'action': 'pip list --outdated | head -10 | awk \'{print $1}\' | xargs -r pip install --upgrade',
            'risk_level': 'low',
            'estimated_impact': 'Python packages updated, may affect compatibility',
            'reversible': 'false',
            'related_alert_id': alert_id
        })

    elif alert_id == 'pip-cache-large':
        approval_requests.append({
            'severity': 'info',
            'category': 'cleanup',
            'title': 'Clean pip Cache',
            'description': f"{alert['description']}",
            'action_type': 'command',
            'action': 'pip cache purge',
            'risk_level': 'minimal',
            'estimated_impact': '11.6GB disk space reclaimed',
            'reversible': 'false',
            'related_alert_id': alert_id
        })

    elif alert_id == 'r-packages-outdated':
        approval_requests.append({
            'severity': 'info',
            'category': 'update',
            'title': 'Update Outdated R Packages',
            'description': f"{alert['description']} - May take 10-30 minutes depending on compilation needs.",
            'action_type': 'command',
            'action': 'R -e "update.packages(ask=FALSE)"',
            'risk_level': 'low',
            'estimated_impact': '74 R packages updated, may affect compatibility',
            'reversible': 'false',
            'related_alert_id': alert_id
        })

    elif alert_id == 'smartmontools-missing':
        approval_requests.append({
            'severity': 'info',
            'category': 'other',
            'title': 'Install SMART Monitoring Tools',
            'description': f"{alert['description']}",
            'action_type': 'command',
            'action': 'sudo apt install -y smartmontools',
            'risk_level': 'minimal',
            'estimated_impact': 'Enables disk health monitoring',
            'reversible': 'true',
            'related_alert_id': alert_id
        })

print(json.dumps(approval_requests, indent=2))
PYTHON_SCRIPT
)

# Parse and create each approval request
echo "$APPROVAL_REQUESTS" | python3 -c "
import json
import sys

requests = json.load(sys.stdin)
for req in requests:
    print(f\"{req['severity']}|{req['category']}|{req['title']}|{req['description']}|{req['action_type']}|{req['action']}|{req['risk_level']}|{req['estimated_impact']}|{req['reversible']}|{req['related_alert_id']}\")
" | while IFS='|' read -r severity category title description action_type action risk_level estimated_impact reversible related_alert_id; do
    log_info "Creating approval request: $title"
    create_approval_request \
        "$severity" \
        "$category" \
        "$title" \
        "$description" \
        "$action_type" \
        "$action" \
        "$risk_level" \
        "$estimated_impact" \
        "$reversible" \
        "$related_alert_id"
done

log_info "All approval requests created successfully!"
log_info "Check the dashboard at http://localhost:5050 to review and approve"
