#!/bin/bash
# GitHub Helpers
# Purpose: Eliminate permission prompts from piped GitHub CLI commands
# Workaround for: https://github.com/anthropics/claude-code/issues/5465

# Extract ticket number from PR body
# Replaces: gh pr view $PR_NUMBER --json body --jq .body | grep -o '#[0-9]\+' | head -1 | tr -d '#'
get_ticket_from_pr() {
    local pr_number=$1

    if [ -z "$pr_number" ]; then
        echo "❌ PR number required"
        return 1
    fi

    local ticket=$(gh pr view "$pr_number" --json body --jq .body 2>/dev/null | grep -o '#[0-9]\+' | head -1 | tr -d '#')

    if [ -z "$ticket" ]; then
        echo "❌ No ticket found in PR #$pr_number"
        return 1
    fi

    echo "$ticket"
}

# Get PR diff summary (first 100 lines)
# Replaces: gh pr diff 135 | head -100
get_pr_diff_summary() {
    local pr_number=$1
    local lines=${2:-100}  # Default 100 lines

    if [ -z "$pr_number" ]; then
        echo "❌ PR number required"
        return 1
    fi

    gh pr diff "$pr_number" 2>/dev/null | head -n "$lines"

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "❌ Failed to get diff for PR #$pr_number"
        return 1
    fi
}

# Get full PR diff (no line limit)
# Replaces: gh pr diff 135
get_pr_diff_full() {
    local pr_number=$1

    if [ -z "$pr_number" ]; then
        echo "❌ PR number required"
        return 1
    fi

    gh pr diff "$pr_number" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "❌ Failed to get diff for PR #$pr_number"
        return 1
    fi
}

# Count ready tickets
# Replaces: gh issue list --label "ready" --json number | jq length
get_ready_ticket_count() {
    local count=$(gh issue list --label "ready" --json number 2>/dev/null | jq length 2>/dev/null)

    if [ -z "$count" ]; then
        echo "0"
        return 1
    fi

    echo "$count"
}

# Count PRs needing review
# Replaces: gh pr list --label "needs-review" --json number | jq length
get_pending_pr_count() {
    local count=$(gh pr list --label "needs-review" --json number 2>/dev/null | jq length 2>/dev/null)

    if [ -z "$count" ]; then
        echo "0"
        return 1
    fi

    echo "$count"
}

# Get latest trigger file for orchestrator
# Replaces: ls -t $STARFORGE_CLAUDE_DIR/triggers/orchestrator-assign_next_work-*.trigger 2>/dev/null | head -1
get_latest_trigger() {
    local agent=${1:-"orchestrator"}
    local action=${2:-"assign_next_work"}

    local trigger_file=$(ls -t "$STARFORGE_CLAUDE_DIR/triggers/${agent}-${action}-"*.trigger 2>/dev/null | head -1)

    if [ -z "$trigger_file" ]; then
        return 1  # No trigger found (not necessarily an error)
    fi

    echo "$trigger_file"
}

# Get PR details (JSON)
# Replaces: gh pr view $PR_NUMBER --json <fields>
get_pr_details() {
    local pr_number=$1
    shift  # Remove first arg, rest are field names

    if [ -z "$pr_number" ]; then
        echo "❌ PR number required"
        return 1
    fi

    local fields="${@:-number,title,author,body,state}"  # Default fields

    gh pr view "$pr_number" --json "$fields" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "{}"
        return 1
    fi
}

# Get issue details (JSON)
# Replaces: gh issue view $ISSUE_NUMBER --json <fields>
get_issue_details() {
    local issue_number=$1
    shift  # Remove first arg, rest are field names

    if [ -z "$issue_number" ]; then
        echo "❌ Issue number required"
        return 1
    fi

    local fields="${@:-number,title,body,state,labels}"  # Default fields

    gh issue view "$issue_number" --json "$fields" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "{}"
        return 1
    fi
}

# List PRs with specific label (as JSON array)
# Replaces: gh pr list --label "needs-review" --json number,title,author
get_prs_by_label() {
    local label=$1

    if [ -z "$label" ]; then
        echo "❌ Label required"
        return 1
    fi

    gh pr list --label "$label" --json number,title,author 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "[]"
        return 1
    fi
}

# List issues with specific label (as JSON array)
# Replaces: gh issue list --label "ready" --json number,title
get_issues_by_label() {
    local label=$1

    if [ -z "$label" ]; then
        echo "❌ Label required"
        return 1
    fi

    gh issue list --label "$label" --json number,title 2>/dev/null

    if [ $? -ne 0 ]; then
        echo "[]"
        return 1
    fi
}

# Check if GitHub CLI is authenticated
# Replaces: gh auth status > /dev/null 2>&1
check_gh_auth() {
    gh auth status > /dev/null 2>&1
    return $?
}
