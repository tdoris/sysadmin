#!/bin/bash
# Python environment health checks for developers
# Checks Python installations, virtual environments, package updates, and security

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check Python installation and version
check_python_installation() {
    log_info "Checking Python installation..."

    # Check if python3 is available
    if ! command -v python3 &>/dev/null; then
        log_error "python3 not found"
        update_alerts "high" "python3-missing" \
            "Python 3 Not Installed" \
            "python3 command not available. Install with: sudo apt install python3"
        return 1
    fi

    local python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_info "✓ Python version: $python_version"
    clear_alert "python3-missing"

    # Check if pip is available
    if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
        log_warning "pip not found"
        update_alerts "medium" "pip-missing" \
            "pip Not Installed" \
            "pip package manager not available. Install with: sudo apt install python3-pip"
        return 1
    fi

    local pip_version=$(python3 -m pip --version 2>/dev/null | awk '{print $2}')
    log_info "✓ pip version: $pip_version"
    clear_alert "pip-missing"

    # Check for essential build dependencies
    if ! dpkg -l | grep -q "python3-dev"; then
        log_warning "python3-dev not installed - needed for compiling Python packages"
        update_alerts "medium" "python-build-deps-missing" \
            "Python Build Dependencies Missing" \
            "python3-dev not installed. Many packages need this for compilation. Install with: sudo apt install python3-dev build-essential"
    else
        log_info "✓ python3-dev installed"
        clear_alert "python-build-deps-missing"
    fi

    return 0
}

# Check for outdated global packages
check_outdated_packages() {
    log_info "Checking for outdated Python packages..."

    if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
        return 1
    fi

    # Get outdated packages (limit output to avoid slowness)
    local outdated=$(python3 -m pip list --outdated --format=columns 2>/dev/null | tail -n +3 | head -10)

    if [[ -n "$outdated" ]]; then
        local count=$(echo "$outdated" | wc -l)
        log_info "Found $count outdated packages (showing first 10):"
        echo "$outdated" | while read -r line; do
            log_info "  $line"
        done

        update_alerts "info" "python-packages-outdated" \
            "Outdated Python Packages" \
            "$count Python packages have updates available. Run: pip list --outdated"
    else
        log_info "✓ No outdated packages found"
        clear_alert "python-packages-outdated"
    fi

    return 0
}

# Check for packages with security vulnerabilities
check_security_vulnerabilities() {
    log_info "Checking for Python package security vulnerabilities..."

    if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
        return 1
    fi

    # Check if pip-audit is installed
    if ! python3 -m pip show pip-audit &>/dev/null; then
        log_debug "pip-audit not installed - skipping vulnerability scan"
        log_debug "Install with: pip install pip-audit"
        return 0
    fi

    # Run pip-audit (with timeout to avoid hanging)
    local audit_output=$(timeout 30s python3 -m pip_audit --format=columns 2>/dev/null || echo "TIMEOUT")

    if [[ "$audit_output" == "TIMEOUT" ]]; then
        log_warning "pip-audit timed out (>30s)"
        return 1
    fi

    local vuln_count=$(echo "$audit_output" | grep -c "^" || echo "0")

    if [[ $vuln_count -gt 0 ]]; then
        log_warning "Found $vuln_count packages with security vulnerabilities"
        echo "$audit_output" | head -10 | while read -r line; do
            log_warning "  $line"
        done

        update_alerts "high" "python-security-vulnerabilities" \
            "Python Packages with Security Vulnerabilities" \
            "$vuln_count packages have known vulnerabilities. Run: pip-audit --fix"
    else
        log_info "✓ No known security vulnerabilities"
        clear_alert "python-security-vulnerabilities"
    fi

    return 0
}

# Find and check virtual environments
check_virtual_environments() {
    log_info "Checking Python virtual environments..."

    # Common locations for venvs
    local venv_locations=(
        "$HOME/venv"
        "$HOME/.venv"
        "$HOME/env"
        "$HOME/.env"
        "$HOME/projects"
        "$HOME/code"
        "$HOME/dev"
    )

    local venv_count=0
    local broken_venvs=0

    for location in "${venv_locations[@]}"; do
        if [[ ! -d "$location" ]]; then
            continue
        fi

        # Find venvs (look for pyvenv.cfg or bin/activate)
        while IFS= read -r venv_dir; do
            venv_count=$((venv_count + 1))
            local venv_name=$(basename "$venv_dir")

            # Check if venv is functional
            if [[ -f "$venv_dir/bin/python" ]]; then
                # Try to run python in the venv
                if "$venv_dir/bin/python" --version &>/dev/null; then
                    log_debug "✓ venv: $venv_name (working)"
                else
                    log_warning "✗ venv: $venv_name (broken - python not executable)"
                    broken_venvs=$((broken_venvs + 1))
                fi
            else
                log_warning "✗ venv: $venv_name (broken - missing bin/python)"
                broken_venvs=$((broken_venvs + 1))
            fi
        done < <(find "$location" -maxdepth 3 -name "pyvenv.cfg" -exec dirname {} \; 2>/dev/null)
    done

    log_info "Found $venv_count virtual environments"

    if [[ $broken_venvs -gt 0 ]]; then
        log_warning "Found $broken_venvs broken virtual environments"
        update_alerts "medium" "python-broken-venvs" \
            "Broken Python Virtual Environments" \
            "$broken_venvs virtual environments are broken or non-functional. Consider recreating them."
    else
        clear_alert "python-broken-venvs"
    fi

    return 0
}

