#!/bin/bash
# Launch Claude Code in interactive sysadmin mode
# Loads current system state and context for interactive troubleshooting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSADMIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOSTNAME=$(hostname)
REPORTS_DIR="$SYSADMIN_DIR/reports/$HOSTNAME"
ACTIVITY_LOG="$REPORTS_DIR/activity.log"

# Ensure reports directory exists
mkdir -p "$REPORTS_DIR"

# Change to sysadmin directory
cd "$SYSADMIN_DIR"

# Find Claude Code binary
CLAUDE_BIN=""

# Check saved path first
if [[ -f "$SYSADMIN_DIR/.claude-path" ]]; then
    CLAUDE_BIN=$(cat "$SYSADMIN_DIR/.claude-path")
fi

# Verify it's executable
if [[ ! -x "$CLAUDE_BIN" ]]; then
    # Try to find it in common locations
    if command -v claude &>/dev/null; then
        CLAUDE_BIN=$(command -v claude)
    elif [[ -f "$HOME/.npm-global/bin/claude" ]]; then
        CLAUDE_BIN="$HOME/.npm-global/bin/claude"
    elif [[ -f "$HOME/.local/bin/claude" ]]; then
        CLAUDE_BIN="$HOME/.local/bin/claude"
    elif [[ -f "/usr/local/bin/claude" ]]; then
        CLAUDE_BIN="/usr/local/bin/claude"
    fi
fi

# Fail if Claude Code not found
if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
    echo "ERROR: Claude Code not found!"
    echo "This system requires Claude Code to function."
    echo "Install from: https://claude.ai/code"
    exit 1
fi

# Generate context summary
echo ""
echo "=========================================="
echo "  Claude Sysadmin - Interactive Mode"
echo "=========================================="
echo ""
echo "Hostname: $HOSTNAME"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Display system status
if [[ -f "$REPORTS_DIR/latest.md" ]]; then
    echo "--- Latest System Report ---"
    head -20 "$REPORTS_DIR/latest.md"
    echo ""
fi

# Display active alerts
if [[ -f "$REPORTS_DIR/alerts.json" ]]; then
    echo "--- Active Alerts ---"
    export HOSTNAME
    python3 <<'EOF'
import json
import sys

try:
    import os
    hostname = os.environ.get('HOSTNAME', 'unknown')
    with open(f'reports/{hostname}/alerts.json', 'r') as f:
        data = json.load(f)

    critical = data.get('critical', [])
    high = data.get('high', [])
    medium = data.get('medium', [])

    total = len(critical) + len(high) + len(medium)

    if total == 0:
        print("✓ No active alerts")
    else:
        print(f"Total: {total} alerts (Critical: {len(critical)}, High: {len(high)}, Medium: {len(medium)})")

        for alert in critical:
            print(f"  🔴 CRITICAL: {alert['title']} - {alert['description']}")

        for alert in high:
            print(f"  🟠 HIGH: {alert['title']} - {alert['description']}")

        for alert in medium[:3]:  # Show first 3 medium alerts
            print(f"  🟡 MEDIUM: {alert['title']} - {alert['description']}")

        if len(medium) > 3:
            print(f"  ... and {len(medium) - 3} more medium priority alerts")
except Exception as e:
    print(f"Unable to read alerts: {e}")
EOF
    echo ""
fi

# Display pending approvals
if [[ -f "$REPORTS_DIR/pending-approvals.json" ]]; then
    echo "--- Pending Approvals ---"
    export HOSTNAME
    python3 <<'EOF'
import json
import sys

try:
    import os
    hostname = os.environ.get('HOSTNAME', 'unknown')
    with open(f'reports/{hostname}/pending-approvals.json', 'r') as f:
        data = json.load(f)

    pending = [item for item in data.get('items', []) if item['status'] == 'pending']
    approved = [item for item in data.get('items', []) if item['status'] == 'approved']

    if len(pending) == 0 and len(approved) == 0:
        print("✓ No pending approvals")
    else:
        if len(pending) > 0:
            print(f"{len(pending)} pending approval(s):")
            for item in pending[:3]:
                print(f"  - {item['title']} ({item['severity']}) - {item['description'][:60]}...")

        if len(approved) > 0:
            print(f"{len(approved)} approved action(s) awaiting execution")
