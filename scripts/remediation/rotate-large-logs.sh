#!/bin/bash
# Automatically rotate large log files
# Preserves recent logs, archives middle portion, deletes oldest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

DRY_RUN="${DRY_RUN:-0}"
SIZE_THRESHOLD_MB="${SIZE_THRESHOLD_MB:-1024}"  # 1GB default

# Rotate a large log file intelligently
# Args: log_file_path
rotate_large_log() {
    local log_file="$1"
    local size_mb=$(get_log_size_mb "$log_file")

    if [[ ! -f "$log_file" ]]; then
        log_warning "Log file not found: $log_file"
        return 1
    fi

    if [[ $size_mb -lt $SIZE_THRESHOLD_MB ]]; then
        log_debug "Log file $log_file is only ${size_mb}MB (threshold: ${SIZE_THRESHOLD_MB}MB)"
        return 0
    fi

    log_warning "Large log file detected: $log_file (${size_mb}MB)"

    local total_lines=$(wc -l < "$log_file")
    local keep_recent=10000  # Keep last 10k lines
    local archive_lines=50000  # Archive 50k lines before that

    if [[ $total_lines -lt $keep_recent ]]; then
        log_info "Log has fewer than $keep_recent lines, skipping rotation"
        return 0
    fi

    local delete_lines=$((total_lines - keep_recent - archive_lines))
    if [[ $delete_lines -lt 0 ]]; then
        delete_lines=0
        archive_lines=$((total_lines - keep_recent))
    fi

    local backup_dir="$(dirname "$log_file")/rotated"
    local backup_file="$backup_dir/$(basename "$log_file").$(date +%Y%m%d-%H%M%S).gz"

    if [[ $DRY_RUN -eq 1 ]]; then
        log_info "[DRY RUN] Would rotate $log_file:"
        log_info "  Total lines: $total_lines"
        log_info "  Delete oldest: $delete_lines lines"
        log_info "  Archive to: $backup_file ($archive_lines lines)"
        log_info "  Keep recent: $keep_recent lines"
        return 0
    fi

    # Create backup directory
    sudo mkdir -p "$backup_dir"

    # Archive middle portion
    if [[ $archive_lines -gt 0 ]]; then
        log_info "Archiving $archive_lines lines to $backup_file"
        sudo tail -n +$((delete_lines + 1)) "$log_file" | sudo head -n "$archive_lines" | gzip | sudo tee "$backup_file" >/dev/null
    fi

    # Keep only recent lines
    log_info "Keeping last $keep_recent lines in $log_file"
    sudo tail -n "$keep_recent" "$log_file" | sudo tee "${log_file}.tmp" >/dev/null
    sudo mv "${log_file}.tmp" "$log_file"

    local new_size_mb=$(get_log_size_mb "$log_file")
    log_info "Log rotation complete: ${size_mb}MB -> ${new_size_mb}MB"

    # Update alert
    update_alerts "medium" "large-log-$(basename "$log_file")" \
        "Large Log Rotated: $(basename "$log_file")" \
        "Rotated from ${size_mb}MB to ${new_size_mb}MB" \
        "resolved"
}

# Main execution
main() {
    log_info "Starting log rotation check (threshold: ${SIZE_THRESHOLD_MB}MB)"

    # Common log locations to check
    local log_locations=(
        "/var/log/syslog"
        "/var/log/kern.log"
        "/var/log/auth.log"
        "/var/log/apache2/*.log"
        "/var/log/nginx/*.log"
        "/var/log/mysql/*.log"
        "/var/log/postgresql/*.log"
    )

    local rotated_count=0

    for pattern in "${log_locations[@]}"; do
        for log_file in $pattern; do
            if [[ -f "$log_file" ]]; then
                if rotate_large_log "$log_file"; then
                    ((rotated_count++)) || true
                fi
            fi
        done
    done

    log_info "Log rotation check complete (rotated: $rotated_count files)"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
