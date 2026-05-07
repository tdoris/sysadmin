# System Review Report
**Generated**: 2025-12-23
**Hostname**: tfd4090
**User**: jim

---

## System Information
- **OS**: Ubuntu 24.04.3 LTS (Noble Numbat)
- **Kernel**: 6.14.0-37-generic (unusually new - likely from mainline/testing)
- **Uptime**: 5 days, 27 minutes
- **Load Average**: 0.19, 0.31, 0.40 (very light)
- **Disk Usage**: 1.1TB / 3.6TB (31%) - Good

---

## 🔴 Critical Issues

### 1. Firewall Disabled (SECURITY RISK)
**Status**: `ufw status: inactive`

Multiple services are exposed to the network without firewall protection:
- **Port 8080**: Open WebUI (LLM interface) - exposed to 0.0.0.0
- **Port 8086**: InfluxDB database - exposed to all interfaces
- **Port 8443**: LXD API - exposed to all interfaces
- **Port 3389**: xrdp (Remote Desktop) - exposed to network
- **Port 3390**: gnome-remote-desktop - exposed to network

**Immediate Action Required**:
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 100.64.0.0/10 to any port 22  # Tailscale only
sudo ufw enable
```

### 2. Reboot Required
**Reason**: gnome-shell update requires reboot
**File**: `/var/run/reboot-required` exists

**Action**:
```bash
sudo reboot
```

### 3. No Backup Solution Configured
**Risk**: No protection against data loss

**Current State**:
- No backup tools installed (timeshift, restic, borgbackup, duplicity)
- Only dpkg-db-backup (package database only)
- No user data backups configured

**Should backup**:
- Home directory (/home/jim)
- System configuration (/etc)
- VM disks (/var/lib/libvirt/images - 21GB)
- Important data

**Recommendations**:
- Timeshift (system snapshots)
- Restic (encrypted cloud backups)
- Borgbackup (deduplicated backups)

---

## ⚠️ High Priority Issues

### 1. System Updates Needed
**88 packages** need updating, including:
- systemd (security updates: 255.4-1ubuntu8.11 → 255.4-1ubuntu8.12)
- NVIDIA drivers (580.95.05-0ubuntu0.24.04.2 → 580.95.05-0ubuntu0.24.04.3)
- GNOME Shell components
- VS Code (1.106.3 → 1.107.1)
- Google Chrome (143.0.7499.40 → 143.0.7499.169)
- QEMU/KVM packages
- PipeWire audio system

**Action**:
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Services That May Not Be Needed

**xrdp + xrdp-sesman** (Enabled & Running):
- Remote Desktop Protocol servers
- Listening on ports 3389 and 3390
- Were likely set up for the deleted desktop-container experiment
- **Action**: Disable if not actively using remote desktop
  ```bash
  sudo systemctl disable --now xrdp xrdp-sesman gnome-remote-desktop
  ```

**InfluxDB** (Enabled & Running):
- Time-series database listening on port 8086
- Currently exposed to all interfaces
- **Question**: Is this being used for monitoring/metrics?
- **Action if not needed**:
  ```bash
  sudo systemctl disable --now influxdb
  ```

---

## 💡 Medium Priority - Cleanup Opportunities

### 1. Docker Images (151GB Recoverable)
**Current State**:
```
Images: 56 total, only 3 active
Reclaimable: 151.3GB (96% of image storage)
```

**Active Containers**:
- ✅ open-webui (running, healthy) - LLM web interface
- ✅ watchtower (running, auto-updates containers)
- ❌ faster-whisper-server (exited 13 months ago) - can be removed

**Action**:
```bash
sudo docker image prune -a  # Will ask for confirmation
sudo docker rm faster-whisper-server  # Remove dead container
```

### 2. Old Kernel Configs & Residual Packages
**62+ residual kernel-related configs** from old versions:
- 6.8.0-45 through 6.8.0-52 (6 kernels)
- 6.11.0-19 through 6.11.0-29 (7 kernels)
- 6.14.0-24, 6.14.0-27 (2 kernels)
- Currently running: **6.14.0-37** ✓

**Also includes**:
- Old desktop environment configs (Unity indicators, lightdm)
- Old NVIDIA driver configs (nvidia-550, switched to nvidia-580)

**Action**:
```bash
sudo apt purge '~c'  # Remove all residual configs
sudo apt autoremove  # Remove orphaned packages
```

### 3. System Logs
- Journal logs: **2.0GB**
- Total /var/log: **2.6GB**

**Action** (optional):
```bash
sudo journalctl --vacuum-time=30d  # Keep only last 30 days
```

---

## ✅ Security Assessment

### Good Security Practices
- ✅ Very few failed login attempts (only 1 invalid SSH attempt from Tailscale network in July)
- ✅ Single sudo user (jim) - proper access control
- ✅ All sudo usage is from legitimate user
- ✅ Only 3 accounts with shell access (root, jim, postgres)
- ✅ Recent logins all from owner (jim)
- ✅ Last remote login from 100.93.121.22 (Tailscale) on Aug 6

### User Accounts
- **root**: UID 0, /root, /bin/bash
- **jim**: UID 1000, /home/jim, /bin/bash (sudo group member)
- **postgres**: UID 127, /var/lib/postgresql, /bin/bash

### SSH Configuration
- Managed by systemd socket activation
- Listening on port 22 (both IPv4 and IPv6)
- No suspicious configuration found

---

## 📊 System Performance & Health

### Excellent Performance Metrics
- **Memory**: 15GB / 124GB used (12%)
- **Swap**: 0B / 8GB used (0% - excellent)
- **CPU Temperatures**: 30-61°C (all within normal range)
- **GPU**: NVIDIA RTX (24GB VRAM)
  - Model: Likely RTX 4090 or similar
  - Temperature: 40°C
  - Utilization: 31%
  - VRAM usage: 1041 MiB / 24564 MiB (4%)

### Disk Health
- **Note**: SMART monitoring tools not installed
- **Recommendation**: Install smartmontools
  ```bash
  sudo apt install smartmontools
  sudo smartctl -a /dev/nvme0n1
  ```

---

## 🖥️ Running Services Summary

### Desktop/Remote Access
- ✅ gdm.service - GNOME Display Manager
- ⚠️ gnome-remote-desktop.service - GNOME RDP (consider disabling)
- ⚠️ xrdp.service, xrdp-sesman.service - RDP server (consider disabling)

### VPN/Network
- ✅ strongswan-starter.service - IPsec VPN (for Versa SASE)
- ✅ versa-sase.service - Versa SASE DBus Service
- ✅ tailscaled.service - Tailscale VPN
- ✅ NetworkManager.service - Network management
- ❓ ctxcwalogd.service - Citrix Log Daemon

### Containers/Virtualization
- ✅ docker.service, containerd.service - Docker
- ✅ libvirtd.service - KVM/QEMU virtualization (running Windows 11 VM)
- ✅ snap.lxd.daemon.service - LXD (containers deleted, but daemon still running)

### Databases/Services
- ⚠️ influxdb.service - InfluxDB time-series database (check if needed)
- ✅ ollama.service - Ollama (local LLM service, localhost only)

### Standard System Services
- ✅ bluetooth.service, ModemManager.service, cups.service
- ✅ systemd-resolved.service, systemd-timesyncd.service
- ✅ unattended-upgrades.service

---

## 🌐 Network Listening Services

### Localhost Only (Safe)
- 127.0.0.1:11434 - Ollama (LLM)
- 127.0.0.1:5900 - QEMU VNC (Windows 11 VM)
- 127.0.0.1:631 - CUPS (printing)
- 127.0.0.1:40829 - containerd
- 127.0.0.53:53 - systemd-resolved (DNS)

### Network Exposed (Review Required)
- 0.0.0.0:22 - SSH (systemd)
- 0.0.0.0:8080 - **Open WebUI** (Python/uvicorn) ⚠️
- *:8086 - **InfluxDB** ⚠️
- *:8443 - **LXD API** ⚠️
- *:3389 - **xrdp** ⚠️
- *:3390 - **gnome-remote-desktop** ⚠️

### Bridge/Virtual Networks
- 192.168.122.1:53 - libvirt dnsmasq (virbr0)
- 10.85.165.1:53 - LXD dnsmasq (lxdbr0, no containers)

---

## 🔄 Scheduled Tasks

### Cron Jobs
- **Root crontab**: None
- **User (jim) crontab**: None
- **System cron jobs**: Standard (apt-daily, logrotate, man-db, plocate, sysstat)

### Active Systemd Timers
- ✅ sysstat-collect.timer (every 10 min) - system statistics
- ✅ apt-daily.timer, apt-daily-upgrade.timer - automatic updates
- ✅ fwupd-refresh.timer - firmware updates
- ✅ logrotate.timer - log rotation
- ✅ dpkg-db-backup.timer - package database backup
- ✅ anacron.timer, man-db.timer, plocate-updatedb.timer
- ✅ systemd-tmpfiles-clean.timer
- ✅ e2scrub_all.timer - filesystem scrubbing
- ✅ fstrim.timer - SSD TRIM operations

---

## 💾 Virtual Machines & Containers

### Running VMs
- **win11** (libvirt/KVM):
  - Status: Running
  - Disk: /var/lib/libvirt/images/win11-1.qcow2 (129GB virtual, 21GB actual)
  - VNC: localhost:5900
  - ISO mounts: virtio-win.iso (mounted twice on sdb, sdc)

### Deleted VMs/Disks
- ✅ Removed: /var/lib/libvirt/images/win11.qcow2 (old disk, 129GB reclaimed)

### Docker Containers
- **open-webui**: Running, healthy, 33 hours uptime
- **watchtower**: Running, healthy, auto-updates containers
- **faster-whisper-server**: Exited 13 months ago (can be removed)

### LXD Containers
- ✅ Deleted: my-container (~708 MB reclaimed)
- ✅ Deleted: desktop-container (~3.0 GB reclaimed)
- Total reclaimed: ~3.7 GB

---

## 📦 Package Management

### Installed Packages
- **Manually installed**: 229 packages
- **Total system packages**: ~2,300+ packages

### Snap Packages
- bare, core22, core24 (base snaps)
- firefox (146.0.1)
- gnome-42-2204, gnome-46-2404
- lxd (5.21.4)
- btop-desktop (system monitor)
- nvtop (NVIDIA GPU monitor)
- snap-store, firmware-updater

---

## 🎯 Priority Action Plan

### Immediate (Today)
1. **Enable firewall** - Critical security issue
2. **Disable unnecessary RDP services** - Reduce attack surface
3. **Secure/disable InfluxDB** if not needed

### High Priority (This Week)
4. **Update system** (88 packages)
5. **Reboot** to apply updates
6. **Set up backup solution** - Critical for data protection
7. **Clean residual configs** - Free space, clean system

### Medium Priority (This Month)
8. **Clean Docker images** - Recover 151GB
9. **Install SMART monitoring** - Monitor disk health
10. **Review and optimize exposed services**

---

## 📋 Useful Commands Reference

### System Maintenance
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clean residual configs
sudo apt purge '~c'
sudo apt autoremove

# Clean old logs
sudo journalctl --vacuum-time=30d

# Check what needs reboot
cat /var/run/reboot-required.pkgs
```

