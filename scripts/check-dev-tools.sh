#!/bin/bash
# Development tools version and health checks
# Checks compilers, build tools, language runtimes, and version managers

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check build essentials and compilers
check_compilers() {
    log_info "Checking compilers and build tools..."

    local tools=(
        "gcc:GCC (C compiler)"
        "g++:G++ (C++ compiler)"
        "gfortran:GFortran (Fortran compiler)"
        "make:Make (build tool)"
        "cmake:CMake (cross-platform build)"
        "autoconf:Autoconf (configure script generator)"
        "pkg-config:pkg-config (library metadata)"
    )

    local missing_tools=()

    for tool_spec in "${tools[@]}"; do
        local cmd="${tool_spec%%:*}"
        local desc="${tool_spec##*:}"

        if command -v "$cmd" &>/dev/null; then
            local version=$("$cmd" --version 2>/dev/null | head -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\.[0-9]/) print $i; exit}')
            log_info "✓ $desc: $version"
        else
            log_warning "✗ $desc not installed"
            missing_tools+=("$cmd")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        update_alerts "medium" "build-tools-missing" \
            "Build Tools Missing" \
            "${#missing_tools[@]} build tools not installed: ${missing_tools[*]}. Install with: sudo apt install build-essential cmake autoconf pkg-config"
    else
        log_info "✓ All essential build tools installed"
        clear_alert "build-tools-missing"
    fi

    # Check if build-essential metapackage is installed
    if ! dpkg -l | grep -q "^ii.*build-essential"; then
        log_warning "build-essential metapackage not installed"
        update_alerts "medium" "build-essential-missing" \
            "build-essential Package Not Installed" \
            "Install with: sudo apt install build-essential"
    else
        clear_alert "build-essential-missing"
    fi

    return 0
}

# Check Node.js and npm
check_nodejs() {
    log_info "Checking Node.js..."

    if command -v node &>/dev/null; then
        local node_version=$(node --version 2>/dev/null)
        log_info "✓ Node.js: $node_version"

        if command -v npm &>/dev/null; then
            local npm_version=$(npm --version 2>/dev/null)
            log_info "✓ npm: $npm_version"
        else
            log_warning "npm not found (but Node.js is installed)"
        fi

        # Check for nvm (Node Version Manager)
        if [[ -d "$HOME/.nvm" ]]; then
            log_info "✓ nvm (Node Version Manager) detected"
        fi

        clear_alert "nodejs-missing"
    else
        log_debug "Node.js not installed"
        # Don't alert - Node.js is optional
    fi

    return 0
}

# Check Go
check_go() {
    log_info "Checking Go..."

    if command -v go &>/dev/null; then
        local go_version=$(go version 2>/dev/null | awk '{print $3}')
        log_info "✓ Go: $go_version"
        clear_alert "go-missing"
    else
        log_debug "Go not installed"
    fi

    return 0
}

# Check Rust and Cargo
check_rust() {
    log_info "Checking Rust..."

    if command -v rustc &>/dev/null; then
        local rust_version=$(rustc --version 2>/dev/null | awk '{print $2}')
        log_info "✓ Rust: $rust_version"

        if command -v cargo &>/dev/null; then
            local cargo_version=$(cargo --version 2>/dev/null | awk '{print $2}')
            log_info "✓ Cargo: $cargo_version"
        fi

        clear_alert "rust-missing"
    else
        log_debug "Rust not installed"
    fi

    return 0
}

# Check Java/JDK
check_java() {
    log_info "Checking Java..."

    if command -v java &>/dev/null; then
        local java_version=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}')
        log_info "✓ Java: $java_version"

        if command -v javac &>/dev/null; then
            local javac_version=$(javac -version 2>&1 | awk '{print $2}')
            log_info "✓ javac (JDK): $javac_version"
        else
            log_warning "javac not found - JDK not installed (only JRE)"
            update_alerts "info" "jdk-missing" \
                "JDK Not Installed" \
                "Java runtime is installed but JDK (compiler) is not. Install with: sudo apt install default-jdk"
        fi

        clear_alert "java-missing"
    else
        log_debug "Java not installed"
    fi

    return 0
}

