# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **Claude Code-powered autonomous sysadmin** designed to operate across multiple machines.

**Architecture**: Claude Code itself IS the system administrator, invoked with `--dangerously-skip-permissions` to allow autonomous maintenance actions. This repository provides:
- Helper scripts and utilities for common tasks
- Configuration and status tracking
- A web dashboard for monitoring and control
- Prompts and context (this file) to guide Claude Code sessions

### Primary Use Cases for Managed Machines

The machines managed by this system are primarily used for:

1. **Quantitative Software Development**: R, Python, and C++ development for numerical/statistical computing
2. **Production Application Hosting**:
   - Interactive web applications (R Shiny, Python Dash, Flask)
   - Batch analytics jobs running via cron or systemd
   - Production services requiring monitoring and auto-remediation

### Operating Philosophy

**Claude Code as Sysadmin**: Claude Code is invoked (via cron or manually) to:
- Read system status and alerts
- Analyze issues and make decisions
- Execute remediation with full permissions (--dangerously-skip-permissions)
- Use helper scripts in this repo as tools
- Update status reports and alerts
- Operate with significant autonomy

**Autonomous Operation Principles**:
- **Preventive action**: Fix issues before they become critical (e.g., rotate oversized logs before disk fills)
- **Intelligent remediation**: Preserve recent data when cleaning (e.g., keep recent logs, purge old)
- **Production-first**: Monitor and auto-fix production apps/jobs to minimize downtime
- **Non-destructive**: Never delete user code or data; focus on system maintenance tasks

**Execution Schedule**:
- **Hourly**: Quick health checks (disk space, critical services, production apps)
- **Daily**: Comprehensive maintenance (updates, cleanup, security audit)

**Web Dashboard**: Accessible at http://localhost:5050
- View system status and alerts
- Review recent activities and recommendations
- Trigger maintenance jobs
- Command to launch interactive Claude Code sessions

### Directory Structure

```
sysadmin/
├── CLAUDE.md              # This file - guidance for Claude Code
├── README.md              # Documentation
├── install.sh             # Setup script for new machines
│
├── claude-admin/          # Claude Code invocation wrappers
│   ├── run-hourly.sh     # Invoke Claude for hourly checks
│   ├── run-daily.sh      # Invoke Claude for daily maintenance
│   └── prompts/          # Prompt templates for Claude
│       ├── hourly.txt
│       └── daily.txt
│
├── dashboard/             # Web dashboard for monitoring
│   ├── app.py            # Flask application
│   ├── api.py            # API endpoints
│   ├── templates/        # HTML templates
│   │   └── index.html
│   └── static/           # CSS, JS
│       ├── style.css
│       └── app.js
│
├── scripts/               # Helper utilities (used by Claude)
│   ├── hourly-check.sh   # Quick system health checks
│   ├── daily-maintenance.sh  # Comprehensive maintenance
│   ├── check-prod-apps.sh    # Monitor production applications
│   ├── remediation/      # Auto-fix utilities
│   └── lib/              # Shared library functions
│
├── reports/              # System status reports per machine
│   └── {hostname}/       # Per-machine status tracking
│       ├── latest.md     # Most recent system report
│       ├── activity.log  # Recent Claude activities
│       ├── recommendations.json  # Claude's recommendations
│       ├── history/      # Historical reports
│       └── alerts.json   # Active alerts/issues
│
└── config/               # Configuration files
    ├── machines.yaml     # Registered machines
    ├── monitored-apps.yaml  # Production apps to monitor
    └── dashboard.yaml    # Dashboard configuration

## System Context

**Hardware Profile:**
- Ubuntu 24.04.3 LTS (Noble Numbat)
- Kernel: 6.14.0-37-generic (mainline/testing kernel, not standard LTS)
- 124GB RAM, 24GB VRAM (NVIDIA RTX GPU, likely 4090)
- 3.6TB storage (31% used)

**Primary Use Case:**
- ML/AI workstation with local LLM capabilities (Ollama, Open WebUI)
- Development machine with virtualization (KVM/QEMU, Docker, LXD)
- Remote access via Tailscale VPN

## Key System Services

### Active Services
- **Ollama**: Local LLM service (localhost:11434)
- **Open WebUI**: LLM web interface (port 8080, Docker)
- **libvirtd**: KVM virtualization running Windows 11 VM
- **Docker**: Container runtime (open-webui, watchtower)
- **Tailscale**: VPN for secure remote access
- **strongswan/versa-sase**: IPsec VPN for enterprise SASE

### Services to Review/Disable
- **xrdp + gnome-remote-desktop**: RDP servers on ports 3389/3390 (likely unused)
- **InfluxDB**: Time-series database on port 8086 (verify if needed)
- **LXD**: Daemon running but all containers deleted

## Common System Administration Commands

### Security & Firewall
```bash
# Enable and configure firewall (CRITICAL - currently disabled)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 100.64.0.0/10 to any port 22  # Tailscale only
sudo ufw enable
sudo ufw status verbose
```

### System Updates
```bash
# Full system update
sudo apt update && sudo apt upgrade -y

