#!/bin/bash
# Installation script for Claude Code Sysadmin Assistant
# Sets up cron jobs, web dashboard, log rotation, and initial configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME=$(hostname)
LOG_DIR="/var/log/sysadmin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "Do not run this script as root. Run as regular user (will use sudo when needed)."
    exit 1
fi

# Check sudo access
if ! sudo -n true 2>/dev/null; then
    log_info "This script requires sudo access. You may be prompted for your password."
    sudo -v
fi

log_info "Installing Claude Code Sysadmin Assistant for hostname: $HOSTNAME"
echo ""

# Create directory structure
log_info "Creating directory structure..."
mkdir -p "$SCRIPT_DIR/scripts/lib"
mkdir -p "$SCRIPT_DIR/scripts/remediation"
mkdir -p "$SCRIPT_DIR/reports/$HOSTNAME/history"
mkdir -p "$SCRIPT_DIR/config"
mkdir -p "$SCRIPT_DIR/claude-admin/prompts"
mkdir -p "$SCRIPT_DIR/dashboard/templates"
mkdir -p "$SCRIPT_DIR/dashboard/static"

# Create log directory
log_info "Creating log directory: $LOG_DIR"
sudo mkdir -p "$LOG_DIR"
sudo chown $USER:$USER "$LOG_DIR"
sudo chmod 755 "$LOG_DIR"

# Set up log rotation
log_info "Configuring log rotation..."
sudo tee /etc/logrotate.d/sysadmin >/dev/null <<EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 $USER $USER
}
EOF

# Install required dependencies
log_info "Checking dependencies..."
MISSING_DEPS=()

for cmd in python3 curl git; do
    if ! command -v $cmd &>/dev/null; then
        MISSING_DEPS+=($cmd)
    fi
done

if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    log_warning "Missing dependencies: ${MISSING_DEPS[*]}"
    log_info "Installing dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-pip python3-venv python3-yaml curl git
fi

# Check for Claude Code - REQUIRED
log_info "Checking for Claude Code..."
CLAUDE_BIN=""

# Check common locations
if command -v claude &>/dev/null; then
    CLAUDE_BIN=$(command -v claude)
elif [[ -f "$HOME/.npm-global/bin/claude" ]]; then
    CLAUDE_BIN="$HOME/.npm-global/bin/claude"
elif [[ -f "$HOME/.local/bin/claude" ]]; then
    CLAUDE_BIN="$HOME/.local/bin/claude"
elif [[ -f "/usr/local/bin/claude" ]]; then
    CLAUDE_BIN="/usr/local/bin/claude"
fi

if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
    echo ""
    log_error "╔════════════════════════════════════════════════════════════╗"
    log_error "║  CLAUDE CODE NOT FOUND - INSTALLATION CANNOT CONTINUE     ║"
    log_error "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log_error "This system requires Claude Code to function."
    log_error "Claude Code IS the autonomous system administrator."
    echo ""
    log_info "To install Claude Code:"
    log_info "  1. Visit: ${BLUE}https://claude.ai/code${NC}"
    log_info "  2. Download and install Claude Code CLI"
    log_info "  3. Verify installation: ${BLUE}claude --version${NC}"
    log_info "  4. Run this installer again: ${BLUE}./install.sh${NC}"
    echo ""
    exit 1
fi

log_info "✓ Claude Code found: $CLAUDE_BIN"

# Verify Claude Code works
if ! "$CLAUDE_BIN" --version &>/dev/null; then
    log_error "Claude Code binary found but not working correctly"
    log_error "Try reinstalling from: https://claude.ai/code"
    exit 1
fi

log_info "✓ Claude Code version: $("$CLAUDE_BIN" --version 2>/dev/null | head -1)"

# Save Claude path for wrapper scripts
echo "$CLAUDE_BIN" > "$SCRIPT_DIR/.claude-path"
chmod 644 "$SCRIPT_DIR/.claude-path"

# Create Python virtual environment
VENV_DIR="$SCRIPT_DIR/venv"
if [[ ! -d "$VENV_DIR" ]]; then
    log_info "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    log_info "✓ Virtual environment created"
else
    log_info "✓ Virtual environment already exists"
fi

# Install Python dependencies in venv
log_info "Installing Python dependencies in virtual environment..."
"$VENV_DIR/bin/pip" install -q --upgrade pip
"$VENV_DIR/bin/pip" install -q -r "$SCRIPT_DIR/dashboard/requirements.txt"
log_info "✓ Python dependencies installed"

# Register machine in config
MACHINES_CONFIG="$SCRIPT_DIR/config/machines.yaml"
if [[ ! -f "$MACHINES_CONFIG" ]]; then
    log_info "Creating machines config..."
    cat > "$MACHINES_CONFIG" <<EOF
# Registered machines managed by the sysadmin assistant
machines: {}
EOF
fi

log_info "Registering machine: $HOSTNAME"
"$VENV_DIR/bin/python" <<EOF
import yaml
import os
from datetime import datetime

config_file = "$MACHINES_CONFIG"

# Load existing config
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        data = yaml.safe_load(f) or {}
else:
    data = {}

if 'machines' not in data:
    data['machines'] = {}

# Get system info
os_version = os.popen('lsb_release -d').read().split(':')[1].strip() if os.path.exists('/usr/bin/lsb_release') else 'Unknown'
kernel = os.popen('uname -r').read().strip()
ram_gb = int(os.popen("free -g | awk 'NR==2 {print \$2}'").read().strip() or '0')