# Check Git
check_git() {
    log_info "Checking Git..."

    if command -v git &>/dev/null; then
        local git_version=$(git --version 2>/dev/null | awk '{print $3}')
        log_info "✓ Git: $git_version"

        # Check git configuration
        local git_user=$(git config --global user.name 2>/dev/null || echo "")
        local git_email=$(git config --global user.email 2>/dev/null || echo "")

        if [[ -z "$git_user" ]] || [[ -z "$git_email" ]]; then
            log_warning "Git not configured (user.name or user.email missing)"
            update_alerts "info" "git-not-configured" \
                "Git Not Configured" \
                "Git user.name and user.email not set. Configure with: git config --global user.name 'Your Name' && git config --global user.email 'you@example.com'"
        else
            log_info "✓ Git configured: $git_user <$git_email>"
            clear_alert "git-not-configured"
        fi

        # Check for git credential helper
        local cred_helper=$(git config --global credential.helper 2>/dev/null || echo "")
        if [[ -z "$cred_helper" ]]; then
            log_debug "No git credential helper configured"
        else
            log_info "✓ Git credential helper: $cred_helper"
        fi

        clear_alert "git-missing"
    else
        log_warning "Git not installed"
        update_alerts "medium" "git-missing" \
            "Git Not Installed" \
            "Git version control is not installed. Install with: sudo apt install git"
    fi

    return 0
}