# Clean residual configs and orphaned packages
sudo apt purge '~c'
sudo apt autoremove

# Check if reboot required
cat /var/run/reboot-required
cat /var/run/reboot-required.pkgs
```

### Docker Management
```bash
# Check Docker disk usage
sudo docker system df

# Clean unused images (151GB potentially reclaimable)
sudo docker image prune -a

# Container operations
sudo docker ps -a
sudo docker logs open-webui
sudo docker rm faster-whisper-server  # Remove dead container
```

### VM Management (libvirt/KVM)
```bash
# List VMs
sudo virsh list --all

# VM operations
sudo virsh dominfo win11
sudo virsh start win11
sudo virsh shutdown win11

# VM disk location
/var/lib/libvirt/images/win11-1.qcow2
```

### Service Management
```bash
# Disable unnecessary services
sudo systemctl disable --now xrdp xrdp-sesman gnome-remote-desktop
sudo systemctl disable --now influxdb  # If not needed

# Check service status
sudo systemctl status SERVICE_NAME
systemctl list-units --type=service --state=running

# View network listeners
sudo ss -tlnp
```

### System Monitoring
```bash
# GPU monitoring (Snap package installed)
nvtop

# System monitor
btop

# Check temperatures
sensors

# Disk usage
df -h
sudo du -sh /var/lib/docker
sudo du -sh /var/log
```

### Log Management
```bash
# Clean old journal logs (currently 2.0GB)
sudo journalctl --vacuum-time=30d

# View system logs
journalctl -u SERVICE_NAME -f
journalctl -b  # Current boot
```

## Critical Security Issues

**IMPORTANT**: The system review identified critical security issues that should be addressed:

1. **Firewall Disabled** - Multiple services exposed without protection (ports 8080, 8086, 8443, 3389, 3390)
2. **No Backup Solution** - No protection against data loss (consider Timeshift, Restic, or Borgbackup)
3. **88 Packages Need Updates** - Including security updates for systemd and NVIDIA drivers
4. **Reboot Required** - gnome-shell updates pending

## Architecture Notes

### Network Topology
- **External Access**: Tailscale VPN (100.64.0.0/10 network)
- **Enterprise VPN**: Versa SASE/strongswan IPsec
- **Bridge Networks**:
  - virbr0 (192.168.122.1) - libvirt for VMs
  - lxdbr0 (10.85.165.1) - LXD bridge (no active containers)
  - docker0 - Docker bridge network

### Exposed Services (Needs Firewall)
- Port 22: SSH (all interfaces)
- Port 8080: Open WebUI (0.0.0.0)
- Port 8086: InfluxDB (all interfaces)
- Port 8443: LXD API (all interfaces)
- Port 3389/3390: RDP services (all interfaces)

### Localhost-Only Services (Safe)
- Port 11434: Ollama
- Port 5900: QEMU VNC (Windows 11 VM)
- Port 631: CUPS printing
- Port 53: systemd-resolved DNS

## Cleanup Opportunities

- **Docker images**: 151GB reclaimable (96% of image storage)
- **Residual kernel configs**: 62+ old kernel packages (6.8.x, 6.11.x, 6.14.x)
- **Journal logs**: 2.0GB (consider vacuum)
- **Dead container**: faster-whisper-server (exited 13 months ago)

## Special Considerations

- **Kernel Version**: Running 6.14.0-37 which is unusually new for Ubuntu 24.04 LTS (standard is 6.8.x). This may be from ubuntu-mainline-kernel PPA or manual installation.
- **NVIDIA Driver**: Version 580.95.05 is relatively new, matches the latest hardware.
- **Performance**: System is very healthy with excellent metrics (12% RAM, 0% swap, normal temps).
- **User Security**: Good security posture - single sudo user, minimal failed logins, no suspicious activity.

## Autonomous Remediation Guidelines

When the assistant encounters issues requiring immediate action:

### Disk Space Management
- **Log files >1GB not rotated**: Preserve last 100MB, compress and archive middle portion, delete oldest
- **Docker images >150GB**: Prune unused images, keep only tagged production images
- **Temp files >10GB**: Clean files older than 7 days from /tmp, /var/tmp
- **Old kernels**: Keep current + 1 previous version, purge older

### Service Management
- **Failed systemd services**: Attempt restart (max 3 tries), log failure, alert if critical
- **High memory processes**: Identify and log, restart if part of managed services
- **Zombie processes**: Clean up, identify parent process issues

### Production Application Monitoring
- **Shiny/Dash/Flask apps**: Check HTTP response, restart if down, verify systemd/docker status
- **Cron jobs**: Verify recent execution, check logs for failures, alert if consecutive failures
- **Database connections**: Test connectivity for PostgreSQL, MySQL, InfluxDB if present

### Security
- **Failed logins >10/hour**: Enable rate limiting, log source IPs
- **Firewall disabled**: Enable with safe defaults (allow SSH from Tailscale only)
- **Critical updates >7 days old**: Apply security updates automatically

## Production Application Patterns

### Common Deployment Methods

**Systemd Service (R Shiny)**:
```bash
# Service file: /etc/systemd/system/myapp.service
[Unit]
Description=My Shiny App
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/Rscript -e "shiny::runApp('.', port=3838, host='0.0.0.0')"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Docker Compose (Python Dash/Flask)**:
```yaml
# docker-compose.yml
version: '3.8'
services:
  webapp:
    build: .
    ports:
      - "8050:8050"
    restart: unless-stopped
    volumes:
      - ./data:/app/data
    environment:
      - FLASK_ENV=production
```

