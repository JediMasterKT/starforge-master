#!/bin/bash
# StarForge Agent Initialization Bundle
# Purpose: Replace 6 separate source commands with 1 to reduce permission prompts
# Impact: 6 prompts → 1 prompt per agent × 5 agents = 25 prompts saved
#
# Workaround for: https://github.com/anthropics/claude-code/issues/5465
# (Permission patterns fail to match piped commands)

# Detect main repo path (works from both main repo and worktrees)
detect_main_repo() {
    # Method 1: If we're already in main repo
    if [ -f .claude/lib/project-env.sh ]; then
        echo "$(pwd)"
        return 0
    fi

    # Method 2: If we're in a worktree, find main via git
    if git worktree list &>/dev/null; then
        git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2
        return 0
    fi

    # Method 3: Fallback to git root
    git rev-parse --show-toplevel 2>/dev/null
}

# Get main repo path
MAIN_REPO=$(detect_main_repo)

if [ -z "$MAIN_REPO" ]; then
    echo "❌ ERROR: Could not detect main repository path"
    echo "   This script must be run from within a git repository"
    return 1 2>/dev/null || exit 1
fi

if [ ! -f "$MAIN_REPO/.claude/lib/project-env.sh" ]; then
    echo "❌ ERROR: project-env.sh not found at $MAIN_REPO/.claude/lib/project-env.sh"
    echo "   This does not appear to be a StarForge repository"
    return 1 2>/dev/null || exit 1
fi

# Source all required scripts in order
# Each script exports functions and variables needed by agents

# 1. Project environment (sets STARFORGE_* variables)
source "$MAIN_REPO/.claude/lib/project-env.sh"

# 2. Context helpers (get_project_context, get_tech_stack, etc.)
source "$MAIN_REPO/.claude/scripts/context-helpers.sh"

# 3. GitHub helpers (get_ticket_from_pr, get_ready_ticket_count, etc.)
source "$MAIN_REPO/.claude/scripts/github-helpers.sh"

# 4. Worktree helpers (is_worktree, get_main_repo_path, etc.)
source "$MAIN_REPO/.claude/scripts/worktree-helpers.sh"

# 5. Test helpers (run_tests, get_test_coverage, etc.)
source "$MAIN_REPO/.claude/scripts/test-helpers.sh"

# 6. Trigger helpers (trigger_junior_dev, trigger_qa_review, etc.)
source "$MAIN_REPO/.claude/scripts/trigger-helpers.sh"

# Set marker that initialization completed successfully
export STARFORGE_AGENT_INITIALIZED=1
export STARFORGE_INIT_TIMESTAMP="$(date -Iseconds)"

# Success message
echo "✅ Agent initialized: ${STARFORGE_AGENT_ID:-unknown}"
echo "   Repository: $STARFORGE_PROJECT_NAME"
echo "   Main repo: $MAIN_REPO"
if is_worktree; then
    echo "   Context: Worktree"
else
    echo "   Context: Main repository"
fi
