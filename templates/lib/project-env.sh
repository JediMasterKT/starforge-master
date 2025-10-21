#!/bin/sh
# StarForge Project Environment Detection Library
# Detects main repo path, project name, and agent ID
# Works from main repo or any worktree
# POSIX-compatible (no bash-isms)

# Prevent multiple sourcing issues (idempotent)
# Only skip if we're in the same directory
if [ -n "$STARFORGE_ENV_LOADED" ] && [ "$STARFORGE_ENV_SOURCE_DIR" = "$(pwd)" ]; then
    return 0
fi

# Auto-detect main repo (works in worktrees)
# Uses git worktree list to find the first worktree, which is always the main repo
# Only proceed if we have a .git file or directory in current location
if [ -e ".git" ] && command -v git >/dev/null 2>&1; then
    # We're in a git repository (main or worktree)
    STARFORGE_MAIN_REPO=$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | cut -d' ' -f2)

    # Fallback if git worktree not available or fails
    if [ -z "$STARFORGE_MAIN_REPO" ]; then
        STARFORGE_MAIN_REPO=$(git rev-parse --show-toplevel 2>/dev/null)
    fi
else
    # Not a git repo - fallback to current directory
    STARFORGE_MAIN_REPO=$(pwd)
fi

# If still empty, use pwd as absolute fallback
if [ -z "$STARFORGE_MAIN_REPO" ]; then
    STARFORGE_MAIN_REPO=$(pwd)
fi

# Extract project name from main repo path
STARFORGE_PROJECT_NAME=$(basename "$STARFORGE_MAIN_REPO")

# Detect if we're in a worktree
# A worktree has a .git file (not directory) pointing to the main repo
_current_pwd=$(pwd)
if [ -f "$_current_pwd/.git" ] && [ "$_current_pwd" != "$STARFORGE_MAIN_REPO" ]; then
    STARFORGE_IS_WORKTREE="true"
else
    STARFORGE_IS_WORKTREE="false"
fi

# Detect agent ID from worktree directory name
# Expected pattern: project-name-junior-dev-{a|b|c}
detect_agent_id() {
    local current_dir
    current_dir=$(basename "$(pwd)")

    # Check if directory name contains junior-dev-{a|b|c}
    case "$current_dir" in
        *-junior-dev-a)
            echo "junior-dev-a"
            ;;
        *-junior-dev-b)
            echo "junior-dev-b"
            ;;
        *-junior-dev-c)
            echo "junior-dev-c"
            ;;
        *)
            echo "main"
            ;;
    esac
}

# Helper function: is_worktree
# Returns 0 (success) if in worktree, 1 (failure) otherwise
is_worktree() {
    [ "$STARFORGE_IS_WORKTREE" = "true" ]
}

# Set agent ID
STARFORGE_AGENT_ID=$(detect_agent_id)

# Set Claude directory (always points to main repo)
STARFORGE_CLAUDE_DIR="$STARFORGE_MAIN_REPO/.claude"

# Export all variables
export STARFORGE_MAIN_REPO
export STARFORGE_PROJECT_NAME
export STARFORGE_AGENT_ID
export STARFORGE_CLAUDE_DIR
export STARFORGE_IS_WORKTREE

# Mark as loaded and remember source directory
STARFORGE_ENV_LOADED="true"
STARFORGE_ENV_SOURCE_DIR="$(pwd)"
export STARFORGE_ENV_LOADED
export STARFORGE_ENV_SOURCE_DIR
