#!/bin/bash
# Daily comprehensive system maintenance
# Includes updates, security checks, cleanup, and detailed reporting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
AUTO_UPDATE="${AUTO_UPDATE:-1}"  # Set to 0 to disable auto-updates
AUTO_REMEDIATE="${AUTO_REMEDIATE:-1}"  # Set to 0 to disable auto-remediation

# Run hourly checks first
run_hourly_checks() {
    log_info "Running hourly checks..."
    "$SCRIPT_DIR/hourly-check.sh"
}

# Check for system updates
check_system_updates() {
    log_info "Checking for system updates..."

    sudo apt-get update -qq

    local update_count=$(get_update_count)
    local security_count=$(get_security_update_count)

    log_info "Available updates: $update_count (security: $security_count)"

    if [[ $update_count -gt 0 ]]; then
        if [[ $security_count -gt 0 ]]; then
            log_warning "$security_count security updates available"
            update_alerts "high" "security-updates" \
                "Security Updates Available" \
                "$security_count security updates are available"

            if [[ $AUTO_UPDATE -eq 1 && $DRY_RUN -eq 0 ]]; then
                log_info "Auto-update enabled, applying security updates..."
                sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
                log_info "Security updates applied"
                clear_alert "security-updates"
                clear_alert "updates-pending"
            fi
        else
            update_alerts "medium" "updates-pending" \
                "System Updates Available" \
                "$update_count package updates are available"
        fi
    else
        log_info "✓ System is up to date"
        clear_alert "security-updates"
        clear_alert "updates-pending"
    fi
}

# Check if reboot is required
check_reboot_required() {
    log_info "Checking if reboot is required..."

    if is_reboot_required; then
        local packages=$(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' ' || echo "unknown packages")
        log_warning "System reboot is required"
        log_info "Packages requiring reboot: $packages"

        update_alerts "high" "reboot-required" \
            "Reboot Required" \
            "System reboot needed for: $packages"
    else
        log_info "✓ No reboot required"
        clear_alert "reboot-required"
    fi
}

# Clean up old kernels
cleanup_old_kernels() {
    log_info "Checking for old kernels..."

    # Get current kernel
    local current_kernel=$(uname -r)
    log_info "Current kernel: $current_kernel"

    # List installed kernels
    local installed_kernels=$(dpkg -l | grep -E 'linux-image-[0-9]' | awk '{print $2}' || echo "")

    if [[ -z "$installed_kernels" ]]; then
        log_debug "No extra kernels found"
        return 0
    fi

    local kernel_count=$(echo "$installed_kernels" | wc -l)
    log_info "Installed kernels: $kernel_count"

    if [[ $kernel_count -gt 3 ]]; then
        log_info "Multiple old kernels detected"

        if [[ $AUTO_REMEDIATE -eq 1 && $DRY_RUN -eq 0 ]]; then
            log_info "Cleaning old kernels (keeping current + 1 previous)..."
            sudo apt-get autoremove -y --purge
            log_info "Old kernels removed"
        else
            log_info "[DRY RUN] Would remove old kernels"
        fi
    fi

    # Clean residual configs
    local residual=$(dpkg -l | grep "^rc" | wc -l)
    if [[ $residual -gt 0 ]]; then
        log_info "Found $residual residual package configs"

        if [[ $AUTO_REMEDIATE -eq 1 && $DRY_RUN -eq 0 ]]; then
            log_info "Cleaning residual configs..."
            sudo apt-get purge -y $(dpkg -l | grep "^rc" | awk '{print $2}')
            log_info "Residual configs cleaned"
        fi
    fi
}

# Check and clean Docker
check_docker_cleanup() {
    log_info "Checking Docker cleanup..."
    "$SCRIPT_DIR/remediation/clean-docker.sh"
}

# Check and rotate large logs
check_log_rotation() {
    log_info "Checking for large logs..."
    "$SCRIPT_DIR/remediation/rotate-large-logs.sh"
}

# Check for orphaned packages
check_orphaned_packages() {
    log_info "Checking for orphaned packages..."

    local orphaned=$(apt-mark showauto | wc -l)
    log_info "Auto-installed packages: $orphaned"

    # Check for packages that are no longer needed
    if [[ $AUTO_REMEDIATE -eq 1 && $DRY_RUN -eq 0 ]]; then
        log_info "Running autoremove to clean orphaned packages..."
        sudo apt-get autoremove -y
        log_info "Orphaned packages cleaned"
    else
        log_info "[DRY RUN] Would clean orphaned packages"
    fi
}