# Check Docker and Docker Compose
check_docker_tools() {
    log_info "Checking Docker tools..."

    if command -v docker &>/dev/null; then
        local docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        log_info "✓ Docker: $docker_version"

        # Check if docker service is running
        if systemctl is-active --quiet docker; then
            log_info "✓ Docker service running"
        else
            log_warning "Docker installed but service not running"
            update_alerts "medium" "docker-service-down" \
                "Docker Service Not Running" \
                "Docker is installed but not running. Start with: sudo systemctl start docker"
        fi

        clear_alert "docker-missing"
    else
        log_debug "Docker not installed"
    fi

    # Check Docker Compose
    if command -v docker-compose &>/dev/null; then
        local compose_version=$(docker-compose --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        log_info "✓ Docker Compose: $compose_version"
    elif docker compose version &>/dev/null 2>&1; then
        local compose_version=$(docker compose version 2>/dev/null | awk '{print $3}')
        log_info "✓ Docker Compose (plugin): $compose_version"
    else
        log_debug "Docker Compose not installed"
    fi

    return 0
}

# Check container/VM tools
check_container_tools() {
    log_info "Checking container and virtualization tools..."

    # Check LXD/LXC
    if command -v lxc &>/dev/null; then
        local lxd_version=$(lxc --version 2>/dev/null)
        log_info "✓ LXD: $lxd_version"
    else
        log_debug "LXD not installed"
    fi

    # Check Podman
    if command -v podman &>/dev/null; then
        local podman_version=$(podman --version 2>/dev/null | awk '{print $3}')
        log_info "✓ Podman: $podman_version"
    else
        log_debug "Podman not installed"
    fi

    # Check QEMU/KVM
    if command -v qemu-system-x86_64 &>/dev/null; then
        local qemu_version=$(qemu-system-x86_64 --version 2>/dev/null | head -1 | awk '{print $4}')
        log_info "✓ QEMU: $qemu_version"
    else
        log_debug "QEMU not installed"
    fi

    # Check if KVM is available
    if [[ -e /dev/kvm ]]; then
        log_info "✓ KVM available"
    else
        log_debug "KVM not available"
    fi

    return 0
}

# Check Python version managers
check_python_version_managers() {
    log_info "Checking Python version managers..."

    # Check for pyenv
    if [[ -d "$HOME/.pyenv" ]]; then
        if command -v pyenv &>/dev/null; then
            local pyenv_version=$(pyenv --version 2>/dev/null | awk '{print $2}')
            log_info "✓ pyenv: $pyenv_version"

            # List installed Python versions
            local python_versions=$(pyenv versions 2>/dev/null | wc -l)
            log_info "  Installed Python versions: $python_versions"
        else
            log_warning "pyenv directory exists but command not in PATH"
        fi
    else
        log_debug "pyenv not installed"
    fi

    # Check for Conda/Miniconda
    if [[ -d "$HOME/miniconda3" ]] || [[ -d "$HOME/anaconda3" ]]; then
        if command -v conda &>/dev/null; then
            local conda_version=$(conda --version 2>/dev/null | awk '{print $2}')
            log_info "✓ Conda: $conda_version"

            # List environments
            local env_count=$(conda env list 2>/dev/null | grep -v "^#" | wc -l)
            log_info "  Conda environments: $env_count"
        else
            log_warning "Conda directory exists but command not in PATH"
        fi
    else
        log_debug "Conda not installed"
    fi

    return 0
}

# Check editor/IDE installations
check_editors() {
    log_info "Checking editors and IDEs..."

    # Check vim
    if command -v vim &>/dev/null; then
        local vim_version=$(vim --version 2>/dev/null | head -1 | awk '{print $5}')
        log_info "✓ Vim: $vim_version"
    fi

    # Check neovim
    if command -v nvim &>/dev/null; then
        local nvim_version=$(nvim --version 2>/dev/null | head -1 | awk '{print $2}')
        log_info "✓ Neovim: $nvim_version"
    fi

    # Check emacs
    if command -v emacs &>/dev/null; then
        local emacs_version=$(emacs --version 2>/dev/null | head -1 | awk '{print $3}')
        log_info "✓ Emacs: $emacs_version"
    fi

    # Check VS Code
    if command -v code &>/dev/null; then
        local code_version=$(code --version 2>/dev/null | head -1)
        log_info "✓ VS Code: $code_version"
    fi

    return 0
}

# Check debugging and profiling tools
check_dev_utilities() {
    log_info "Checking development utilities..."

    local tools=(
        "gdb:GDB debugger"
        "valgrind:Valgrind (memory debugger)"
        "strace:strace (system call tracer)"
        "ltrace:ltrace (library call tracer)"
        "perf:perf (performance profiler)"
    )

    for tool_spec in "${tools[@]}"; do
        local cmd="${tool_spec%%:*}"
        local desc="${tool_spec##*:}"

        if command -v "$cmd" &>/dev/null; then
            log_debug "✓ $desc installed"
        else
            log_debug "✗ $desc not installed"
        fi
    done

    return 0
}

# Generate development tools report
generate_dev_tools_report() {
    log_info "Generating development tools report..."

    local report_file="$REPORTS_DIR/dev-tools.txt"

    {
        echo "Development Tools Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "=== Compilers ==="
        command -v gcc &>/dev/null && gcc --version | head -1 || echo "gcc: not installed"
        command -v g++ &>/dev/null && g++ --version | head -1 || echo "g++: not installed"
        command -v gfortran &>/dev/null && gfortran --version | head -1 || echo "gfortran: not installed"
        echo ""
        echo "=== Build Tools ==="
        command -v make &>/dev/null && make --version | head -1 || echo "make: not installed"
        command -v cmake &>/dev/null && cmake --version | head -1 || echo "cmake: not installed"
        echo ""
        echo "=== Language Runtimes ==="
        command -v python3 &>/dev/null && python3 --version || echo "python3: not installed"
        command -v node &>/dev/null && node --version || echo "node: not installed"
        command -v go &>/dev/null && go version || echo "go: not installed"
        command -v rustc &>/dev/null && rustc --version || echo "rust: not installed"
        command -v java &>/dev/null && java -version 2>&1 | head -1 || echo "java: not installed"
        command -v R &>/dev/null && R --version | head -1 || echo "R: not installed"
        echo ""
        echo "=== Version Control ==="
        command -v git &>/dev/null && git --version || echo "git: not installed"
        echo ""
        echo "=== Container Tools ==="
        command -v docker &>/dev/null && docker --version || echo "docker: not installed"
        command -v lxc &>/dev/null && lxc --version || echo "lxd: not installed"
    } > "$report_file"

    log_info "Report saved to: $report_file"
}

# Main execution
main() {
    log_info "==================== DEVELOPMENT TOOLS CHECK ===================="

    check_compilers
    check_git
    check_nodejs
    check_go
    check_rust
    check_java
    check_docker_tools
    check_container_tools
    check_python_version_managers
    check_editors
    check_dev_utilities

    generate_dev_tools_report

    log_info "==================== DEVELOPMENT TOOLS CHECK COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
