#!/bin/bash
# Network performance tuning for high-bandwidth connections
# Optimizes TCP buffers and network settings for modern internet speeds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"

# Check current network settings
check_current_settings() {
    log_info "Checking current network settings..."

    echo "Current TCP buffer sizes:"
    sysctl net.core.rmem_max net.core.wmem_max net.core.rmem_default net.core.wmem_default
    echo ""
    echo "Current TCP window sizes:"
    sysctl net.ipv4.tcp_rmem net.ipv4.tcp_wmem
    echo ""
    echo "Current TCP settings:"
    sysctl net.ipv4.tcp_window_scaling net.ipv4.tcp_timestamps net.ipv4.tcp_sack
}

# Apply optimized settings for high-bandwidth connections
apply_network_tuning() {
    log_info "Applying network performance tuning..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would apply the following settings:"
        cat <<'EOF'
# Increase TCP buffer sizes for high-bandwidth connections
net.core.rmem_max = 134217728          # 128MB max receive buffer
net.core.wmem_max = 134217728          # 128MB max send buffer
net.core.rmem_default = 16777216       # 16MB default receive buffer
net.core.wmem_default = 16777216       # 16MB default send buffer

# TCP window auto-tuning (min, default, max)
net.ipv4.tcp_rmem = 4096 87380 134217728    # Receive window
net.ipv4.tcp_wmem = 4096 65536 134217728    # Send window

# Enable TCP window scaling (required for high-bandwidth)
net.ipv4.tcp_window_scaling = 1

# Enable TCP timestamps for better RTT estimation
net.ipv4.tcp_timestamps = 1

# Enable selective acknowledgements
net.ipv4.tcp_sack = 1

# Increase max syn backlog for busy servers
net.ipv4.tcp_max_syn_backlog = 8192

# Increase network device backlog
net.core.netdev_max_backlog = 5000

# Enable TCP Fast Open (reduces latency)
net.ipv4.tcp_fastopen = 3

# Increase the maximum amount of option memory buffers
net.core.optmem_max = 65536
EOF
        return 0
    fi

    # Create sysctl configuration file
    local sysctl_conf="/etc/sysctl.d/99-network-performance.conf"

    log_info "Creating $sysctl_conf..."

    sudo tee "$sysctl_conf" > /dev/null <<'EOF'
# Network Performance Tuning for High-Bandwidth Connections
# Optimized for gigabit+ internet and modern workloads (git, docker, ssh)
# Applied by Claude Code Sysadmin Assistant

# Increase TCP buffer sizes for high-bandwidth connections
# Default Linux settings are optimized for slow connections from the 1990s
net.core.rmem_max = 134217728          # 128MB max receive buffer
net.core.wmem_max = 134217728          # 128MB max send buffer
net.core.rmem_default = 16777216       # 16MB default receive buffer
net.core.wmem_default = 16777216       # 16MB default send buffer

# TCP window auto-tuning (min, default, max in bytes)
# Allows TCP to automatically scale the window size
net.ipv4.tcp_rmem = 4096 87380 134217728    # Receive: 4KB min, 85KB default, 128MB max
net.ipv4.tcp_wmem = 4096 65536 134217728    # Send: 4KB min, 64KB default, 128MB max

# Enable TCP window scaling (RFC 1323)
# Required for windows larger than 64KB
net.ipv4.tcp_window_scaling = 1

# Enable TCP timestamps (RFC 1323)
# Improves RTT estimation and protects against wrapped sequence numbers
net.ipv4.tcp_timestamps = 1

# Enable selective acknowledgements (SACK)
# Improves performance when packets are lost
net.ipv4.tcp_sack = 1

# Increase max SYN backlog for handling connection bursts
net.ipv4.tcp_max_syn_backlog = 8192

# Increase network device backlog queue
# Helps prevent packet drops under load
net.core.netdev_max_backlog = 5000

# Enable TCP Fast Open (TFO)
# Reduces latency for repeat connections (git, docker, ssh)
# 1 = client only, 2 = server only, 3 = both
net.ipv4.tcp_fastopen = 3

# Increase maximum amount of option memory buffers
net.core.optmem_max = 65536
EOF

    # Apply settings immediately
    log_info "Applying settings with sysctl..."
    sudo sysctl -p "$sysctl_conf"

    log_info "✓ Network tuning applied successfully"
    log_info "Settings will persist across reboots"
}

# Test if settings need updating
needs_tuning() {
    local current_rmem_max=$(sysctl -n net.core.rmem_max)
    local current_wmem_max=$(sysctl -n net.core.wmem_max)

    # Check if buffers are smaller than our target (128MB)
    if [[ $current_rmem_max -lt 134217728 ]] || [[ $current_wmem_max -lt 134217728 ]]; then
        return 0  # Needs tuning
    fi

    return 1  # Already tuned
}

# Main execution
main() {
    log_info "==================== NETWORK TUNING ===================="

    check_current_settings

    if needs_tuning; then
        log_info "Network settings are suboptimal for high-bandwidth connections"
        apply_network_tuning
    else
        log_info "✓ Network settings already optimized"
    fi

    log_info "==================== NETWORK TUNING COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
