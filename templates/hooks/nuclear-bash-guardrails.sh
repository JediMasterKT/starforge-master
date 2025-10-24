#!/bin/bash
# Nuclear-Safe Bash Command Guardrails
# Upgrades block-main-bash.sh with defense-in-depth for autonomous mode

# Log file for debugging
LOG_FILE="$HOME/.claude/hook-debug.log"
mkdir -p "$HOME/.claude"

# Log start
echo "=== $(date) ===" >> "$LOG_FILE"
echo "Hook: nuclear-bash-guardrails.sh" >> "$LOG_FILE"

# Read JSON input from stdin
json_input=$(cat)
echo "JSON Input: $json_input" >> "$LOG_FILE"

# Extract command from JSON
command=$(echo "$json_input" | jq -r '.tool_input.command // .command // "unknown"')
echo "Command: $command" >> "$LOG_FILE"

# Extract CWD from JSON
cwd=$(echo "$json_input" | jq -r '.cwd // "."')
echo "CWD: $cwd" >> "$LOG_FILE"

# Get current branch
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
echo "Current branch: $current_branch" >> "$LOG_FILE"

# Get agent type
agent_type="${STARFORGE_AGENT_ID:-main}"
echo "Agent type: $agent_type" >> "$LOG_FILE"

# Source agent isolation validator library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/agent-isolation-validator.sh" ]; then
    . "$SCRIPT_DIR/agent-isolation-validator.sh"
elif [ -f ".claude/hooks/agent-isolation-validator.sh" ]; then
    . .claude/hooks/agent-isolation-validator.sh
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 1: Dangerous Command Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Category 1: Filesystem Destruction
if echo "$command" | grep -qE "rm\s+(-[a-zA-Z]*r[a-zA-Z]*f|.*--force).*\s+(/\s|/\$|~/?$|/Users/?$|/home/?$)"; then
    echo "BLOCKING: Dangerous filesystem destruction command" >> "$LOG_FILE"
    echo "❌ BLOCKED: Dangerous command detected: rm -rf on critical path" >&2
    echo "💡 This pattern destroys system files" >&2
    echo "💡 If you need to clean a directory, use specific paths within project" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for dd to block devices
if echo "$command" | grep -qE "dd\s+.*of=/dev/"; then
    echo "BLOCKING: dd to block device" >> "$LOG_FILE"
    echo "❌ BLOCKED: dd write to block device detected" >&2
    echo "💡 This can destroy disk data" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for mkfs (filesystem formatting)
if echo "$command" | grep -qE "^mkfs\."; then
    echo "BLOCKING: mkfs command" >> "$LOG_FILE"
    echo "❌ BLOCKED: Filesystem formatting command detected" >&2
    echo "💡 This destroys all data on a partition" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Category 2: Remote Code Execution
if echo "$command" | grep -qE "(curl|wget).*\|\s*(bash|sh)"; then
    echo "BLOCKING: Pipe to shell from remote source" >> "$LOG_FILE"
    echo "❌ BLOCKED: Remote code execution pattern detected" >&2
    echo "💡 Downloading and executing scripts is dangerous" >&2
    echo "💡 Download first, review, then execute separately" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for eval with curl/wget (handles escaped quotes)
if echo "$command" | grep -qE "eval.*\\\$\((curl|wget)"; then
    echo "BLOCKING: eval with remote fetch" >> "$LOG_FILE"
    echo "❌ BLOCKED: eval with remote code fetch detected" >&2
    echo "💡 This executes arbitrary remote code" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Also check non-escaped version
if echo "$command" | grep -qE "eval.*\$\((curl|wget)"; then
    echo "BLOCKING: eval with remote fetch" >> "$LOG_FILE"
    echo "❌ BLOCKED: eval with remote code fetch detected" >&2
    echo "💡 This executes arbitrary remote code" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Category 3: Data Exfiltration
if echo "$command" | grep -qE "curl.*(-X POST|--data).*(@\.env|@\.ssh|@.*\.pem|@.*\.key)"; then
    echo "BLOCKING: Data exfiltration via curl" >> "$LOG_FILE"
    echo "❌ BLOCKED: Potential credential exfiltration detected" >&2
    echo "💡 Sending credentials over network is dangerous" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

if echo "$command" | grep -qE "nc\s+.*<\s*(\.env|\.ssh|.*\.pem|.*\.key)"; then
    echo "BLOCKING: Data exfiltration via netcat" >> "$LOG_FILE"
    echo "❌ BLOCKED: Potential credential exfiltration via netcat" >&2
    echo "💡 Sending files over raw network connection is dangerous" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Category 4: Fork Bombs
if echo "$command" | grep -qE ":\(\)\{.*:\|:.*\}"; then
    echo "BLOCKING: Fork bomb pattern" >> "$LOG_FILE"
    echo "❌ BLOCKED: Fork bomb pattern detected" >&2
    echo "💡 This would exhaust system resources" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Category 5: Privilege Escalation (handled by settings.json but double-check)
if echo "$command" | grep -qE "^(sudo|su)\s+"; then
    echo "BLOCKING: Privilege escalation attempt" >> "$LOG_FILE"
    echo "❌ BLOCKED: Privilege escalation detected" >&2
    echo "💡 sudo/su should be handled by settings.json 'ask' rules" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Category 6: Dangerous chmod on root paths
if echo "$command" | grep -qE "chmod\s+777\s+/"; then
    echo "BLOCKING: chmod 777 on root path" >> "$LOG_FILE"
    echo "❌ BLOCKED: Dangerous chmod on root path detected" >&2
    echo "💡 chmod 777 on system paths is a security risk" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 2: Protected Path Access
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# System critical paths
if echo "$command" | grep -qE "(echo|cat|cp|mv|>|>>)\s+.*(/etc/|/usr/|/bin/|/sbin/)"; then
    echo "BLOCKING: Write to system directory" >> "$LOG_FILE"
    echo "❌ BLOCKED: Write to system directory detected" >&2
    echo "💡 Modifying /etc/, /usr/, /bin/ can break the system" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Credential paths
if echo "$command" | grep -qE "(cat|less|more|tail|head)\s+.*(~/\.ssh/|~/.aws/|\.ssh/|\.aws/)"; then
    echo "BLOCKING: Access to credential directory" >> "$LOG_FILE"
    echo "❌ BLOCKED: Access to credential directory detected" >&2
    echo "💡 Reading .ssh/ or .aws/ credentials is not allowed" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 3: Agent Isolation Enforcement
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Call agent isolation validator if available
if type validate_agent_access > /dev/null 2>&1; then
    if ! validate_agent_access "$agent_type" "bash" "$command" "$cwd"; then
        echo "BLOCKING: Agent isolation violation" >> "$LOG_FILE"
        echo "Exit code: 2" >> "$LOG_FILE"
        exit 2
    fi
else
    echo "WARNING: agent-isolation-validator.sh not loaded" >> "$LOG_FILE"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 4: Main Branch Protection (Preserved from block-main-bash.sh)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# WHITELIST: Allow file operations in coordination directories
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# All checks passed
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "ALLOWING: Command passed all safety checks" >> "$LOG_FILE"
echo "Exit code: 0" >> "$LOG_FILE"
exit 0
