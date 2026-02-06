#!/bin/bash
# Common library functions for sysadmin assistant
# Source this file in all scripts: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# Configuration
SYSADMIN_DIR="${SYSADMIN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
LOG_DIR="/var/log/sysadmin"
HOSTNAME=$(hostname)
REPORTS_DIR="$SYSADMIN_DIR/reports/$HOSTNAME"
CONFIG_DIR="$SYSADMIN_DIR/config"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure log directory exists
sudo mkdir -p "$LOG_DIR"
sudo chmod 755 "$LOG_DIR"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | sudo tee -a "$LOG_DIR/sysadmin.log" >/dev/null

    case "$level" in
        ERROR|CRITICAL)
            echo -e "${RED}[$level]${NC} $message" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}[$level]${NC} $message" >&2
            ;;
        INFO)
            echo -e "${GREEN}[$level]${NC} $message"
            ;;
        DEBUG)
            if [[ "${VERBOSE:-0}" == "1" ]]; then
                echo -e "${BLUE}[$level]${NC} $message"
            fi
            ;;
    esac
}

log_info() { log INFO "$@"; }
log_warning() { log WARNING "$@"; }
log_error() { log ERROR "$@"; }
log_critical() { log CRITICAL "$@"; }
log_debug() { log DEBUG "$@"; }

# Check if running as root or with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo privileges"
        exit 1
    fi
}

# Check disk space usage
# Returns: percentage used (without % sign)
check_disk_space() {
    local mount_point="${1:-/}"
    df -h "$mount_point" | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Check if a systemd service is active
# Returns: 0 if active, 1 if not
check_service_status() {
    local service_name="$1"
    systemctl is-active --quiet "$service_name"
}

# Check HTTP endpoint health
# Args: url, timeout (default 5)
# Returns: 0 if healthy, 1 if not
check_http_endpoint() {
    local url="$1"
    local timeout="${2:-5}"

    if curl -f -s -m "$timeout" "$url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get system memory usage percentage
get_memory_usage() {
    free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}'
}

# Get system load average (1 min)
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' '
}

# Check if reboot is required
is_reboot_required() {
    [[ -f /var/run/reboot-required ]]
}

# Get count of available updates
get_update_count() {
    apt list --upgradable 2>/dev/null | grep upgradable | grep -v "Listing" | wc -l
}

# Check if firewall (ufw) is enabled
is_firewall_enabled() {
    sudo ufw status | grep -q "Status: active"
}

# Get Docker disk usage (images)
get_docker_image_usage() {
    if command -v docker &>/dev/null; then
        docker system df 2>/dev/null | awk '/Images/ {print $4}' || echo "0GB"
    else
        echo "0GB"
    fi
}

# Check if a process is running by name
is_process_running() {
    local process_name="$1"
    pgrep -f "$process_name" >/dev/null 2>&1
}

# Send alert (currently just logs, can be extended for email/webhook)
send_alert() {
    local severity="$1"
    local title="$2"
    local description="$3"

    log_critical "ALERT [$severity]: $title - $description"

    # Future: Add email/webhook notification here
    # Example: echo "$description" | mail -s "[$severity] $title" admin@example.com
}

