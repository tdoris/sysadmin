# Claude Code Autonomous Sysadmin

**For ML engineers, data scientists, and quants who need their machines to just work—without babysitting them.**

---

## The Problem

You're not a sysadmin. You're a developer. But you're responsible for keeping your machine running, and:

- 🔴 **CUDA breaks after every driver update** - "torch.cuda.is_available() = False" costs you 2-4 hours
- 🔴 **Disk fills up at 3am** - your training job crashes, you lose hours of compute
- 🔴 **Python environments break mysteriously** - ImportError, missing dependencies, security vulnerabilities
- 🔴 **R packages fail to compile** - missing system libraries you've never heard of
- 🔴 **Docker images consume 200GB** - you didn't know you needed to prune them
- 🔴 **System updates need a reboot** - but you have 5 days of unsaved work
- 🔴 **Your Shiny dashboard is down** - and you're in a meeting with stakeholders

You *could* spend time learning sysadmin skills. Or you could let Claude Code handle it.

---

## The Solution

**Claude Code IS your sysadmin.** It monitors your machine, detects problems, and fixes them autonomously.

This repository provides:
- ✅ Comprehensive health checks for ML/data science stacks (GPU, CUDA, Python, R, databases)
- ✅ Autonomous remediation (cleans up disk, rotates logs, restarts services)
- ✅ Web dashboard for monitoring (http://localhost:5050)
- ✅ Scheduled maintenance (hourly checks, daily cleanup)
- ✅ Production app monitoring (Shiny, Dash, Flask, cron jobs)

**Claude Code runs with `--dangerously-skip-permissions`** so it can actually fix things, not just complain about them.

---

## What It Actually Does

### Prevents Disasters Before They Happen

**Disk Space Management** (critical for training jobs)
- Monitors disk usage every hour
- Automatically cleans up when >85% full:
  - Rotates logs >1GB (keeps recent data)
  - Prunes unused Docker images
  - Cleans pip/R package caches
  - Removes old kernels
- **Typical recovery**: 10-50GB in minutes

**GPU/CUDA Environment** (the #1 ML developer pain point)
- Checks NVIDIA driver health after kernel updates
- Verifies PyTorch/TensorFlow can access GPU
- Detects CUDA version mismatches
- Monitors GPU temperature and memory
- Identifies broken CUDA library paths
- **Time saved**: 1-4 hours per CUDA debugging session

**Python Environment Health**
- Detects outdated packages with security vulnerabilities
- Finds broken virtual environments
- Identifies missing system dependencies (python3-dev, libssl-dev, etc.)
- Monitors pip cache size (often bloats to 10GB+)
- Checks for conflicting package versions
- **Time saved**: 30min - 2 hours per environment issue

**R Environment Management**
- Tracks outdated R packages (quant shops often have 100+ packages)
- Detects missing system libraries (libcurl, libxml2, GDAL, GEOS, etc.)
- Monitors RStudio Server health
- Identifies broken package installations
- Checks compiler availability for package compilation
- **Time saved**: 30min - 1 hour per R package issue

**Production App Monitoring** (for your Shiny dashboards, Dash apps, APIs)
- HTTP health checks every hour
- Auto-restart on failure (if configured)
- Service status monitoring (systemd, Docker)
- Alerts when apps go down
- **Downtime prevented**: Hours of stakeholder-facing outages

**Development Tool Verification**
- Tracks versions: Node.js, Go, Rust, Java, Docker, Git
- Verifies compilers installed (gcc, g++, gfortran, make, cmake)
- Checks Git configuration
- Monitors build tool availability
- **Time saved**: 15-30 min per "command not found" issue

**Database Health Checks**
- PostgreSQL, MySQL, MongoDB, Redis, InfluxDB monitoring
- Connection verification
- Long-running query detection
- Disk usage tracking
- **Time saved**: 15-45 min per database issue

---

## Who This Is For

### ML Engineers & Data Scientists
- Training models on local GPUs
- Running Jupyter notebooks 24/7
- Need CUDA to work reliably
- Can't afford downtime during long training runs
- Don't have time to debug NVIDIA driver issues

### Quantitative Researchers & Analysts
- Developing in R and Python
- Running production analytics jobs via cron
- Hosting Shiny dashboards for stakeholders
- Need packages to install without compilation failures
- Want systems that stay up during market hours

### Solo Developers & Small Teams
- No dedicated DevOps/sysadmin support
- Responsible for your own infrastructure
- Need machines that maintain themselves
- Want to focus on code, not system administration
- Prefer automation over manual maintenance

### Anyone With:
- A Linux workstation doing real work
- Production applications that need monitoring
- Limited patience for system administration
- Better things to do than debug environment issues

---

## What Makes This Different

### It Actually Fixes Things

Most monitoring tools send you alerts. This one sends alerts **and fixes the problem**.

- Disk at 92%? Cleaned automatically.
- Docker using 150GB? Pruned automatically.
- Service crashed? Restarted automatically.
- Logs filled up? Rotated automatically.
- System updates available? Applied automatically (with safety checks).

### It Understands Your Stack

Generic monitoring doesn't know about:
- CUDA driver compatibility matrices
- Python virtual environment patterns
- R package compilation dependencies
- Shiny app deployment patterns
- ML workflow requirements

This does. Because it's designed for developers who actually use these tools.

### It's Autonomous

Not "runs a script and emails you." Actually autonomous:

1. **Detects** problem (disk space, GPU issue, crashed service)
2. **Analyzes** root cause (using Claude's reasoning)
3. **Remediates** automatically (if safe to do so)
4. **Reports** what it did (via dashboard and logs)
5. **Escalates** if human intervention needed

You wake up to fixed problems, not problem reports.

### It Adapts

Claude Code reads context (CLAUDE.md) and adapts to your specific setup:
- Learns which apps are critical
- Understands your deployment patterns
- Respects your priorities (performance > security hardening for dev machines)
- Adjusts remediation based on machine usage

Not just running static scripts—intelligent system administration.

---

## Real-World Impact

**Scenario 1: CUDA Breaks (Again)**

*Without this:*
- Training job fails at 3am
- You discover it at 9am (6 hours lost)
- Spend 2 hours debugging "torch.cuda.is_available() = False"
- Find driver update broke CUDA compatibility
- Reinstall driver, test, restart training
- **Total loss**: 8+ hours

*With this:*
- Hourly check detects PyTorch can't access GPU
- Alert created: "pytorch-cuda-unavailable"
- You see it at 9am on dashboard
- Full diagnostic report already generated
- Claude identified: driver version mismatch with PyTorch CUDA build
- Specific fix recommended
- **Total loss**: 6 hours compute, 15 minutes to fix

**Scenario 2: Disk Full During Training**

*Without this:*
- Training crashes at 87% complete
- Disk at 100% (Docker images + logs)
- Manually investigate what's using space
- Clean up manually (which files are safe to delete?)
- Restart training from last checkpoint
- **Total loss**: 2 days of compute

*With this:*
- Detected disk at 86% during hourly check
- Automatically cleaned: Docker (120GB), logs (8GB), pip cache (12GB)
- Freed 140GB in 5 minutes
- Training continues uninterrupted
- **Total loss**: 0

**Scenario 3: Stakeholder Demo App Down**

*Without this:*
- Stakeholder emails: "dashboard not loading"
- You're in a different meeting
- Frantically debug while people wait
- Find systemd service crashed
- Restart manually
- **Professional cost**: High

*With this:*
- App health check fails
- Auto-restart configured
- Service back up in 30 seconds
- You get alert: "Restarted portfolio-dashboard (HTTP check failed)"
- Stakeholder never notices
- **Professional cost**: 0

---

## Quick Start

### Prerequisites

- Linux machine (Ubuntu 24.04 recommended)
- Claude Code installed ([claude.ai/code](https://claude.ai/code))
- Sudo access

### Installation

```bash
cd ~ && git clone <your-repo-url> sysadmin && cd sysadmin
./install.sh
```

This sets up:
- Python virtual environment
- Web dashboard on http://localhost:5050
- Cron jobs (hourly + daily maintenance)
- Initial system scan

**Time to value**: 5 minutes

### Access Dashboard

Open http://localhost:5050 to see:
- Real-time system status (disk, memory, GPU temperature)
- Active alerts by severity
- Claude Code's recent actions
- Recommendations for human intervention
- Production app health

### Configure Your Apps

Edit `config/monitored-apps.yaml`:

```yaml
apps:
  my-shiny-dashboard:
    type: systemd
    service_name: shiny-dashboard.service
    health_check:
      method: http
      url: http://localhost:3838/
      timeout: 5
    auto_restart: true
    critical: true  # Alert immediately if down
```

### That's It

Claude Code now:
- Runs health checks every hour
- Performs comprehensive maintenance daily (2am)
- Monitors your apps continuously
- Fixes problems autonomously
- Reports via dashboard

You get on with your work.

---

## What It Checks

### Every Hour (Quick Health Checks)
- Disk space (alert at 90%, remediate at 85%)
- Memory usage
- Critical services (database, Docker, etc.)
- GPU temperature
- Production app health (HTTP checks)
- Zombie processes

### Daily (Comprehensive Maintenance)
- **System Updates**: Security patches applied automatically
- **GPU/CUDA**: Driver health, PyTorch/TensorFlow GPU access
- **Python**: Outdated packages, security vulns, broken venvs, pip cache
- **R**: Package updates, missing system libs, RStudio health
- **Development Tools**: Compiler versions, Git config, Docker status
- **Databases**: PostgreSQL, MySQL, MongoDB, Redis, InfluxDB health
- **Disk Cleanup**: Docker images, logs, old kernels, temp files, package cache
- **Hardware Health**: SMART disk status, temperature monitoring
- **Network**: TCP buffer optimization, BBR congestion control

**Total time**: ~45 seconds
**Problems prevented**: Countless

---

## Philosophy

This system is designed for **developer workstations**, not production servers.

**Priorities** (in order):
1. **Developer Experience** - Keep the machine fast, clean, pleasant to use
2. **Performance** - Optimize resources, prevent slowdowns
3. **Stability** - Prevent crashes, handle updates smoothly
4. **Basic Security** - Avoid stupid mistakes, apply patches
5. **Maintenance** - Keep things clean, remove cruft

**Not priorities**:
- Military-grade hardening
- Compliance theater
- Restrictive policies that block development workflows
- Manual approval for every change

**Key principle**: The machine should help you work, not get in your way.

---

## Autonomous Operation

### Scheduled Maintenance

**Hourly (every hour at :00):**
```
claude-admin/run-hourly.sh
↓
Quick checks: disk, memory, services, GPU, production apps
↓
Urgent fixes applied automatically
↓
Dashboard updated
```

**Daily (2:00 AM):**
```
claude-admin/run-daily.sh
↓
Comprehensive scan: all health checks
↓
System updates + cleanup + optimization
↓
Generate detailed report
↓
Update recommendations
```

### Remediation Examples

**Disk Space Critical**
```bash
Trigger: Disk >85% full
Actions:
  1. Rotate logs >1GB (preserve last 100MB)
  2. Prune Docker images if >150GB
  3. Clean pip/R package caches if >5GB
  4. Remove old kernels (keep current + 1)
  5. Clean apt cache
Result: Typically recovers 10-50GB
Alert: Updated to "resolved"
```

**GPU Temperature High**
```bash
Trigger: GPU >85°C
Actions:
  1. Check running processes
  2. Verify fan operation
  3. Alert if >95°C (thermal throttling risk)
Result: Alert for human review (hardware issue)
```

**Service Failed**
```bash
Trigger: systemd service inactive
Actions:
  1. Check logs for error
  2. Attempt restart (max 3 tries)
  3. If auto_restart enabled: restart immediately
  4. If restart succeeds: clear alert
  5. If restart fails: escalate alert to "high"
Result: Service recovered or human notified
```

**PyTorch Can't Access GPU**
```bash
Trigger: torch.cuda.is_available() = False
Actions:
  1. Check nvidia-smi works
  2. Check driver version
  3. Check CUDA toolkit installed
  4. Check PyTorch CUDA version matches driver
  5. Generate diagnostic report
Result: Alert with specific remediation steps
```

---

## Interactive Use

Launch Claude Code manually for custom tasks:

```bash
cd ~/sysadmin
claude --dangerously-skip-permissions
```

Example prompts:
- "Check the system and fix any critical issues"
- "Why is disk space high? Investigate and clean up"
- "My PyTorch can't see the GPU, debug this"
- "Add monitoring for my new Shiny app on port 4000"
- "Why did my training job crash last night?"
- "Review all production apps and restart any that are down"
- "My R package installation is failing, figure out why"

Claude Code reads CLAUDE.md and understands your system's context.

---

## Monitoring & Logs

### Web Dashboard (http://localhost:5050)
- Real-time system metrics
- Alert management by severity
- Claude Code activity log
- Recommendations
- Production app status
- Quick action buttons

### Activity Log
```bash
# Recent Claude actions
cat reports/$(hostname)/activity.log

# Watch live
tail -f reports/$(hostname)/activity.log
```

### System Log
```bash
# Helper script output
tail -f /var/log/sysadmin/sysadmin.log

# Today's actions
grep "$(date +%Y-%m-%d)" /var/log/sysadmin/sysadmin.log
```

### Generated Reports
```bash
# Latest comprehensive report
cat reports/$(hostname)/latest.md

# GPU environment
cat reports/$(hostname)/gpu-environment.txt

# Python environment
cat reports/$(hostname)/python-environment.txt

# R environment
cat reports/$(hostname)/r-environment.txt
```

---

## Cost/Benefit

### Time Investment

**Setup**: 5 minutes (one-time)
**Configuration**: 10 minutes (configure monitored apps)
**Maintenance**: ~0 minutes (it maintains itself)

**Total**: 15 minutes initial setup, then zero ongoing effort

### Time Savings

**Per incident prevented** (conservative estimates):
- Disk full: 30-120 min
- CUDA broken: 60-240 min
- Python environment issue: 30-120 min
- R package failure: 30-60 min
- Service crashed: 15-45 min
- Database issue: 15-45 min

**Typical system**: 1-2 incidents per week prevented

**Annual time saved**: 50-100+ hours

**ROI**: Astronomical

---

## What You Don't Need

- **A dedicated sysadmin** - Claude Code fills this role
- **DevOps expertise** - The system is self-maintaining
- **Manual monitoring** - Checks run automatically
- **Late night pages** - Problems fixed before you wake up
- **Deep Linux knowledge** - Claude Code has that covered
- **Hours debugging environments** - Automated detection and diagnosis

---

## What You Get

- **More uptime** - Problems caught and fixed early
- **Faster debugging** - Comprehensive diagnostics generated automatically
- **Better sleep** - No 3am alerts for fixable issues
- **Focus on work** - Not system administration
- **Confidence** - Your machine maintains itself
- **Documentation** - Every action logged and explained
- **Peace of mind** - Critical apps monitored 24/7

---

## Multi-Machine Support

Same repository works on all your machines:

```bash
# Workstation 1
cd ~/sysadmin && ./install.sh

# GPU server
cd ~/sysadmin && ./install.sh

# Analysis box
cd ~/sysadmin && ./install.sh
```

Each machine gets:
- Own dashboard (localhost:5050)
- Own reports directory
- Own alert tracking
- Own scheduled maintenance
- Entry in config/machines.yaml

One codebase, unlimited machines.

---

## Manual Operations

```bash
# Run checks now (don't wait for cron)
./claude-admin/run-hourly.sh
./claude-admin/run-daily.sh

# Use helper scripts directly
./scripts/check-gpu-environment.sh
./scripts/check-python-environments.sh
./scripts/check-r-environment.sh

# Test specific remediation
./scripts/remediation/clean-docker.sh
./scripts/remediation/rotate-large-logs.sh

# Dry-run mode (show what would be done)
DRY_RUN=1 ./scripts/daily-maintenance.sh

# Disable auto-updates
AUTO_UPDATE=0 ./scripts/daily-maintenance.sh
```

---

## Security Posture

**For developer workstations** (not public servers):

- Runs on localhost (dashboard not network-exposed)
- Behind firewall / VPN
- Full sudo access required for autonomous operation
- All actions logged for audit trail
- Sensitive operations flagged for human approval
- No data leaves your machine

**Philosophy**: Basic security hygiene, not paranoid hardening. These are development machines behind corporate firewalls, not DMZ servers.

---

## Support & Documentation

- **README.md** (this file) - Overview and quick start
- **CLAUDE.md** - Comprehensive context for Claude Code
- **PRINCIPLES.md** - Operating philosophy and priorities
- **COVERAGE_ANALYSIS.md** - What we check and why
- **IMPLEMENTATION_SUMMARY.md** - Technical implementation details
- **Dashboard** - http://localhost:5050 for visual monitoring

---

## Troubleshooting

### Dashboard not loading

```bash
sudo systemctl status sysadmin-dashboard.service
sudo journalctl -u sysadmin-dashboard.service -n 50
sudo systemctl restart sysadmin-dashboard.service
```

### Claude Code not found

```bash
which claude
# If not found, install from: https://claude.ai/code
```

### Cron jobs not running

```bash
crontab -l  # Verify cron jobs exist
grep CRON /var/log/syslog | tail -20  # Check execution log
./claude-admin/run-hourly.sh  # Test manual execution
```

### Need immediate help

```bash
cd ~/sysadmin
claude --dangerously-skip-permissions

# Tell Claude what's wrong, it will investigate and fix
```

---

## Updates

```bash
cd ~/sysadmin
git pull

# Restart dashboard if needed
sudo systemctl restart sysadmin-dashboard.service

# Cron jobs automatically use updated scripts
```

---

## Uninstallation

```bash
# Remove cron jobs
crontab -l | grep -v "claude-admin" | crontab -

# Stop dashboard
sudo systemctl stop sysadmin-dashboard.service
sudo systemctl disable sysadmin-dashboard.service
sudo rm /etc/systemd/system/sysadmin-dashboard.service

# Remove files
sudo rm -rf /var/log/sysadmin
rm -rf ~/sysadmin
```

---

## License

Personal system administration tool. Use and customize as needed.

---

## The Bottom Line

**You're not a sysadmin. You shouldn't have to be one.**

This tool handles the system administration work so you can focus on your actual job: developing ML models, analyzing data, writing code, running quantitative research.

Your time is valuable. Don't spend it debugging CUDA drivers, cleaning up disk space, or figuring out why R packages won't compile.

Let Claude Code handle it.

**Setup time**: 5 minutes
**Ongoing effort**: ~0 minutes
**Time saved**: 50-100+ hours/year
**ROI**: Worth it

Install it, configure your apps, then forget about system administration.

*That's the point.*
