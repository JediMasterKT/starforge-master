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
# Dynamically detects based on actual worktree configuration
# Supports any number of agents and custom naming patterns
detect_agent_id() {
    local current_dir
    current_dir=$(basename "$(pwd)")

    # Try to extract agent ID using common patterns
    # Pattern 1: junior-dev-{letter} (e.g., junior-dev-a, junior-dev-b, junior-dev-z)
    if echo "$current_dir" | grep -qE 'junior-dev-[a-z]$'; then
        echo "$current_dir" | sed -E 's/.*-(junior-dev-[a-z])$/\1/'
        return
    fi

    # Pattern 2: dev-{number} (e.g., dev-1, dev-2, dev-10)
    # Must have a hyphen before "dev-" to distinguish from "junior-dev-"
    if echo "$current_dir" | grep -qE '[^-]+-dev-[0-9]+$'; then
        echo "$current_dir" | sed -E 's/.*-(dev-[0-9]+)$/\1/'
        return
    fi

    # Pattern 3: Check against actual git worktrees (most reliable)
    if command -v git >/dev/null 2>&1 && [ -e ".git" ]; then
        local current_path
        current_path=$(pwd)

        # Get all worktree paths
        local worktrees
        worktrees=$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | cut -d' ' -f2)

        if [ -n "$worktrees" ]; then
            # Get main repo path (first worktree)
            local main_repo
            main_repo=$(echo "$worktrees" | head -1)

            # If we're in main repo, return "main"
            if [ "$current_path" = "$main_repo" ]; then
                echo "main"
                return
            fi

            # Check each worktree to find where we are
            while IFS= read -r worktree_path; do
                if [ "$current_path" = "$worktree_path" ]; then
                    # Extract the suffix after the main repo name
                    local worktree_name
                    worktree_name=$(basename "$worktree_path")

                    # Try to extract agent ID from the worktree name
                    # This handles any pattern: project-{agent-id}
                    local project_base
                    project_base=$(basename "$main_repo")

                    # Remove project base to get agent ID
                    if [ "$worktree_name" != "$project_base" ]; then
                        # Extract everything after project_base-
                        local agent_id
                        agent_id=$(echo "$worktree_name" | sed "s/^${project_base}-//")

                        if [ -n "$agent_id" ] && [ "$agent_id" != "$worktree_name" ]; then
                            echo "$agent_id"
                            return
                        fi
                    fi
                fi
            done <<EOF
$worktrees
EOF
        fi
    fi

    # Default fallback: not a recognized agent worktree
    echo "main"
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
