## Claude Code Autonomous Sysadmin

**A portable, Claude Code-powered system administrator** that autonomously monitors, maintains, and remediates Linux workstations across multiple machines.

## Overview

**Claude Code IS the sysadmin.** This repository provides:
- ✅ Helper scripts and utilities for common tasks
- ✅ Web dashboard for monitoring and control (http://localhost:5050)
- ✅ Configuration and status tracking across machines
- ✅ Prompts and context to guide Claude Code sessions
- ✅ Autonomous operation via cron with `--dangerously-skip-permissions`

### Architecture

```
┌─────────────────────────────────────────────┐
│  Cron Schedule                              │
│  • Hourly: Quick health checks              │
│  • Daily (2am): Comprehensive maintenance   │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Claude Code Invocation                     │
│  claude --dangerously-skip-permissions      │
│  • Reads prompts from claude-admin/prompts/ │
│  • Full sudo access for autonomous actions  │
│  • Uses helper scripts as tools             │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Actions & Reporting                        │
│  • Analyzes system status                   │
│  • Applies autonomous remediation           │
│  • Updates alerts and recommendations       │
│  • Logs all activities                      │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│  Web Dashboard (localhost:5050)             │
│  • View system status and alerts            │
│  • Review Claude's activities               │
│  • Trigger maintenance jobs                 │
│  • Launch interactive sessions              │
└─────────────────────────────────────────────┘
```

## Quick Start

### Installation

```bash
# Clone the repository
cd ~ && git clone <your-repo-url> sysadmin && cd sysadmin

# Run installation script
./install.sh

# This will:
# 1. Check for Claude Code installation
# 2. Install system dependencies (python3-venv, etc.)
# 3. Create Python virtual environment (venv/)
# 4. Install Python packages in venv (Flask, PyYAML, markdown)
# 5. Set up cron jobs (hourly + daily)
# 6. Start web dashboard on port 5050 (using venv)
# 7. Register machine in config
# 8. Run initial system check
```

### Access the Dashboard

Open http://localhost:5050 in your browser to:
- 📊 View real-time system status
- ⚠️ See active alerts and their severity
- 📝 Review Claude Code's recent activities
- 💡 Read Claude's recommendations
- ⚡ Trigger maintenance jobs on-demand
- 🚀 Get command to launch interactive sessions

### Interactive Claude Code Session

```bash
cd ~/sysadmin
claude --dangerously-skip-permissions

# Claude will read CLAUDE.md and understand:
# - System context and use cases
# - Autonomous remediation guidelines
# - Helper scripts available
# - Production app patterns
```

## Directory Structure

```
sysadmin/
├── CLAUDE.md                    # Guidance for Claude Code (primary documentation)
├── README.md                    # This file
├── install.sh                   # Installation script
│
├── claude-admin/                # Claude Code invocation system
│   ├── run-hourly.sh           # Wrapper to invoke Claude for hourly checks
│   ├── run-daily.sh            # Wrapper to invoke Claude for daily maintenance
│   └── prompts/
│       ├── hourly.txt          # Prompt for hourly checks
│       └── daily.txt           # Prompt for daily maintenance
│
├── dashboard/                   # Web interface (Flask)
│   ├── app.py                  # Main application
│   ├── requirements.txt        # Python dependencies
│   ├── templates/
│   │   └── index.html          # Dashboard UI
│   └── static/
│       ├── style.css           # Styling
│       └── app.js              # Frontend JavaScript
│
├── venv/                        # Python virtual environment
│   ├── bin/python              # Isolated Python interpreter
│   ├── bin/pip                 # Package installer for venv
│   └── lib/                    # Installed packages (Flask, etc.)
│
├── scripts/                     # Helper utilities (used by Claude)
│   ├── hourly-check.sh         # Quick health checks
│   ├── daily-maintenance.sh    # Comprehensive maintenance
│   ├── check-prod-apps.sh      # Production app monitoring
│   ├── lib/
│   │   └── common.sh           # Shared functions (50+ utilities)
│   └── remediation/
│       ├── rotate-large-logs.sh    # Auto-rotate oversized logs
│       ├── clean-docker.sh         # Docker cleanup
│       └── enable-firewall.sh      # Enable UFW firewall
│
├── reports/                     # Per-machine status tracking
│   └── {hostname}/
│       ├── latest.md           # Current system report
│       ├── activity.log        # Claude Code activities
│       ├── recommendations.json # Claude's recommendations
│       ├── alerts.json         # Active alerts
│       └── history/            # Historical reports
│
└── config/                      # Configuration files
    ├── machines.yaml           # Registered machines
    ├── monitored-apps.yaml     # Production apps to monitor
    └── dashboard.yaml          # Dashboard configuration
```

## Use Cases

This system is designed for machines used for:

### 1. Quantitative Development
- R, Python, and C++ development
- Numerical/statistical computing
- Large dataset management
- Memory-intensive workloads

### 2. Production Application Hosting
- **R Shiny** applications
- **Python Dash/Flask** web apps
- **Batch analytics jobs** (cron/systemd)
- Auto-restart and health monitoring

### 3. Autonomous Maintenance
- Preventive disk space management
- Security updates and hardening
- Service recovery
- Log rotation

## Configuring Production Apps

Edit `config/monitored-apps.yaml`:

### R Shiny Application (systemd)

```yaml
apps:
  portfolio-dashboard:
    type: systemd
    service_name: portfolio-dashboard.service
    health_check:
      method: http
      url: http://localhost:3838/
      timeout: 5
    auto_restart: true
    critical: true
```

### Python Dash Application (Docker)

```yaml
apps:
  analytics-platform:
    type: docker
    container_name: analytics
    health_check:
      method: http
      url: http://localhost:8050/health
      timeout: 10
    auto_restart: true
    critical: false
```

### Batch Analytics Job (cron)

```yaml
apps:
  daily-risk-report:
    type: cron
    cron_pattern: "0 2 * * *"
    check_log: /var/log/analytics/risk-report.log
    max_failures: 3
    critical: true
```

## Web Dashboard Features

### Real-Time Monitoring
- Disk usage, memory, load average
- System uptime and firewall status
- Color-coded health indicators

### Alert Management
- Critical, high, and medium priority alerts
- Detailed descriptions and detection timestamps
- Auto-updated from Claude Code sessions

### Activity Tracking
- Real-time view of Claude Code actions
- Color-coded log levels (ERROR, WARNING, INFO)
- Filterable and searchable

### Recommendations
- Claude's analysis and suggestions
- Prioritized by severity
- Actionable next steps

### Quick Actions
- Run hourly check on-demand
- Trigger daily maintenance
- Refresh dashboard data

### Monitored Apps View
- All configured applications
- Type, health check, auto-restart status
- Critical flag indicator

## How Claude Code Operates

### Scheduled Operation (Autonomous)

**Hourly (every hour at :00):**
```bash
claude-admin/run-hourly.sh
↓
Reads: claude-admin/prompts/hourly.txt
↓
Claude Code:
  • Checks disk space, memory, services
  • Monitors production apps
  • Applies urgent fixes if needed
  • Updates activity.log and alerts.json
```

**Daily (2:00 AM):**
```bash
claude-admin/run-daily.sh
↓
Reads: claude-admin/prompts/daily.txt
↓
Claude Code:
  • Runs hourly checks
  • Applies system updates
  • Cleans old kernels, Docker images
  • Rotates large logs
  • Enables firewall if disabled
  • Generates comprehensive report
  • Updates recommendations.json
```

### Interactive Operation

Launch manually for custom tasks:

```bash
cd ~/sysadmin
claude --dangerously-skip-permissions

# Example prompts:
"Check the system and fix critical issues"
"Why is disk space high? Investigate and clean up"
"Add monitoring for the new Shiny app on port 4000"
"Review production apps and restart any that are down"
```

## Autonomous Remediation Examples

Claude Code automatically handles:

### Disk Space Critical (>90%)
```bash
1. Rotate logs >1GB (keep last 100MB)
2. Clean Docker images >150GB
3. Clean journal logs (keep 7 days)
4. Clean apt cache
Result: Typically recovers 10-50GB
```

### Service Failures
```bash
1. Identify failed services
2. Attempt restart (max 3 tries)
3. Log failures if unsuccessful
4. Update alerts for human review
```

### Production App Down
```bash
1. Check service/container status
2. Verify health endpoint
3. Auto-restart if configured
4. Update alerts.json
5. Log actions to activity.log
```

### Firewall Disabled
```bash
1. Enable UFW with safe defaults
2. Allow SSH from Tailscale only (100.64.0.0/10)
3. Default deny incoming, allow outgoing
4. Update alerts (resolved)
```

## Logs and Debugging

### Activity Log (Claude Code actions)
```bash
# View recent Claude activities
cat reports/$(hostname)/activity.log

# Watch in real-time
tail -f reports/$(hostname)/activity.log

# Last 50 lines
tail -50 reports/$(hostname)/activity.log
```

### System Log (helper scripts)
```bash
# View script logs
tail -f /var/log/sysadmin/sysadmin.log

# Today's actions
grep "$(date +%Y-%m-%d)" /var/log/sysadmin/sysadmin.log

# Errors only
grep ERROR /var/log/sysadmin/sysadmin.log
```

### Dashboard Service
```bash
# View dashboard logs
sudo journalctl -u sysadmin-dashboard.service -f

# Restart dashboard
sudo systemctl restart sysadmin-dashboard.service

# Check status
sudo systemctl status sysadmin-dashboard.service

# Run dashboard manually (for testing)
cd ~/sysadmin
./venv/bin/python dashboard/app.py
```

### Cron Execution
```bash
# Check cron jobs
crontab -l | grep claude-admin

# View cron execution log
grep CRON /var/log/syslog | grep claude-admin | tail -20
```

## Multi-Machine Deployment

Same repository works across all machines:

```bash
# Machine 1 (workstation)
cd ~/sysadmin && ./install.sh

# Machine 2 (server)
cd ~/sysadmin && ./install.sh

# Each machine gets:
# - Own reports directory (reports/{hostname}/)
# - Own dashboard on localhost:5050
# - Own cron jobs
# - Entry in config/machines.yaml
```

## Manual Operations

```bash
# Run hourly check now
./claude-admin/run-hourly.sh

# Run daily maintenance now
./claude-admin/run-daily.sh

# Use helper scripts directly (without Claude)
./scripts/hourly-check.sh
./scripts/daily-maintenance.sh
./scripts/check-prod-apps.sh

# Dry-run mode (no changes)
DRY_RUN=1 ./scripts/daily-maintenance.sh

# Disable auto-updates
AUTO_UPDATE=0 ./scripts/daily-maintenance.sh

# Test remediation scripts
./scripts/remediation/rotate-large-logs.sh
./scripts/remediation/clean-docker.sh
./scripts/remediation/enable-firewall.sh
```

## Troubleshooting

### Dashboard not accessible

```bash
# Check service status
sudo systemctl status sysadmin-dashboard.service

# View logs
sudo journalctl -u sysadmin-dashboard.service -n 50

# Restart service
sudo systemctl restart sysadmin-dashboard.service

# Check port
sudo netstat -tlnp | grep 5050
```

### Claude Code not found

```bash
# Check installation
which claude

# If not found, install from:
# https://claude.ai/code
```

### Cron jobs not running

```bash
# Verify cron jobs
crontab -l

# Check cron log
grep CRON /var/log/syslog | tail -20

# Test manual execution
./claude-admin/run-hourly.sh
```

### Permission errors

```bash
# Fix log directory permissions
sudo chown -R $USER:$USER /var/log/sysadmin
sudo chmod -R 755 /var/log/sysadmin

# Fix reports directory
chmod -R 755 reports/
```

## Security Considerations

- Claude Code runs with `--dangerously-skip-permissions` for autonomous operation
- Firewall configured to allow SSH from Tailscale network only (100.64.0.0/10)
- Dashboard runs on localhost:5050 (not exposed to network)
- All actions logged to activity.log for audit trail
- Sensitive operations (reboots, major changes) flagged for human review

## Updating

```bash
cd ~/sysadmin
git pull

# Update Python dependencies if requirements.txt changed
./venv/bin/pip install -r dashboard/requirements.txt

# Restart dashboard to pick up changes
sudo systemctl restart sysadmin-dashboard.service

# Cron jobs automatically use updated scripts
```

## Uninstallation

```bash
# Remove cron jobs
crontab -l | grep -v "claude-admin" | crontab -

# Stop and remove dashboard service
sudo systemctl stop sysadmin-dashboard.service
sudo systemctl disable sysadmin-dashboard.service
sudo rm /etc/systemd/system/sysadmin-dashboard.service
sudo systemctl daemon-reload

# Remove log directory
sudo rm -rf /var/log/sysadmin
sudo rm /etc/logrotate.d/sysadmin

# Remove repository (includes venv)
rm -rf ~/sysadmin
```

## Support

- **CLAUDE.md**: Comprehensive guidance for Claude Code
- **Dashboard**: http://localhost:5050 for visual monitoring
- **Activity Log**: reports/{hostname}/activity.log for Claude actions
- **System Log**: /var/log/sysadmin/sysadmin.log for helper scripts

## License

Personal system administration tool. Customize for your environment.
