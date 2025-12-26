#!/bin/bash
# Invoke Claude Code for hourly system checks
# This script is run by cron every hour

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSADMIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOSTNAME=$(hostname)
REPORTS_DIR="$SYSADMIN_DIR/reports/$HOSTNAME"
ACTIVITY_LOG="$REPORTS_DIR/activity.log"

# Ensure reports directory exists
mkdir -p "$REPORTS_DIR"

# Log invocation
echo "" >> "$ACTIVITY_LOG"
echo "==================== $(date '+%Y-%m-%d %H:%M:%S') ====================" >> "$ACTIVITY_LOG"
echo "Action: Hourly Check" >> "$ACTIVITY_LOG"

# Change to sysadmin directory
cd "$SYSADMIN_DIR"

# Find Claude Code binary
CLAUDE_BIN=""

# Check saved path first
if [[ -f "$SYSADMIN_DIR/.claude-path" ]]; then
    CLAUDE_BIN=$(cat "$SYSADMIN_DIR/.claude-path")
fi

# Verify it's executable
if [[ ! -x "$CLAUDE_BIN" ]]; then
    # Try to find it in common locations
    if command -v claude &>/dev/null; then
        CLAUDE_BIN=$(command -v claude)
    elif [[ -f "$HOME/.npm-global/bin/claude" ]]; then
        CLAUDE_BIN="$HOME/.npm-global/bin/claude"
    elif [[ -f "$HOME/.local/bin/claude" ]]; then
        CLAUDE_BIN="$HOME/.local/bin/claude"
    elif [[ -f "/usr/local/bin/claude" ]]; then
        CLAUDE_BIN="/usr/local/bin/claude"
    fi
fi

# Fail if Claude Code not found
if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
    echo "ERROR: Claude Code not found!" >> "$ACTIVITY_LOG"
    echo "This system requires Claude Code to function." >> "$ACTIVITY_LOG"
    echo "Install from: https://claude.ai/code" >> "$ACTIVITY_LOG"
    echo "Then run: ./install.sh" >> "$ACTIVITY_LOG"
    echo "Status: FAILED - Claude Code not available" >> "$ACTIVITY_LOG"
    exit 1
fi

echo "Method: Claude Code ($CLAUDE_BIN)" >> "$ACTIVITY_LOG"

# Read the prompt
PROMPT=$(cat "$SCRIPT_DIR/prompts/hourly.txt")

# Invoke Claude Code with --dangerously-skip-permissions
echo "$PROMPT" | "$CLAUDE_BIN" --dangerously-skip-permissions \
    --model sonnet \
    2>&1 | tee -a "$ACTIVITY_LOG"

echo "Status: Claude Code session completed" >> "$ACTIVITY_LOG"

echo "======================================================" >> "$ACTIVITY_LOG"