# Update alerts JSON file
update_alerts() {
    local severity="$1"
    local alert_id="$2"
    local title="$3"
    local description="$4"
    local status="${5:-open}"

    local alerts_file="$REPORTS_DIR/alerts.json"

    # Create temporary Python script to update JSON
    python3 <<EOF
import json
import os
from datetime import datetime, UTC

alerts_file = "$alerts_file"
severity = "$severity"
alert_id = "$alert_id"
title = "$title"
description = "$description"
status = "$status"

# Load existing alerts
if os.path.exists(alerts_file):
    with open(alerts_file, 'r') as f:
        data = json.load(f)
else:
    data = {"generated": "", "hostname": "$HOSTNAME", "critical": [], "high": [], "medium": [], "info": []}

# Update timestamp
data["generated"] = datetime.now(UTC).isoformat()

# Find and update or add alert
# Initialize alerts structure if needed
if "alerts" not in data:
    data["alerts"] = []

# Find and update or add alert in main alerts array
found = False
for alert in data.get("alerts", []):
    if isinstance(alert, dict) and alert.get("id") == alert_id:
        alert["title"] = title
        alert["description"] = description
        alert["status"] = status
        alert["updated"] = datetime.now(UTC).strftime("%Y-%m-%d")
        found = True
        break

if not found:
    data["alerts"].append({
        "id": alert_id,
        "severity": severity,
        "title": title,
        "description": description,
        "detected": datetime.now(UTC).strftime("%Y-%m-%d"),
        "status": status
    })

# Also update severity-specific list for backward compatibility
severity_list = data.get(severity, [])
# Filter out old string entries and rebuild with just titles
if severity_list and isinstance(severity_list[0], str):
    # Old format - clean it out
    data[severity] = [title]
else:
    # Check if title already in list
    if title not in severity_list:
        severity_list.append(title)
        data[severity] = severity_list

# Write back
with open(alerts_file, 'w') as f:
    json.dump(data, f, indent=2)
EOF
}

# Remove alert from JSON
clear_alert() {
    local alert_id="$1"
    local alerts_file="$REPORTS_DIR/alerts.json"

    python3 <<EOF
import json
import os
from datetime import datetime, UTC

alerts_file = "$alerts_file"
alert_id = "$alert_id"

if os.path.exists(alerts_file):
    with open(alerts_file, 'r') as f:
        data = json.load(f)

    data["generated"] = datetime.now(UTC).isoformat()

    # Remove from main alerts array
    if "alerts" in data:
        data["alerts"] = [a for a in data["alerts"] if isinstance(a, dict) and a.get("id") != alert_id]

    # Remove from severity-specific lists (handle both string and dict formats)
    for severity in ["critical", "high", "medium", "info"]:
        severity_list = data.get(severity, [])
        if severity_list:
            # Remove if it's a dict with matching id, or skip if it's a string
            data[severity] = [a for a in severity_list if not (isinstance(a, dict) and a.get("id") == alert_id)]

    with open(alerts_file, 'w') as f:
        json.dump(data, f, indent=2)
EOF
}

# Get list of failed systemd services (excluding disabled services)
get_failed_services() {
    local all_failed=$(systemctl list-units --type=service --state=failed --no-pager --no-legend | awk '{print $2}')

    # Filter out disabled services
    for service in $all_failed; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            echo "$service"
        fi
    done
}

# Get zombie processes
get_zombie_processes() {
    ps aux | awk '$8 ~ /Z/ {print $2,$11}'
}

# Check log file size
# Args: log_file_path
# Returns: size in MB
get_log_size_mb() {
    local log_file="$1"
    if [[ -f "$log_file" ]]; then
        du -m "$log_file" | awk '{print $1}'
    else
        echo "0"
    fi
}

# Check if a Docker container is running
is_docker_container_running() {
    local container_name="$1"
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container_name}$"
}

# Get container status
get_docker_container_status() {
    local container_name="$1"
    docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found"
}

# Restart a systemd service safely
restart_service_safe() {
    local service_name="$1"
    local max_attempts="${2:-3}"

    for attempt in $(seq 1 "$max_attempts"); do
        log_info "Attempting to restart $service_name (attempt $attempt/$max_attempts)"

        if systemctl restart "$service_name"; then
            sleep 2
            if check_service_status "$service_name"; then
                log_info "Successfully restarted $service_name"
                return 0
            fi
        fi

        sleep 5
    done

    log_error "Failed to restart $service_name after $max_attempts attempts"
    return 1
}

# Get failed login count in last N hours
get_failed_login_count() {
    local hours="${1:-1}"
    local since=$(date -d "$hours hours ago" '+%Y-%m-%d %H:%M:%S')
    journalctl -u ssh -u sshd --since "$since" 2>/dev/null | grep -c "Failed password" || echo "0"
}