### Docker Maintenance
```bash
# View Docker space usage
sudo docker system df

# Clean unused images
sudo docker image prune -a

# Remove stopped containers
sudo docker container prune
```

### Service Management
```bash
# Disable services
sudo systemctl disable --now SERVICE_NAME

# Check service status
sudo systemctl status SERVICE_NAME

# List all running services
systemctl list-units --type=service --state=running
```

### Network & Security
```bash
# Enable firewall
sudo ufw enable

# Check firewall status
sudo ufw status verbose

# View listening ports
sudo ss -tlnp

# Check failed login attempts
sudo lastb
```

### VM Management
```bash
# List VMs
sudo virsh list --all

# VM info
sudo virsh dominfo win11

# Start/stop VM
sudo virsh start win11
sudo virsh shutdown win11
```

---

## 📝 Notes

- System is generally well-maintained with good performance
- Main concerns are security (firewall) and lack of backups
- Kernel version (6.14.x) is unusually new for Ubuntu 24.04 LTS (typically 6.8.x)
  - May be from ubuntu-mainline-kernel PPA or manual installation
  - Consider reverting to LTS kernel if stability is a concern
- NVIDIA driver 580 is relatively new (580.95.05)
- System has significant resources: 124GB RAM, 24GB VRAM, 3.6TB storage
- Appears to be a workstation/development machine with ML/AI capabilities (Ollama, Open WebUI, GPU)

---

**Review completed**: 2025-12-23 15:46 GMT
**Next review recommended**: 2026-01-23 (1 month)