# Check hardware health (SMART status)
check_hardware_health() {
    log_info "Checking hardware health..."

    if command -v smartctl &>/dev/null; then
        # Find physical disks
        local disks=$(lsblk -d -n -o NAME,TYPE | grep disk | awk '{print $1}')

        for disk in $disks; do
            log_info "Checking /dev/$disk..."

            local smart_status=$(sudo smartctl -H /dev/$disk 2>/dev/null | grep "SMART overall-health" | awk '{print $NF}' || echo "UNKNOWN")

            if [[ "$smart_status" == "PASSED" ]]; then
                log_info "✓ /dev/$disk health: PASSED"
            elif [[ "$smart_status" != "UNKNOWN" ]]; then
                log_critical "Disk /dev/$disk SMART status: $smart_status"
                update_alerts "critical" "disk-health-$disk" \
                    "Disk Health Warning" \
                    "/dev/$disk SMART status is $smart_status - check immediately"
            fi
        done
    else
        log_debug "smartctl not installed, skipping SMART checks"
    fi
}

# Check for broken symlinks in common paths
check_broken_symlinks() {
    log_info "Checking for broken symlinks..."

    local broken_links=""
    for path in /usr/bin /usr/local/bin /opt "$HOME/.local/bin"; do
        if [[ -d "$path" ]]; then
            local found=$(find "$path" -xtype l 2>/dev/null | head -10)
            if [[ -n "$found" ]]; then
                broken_links="$broken_links$found\n"
            fi
        fi
    done

    if [[ -n "$broken_links" ]]; then
        log_warning "Found broken symlinks:"
        echo -e "$broken_links" | head -10 | while read -r link; do
            if [[ -n "$link" ]]; then
                log_warning "  $link"
            fi
        done

        update_alerts "info" "broken-symlinks" \
            "Broken Symlinks Detected" \
            "Found broken symlinks in system paths"
    else
        log_info "✓ No broken symlinks in common paths"
        clear_alert "broken-symlinks"
    fi
}

# Check and clean temp directories
check_temp_directories() {
    log_info "Checking temp directories..."

    local tmp_size=$(du -sm /tmp 2>/dev/null | awk '{print $1}' || echo "0")
    local var_tmp_size=$(du -sm /var/tmp 2>/dev/null | awk '{print $1}' || echo "0")

    log_info "/tmp size: ${tmp_size}MB"
    log_info "/var/tmp size: ${var_tmp_size}MB"

    if [[ $tmp_size -gt 10240 ]]; then  # > 10GB
        log_warning "/tmp is using ${tmp_size}MB"

        if [[ $AUTO_REMEDIATE -eq 1 && $DRY_RUN -eq 0 ]]; then
            log_info "Cleaning files older than 7 days from /tmp..."
            sudo find /tmp -type f -mtime +7 -delete 2>/dev/null || true
            log_info "/tmp cleaned"
        fi
    fi

    if [[ $var_tmp_size -gt 10240 ]]; then  # > 10GB
        log_warning "/var/tmp is using ${var_tmp_size}MB"

        if [[ $AUTO_REMEDIATE -eq 1 && $DRY_RUN -eq 0 ]]; then
            log_info "Cleaning files older than 7 days from /var/tmp..."
            sudo find /var/tmp -type f -mtime +7 -delete 2>/dev/null || true
            log_info "/var/tmp cleaned"
        fi
    fi
}