except Exception as e:
    print(f"Unable to read approvals: {e}")
EOF
    echo ""
fi

# Display recent activity
if [[ -f "$ACTIVITY_LOG" ]]; then
    echo "--- Recent Activity (last 5 entries) ---"
    grep "^Action:" "$ACTIVITY_LOG" | tail -5 | while read -r line; do
        echo "  $line"
    done
    echo ""
fi

# Display quick system health
echo "--- System Health ---"
echo "Disk usage: $(df -h / | awk 'NR==2 {print $5}') of root filesystem"
echo "Memory: $(free -h | awk 'NR==2 {printf "%.1fG / %.1fG (%.0f%%)", $3/1024, $2/1024, ($3/$2)*100}')"
echo "Load average: $(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')"
echo "Uptime: $(uptime -p)"
echo ""

echo "=========================================="
echo ""
echo "Launching interactive Claude Code session..."
echo ""
echo "Context loaded:"
echo "  ✓ System reports and status"
echo "  ✓ Active alerts and issues"
echo "  ✓ Pending approvals"
echo "  ✓ Recent activity history"
echo ""
echo "Claude will be aware of the current system state."
echo "Press Ctrl+D or type 'exit' to end the session."
echo ""
echo "=========================================="
echo ""

# Log invocation
echo "" >> "$ACTIVITY_LOG"
echo "==================== $(date '+%Y-%m-%d %H:%M:%S') ====================" >> "$ACTIVITY_LOG"
echo "Action: Interactive Session Started" >> "$ACTIVITY_LOG"
echo "Method: Claude Code ($CLAUDE_BIN)" >> "$ACTIVITY_LOG"

# Create a context file that Claude can reference
CONTEXT_FILE="$REPORTS_DIR/interactive-context.md"
cat > "$CONTEXT_FILE" <<CONTEXT_EOF
# Claude Sysadmin Interactive Session - $(date '+%Y-%m-%d %H:%M:%S')

**Hostname:** $HOSTNAME

This file contains the current system context for your interactive session.
CLAUDE.md is automatically loaded and contains your role and capabilities.

---

## Current System Status

$(if [[ -f "$REPORTS_DIR/latest.md" ]]; then cat "$REPORTS_DIR/latest.md"; else echo "No recent report available"; fi)

---

## Active Alerts

$(if [[ -f "$REPORTS_DIR/alerts.json" ]]; then python3 -c "
import json
with open('$REPORTS_DIR/alerts.json', 'r') as f:
    data = json.load(f)
    import json as j
    print(j.dumps(data, indent=2))
"; else echo "No alerts file"; fi)

---

## Pending Approvals

$(if [[ -f "$REPORTS_DIR/pending-approvals.json" ]]; then python3 -c "
import json
with open('$REPORTS_DIR/pending-approvals.json', 'r') as f:
    data = json.load(f)
    pending = [item for item in data.get('items', []) if item['status'] == 'pending']
    approved = [item for item in data.get('items', []) if item['status'] == 'approved']
    if pending or approved:
        print(json.dumps({'pending': pending, 'approved': approved}, indent=2))
    else:
        print('No pending or approved items')
" 2>/dev/null; else echo "No approvals file"; fi)

---

## Recent Activity

$(if [[ -f "$ACTIVITY_LOG" ]]; then tail -30 "$ACTIVITY_LOG"; else echo "No activity log"; fi)

CONTEXT_EOF

echo ""
echo "System context saved to: reports/$HOSTNAME/interactive-context.md"
echo ""

# Launch Claude Code in interactive mode
# It will automatically read CLAUDE.md which contains the sysadmin role
# The context file is available at reports/$HOSTNAME/interactive-context.md
"$CLAUDE_BIN" --dangerously-skip-permissions \
    --model sonnet

# Log completion
echo "Status: Interactive session ended" >> "$ACTIVITY_LOG"
echo "======================================================" >> "$ACTIVITY_LOG"
