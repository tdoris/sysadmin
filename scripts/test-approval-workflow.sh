#!/bin/bash
# Test script for approval workflow
# Creates a test approval request to validate the complete workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Creating test approval request..."

# Create a harmless test approval
create_approval_request \
    "medium" \
    "other" \
    "Test Approval Request" \
    "This is a test approval request to validate the workflow. The action will simply echo a message to demonstrate the approval system is working." \
    "command" \
    "echo 'Test approval executed successfully at $(date)'" \
    "minimal" \
    "No system impact - this is a test" \
    "true" \
    ""

log_info "Test approval request created!"
log_info "Check the dashboard at http://localhost:5050 to see the pending approval"
log_info "After approving, run ./execute-approved-actions.sh to execute it"
