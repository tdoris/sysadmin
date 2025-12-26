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
    echo ""
    echo "Congestion control:"
    sysctl net.ipv4.tcp_congestion_control net.ipv4.tcp_available_congestion_control
    echo ""
    echo "TCP keepalive settings:"
    sysctl net.ipv4.tcp_keepalive_time net.ipv4.tcp_keepalive_intvl net.ipv4.tcp_keepalive_probes
}

# Apply optimized settings for high-bandwidth connections
apply_network_tuning() {
    log_info "Applying network performance tuning..."

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would apply the following settings:"
        cat <<'EOF'
# Congestion Control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP Buffer Sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# TCP Performance Features
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fastopen = 3

# TCP Keepalive (faster dead connection detection)
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 3

# Connection Handling
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
EOF
        return 0
    fi

    # Load BBR module if not already loaded
    log_info "Loading tcp_bbr kernel module..."
    sudo modprobe tcp_bbr 2>/dev/null || log_warning "Could not load BBR module (may already be built-in)"

    # Create sysctl configuration file
    local sysctl_conf="/etc/sysctl.d/99-network-performance.conf"

    log_info "Creating $sysctl_conf..."

    sudo tee "$sysctl_conf" > /dev/null <<'EOF'
# Network Performance Tuning for High-Bandwidth Connections
# Optimized for gigabit+ internet and modern workloads (git, docker, ssh)
# Applied by Claude Code Sysadmin Assistant

# ==============================================================================
# Congestion Control - BBR for better performance on modern networks
# ==============================================================================
# BBR (Bottleneck Bandwidth and RTT) is Google's congestion control algorithm
# designed for high-bandwidth, variable-latency networks
# Improves: git operations, Docker pulls, SSH over VPN, general throughput
net.core.default_qdisc = fq                    # Fair Queue required for BBR
net.ipv4.tcp_congestion_control = bbr          # Use BBR instead of cubic

# ==============================================================================
# TCP Buffer Sizes - Optimized for high-bandwidth connections
# ==============================================================================
# Default Linux settings (212KB) are from 1990s dial-up era
# Modern gigabit+ connections need larger buffers
net.core.rmem_max = 134217728          # 128MB max receive buffer
net.core.wmem_max = 134217728          # 128MB max send buffer
net.core.rmem_default = 16777216       # 16MB default receive buffer
net.core.wmem_default = 16777216       # 16MB default send buffer

# TCP window auto-tuning (min, default, max in bytes)
# Allows TCP to automatically scale the window size
net.ipv4.tcp_rmem = 4096 87380 134217728    # Receive: 4KB min, 85KB default, 128MB max
net.ipv4.tcp_wmem = 4096 65536 134217728    # Send: 4KB min, 64KB default, 128MB max

# ==============================================================================
# TCP Performance Features
# ==============================================================================
# Enable TCP window scaling (RFC 1323)
# Required for windows larger than 64KB
net.ipv4.tcp_window_scaling = 1

# Enable TCP timestamps (RFC 1323)
# Improves RTT estimation and protects against wrapped sequence numbers
net.ipv4.tcp_timestamps = 1

# Enable selective acknowledgements (SACK)
# Improves performance when packets are lost
net.ipv4.tcp_sack = 1

# Enable TCP Fast Open (TFO)
# Reduces latency for repeat connections (git, docker, ssh)
# 1 = client only, 2 = server only, 3 = both
net.ipv4.tcp_fastopen = 3

# ==============================================================================
# TCP Keepalive - Optimized for developer workstation
# ==============================================================================
# Faster detection of broken connections for SSH, VS Code remote, git over SSH
# Default: 2 hours to detect dead connection
# New: ~12 minutes to detect dead connection
net.ipv4.tcp_keepalive_time = 600      # 10 minutes before first probe
net.ipv4.tcp_keepalive_intvl = 30      # 30 seconds between probes
net.ipv4.tcp_keepalive_probes = 3      # 3 probes before declaring dead

# ==============================================================================
# Connection Handling
# ==============================================================================
# Faster cleanup of closed connections
net.ipv4.tcp_fin_timeout = 30          # 30 seconds (reduced from 60)

# Faster failure detection for unreachable hosts
net.ipv4.tcp_syn_retries = 3           # 3 retries (reduced from 6)

# Increase max SYN backlog for handling connection bursts
net.ipv4.tcp_max_syn_backlog = 8192

# Increase network device backlog queue
# Helps prevent packet drops under load
net.core.netdev_max_backlog = 5000

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
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control)
    local current_keepalive=$(sysctl -n net.ipv4.tcp_keepalive_time)

    # Check if buffers are smaller than our target (128MB)
    if [[ $current_rmem_max -lt 134217728 ]] || [[ $current_wmem_max -lt 134217728 ]]; then
        log_info "TCP buffers need optimization (current: ${current_rmem_max} / ${current_wmem_max})"
        return 0  # Needs tuning
    fi

    # Check if BBR is not enabled
    if [[ "$current_cc" != "bbr" ]]; then
        log_info "Congestion control not optimized (current: $current_cc, target: bbr)"
        return 0  # Needs tuning
    fi

    # Check if keepalive is not optimized (default is 7200)
    if [[ $current_keepalive -gt 1000 ]]; then
        log_info "TCP keepalive not optimized (current: ${current_keepalive}s, target: 600s)"
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
