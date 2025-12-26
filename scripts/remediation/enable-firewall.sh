#!/bin/bash
# Enable and configure UFW firewall with safe defaults

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"

enable_firewall() {
    if is_firewall_enabled; then
        log_info "Firewall is already enabled"
        clear_alert "firewall-disabled"
        return 0
    fi

    log_critical "Firewall is DISABLED - enabling with safe defaults"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would enable firewall with:"
        log_info "  - Default deny incoming"
        log_info "  - Default allow outgoing"
        log_info "  - Allow SSH from Tailscale network (100.64.0.0/10)"
        return 0
    fi

    # Configure defaults
    sudo ufw --force default deny incoming
    sudo ufw --force default allow outgoing

    # Allow SSH from Tailscale only (safe remote access)
    sudo ufw allow from 100.64.0.0/10 to any port 22 comment 'SSH from Tailscale'

    # Enable firewall
    sudo ufw --force enable

    log_info "Firewall enabled successfully"
    log_warning "Note: Only SSH from Tailscale network is allowed"
    log_warning "Add additional rules as needed for your services"

    clear_alert "firewall-disabled"
}

# Main execution
main() {
    check_sudo
    log_info "Checking firewall status"
    enable_firewall
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
