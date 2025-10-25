#!/bin/bash
# Worktree Helpers
# Purpose: Eliminate permission prompts from piped git worktree commands
# Workaround for: https://github.com/anthropics/claude-code/issues/5465

# Get main repo path from worktree list
# Replaces: git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2
get_main_repo_path() {
    local main_path=$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | cut -d' ' -f2)

    if [ -z "$main_path" ]; then
        # If worktree command fails, we're probably in the main repo
        echo "$(git rev-parse --show-toplevel 2>/dev/null)"
        return 0
    fi

    echo "$main_path"
}

# Check if current directory is a worktree (not main repo)
is_worktree() {
    local git_dir=$(git rev-parse --git-dir 2>/dev/null)

    if [ -z "$git_dir" ]; then
        return 1  # Not in a git repo
    fi

    # If git-dir contains .git/worktrees/, we're in a worktree
    if [[ "$git_dir" == *".git/worktrees/"* ]]; then
        return 0  # Is a worktree
    fi

    return 1  # Not a worktree (main repo)
}

# List all worktrees with their branches
# Replaces: git worktree list --porcelain | grep -E "^worktree|^branch" | paste -d' ' - -
list_worktrees() {
    git worktree list 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "❌ Not in a git repository"
        return 1
    fi
}

# Get worktree path for a specific branch
# Replaces: git worktree list --porcelain | grep -A1 "branch refs/heads/$BRANCH" | grep "^worktree" | cut -d' ' -f2
get_worktree_path() {
    local branch_name=$1

    if [ -z "$branch_name" ]; then
        echo "❌ Branch name required"
        return 1
    fi

    local worktree_path=$(git worktree list --porcelain 2>/dev/null | grep -A1 "branch refs/heads/$branch_name" | grep "^worktree" | cut -d' ' -f2)

    if [ -z "$worktree_path" ]; then
        return 1  # Worktree not found for this branch
    fi

    echo "$worktree_path"
}

# Count active worktrees
# Replaces: git worktree list | wc -l
count_worktrees() {
    local count=$(git worktree list 2>/dev/null | wc -l | tr -d ' ')

    if [ -z "$count" ]; then
        echo "0"
        return 1
    fi

    echo "$count"
}

# Check if branch has an active worktree
has_worktree() {
    local branch_name=$1

    if [ -z "$branch_name" ]; then
        echo "❌ Branch name required"
        return 1
    fi

    git worktree list --porcelain 2>/dev/null | grep -q "branch refs/heads/$branch_name"

    return $?
}

# Get current branch name
get_current_branch() {
    git branch --show-current 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "❌ Not in a git repository"
        return 1
    fi
}

# Verify we're in main repo (not a worktree) - used by agent pre-flight checks
verify_main_repo() {
    if is_worktree; then
        local main_path=$(get_main_repo_path)
        echo "❌ Must run from main repo: $main_path"
        return 1
    fi

    echo "✅ Running from main repository"
    return 0
}

# ============================================================================
# GIT COMMIT HELPERS (Added for ticket #148)
# ============================================================================

# Extract ticket number from branch name
# Replaces: git branch --show-current | sed -n 's/.*ticket-\([0-9]*\).*/\1/p'
extract_ticket_from_branch() {
    local branch_name=${1:-$(git branch --show-current 2>/dev/null)}

    if [ -z "$branch_name" ]; then
        echo "❌ No branch name provided or not in a git repo"
        return 1
    fi

    # Extract number after "ticket-"
    local ticket=$(echo "$branch_name" | sed -n 's/.*ticket-\([0-9]*\).*/\1/p')

    if [ -z "$ticket" ]; then
        return 1  # No ticket number found
    fi

    echo "$ticket"
}

# Get bullet points from commit messages
# Replaces: git log origin/main..HEAD --format="%b" --reverse | grep -E '^\s*-' | sort -u
get_commit_bullets() {
    local base_ref=${1:-"origin/main"}

    local bullets=$(git log "${base_ref}..HEAD" --format="%b" --reverse 2>/dev/null | grep -E '^\s*-' | sort -u)

    if [ -z "$bullets" ]; then
        # No bullet points found, return placeholder
        echo "- Implementation completed"
        return 0
    fi

    echo "$bullets"
}

# Count commits since a reference
# Replaces: git rev-list --count origin/main..HEAD
count_commits_since() {
    local base_ref=${1:-"origin/main"}

    local count=$(git rev-list --count "${base_ref}..HEAD" 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "0"
        return 1
    fi

    echo "$count"
}