# Register or update machine
if "$HOSTNAME" not in data['machines']:
    data['machines']["$HOSTNAME"] = {
        'hostname': "$HOSTNAME",
        'os': os_version,
        'kernel': kernel,
        'registered': datetime.now().strftime('%Y-%m-%d'),
        'primary_use': 'Development/Analytics',
        'hardware': {
            'ram': f'{ram_gb}GB' if ram_gb > 0 else 'Unknown'
        }
    }
else:
    data['machines']["$HOSTNAME"]['os'] = os_version
    data['machines']["$HOSTNAME"]['kernel'] = kernel
    data['machines']["$HOSTNAME"]['last_updated'] = datetime.now().strftime('%Y-%m-%d')

# Write back
with open(config_file, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)
EOF

# Create monitored apps config if not present
APPS_CONFIG="$SCRIPT_DIR/config/monitored-apps.yaml"
if [[ ! -f "$APPS_CONFIG" ]]; then
    log_info "Creating apps config template..."
    cat > "$APPS_CONFIG" <<EOF
# Production applications to monitor
apps: {}
EOF
fi

# Create initial alerts file
ALERTS_FILE="$SCRIPT_DIR/reports/$HOSTNAME/alerts.json"
if [[ ! -f "$ALERTS_FILE" ]]; then
    log_info "Creating initial alerts file..."
    cat > "$ALERTS_FILE" <<EOF
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$HOSTNAME",
  "critical": [],
  "high": [],
  "medium": [],
  "info": []
}
EOF
fi

# Create initial recommendations file
RECS_FILE="$SCRIPT_DIR/reports/$HOSTNAME/recommendations.json"
if [[ ! -f "$RECS_FILE" ]]; then
    cat > "$RECS_FILE" <<EOF
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "critical": [],
  "high": [],
  "medium": [],
  "optimizations": []
}
EOF
fi

# Set up cron jobs for Claude Code invocations
log_info "Setting up cron jobs..."

CRON_FILE="/tmp/sysadmin-cron-$$"
crontab -l 2>/dev/null > "$CRON_FILE" || true

# Remove old entries
sed -i '/claude-admin\/run-hourly.sh/d' "$CRON_FILE" 2>/dev/null || true
sed -i '/claude-admin\/run-daily.sh/d' "$CRON_FILE" 2>/dev/null || true

# Add new entries
cat >> "$CRON_FILE" <<EOF

# Claude Code Sysadmin - Hourly checks
0 * * * * $SCRIPT_DIR/claude-admin/run-hourly.sh >/dev/null 2>&1

# Claude Code Sysadmin - Daily maintenance
0 2 * * * $SCRIPT_DIR/claude-admin/run-daily.sh >/dev/null 2>&1
EOF

crontab "$CRON_FILE"
rm "$CRON_FILE"

log_info "✓ Cron jobs installed"

# Set up systemd service for dashboard
log_info "Setting up web dashboard service..."

# Create service file with venv Python
sudo tee /etc/systemd/system/sysadmin-dashboard.service >/dev/null <<EOF
[Unit]
Description=Sysadmin Dashboard - Claude Code Web Interface
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR/dashboard
ExecStart=$SCRIPT_DIR/venv/bin/python $SCRIPT_DIR/dashboard/app.py
Restart=always
RestartSec=10
Environment="PYTHONUNBUFFERED=1"
Environment="PATH=$SCRIPT_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable sysadmin-dashboard.service
sudo systemctl restart sysadmin-dashboard.service

# Wait for service to start
sleep 2

if sudo systemctl is-active --quiet sysadmin-dashboard.service; then
    log_info "✓ Web dashboard started successfully"
else
    log_error "Failed to start web dashboard"
    log_info "Check logs with: sudo journalctl -u sysadmin-dashboard.service -f"
fi

# Run initial check using helper script (not Claude for install)
log_info ""
log_info "Running initial system check..."
if [[ -x "$SCRIPT_DIR/scripts/daily-maintenance.sh" ]]; then
    "$SCRIPT_DIR/scripts/daily-maintenance.sh" 2>&1 | head -30
fi

echo ""
log_info "${GREEN}===============================================${NC}"
log_info "${GREEN}Installation Complete!${NC}"
log_info "${GREEN}===============================================${NC}"
echo ""
log_info "📊 Web Dashboard: ${BLUE}http://localhost:5050${NC}"
echo ""
log_info "🤖 Claude Code will run automatically:"
log_info "   • Hourly checks: Every hour at :00"
log_info "   • Daily maintenance: Every day at 2:00 AM"
echo ""
log_info "🚀 Launch interactive Claude Code session:"
log_info "   cd ~/sysadmin && claude --dangerously-skip-permissions"
echo ""
log_info "📁 Key Files:"
log_info "   • System status: reports/$HOSTNAME/latest.md"
log_info "   • Alerts: reports/$HOSTNAME/alerts.json"
log_info "   • Activity log: reports/$HOSTNAME/activity.log"
log_info "   • Configure apps: config/monitored-apps.yaml"
echo ""
log_info "🔧 Manual Execution:"
log_info "   • Hourly: ./claude-admin/run-hourly.sh"
log_info "   • Daily: ./claude-admin/run-daily.sh"
log_info "   • Dashboard logs: sudo journalctl -u sysadmin-dashboard.service -f"
echo ""
log_info "Next: Open ${BLUE}http://localhost:5050${NC} in your browser"
echo ""
