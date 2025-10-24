#!/bin/bash
# Nuclear-Safe Edit Guardrails
# Upgrades block-main-edits.sh with defense-in-depth for autonomous mode

# Preserve agent ID if already set (e.g., in tests)
# project-env.sh will try to auto-detect and overwrite
STARFORGE_AGENT_ID_OVERRIDE="$STARFORGE_AGENT_ID"

# Source project environment for dynamic paths
# Try multiple locations to support main repo and worktrees
if [ -f ".claude/lib/project-env.sh" ]; then
    . .claude/lib/project-env.sh
elif [ -f "../.claude/lib/project-env.sh" ]; then
    . ../.claude/lib/project-env.sh
fi

# Restore overridden agent ID if it was explicitly set
if [ -n "$STARFORGE_AGENT_ID_OVERRIDE" ]; then
    STARFORGE_AGENT_ID="$STARFORGE_AGENT_ID_OVERRIDE"
    export STARFORGE_AGENT_ID
fi

# Log file for debugging
LOG_FILE="$HOME/.claude/hook-debug.log"
mkdir -p "$HOME/.claude"

# Log start
echo "=== $(date) ===" >> "$LOG_FILE"
echo "Hook: nuclear-edit-guardrails.sh" >> "$LOG_FILE"

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
# LAYER 1: Credential File Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check for .env files
if [[ "$file_path" =~ \.env($|\.|/) ]]; then
    echo "BLOCKING: Credential file (.env)" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit credential file: $file_path" >&2
    echo "💡 .env files contain secrets and should not be modified by agents" >&2
    echo "💡 Use environment variables or config files instead" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for .pem files (certificates)
if [[ "$file_path" =~ \.pem$ ]]; then
    echo "BLOCKING: Certificate file (.pem)" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit certificate file: $file_path" >&2
    echo "💡 Certificate files should not be modified" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for .key files (private keys)
if [[ "$file_path" =~ \.key$ ]]; then
    echo "BLOCKING: Private key file (.key)" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit private key file: $file_path" >&2
    echo "💡 Private keys should not be modified" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for credentials.json
if [[ "$file_path" =~ credentials\.json$ ]]; then
    echo "BLOCKING: Credentials file" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit credentials file: $file_path" >&2
    echo "💡 Credential files should not be modified by agents" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for secrets.yaml
if [[ "$file_path" =~ secrets\.(yaml|yml)$ ]]; then
    echo "BLOCKING: Secrets file" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit secrets file: $file_path" >&2
    echo "💡 Secret files should not be modified by agents" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for .ssh directory
if [[ "$file_path" =~ \.ssh/ ]]; then
    echo "BLOCKING: SSH directory access" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit SSH files: $file_path" >&2
    echo "💡 SSH keys and config should not be modified" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Check for .aws directory
if [[ "$file_path" =~ \.aws/ ]]; then
    echo "BLOCKING: AWS credentials directory" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit AWS credential files: $file_path" >&2
    echo "💡 AWS credentials should not be modified" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 2: Infrastructure Protection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Block editing agent definitions (unless specifically allowed by agent type)
if [[ "$file_path" =~ \.claude/agents/ ]] && [[ "$agent_type" != "main" ]]; then
    echo "BLOCKING: Agent definition edit" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit agent definitions: $file_path" >&2
    echo "💡 Agent definitions are system-managed" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Block editing hooks
if [[ "$file_path" =~ \.claude/hooks/ ]]; then
    echo "BLOCKING: Hook file edit" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit hook files: $file_path" >&2
    echo "💡 Hooks are security-critical and system-managed" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Block editing lib files
if [[ "$file_path" =~ \.claude/lib/ ]]; then
    echo "BLOCKING: Library file edit" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit library files: $file_path" >&2
    echo "💡 Library files are system-managed" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# Block editing .git directory
if [[ "$file_path" =~ \.git/ ]]; then
    echo "BLOCKING: Git internals edit" >> "$LOG_FILE"
    echo "❌ BLOCKED: Cannot edit .git directory: $file_path" >&2
    echo "💡 Git internals should not be manually edited" >&2
    echo "Exit code: 2" >> "$LOG_FILE"
    exit 2
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 3: Agent Isolation Enforcement
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Call agent isolation validator if available
if type validate_agent_access > /dev/null 2>&1; then
    if ! validate_agent_access "$agent_type" "edit" "$file_path" "$cwd"; then
        echo "BLOCKING: Agent isolation violation" >> "$LOG_FILE"
        echo "Exit code: 2" >> "$LOG_FILE"
        exit 2
    fi
else
    echo "WARNING: agent-isolation-validator.sh not loaded" >> "$LOG_FILE"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LAYER 4: Main Branch Protection (Preserved from block-main-edits.sh)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

# WHITELIST: Allow edits to coordination, triggers, spikes on main
# These are NOT code files and should not be blocked
if [[ "$file_path" =~ \.claude/(coordination|triggers|spikes|scripts)/ ]]; then
    echo "ALLOWING: Coordination/trigger/spike file (not source code)" >> "$LOG_FILE"
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

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# All checks passed
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "ALLOWING: File edit passed all safety checks" >> "$LOG_FILE"
echo "Exit code: 0" >> "$LOG_FILE"
exit 0