**Cron Batch Jobs**:
```bash
# /etc/cron.d/analytics-job
0 2 * * * appuser /opt/analytics/run-daily-report.sh >> /var/log/analytics/daily.log 2>&1
```

### Health Check Commands

```bash
# Check Shiny/Dash app
curl -f http://localhost:3838/ || systemctl restart myapp.service

# Check systemd service
systemctl is-active myapp.service

# Check Docker container
docker ps | grep webapp || docker-compose up -d

# Check recent cron execution
grep "analytics-job" /var/log/syslog | tail -5

# Check app logs for errors
journalctl -u myapp.service --since "1 hour ago" | grep -i error
```

## Script Development Guidelines

### When Writing Automation Scripts

1. **Logging**: All scripts must log to `/var/log/sysadmin/` with timestamps
2. **Error handling**: Use `set -euo pipefail` for bash scripts
3. **Dry-run mode**: Support `--dry-run` flag for testing
4. **Idempotency**: Scripts should be safe to run multiple times
5. **Notifications**: Log to file, optionally send alerts (email, webhook)

### Library Functions (scripts/lib/)

Create reusable functions for:
- `check_disk_space()` - Return percentage used
- `check_service_status()` - Test if service is healthy
- `check_http_endpoint()` - Test web app availability
- `rotate_large_log()` - Intelligently trim log files
- `send_alert()` - Notification system
- `update_status_report()` - Write to reports/{hostname}/

## Machine Registration

When setting up on a new machine:

```bash
# Clone repository
cd ~ && git clone <repo-url> sysadmin && cd sysadmin

# Run installation script
./install.sh

# This will:
# 1. Create directory structure
# 2. Register machine in config/machines.yaml
# 3. Set up cron jobs (hourly + daily)
# 4. Generate initial system report
# 5. Configure log rotation for /var/log/sysadmin/
```

## When Working in This Directory

### For Manual System Administration Tasks

1. Check latest status: `cat reports/$(hostname)/latest.md`
2. Review alerts: `cat reports/$(hostname)/alerts.json`
3. Run checks manually: `./scripts/hourly-check.sh` or `./scripts/daily-maintenance.sh`

### For Autonomous Operations

1. **Assess first**: Always read the current system state before taking action
2. **Prioritize safety**: Don't break production apps or delete user data
3. **Document actions**: Update status reports and alert logs
4. **Escalate when needed**: Some issues require human intervention (hardware failures, security breaches)

### For Script Development

1. Test scripts with `--dry-run` first
2. Follow error handling patterns from existing scripts
3. Add new remediation functions to `scripts/remediation/`
4. Update `monitored-apps.yaml` when adding new production apps

## Example Session Workflow

When Claude Code is invoked (either manually or via cron):

1. **Identify context**: Determine hostname, read machine config
2. **Load current status**: Read `reports/{hostname}/latest.md` and `alerts.json`
3. **Execute checks**: Run appropriate script (hourly or daily)
4. **Analyze results**: Identify issues requiring action
5. **Take action**: Apply autonomous remediation where appropriate
6. **Update reports**: Write new status report and update alerts
7. **Summarize**: Present findings and actions taken