# Get security update count
get_security_update_count() {
    apt list --upgradable 2>/dev/null | grep -i security | wc -l
}

# =============================================================================
# Approval Workflow Functions
# =============================================================================

# Create a pending approval request
# Args: severity, category, title, description, action_type, action, risk_level,
#       estimated_impact, reversible, related_alert_id (optional)
create_approval_request() {
    local severity="$1"
    local category="$2"
    local title="$3"
    local description="$4"
    local action_type="$5"
    local action="$6"
    local risk_level="$7"
    local estimated_impact="$8"
    local reversible="$9"
    local related_alert_id="${10:-}"

    local approvals_file="$REPORTS_DIR/pending-approvals.json"
    local approval_id="${category}-$(date +%Y-%m-%d-%H%M%S)"

    log_info "Creating approval request: $approval_id - $title"

    # Create Python script to add approval request
    python3 <<EOF
import json
import os
from datetime import datetime, UTC

approvals_file = "$approvals_file"

# Load existing approvals or create new
if os.path.exists(approvals_file):
    with open(approvals_file, 'r') as f:
        data = json.load(f)
else:
    data = {"items": []}

# Add new approval request
new_approval = {
    "id": "$approval_id",
    "created": datetime.now(UTC).isoformat(),
    "severity": "$severity",
    "category": "$category",
    "title": "$title",
    "description": "$description",
    "action_type": "$action_type",
    "action": "$action",
    "risk_level": "$risk_level",
    "estimated_impact": "$estimated_impact",
    "reversible": $(python3 -c "print('True' if '$reversible'.lower() in ['true', 'yes', '1'] else 'False')"),
    "related_alert_id": "$related_alert_id" if "$related_alert_id" else None,
    "status": "pending",
    "approved_at": None,
    "approved_by": None,
    "user_comment": None,
    "execution_started": None,
    "execution_completed": None,
    "execution_output": None,
    "execution_error": None
}

data["items"].append(new_approval)

# Write back
with open(approvals_file, 'w') as f:
    json.dump(data, f, indent=2)

print(f"Created approval request: $approval_id")
EOF
}

# Get pending approvals (returns JSON)
get_pending_approvals() {
    local approvals_file="$REPORTS_DIR/pending-approvals.json"

    if [[ -f "$approvals_file" ]]; then
        python3 <<EOF
import json

approvals_file = "$approvals_file"

with open(approvals_file, 'r') as f:
    data = json.load(f)

# Filter for pending items only
pending = [item for item in data["items"] if item["status"] == "pending"]

print(json.dumps({"items": pending}, indent=2))
EOF
    else
        echo '{"items": []}'
    fi
}

# Get approved actions that haven't been executed yet
get_approved_actions() {
    local approvals_file="$REPORTS_DIR/pending-approvals.json"

    if [[ -f "$approvals_file" ]]; then
        python3 <<EOF
import json

approvals_file = "$approvals_file"

with open(approvals_file, 'r') as f:
    data = json.load(f)

# Filter for approved but not yet executed
approved = [item for item in data["items"] if item["status"] == "approved"]

print(json.dumps({"items": approved}, indent=2))
EOF
    else
        echo '{"items": []}'
    fi
}

