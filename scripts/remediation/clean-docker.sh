#!/bin/bash
# Clean up Docker images and containers
# Preserves tagged production images

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
SIZE_THRESHOLD_GB="${SIZE_THRESHOLD_GB:-150}"

clean_docker_images() {
    if ! command -v docker &>/dev/null; then
        log_debug "Docker not installed, skipping"
        return 0
    fi

    local images_size=$(docker system df 2>/dev/null | awk '/Images/ {print $3}' | sed 's/GB//')

    if [[ -z "$images_size" ]]; then
        log_debug "Could not determine Docker image size"
        return 0
    fi

    # Convert to integer for comparison
    local size_int=$(echo "$images_size" | cut -d. -f1)

    if [[ $size_int -lt $SIZE_THRESHOLD_GB ]]; then
        log_debug "Docker images using ${images_size}GB (threshold: ${SIZE_THRESHOLD_GB}GB)"
        return 0
    fi

    log_warning "Docker images using ${images_size}GB (threshold: ${SIZE_THRESHOLD_GB}GB)"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would prune unused Docker images"
        docker image ls
        return 0
    fi

    log_info "Pruning unused Docker images"
    docker image prune -a -f

    # Remove stopped containers
    log_info "Removing stopped containers"
    docker container prune -f

    # Remove unused volumes
    log_info "Removing unused volumes"
    docker volume prune -f

    local new_size=$(docker system df 2>/dev/null | awk '/Images/ {print $3}')
    log_info "Docker cleanup complete: ${images_size}GB -> ${new_size}"

    clear_alert "docker-cleanup"
}

# Main execution
main() {
    log_info "Starting Docker cleanup check (threshold: ${SIZE_THRESHOLD_GB}GB)"
    clean_docker_images
    log_info "Docker cleanup check complete"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
