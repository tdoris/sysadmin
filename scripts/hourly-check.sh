#!/bin/bash
# Hourly system health checks
# Quick checks for critical issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"

# Check disk space and auto-remediate if critical
check_disk_space_critical() {
    log_info "Checking disk space..."

    local usage=$(check_disk_space "/")
    log_info "Root disk usage: ${usage}%"

    if [[ $usage -gt 90 ]]; then
        log_critical "Disk space critically low: ${usage}%"
        update_alerts "critical" "disk-space-critical" \
            "Disk Space Critical" \
            "Root filesystem is ${usage}% full"

        # Auto-remediate: clean logs
        if [[ $DRY_RUN -eq 0 ]]; then
            log_info "Attempting automatic remediation..."

            # Rotate large logs
            SIZE_THRESHOLD_MB=500 "$SCRIPT_DIR/remediation/rotate-large-logs.sh"

            # Clean Docker if available
            SIZE_THRESHOLD_GB=100 "$SCRIPT_DIR/remediation/clean-docker.sh"

            # Clean journal logs
            log_info "Cleaning journal logs (keeping last 7 days)"
            sudo journalctl --vacuum-time=7d

            # Clean apt cache
            log_info "Cleaning apt cache"
            sudo apt-get clean

            # Check new usage
            local new_usage=$(check_disk_space "/")
            log_info "Disk usage after cleanup: ${new_usage}%"

            if [[ $new_usage -lt 85 ]]; then
                clear_alert "disk-space-critical"
                update_alerts "info" "disk-space-cleaned" \
                    "Disk Space Cleaned" \
                    "Reduced from ${usage}% to ${new_usage}%" \
                    "resolved"
            fi
        fi
    elif [[ $usage -gt 80 ]]; then
        log_warning "Disk space high: ${usage}%"
        update_alerts "medium" "disk-space-high" \
            "Disk Space High" \
            "Root filesystem is ${usage}% full"
    else
        clear_alert "disk-space-critical"
        clear_alert "disk-space-high"
    fi
}

# Check memory usage
check_memory_usage_critical() {
    log_info "Checking memory usage..."

    local mem_usage=$(get_memory_usage)
    log_info "Memory usage: ${mem_usage}%"

    if [[ $mem_usage -gt 90 ]]; then
        log_critical "Memory usage critically high: ${mem_usage}%"
        update_alerts "critical" "memory-critical" \
            "Memory Usage Critical" \
            "System memory is ${mem_usage}% full"

        # Log top memory consumers
        log_info "Top memory consumers:"
        ps aux --sort=-%mem | head -6 | sudo tee -a "$LOG_DIR/sysadmin.log" >/dev/null
    elif [[ $mem_usage -gt 80 ]]; then
        log_warning "Memory usage high: ${mem_usage}%"
        update_alerts "medium" "memory-high" \
            "Memory Usage High" \
            "System memory is ${mem_usage}% full"
    else
        clear_alert "memory-critical"
        clear_alert "memory-high"
    fi
}

# Check critical services
check_critical_services() {
    log_info "Checking critical services..."

    local failed_services=$(get_failed_services)

    if [[ -n "$failed_services" ]]; then
        log_error "Failed services detected:"
        echo "$failed_services" | while read -r service; do
            log_error "  - $service"

            # Attempt to restart non-critical failed services
            if [[ $DRY_RUN -eq 0 ]]; then
                case "$service" in
                    ssh.service|sshd.service|network*.service)
                        log_warning "Not auto-restarting critical service: $service"
                        ;;
                    *)
                        log_info "Attempting to restart $service"
                        restart_service_safe "$service" || true
                        ;;
                esac
            fi
        done

        update_alerts "high" "failed-services" \
            "Failed Services" \
            "$(echo "$failed_services" | wc -l) services have failed"
    else
        log_info "✓ No failed services"
        clear_alert "failed-services"
    fi
}

# Check firewall status
check_firewall_status() {
    log_info "Checking firewall status..."

    if ! is_firewall_enabled; then
        log_critical "Firewall is DISABLED"
        update_alerts "critical" "firewall-disabled" \
            "Firewall Disabled" \
            "UFW firewall is not active - system is exposed"

        # Don't auto-enable firewall in hourly check (might break things)
        # This is handled in daily maintenance
    else
        log_info "✓ Firewall is enabled"
        clear_alert "firewall-disabled"
    fi
}

# Check production apps
check_production_apps() {
    log_info "Checking production applications..."
    "$SCRIPT_DIR/check-prod-apps.sh"
}

# Check for zombie processes
check_zombie_processes() {
    log_info "Checking for zombie processes..."

    local zombies=$(get_zombie_processes)

    if [[ -n "$zombies" ]]; then
        log_warning "Zombie processes detected:"
        echo "$zombies" | while read -r pid cmd; do
            log_warning "  PID $pid: $cmd"
        done

        update_alerts "medium" "zombie-processes" \
            "Zombie Processes" \
            "$(echo "$zombies" | wc -l) zombie processes detected"
    else
        clear_alert "zombie-processes"
    fi
}

# Generate quick summary
generate_summary() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat > "$REPORTS_DIR/hourly-summary.txt" <<EOF
Hourly Check Summary
Generated: $timestamp
Hostname: $HOSTNAME

Disk Usage: $(check_disk_space /)%
Memory Usage: $(get_memory_usage)%
Load Average: $(get_load_average)
Firewall: $(is_firewall_enabled && echo "Enabled" || echo "DISABLED")

See alerts.json for detailed issues.
See /var/log/sysadmin/sysadmin.log for full log.
EOF

    log_info "Summary written to $REPORTS_DIR/hourly-summary.txt"
}

# Main execution
main() {
    log_info "==================== HOURLY CHECK START ===================="
    log_info "Hostname: $HOSTNAME"
    log_info "Time: $(date '+%Y-%m-%d %H:%M:%S')"

    # Ensure reports directory exists
    mkdir -p "$REPORTS_DIR"

    # Run checks
    check_disk_space_critical
    check_memory_usage_critical
    check_critical_services
    check_firewall_status
    check_production_apps
    check_zombie_processes

    # Generate summary
    generate_summary

    log_info "==================== HOURLY CHECK COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