# Update approval status
# Args: approval_id, new_status, user_comment (optional), execution_output (optional), execution_error (optional)
update_approval_status() {
    local approval_id="$1"
    local new_status="$2"
    local user_comment="${3:-}"
    local execution_output="${4:-}"
    local execution_error="${5:-}"

    local approvals_file="$REPORTS_DIR/pending-approvals.json"

    log_info "Updating approval $approval_id status to: $new_status"

    python3 <<EOF
import json
import os
from datetime import datetime, UTC

approvals_file = "$approvals_file"
approval_id = "$approval_id"
new_status = "$new_status"
user_comment = "$user_comment"
execution_output = """$execution_output"""
execution_error = """$execution_error"""

if not os.path.exists(approvals_file):
    print(f"Approvals file not found: {approvals_file}")
    exit(1)

with open(approvals_file, 'r') as f:
    data = json.load(f)

# Find and update the approval
found = False
for item in data["items"]:
    if item["id"] == approval_id:
        item["status"] = new_status

        if new_status == "approved":
            item["approved_at"] = datetime.now(UTC).isoformat()
            item["approved_by"] = "dashboard"
            if user_comment:
                item["user_comment"] = user_comment

        elif new_status == "denied":
            if user_comment:
                item["user_comment"] = user_comment

        elif new_status == "executing":
            item["execution_started"] = datetime.now(UTC).isoformat()

        elif new_status == "completed":
            item["execution_completed"] = datetime.now(UTC).isoformat()
            if execution_output:
                item["execution_output"] = execution_output

        elif new_status == "failed":
            item["execution_completed"] = datetime.now(UTC).isoformat()
            if execution_error:
                item["execution_error"] = execution_error

        found = True
        break

if not found:
    print(f"Approval {approval_id} not found")
    exit(1)

with open(approvals_file, 'w') as f:
    json.dump(data, f, indent=2)

print(f"Updated approval {approval_id} to status: {new_status}")
EOF
}

# Execute an approved action
# Args: approval_id
execute_approved_action() {
    local approval_id="$1"
    local approvals_file="$REPORTS_DIR/pending-approvals.json"

    log_info "Executing approved action: $approval_id"

    # Get the action details
    local action_details=$(python3 <<EOF
import json
import sys

approvals_file = "$approvals_file"
approval_id = "$approval_id"

with open(approvals_file, 'r') as f:
    data = json.load(f)

for item in data["items"]:
    if item["id"] == approval_id and item["status"] == "approved":
        print(json.dumps(item))
        sys.exit(0)

sys.exit(1)
EOF
)

    if [[ $? -ne 0 ]]; then
        log_error "Approval $approval_id not found or not in approved status"
        return 1
    fi

    # Extract action details
    local action_type=$(echo "$action_details" | python3 -c "import sys, json; print(json.load(sys.stdin)['action_type'])")
    local action=$(echo "$action_details" | python3 -c "import sys, json; print(json.load(sys.stdin)['action'])")
    local user_comment=$(echo "$action_details" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user_comment', ''))")

    log_info "Action type: $action_type"
    log_info "Action: $action"
    if [[ -n "$user_comment" ]]; then
        log_info "User comment: $user_comment"
    fi

    # Update status to executing
    update_approval_status "$approval_id" "executing"

    # Execute the action based on type
    local output
    local exit_code

    case "$action_type" in
        command)
            log_info "Executing command: $action"
            output=$(eval "$action" 2>&1)
            exit_code=$?
            ;;
        script)
            log_info "Executing script: $action"
            if [[ -x "$action" ]]; then
                output=$("$action" 2>&1)
                exit_code=$?
            else
                output="Script not found or not executable: $action"
                exit_code=1
            fi
            ;;
        manual)
            log_warning "Manual action required - cannot execute automatically"
            update_approval_status "$approval_id" "completed" "" "Manual action - requires human intervention"
            return 0
            ;;
        *)
            log_error "Unknown action type: $action_type"
            update_approval_status "$approval_id" "failed" "" "" "Unknown action type"
            return 1
            ;;
    esac

    # Update status based on execution result
    if [[ $exit_code -eq 0 ]]; then
        log_info "Action completed successfully"
        update_approval_status "$approval_id" "completed" "" "$output"

        # Clear related alert if present
        local related_alert=$(echo "$action_details" | python3 -c "import sys, json; print(json.load(sys.stdin).get('related_alert_id', ''))")
        if [[ -n "$related_alert" && "$related_alert" != "None" ]]; then
            clear_alert "$related_alert"
        fi

        return 0
    else
        log_error "Action failed with exit code: $exit_code"
        update_approval_status "$approval_id" "failed" "" "" "$output"
        return 1
    fi
}