# Generate comprehensive system report
generate_system_report() {
    log_info "Generating comprehensive system report..."

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$REPORTS_DIR/latest.md"
    local history_file="$REPORTS_DIR/history/$(date +%Y-%m-%d)-daily-report.md"

    mkdir -p "$(dirname "$history_file")"

    cat > "$report_file" <<EOF
# System Report: $HOSTNAME
**Generated**: $timestamp
**Type**: Daily Maintenance Report

---

## System Status

- **OS**: $(lsb_release -d | cut -f2-)
- **Kernel**: $(uname -r)
- **Uptime**: $(uptime -p)
- **Load Average**: $(get_load_average)

---

## Resource Usage

- **Disk Usage**: $(check_disk_space /)% (root filesystem)
- **Memory Usage**: $(get_memory_usage)%
- **Swap Usage**: $(free | awk 'NR==3 {printf "%.0f%%", $3/$2 * 100}' 2>/dev/null || echo "0%")

### Disk Space Details
\`\`\`
$(df -h / /home /var 2>/dev/null | head -5)
\`\`\`

---

## Updates & Maintenance

- **Available Updates**: $(get_update_count) packages
- **Security Updates**: $(get_security_update_count) packages
- **Reboot Required**: $(is_reboot_required && echo "YES" || echo "No")
- **Old Kernels**: $(dpkg -l | grep -c "^ii.*linux-image-[0-9]" || echo "0") installed

## Hardware Health

- **Disk SMART Status**: $(command -v smartctl &>/dev/null && echo "Monitored" || echo "Not available")
- **System Temperatures**: $(command -v sensors &>/dev/null && sensors 2>/dev/null | grep -E "Core |temp" | grep -oP '\+\d+\.\d+°C' | head -1 || echo "N/A")

---

## Services

### Failed Services
$(
    local failed=$(get_failed_services)
    if [[ -n "$failed" ]]; then
        echo "\`\`\`"
        echo "$failed"
        echo "\`\`\`"
    else
        echo "None ✓"
    fi
)

### Active Docker Containers
$(
    if command -v docker &>/dev/null; then
        echo "\`\`\`"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.State}}" 2>/dev/null || echo "No containers"
        echo "\`\`\`"
    else
        echo "Docker not installed"
    fi
)

---

## Production Applications

$(
    if [[ -f "$CONFIG_DIR/monitored-apps.yaml" ]]; then
        python3 -c "
import yaml
import sys

try:
    with open('$CONFIG_DIR/monitored-apps.yaml', 'r') as f:
        data = yaml.safe_load(f)
        apps = data.get('apps', {})
        if apps:
            print(f'Monitoring {len(apps)} application(s)')
            for name in apps.keys():
                print(f'  - {name}')
        else:
            print('No applications configured')
except Exception as e:
    print('Unable to read apps config')
" 2>/dev/null || echo "No apps configured"
    else
        echo "No apps configured"
    fi
)

See alerts.json for detailed status of each application.

---

## Storage Analysis

### Docker Usage
$(
    if command -v docker &>/dev/null; then
        echo "\`\`\`"
        docker system df 2>/dev/null || echo "Docker not running"
        echo "\`\`\`"
    else
        echo "Docker not installed"
    fi
)

### Large Log Files (>100MB)
\`\`\`
$(sudo find /var/log -type f -size +100M -exec ls -lh {} \; 2>/dev/null | awk '{print $9, $5}' || echo "None found")
\`\`\`

---

## Alerts Summary

$(
    if [[ -f "$REPORTS_DIR/alerts.json" ]]; then
        python3 -c "
import json
import sys

try:
    with open('$REPORTS_DIR/alerts.json', 'r') as f:
        data = json.load(f)
        critical = len(data.get('critical', []))
        high = len(data.get('high', []))
        medium = len(data.get('medium', []))
        print(f'- Critical: {critical}')
        print(f'- High: {high}')
        print(f'- Medium: {medium}')

        if critical > 0:
            print('\n### Critical Alerts')
            for alert in data.get('critical', []):
                print(f\"- **{alert['title']}**: {alert['description']}\")

        if high > 0:
            print('\n### High Priority Alerts')
            for alert in data.get('high', []):
                print(f\"- **{alert['title']}**: {alert['description']}\")
except Exception as e:
    print('Unable to read alerts')
" 2>/dev/null
    else
        echo "No alerts file found"
    fi
)

---

## Maintenance Actions Taken

$(grep "$(date +%Y-%m-%d)" "$LOG_DIR/sysadmin.log" 2>/dev/null | grep -E "cleaned|rotated|restarted|applied|enabled" | tail -20 || echo "No maintenance actions today")

---

**Full logs**: /var/log/sysadmin/sysadmin.log
**Next maintenance**: $(date -d "tomorrow 2am" '+%Y-%m-%d 02:00')
EOF

    # Copy to history
    cp "$report_file" "$history_file"

    log_info "Report generated: $report_file"
    log_info "History saved: $history_file"
}

# Main execution
main() {
    log_info "==================== DAILY MAINTENANCE START ===================="
    log_info "Hostname: $HOSTNAME"
    log_info "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "Auto-update: $AUTO_UPDATE"
    log_info "Auto-remediate: $AUTO_REMEDIATE"
    log_info "Dry-run: $DRY_RUN"

    # Ensure directories exist
    mkdir -p "$REPORTS_DIR/history"

    # Run all checks and maintenance
    run_hourly_checks
    check_system_updates
    check_reboot_required
    cleanup_old_kernels
    check_orphaned_packages
    check_docker_cleanup
    check_log_rotation
    check_hardware_health
    check_broken_symlinks
    check_temp_directories

    # Generate comprehensive report
    generate_system_report

    log_info "==================== DAILY MAINTENANCE COMPLETE ===================="

    # Print summary
    echo ""
    echo "Daily Maintenance Summary"
    echo "========================="
    echo "Disk Usage: $(check_disk_space /)%"
    echo "Memory Usage: $(get_memory_usage)%"
    echo "Updates Available: $(get_update_count)"
    echo "Critical Alerts: $(python3 -c "import json; f=open('$REPORTS_DIR/alerts.json'); d=json.load(f); print(len(d.get('critical',[])))" 2>/dev/null || echo "?")"
    echo ""
    echo "Full report: $REPORTS_DIR/latest.md"
    echo "Logs: $LOG_DIR/sysadmin.log"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