# Check for common Python environment issues
check_common_issues() {
    log_info "Checking for common Python issues..."

    # Check if multiple Python versions might cause conflicts
    local python_versions=$(ls -1 /usr/bin/python3.* 2>/dev/null | wc -l)
    if [[ $python_versions -gt 3 ]]; then
        log_info "Multiple Python 3 versions installed: $python_versions"
        log_debug "This is normal but can cause confusion about which python/pip is used"
    fi

    # Check for user-installed Python (pyenv, conda, etc.)
    if [[ -d "$HOME/.pyenv" ]]; then
        log_info "✓ pyenv detected at $HOME/.pyenv"
    fi

    if [[ -d "$HOME/miniconda3" ]] || [[ -d "$HOME/anaconda3" ]]; then
        log_info "✓ Conda detected"
    fi

    # Check for common missing system libraries
    local missing_libs=()

    if ! dpkg -l | grep -q "libssl-dev"; then
        missing_libs+=("libssl-dev")
    fi

    if ! dpkg -l | grep -q "libffi-dev"; then
        missing_libs+=("libffi-dev")
    fi

    if ! dpkg -l | grep -q "libbz2-dev"; then
        missing_libs+=("libbz2-dev")
    fi

    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        log_warning "Missing system libraries that some Python packages need:"
        for lib in "${missing_libs[@]}"; do
            log_warning "  - $lib"
        done

        update_alerts "info" "python-system-libs-missing" \
            "Optional Python System Libraries Missing" \
            "Some system libraries are missing: ${missing_libs[*]}. Install with: sudo apt install ${missing_libs[*]}"
    else
        clear_alert "python-system-libs-missing"
    fi

    return 0
}

# Check pip configuration and cache
check_pip_health() {
    log_info "Checking pip health..."

    if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null; then
        return 1
    fi

    # Check pip cache size
    local cache_dir="$HOME/.cache/pip"
    if [[ -d "$cache_dir" ]]; then
        local cache_size=$(du -sm "$cache_dir" 2>/dev/null | awk '{print $1}')
        log_info "pip cache size: ${cache_size}MB"

        if [[ $cache_size -gt 5000 ]]; then
            log_warning "pip cache is large (${cache_size}MB)"
            update_alerts "info" "pip-cache-large" \
                "Large pip Cache" \
                "pip cache is ${cache_size}MB. Clean with: pip cache purge"
        else
            clear_alert "pip-cache-large"
        fi
    fi

    # Check for pip config issues
    if python3 -m pip config list &>/dev/null; then
        log_debug "pip config:"
        python3 -m pip config list 2>/dev/null | while read -r line; do
            log_debug "  $line"
        done
    fi

    return 0
}

# Check for Jupyter installation and kernels
check_jupyter_environment() {
    log_info "Checking Jupyter environment..."

    # Check if Jupyter is installed
    if ! python3 -c "import jupyter" 2>/dev/null && ! command -v jupyter &>/dev/null; then
        log_debug "Jupyter not installed, skipping"
        return 0
    fi

    log_info "✓ Jupyter installed"

    # Check available kernels
    if command -v jupyter &>/dev/null; then
        local kernel_count=$(jupyter kernelspec list 2>/dev/null | grep -v "Available" | grep -v "^$" | wc -l)
        log_info "Jupyter kernels available: $kernel_count"

        # List kernels
        jupyter kernelspec list 2>/dev/null | grep -v "Available" | while read -r line; do
            log_debug "  $line"
        done
    fi

    return 0
}

# Generate Python environment report
generate_python_report() {
    log_info "Generating Python environment report..."

    local report_file="$REPORTS_DIR/python-environment.txt"

    {
        echo "Python Environment Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "=== Python Version ==="
        python3 --version
        echo ""
        echo "=== pip Version ==="
        python3 -m pip --version 2>/dev/null || echo "pip not available"
        echo ""
        echo "=== Installed Packages (global) ==="
        python3 -m pip list 2>/dev/null | head -20 || echo "Cannot list packages"
        echo ""
        echo "=== Outdated Packages ==="
        python3 -m pip list --outdated 2>/dev/null | head -10 || echo "Cannot check outdated"
        echo ""
        echo "=== System Python Packages ==="
        dpkg -l | grep python3 | grep "^ii" | awk '{print $2, $3}' | head -20
    } > "$report_file"

    log_info "Report saved to: $report_file"
}

# Main execution
main() {
    log_info "==================== PYTHON ENVIRONMENT CHECK ===================="

    check_python_installation
    check_outdated_packages
    check_security_vulnerabilities
    check_virtual_environments
    check_common_issues
    check_pip_health
    check_jupyter_environment

    generate_python_report

    log_info "==================== PYTHON ENVIRONMENT CHECK COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
