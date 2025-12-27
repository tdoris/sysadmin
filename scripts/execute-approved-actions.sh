#!/bin/bash
# Execute approved actions from the approval workflow
# This script is called by Claude Code during maintenance runs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

main() {
    log_info "========================================"
    log_info "Checking for approved actions to execute"
    log_info "========================================"

    # Get list of approved actions
    local approved_json=$(get_approved_actions)
    local approved_count=$(echo "$approved_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['items']))")

    if [[ "$approved_count" -eq 0 ]]; then
        log_info "No approved actions waiting for execution"
        return 0
    fi

    log_info "Found $approved_count approved action(s) to execute"

    # Execute each approved action
    echo "$approved_json" | python3 <<EOF
import json
import sys

data = json.load(sys.stdin)
for item in data["items"]:
    print(item["id"])
EOF

    while IFS= read -r approval_id; do
        if [[ -n "$approval_id" ]]; then
            log_info "============================================"
            log_info "Executing approved action: $approval_id"
            log_info "============================================"

            if execute_approved_action "$approval_id"; then
                log_info "Successfully executed: $approval_id"
            else
                log_error "Failed to execute: $approval_id"
            fi

            echo ""
        fi
    done < <(echo "$approved_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print('\\n'.join([item['id'] for item in data['items']]))")

    log_info "========================================"
    log_info "Finished executing approved actions"
    log_info "========================================"
}

main "$@"
