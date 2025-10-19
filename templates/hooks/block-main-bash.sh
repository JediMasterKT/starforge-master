#!/bin/bash

# Log file for debugging
LOG_FILE="$HOME/.claude/hook-debug.log"
mkdir -p "$HOME/.claude"

# Log start
echo "=== $(date) ===" >> "$LOG_FILE"
echo "Hook: block-main-bash.sh" >> "$LOG_FILE"

# Read JSON input from stdin
json_input=$(cat)
echo "JSON Input: $json_input" >> "$LOG_FILE"

# Extract command from JSON
command=$(echo "$json_input" | jq -r '.tool_input.command // .command // "unknown"')
echo "Command: $command" >> "$LOG_FILE"

# Get current branch
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
echo "Current branch: $current_branch" >> "$LOG_FILE"

# WHITELIST: Allow file operations in coordination directories
# These operations are part of the agent coordination system
if echo "$command" | grep -qE "\.claude/(coordination|triggers|spikes|agents)"; then
    echo "ALLOWING: Coordination/trigger/agent operation" >> "$LOG_FILE"
    echo "Exit code: 0" >> "$LOG_FILE"
    exit 0
fi

# WHITELIST: Allow trigger helper functions
if echo "$command" | grep -qE "(trigger_junior_dev|trigger_qa_review|trigger_work_ready|trigger_create_tickets|trigger_next_assignment|create_trigger)"; then
    echo "ALLOWING: Trigger helper function" >> "$LOG_FILE"
    echo "Exit code: 0" >> "$LOG_FILE"
    exit 0
fi

# WHITELIST: Allow safe git commands on main (read-only operations)
if [ "$current_branch" = "main" ]; then
    if echo "$command" | grep -qE "^git (status|log|diff|fetch|branch|show|rev-parse|ls-files|check-ignore)"; then
        echo "ALLOWING: Read-only git command on main" >> "$LOG_FILE"
        echo "Exit code: 0" >> "$LOG_FILE"
        exit 0
    fi
fi

# Block dangerous git commands on main
if [ "$current_branch" = "main" ]; then
    # Block: commit, push to main, merge, rebase, reset
    if echo "$command" | grep -qE "^git (commit|push.*origin main|push.*--force|merge|rebase|reset --hard)"; then
        echo "BLOCKING: Dangerous git command on main branch!" >> "$LOG_FILE"
        echo "❌ BLOCKED: Cannot run '$command' on main branch" >&2
        echo "💡 This prevents accidental commits/pushes to main" >&2
        echo "💡 Create a feature branch first:" >&2
        echo "   git checkout -b feature/your-feature-name" >&2
        echo "Exit code: 2" >> "$LOG_FILE"
        exit 2
    fi
fi

echo "ALLOWING: Command is safe or not on main branch" >> "$LOG_FILE"
echo "Exit code: 0" >> "$LOG_FILE"
exit 0