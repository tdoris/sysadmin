# Claude Code Autonomous Sysadmin

**For ML engineers, data scientists, and quants who need their machines to just work—without babysitting them.**

---

## The Problem

You're not a sysadmin. You're a developer. But you're responsible for keeping your machine running, and:

- 🔴 **CUDA breaks after every driver update** - costs you 2-4 hours debugging
- 🔴 **Disk fills up during training** - your job crashes, you lose compute time
- 🔴 **Python environments break mysteriously** - ImportError, missing dependencies
- 🔴 **R packages fail to compile** - missing system libraries
- 🔴 **Docker images consume 200GB** - you didn't know you needed to prune them
- 🔴 **Your production dashboard is down** - and you're in a meeting

You could spend time learning sysadmin skills. Or you could let Claude Code handle it.

---

## The Solution

**Claude Code IS your sysadmin.** It monitors your machine, detects problems, and fixes them autonomously.

- ✅ Comprehensive health checks (GPU, CUDA, Python, R, databases, development tools)
- ✅ Autonomous remediation (cleans disk, rotates logs, restarts services)
- ✅ Web dashboard (http://localhost:5050)
- ✅ Scheduled maintenance (hourly + daily)
- ✅ Production app monitoring (Shiny, Dash, Flask)

**Claude Code runs with `--dangerously-skip-permissions`** so it can actually fix things, not just complain about them.

---

## What It Does

### System Configuration

**Network Performance**
- Optimizes TCP buffer sizes for high-bandwidth connections
- Enables BBR congestion control for better throughput
- Configures network stack for ML workloads

**Security Baseline**
- Ensures firewall is enabled and properly configured
- Applies security updates automatically
- Monitors for suspicious activity and failed logins

**Performance Settings**
- Tunes kernel parameters for development workloads
- Optimizes disk I/O scheduling
- Monitors and adjusts swap usage

**Software Updates**
- Keeps system packages current
- Tracks and applies security patches
- Manages kernel versions (keeps current + 1 previous)

### Prevents Common Issues

**Disk Space Management**
- Monitors every hour, auto-cleans when >85% full
- Rotates large logs, prunes Docker images, cleans package caches

**GPU/CUDA Environment**
- Verifies NVIDIA driver health after kernel updates
- Checks PyTorch/TensorFlow GPU access
- Detects CUDA version mismatches

**Python Environments**
- Scans for security vulnerabilities in packages
- Identifies broken virtual environments
- Detects missing build dependencies

**R Environment**
- Tracks outdated packages and system libraries
- Monitors RStudio Server health
- Checks for missing compilation tools (libcurl, libxml2, GDAL, GEOS)

**Production Apps**
- HTTP health checks every hour with auto-restart on failure
- Monitors systemd services and Docker containers

**Development Tools**
- Verifies compilers (gcc, g++, gfortran) and build tools
- Checks language runtimes (Node.js, Go, Rust, Java)
- Monitors databases (PostgreSQL, MySQL, MongoDB, Redis, InfluxDB)

---

## Who This Is For

**ML Engineers & Data Scientists**
- Training models on local GPUs
- Need CUDA to work reliably
- Can't afford downtime during long runs

**Quantitative Researchers**
- Developing in R and Python
- Running production analytics jobs
- Hosting dashboards for stakeholders

**Solo Developers & Small Teams**
- No dedicated DevOps/sysadmin support
- Need machines that maintain themselves
- Want to focus on code, not system administration

---

## Quick Start

### Installation

```bash
cd ~ && git clone <your-repo-url> sysadmin && cd sysadmin
./install.sh
```

This sets up:
- Web dashboard on http://localhost:5050
- Cron jobs (hourly + daily at 2am)
- Initial system scan

**Time to value**: 5 minutes

### Configure Your Apps

Edit `config/monitored-apps.yaml`:

```yaml
apps:
  my-dashboard:
    type: systemd
    service_name: shiny-dashboard.service
    health_check:
      method: http
      url: http://localhost:3838/
    auto_restart: true
    critical: true
```

### That's It

Claude Code now monitors, maintains, and fixes your system autonomously.

---

## What It Checks

**Hourly**: Disk space, memory, critical services, GPU temperature, production apps, zombie processes

**Daily**: System updates, GPU/CUDA health, Python/R environments, development tools, databases, disk cleanup, hardware health, network optimization

**Total time**: ~45 seconds
**Problems prevented**: Countless

---

## Philosophy

Designed for **developer workstations**, not production servers.

**Priorities**: Developer experience > Performance > Stability > Basic security > Maintenance

**Not priorities**: Military-grade hardening, compliance theater, restrictive policies, manual approval for every change

**Key principle**: The machine should help you work, not get in your way.

---

## Autonomous Operation

**Hourly (every hour at :00):**
- Quick health checks
- Urgent fixes applied automatically
- Dashboard updated

**Daily (2:00 AM):**
- Comprehensive scan
- System updates + cleanup + optimization
- Detailed report generated

### Example Remediations

**Disk >85%**: Rotate logs, prune Docker, clean caches, remove old kernels → recovers 10-50GB

**Service failed**: Check logs, restart (max 3 tries), alert if fails

**CUDA broken**: Check driver, CUDA toolkit, version compatibility → diagnostic report with fix

---

## Interactive Use

Launch Claude Code for custom tasks:

```bash
cd ~/sysadmin
claude --dangerously-skip-permissions
```

Example prompts:
- "Check the system and fix any critical issues"
- "Why is disk space high? Investigate and clean up"
- "My PyTorch can't see the GPU, debug this"
- "Add monitoring for my new Shiny app on port 4000"

---

## Monitoring & Logs

**Web Dashboard**: http://localhost:5050
Real-time metrics, alerts, activity log, recommendations, app status, approval requests

### Activity & Maintenance Logs

**Activity Log** - All sysadmin actions and maintenance activities:
```bash
cat reports/$(hostname)/activity.log
tail -f reports/$(hostname)/activity.log
```

**System Logs** - Detailed maintenance script logs:
```bash
# Cron job logs (hourly and daily maintenance)
sudo journalctl -u cron | grep sysadmin

# Script execution logs
ls -lh /var/log/sysadmin/

# Today's maintenance log
cat /var/log/sysadmin/daily-maintenance-$(date +%Y-%m-%d).log
cat /var/log/sysadmin/hourly-check-$(date +%Y-%m-%d).log
```

### Status Reports & Alerts

**Current System Status**:
```bash
cat reports/$(hostname)/latest.md           # Latest system report
cat reports/$(hostname)/alerts.json         # Active alerts
cat reports/$(hostname)/recommendations.json  # Sysadmin recommendations
```

**Historical Reports**:
```bash
ls -lh reports/$(hostname)/history/
cat reports/$(hostname)/history/2025-12-27-daily-report.md
```

**Environment Checks**:
```bash
cat reports/$(hostname)/gpu-environment.txt
cat reports/$(hostname)/python-environment.txt
cat reports/$(hostname)/r-environment.txt
```

### Approval Workflow Logs

**Pending & Completed Actions**:
```bash
cat reports/$(hostname)/pending-approvals.json  # All approval requests
python3 -c "import json; data=json.load(open('reports/$(hostname)/pending-approvals.json')); print(f\"Pending: {len([x for x in data['items'] if x['status']=='pending'])}\nCompleted: {len([x for x in data['items'] if x['status']=='completed'])}\")"
```

---

## Cost/Benefit

**Setup**: 5 minutes (one-time)
**Maintenance**: ~0 minutes (self-maintaining)
**Annual time saved**: 50-100+ hours
**ROI**: Astronomical

---

## Multi-Machine Support

Same repository works on all your machines:

```bash
# Workstation 1
cd ~/sysadmin && ./install.sh

# GPU server
cd ~/sysadmin && ./install.sh
```

Each machine gets its own dashboard, reports, alerts, and maintenance schedule.

---

## Manual Operations

```bash
# Run checks now
./claude-admin/run-hourly.sh
./claude-admin/run-daily.sh

# Dry-run mode
DRY_RUN=1 ./scripts/daily-maintenance.sh

# Disable auto-updates
AUTO_UPDATE=0 ./scripts/daily-maintenance.sh
```

---

## Documentation

- **README.md** (this file) - Overview and quick start
- **CLAUDE.md** - Comprehensive context for Claude Code
- **PRINCIPLES.md** - Operating philosophy
- **COVERAGE_ANALYSIS.md** - What we check and why
- **Dashboard** - http://localhost:5050

---

## Troubleshooting

**Dashboard not loading**:
```bash
sudo systemctl status sysadmin-dashboard.service
sudo systemctl restart sysadmin-dashboard.service
```

**Cron jobs not running**:
```bash
crontab -l  # Verify jobs exist
./claude-admin/run-hourly.sh  # Test manually
```

**Need help**:
```bash
cd ~/sysadmin
claude --dangerously-skip-permissions
# Tell Claude what's wrong
```

---

## The Bottom Line

You're not a sysadmin. You shouldn't have to be one.

This tool handles system administration so you can focus on your actual work: developing ML models, analyzing data, writing code, running quantitative research.

**Setup**: 5 minutes
**Ongoing effort**: ~0 minutes
**Time saved**: 50-100+ hours/year

Install it, configure your apps, then forget about system administration.

*That's the point.*
