#!/bin/bash

# Source project environment for dynamic paths
# Try multiple locations to support main repo and worktrees
if [ -f ".claude/lib/project-env.sh" ]; then
    . .claude/lib/project-env.sh
elif [ -f "../.claude/lib/project-env.sh" ]; then
    . ../.claude/lib/project-env.sh
fi

# Log file for debugging
LOG_FILE="$HOME/.claude/hook-debug.log"
mkdir -p "$HOME/.claude"

# Log start
echo "=== $(date) ===" >> "$LOG_FILE"
echo "Hook: block-main-edits.sh" >> "$LOG_FILE"

# Read JSON input from stdin
json_input=$(cat)
echo "JSON Input: $json_input" >> "$LOG_FILE"

# Extract file path from JSON
file_path=$(echo "$json_input" | jq -r '.tool_input.file_path // .file_path // "unknown"')
echo "File path: $file_path" >> "$LOG_FILE"

# Extract CWD from JSON to detect worktrees
cwd=$(echo "$json_input" | jq -r '.cwd // "."')
echo "CWD: $cwd" >> "$LOG_FILE"

# Get current branch
current_branch=$(git branch --show-current 2>&1)
echo "Current branch: $current_branch" >> "$LOG_FILE"

# WHITELIST: Allow ALL edits in junior-dev worktrees
# Junior-devs work on feature branches by architectural design (never on main)
# Use dynamic project name from environment
if [ -n "$STARFORGE_PROJECT_NAME" ]; then
    if [[ "$cwd" =~ $STARFORGE_PROJECT_NAME-junior-dev-[abc] ]] || [[ "$file_path" =~ $STARFORGE_PROJECT_NAME-junior-dev-[abc] ]]; then
        echo "ALLOWING: Junior-dev worktree detected (feature branches only by design)" >> "$LOG_FILE"
        echo "Exit code: 0" >> "$LOG_FILE"
        exit 0
    fi
fi

# WHITELIST: Allow edits to coordination, triggers, agents, spikes on main
# These are NOT code files and should not be blocked
if [[ "$file_path" =~ \.claude/(coordination|triggers|agents|spikes|scripts)/ ]]; then
    echo "ALLOWING: Coordination/trigger/agent file (not source code)" >> "$LOG_FILE"
    echo "Exit code: 0" >> "$LOG_FILE"
    exit 0
fi

# WHITELIST: Allow edits to documentation
if [[ "$file_path" =~ \.(md|txt|json)$ ]] && [[ ! "$file_path" =~ ^(src|tests)/ ]]; then
    echo "ALLOWING: Documentation file" >> "$LOG_FILE"
    echo "Exit code: 0" >> "$LOG_FILE"
    exit 0
fi

# WHITELIST: Allow creating new untracked files
# git ls-files returns error if file is not tracked
if ! git ls-files --error-unmatch "$file_path" > /dev/null 2>&1; then
    echo "ALLOWING: Untracked file (not in git)" >> "$LOG_FILE"
    echo "Exit code: 0" >> "$LOG_FILE"
    exit 0
fi

# Block edits to tracked source code files on main
if [ "$current_branch" = "main" ]; then
    echo "BLOCKING: Tracked source file edit on main branch!" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot modify tracked file '$file_path' on main branch" >&2
    echo "💡 This protects against accidental commits to main" >&2
    echo "💡 Create a feature branch first:" >&2
    echo "   git checkout -b feature/your-feature-name" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

echo "ALLOWING: Not on main branch or whitelisted path" >> "$LOG_FILE"
echo "Exit code: 0" >> "$LOG_FILE"
exit 0