#!/bin/bash
# R environment health checks for data scientists and quant researchers
# Checks R installation, packages, RStudio, and common issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check R installation
check_r_installation() {
    log_info "Checking R installation..."

    # Check if R is installed
    if ! command -v R &>/dev/null; then
        log_info "R not installed - skipping R checks"
        return 1
    fi

    local r_version=$(R --version 2>/dev/null | head -1 | awk '{print $3}')
    log_info "✓ R version: $r_version"

    # Check if Rscript is available
    if ! command -v Rscript &>/dev/null; then
        log_warning "Rscript not found"
        update_alerts "medium" "rscript-missing" \
            "Rscript Command Not Available" \
            "Rscript command not found but R is installed. This is unusual."
        return 1
    fi

    log_info "✓ Rscript available"
    clear_alert "rscript-missing"

    return 0
}

# Check for system dependencies needed by R packages
check_r_system_dependencies() {
    log_info "Checking R system dependencies..."

    # Common system libraries needed for popular R packages
    local required_libs=(
        "libcurl4-openssl-dev:libcurl4"      # curl, httr, devtools
        "libssl-dev:libssl"                  # openssl, httr
        "libxml2-dev:libxml2"                # xml2, rvest
        "libfontconfig1-dev:libfontconfig1"  # graphics
        "libharfbuzz-dev:libharfbuzz"        # graphics, ragg
        "libfribidi-dev:libfribidi"          # graphics
        "libfreetype6-dev:libfreetype6"      # graphics
        "libpng-dev:libpng"                  # graphics
        "libtiff5-dev:libtiff5"              # graphics
        "libjpeg-dev:libjpeg"                # graphics
        "libgit2-dev:libgit2"                # gert, devtools
        "libssh2-1-dev:libssh2"              # git2r
        "libudunits2-dev:libudunits2"        # units (sf, spatial packages)
        "libgdal-dev:libgdal"                # sf, rgdal (geospatial)
        "libgeos-dev:libgeos"                # sf (geospatial)
        "libproj-dev:libproj"                # proj (geospatial)
    )

    local missing_libs=()
    local missing_dev_pkgs=()

    for lib_spec in "${required_libs[@]}"; do
        local dev_pkg="${lib_spec%%:*}"
        local runtime_lib="${lib_spec##*:}"

        # Check if dev package is installed
        if ! dpkg -l | grep -q "^ii.*$dev_pkg"; then
            # Check if runtime library exists (package might be installed)
            if ! ldconfig -p 2>/dev/null | grep -q "$runtime_lib"; then
                missing_libs+=("$dev_pkg")
                missing_dev_pkgs+=("$dev_pkg")
            fi
        fi
    done

    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        log_warning "Missing system libraries for R packages:"
        for lib in "${missing_libs[@]}"; do
            log_warning "  - $lib"
        done

        update_alerts "medium" "r-system-libs-missing" \
            "R System Libraries Missing" \
            "${#missing_libs[@]} system libraries are missing that R packages commonly need. Install with: sudo apt install ${missing_dev_pkgs[*]}"
    else
        log_info "✓ Common R system dependencies installed"
        clear_alert "r-system-libs-missing"
    fi

    # Check for compilers (needed for packages with C/C++/Fortran code)
    local missing_compilers=()

    if ! command -v gcc &>/dev/null; then
        missing_compilers+=("gcc")
    fi

    if ! command -v g++ &>/dev/null; then
        missing_compilers+=("g++")
    fi

    if ! command -v gfortran &>/dev/null; then
        missing_compilers+=("gfortran")
    fi

    if [[ ${#missing_compilers[@]} -gt 0 ]]; then
        log_warning "Missing compilers: ${missing_compilers[*]}"
        update_alerts "high" "r-compilers-missing" \
            "R Compilers Missing" \
            "Compilers needed for R package compilation are missing: ${missing_compilers[*]}. Install with: sudo apt install build-essential gfortran"
    else
        log_info "✓ R compilers (gcc, g++, gfortran) installed"
        clear_alert "r-compilers-missing"
    fi

    return 0
}

# Check R package library status
check_r_packages() {
    log_info "Checking R packages..."

    if ! command -v Rscript &>/dev/null; then
        return 1
    fi

    # Get installed package count
    local pkg_count=$(Rscript -e 'cat(length(.packages(all.available=TRUE)))' 2>/dev/null || echo "0")
    log_info "Installed R packages: $pkg_count"

    # Check for packages with updates available
    local outdated=$(Rscript -e '
        options(repos=c(CRAN="https://cloud.r-project.org"))
        old <- old.packages()
        if(!is.null(old)) {
            cat(nrow(old))
        } else {
            cat(0)
        }
    ' 2>/dev/null || echo "unknown")

    if [[ "$outdated" != "unknown" ]] && [[ "$outdated" != "0" ]]; then
        log_info "Outdated R packages: $outdated"
        update_alerts "info" "r-packages-outdated" \
            "Outdated R Packages" \
            "$outdated R packages have updates available. Update with: R -e 'update.packages(ask=FALSE)'"
    else
        log_info "✓ R packages up to date"
        clear_alert "r-packages-outdated"
    fi

    return 0
}

# Check for broken R package installations
check_broken_r_packages() {
    log_info "Checking for broken R packages..."

    if ! command -v Rscript &>/dev/null; then
        return 1
    fi

    # Try to load common packages and detect failures
    local test_packages=("ggplot2" "dplyr" "tidyr" "readr" "data.table" "shiny")
    local broken_packages=()

    for pkg in "${test_packages[@]}"; do
        if Rscript -e "library($pkg)" &>/dev/null; then
            log_debug "✓ Package $pkg loads correctly"
        else
            # Check if package is installed but broken
            if Rscript -e "if('$pkg' %in% installed.packages()[,1]) quit(status=0) else quit(status=1)" 2>/dev/null; then
                log_warning "✗ Package $pkg is installed but fails to load"
                broken_packages+=("$pkg")
            fi
        fi
    done

    if [[ ${#broken_packages[@]} -gt 0 ]]; then
        log_warning "Found ${#broken_packages[@]} broken R packages: ${broken_packages[*]}"
        update_alerts "medium" "r-packages-broken" \
            "Broken R Packages" \
            "${#broken_packages[@]} R packages are installed but fail to load: ${broken_packages[*]}. Reinstall with: R -e 'install.packages(c(${broken_packages[*]}))'  "
    else
        clear_alert "r-packages-broken"
    fi

    return 0
}

# Check RStudio installation and health
check_rstudio() {
    log_info "Checking RStudio..."

    # Check for RStudio Desktop
    if command -v rstudio &>/dev/null; then
        local rstudio_version=$(rstudio --version 2>/dev/null | head -1 || echo "unknown")
        log_info "✓ RStudio Desktop installed: $rstudio_version"
    else
        log_debug "RStudio Desktop not installed"
    fi

    # Check for RStudio Server
    if systemctl list-unit-files | grep -q "rstudio-server"; then
        if systemctl is-active --quiet rstudio-server; then
            log_info "✓ RStudio Server is running"

            # Check if RStudio Server is accessible
            if curl -f -s -m 2 http://localhost:8787 >/dev/null 2>&1; then
                log_info "✓ RStudio Server accessible on port 8787"
                clear_alert "rstudio-server-down"
            else
                log_warning "RStudio Server running but not accessible on port 8787"
                update_alerts "medium" "rstudio-server-inaccessible" \
                    "RStudio Server Not Accessible" \
                    "RStudio Server service is running but not responding on port 8787"
            fi
        else
            log_warning "RStudio Server installed but not running"
            update_alerts "medium" "rstudio-server-down" \
                "RStudio Server Not Running" \
                "RStudio Server is installed but not active. Start with: sudo systemctl start rstudio-server"
        fi
    else
        log_debug "RStudio Server not installed"
    fi

    return 0
}

# Check R configuration
check_r_configuration() {
    log_info "Checking R configuration..."

    if ! command -v Rscript &>/dev/null; then
        return 1
    fi

    # Check library paths
    local lib_paths=$(Rscript -e 'cat(.libPaths(), sep="\n")' 2>/dev/null)
    log_info "R library paths:"
    echo "$lib_paths" | while read -r path; do
        log_info "  $path"
    done

    # Check CRAN mirror
    local cran_mirror=$(Rscript -e 'cat(getOption("repos")["CRAN"])' 2>/dev/null || echo "unknown")
    log_info "CRAN mirror: $cran_mirror"

    # Check if CRAN is accessible
    if [[ "$cran_mirror" != "unknown" ]] && [[ "$cran_mirror" != "@CRAN@" ]]; then
        if curl -f -s -m 5 "$cran_mirror" >/dev/null 2>&1; then
            log_info "✓ CRAN mirror accessible"
            clear_alert "cran-unreachable"
        else
            log_warning "CRAN mirror not accessible: $cran_mirror"
            update_alerts "medium" "cran-unreachable" \
                "CRAN Mirror Not Accessible" \
                "Cannot reach CRAN mirror: $cran_mirror. Package installation may fail."
        fi
    fi

    return 0
}

# Check for common R environment issues
check_r_common_issues() {
    log_info "Checking for common R issues..."

    if ! command -v R &>/dev/null; then
        return 1
    fi

    # Check R library directory permissions
    local user_lib=$(Rscript -e 'cat(Sys.getenv("R_LIBS_USER"))' 2>/dev/null)
    if [[ -n "$user_lib" ]] && [[ -d "$user_lib" ]]; then
        if [[ ! -w "$user_lib" ]]; then
            log_warning "R user library directory not writable: $user_lib"
            update_alerts "medium" "r-lib-not-writable" \
                "R Library Directory Not Writable" \
                "R user library directory is not writable: $user_lib. Fix with: chmod u+w $user_lib"
        else
            clear_alert "r-lib-not-writable"
        fi
    fi

    # Check for large R package cache
    local r_cache="$HOME/.cache/R"
    if [[ -d "$r_cache" ]]; then
        local cache_size=$(du -sm "$r_cache" 2>/dev/null | awk '{print $1}')
        log_info "R cache size: ${cache_size}MB"

        if [[ $cache_size -gt 5000 ]]; then
            log_warning "R cache is large (${cache_size}MB)"
            update_alerts "info" "r-cache-large" \
                "Large R Cache" \
                "R cache is ${cache_size}MB. Clean old packages to free space."
        else
            clear_alert "r-cache-large"
        fi
    fi

    return 0
}

# Check for Shiny Server
check_shiny_server() {
    log_info "Checking Shiny Server..."

    if systemctl list-unit-files | grep -q "shiny-server"; then
        if systemctl is-active --quiet shiny-server; then
            log_info "✓ Shiny Server is running"

            # Check if Shiny Server is accessible
            if curl -f -s -m 2 http://localhost:3838 >/dev/null 2>&1; then
                log_info "✓ Shiny Server accessible on port 3838"
                clear_alert "shiny-server-down"
            else
                log_warning "Shiny Server running but not accessible on port 3838"
                update_alerts "medium" "shiny-server-inaccessible" \
                    "Shiny Server Not Accessible" \
                    "Shiny Server service is running but not responding on port 3838"
            fi
        else
            log_warning "Shiny Server installed but not running"
            update_alerts "medium" "shiny-server-down" \
                "Shiny Server Not Running" \
                "Shiny Server is installed but not active. Start with: sudo systemctl start shiny-server"
        fi
    else
        log_debug "Shiny Server not installed"
    fi

    return 0
}

# Generate R environment report
generate_r_report() {
    log_info "Generating R environment report..."

    if ! command -v R &>/dev/null; then
        return 0
    fi

    local report_file="$REPORTS_DIR/r-environment.txt"

    {
        echo "R Environment Report"
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "=== R Version ==="
        R --version | head -5
        echo ""
        echo "=== R Configuration ==="
        Rscript -e 'cat("R library paths:\n"); cat(.libPaths(), sep="\n")' 2>/dev/null
        echo ""
        Rscript -e 'cat("\nCRAN mirror:", getOption("repos")["CRAN"], "\n")' 2>/dev/null
        echo ""
        echo "=== Installed Packages ==="
        Rscript -e 'cat("Total packages:", length(.packages(all.available=TRUE)), "\n")' 2>/dev/null
        echo ""
        echo "=== System Info ==="
        Rscript -e 'print(Sys.info())' 2>/dev/null
    } > "$report_file"

    log_info "Report saved to: $report_file"
}

# Main execution
main() {
    log_info "==================== R ENVIRONMENT CHECK ===================="

    # Check if R is installed
    if ! check_r_installation; then
        log_info "R not installed - skipping R environment checks"
        log_info "==================== R CHECK COMPLETE (R NOT INSTALLED) ===================="
        return 0
    fi

    # Run all R checks
    check_r_system_dependencies
    check_r_packages
    check_broken_r_packages
    check_r_configuration
    check_r_common_issues
    check_rstudio
    check_shiny_server

    generate_r_report

    log_info "==================== R ENVIRONMENT CHECK COMPLETE ===================="
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
