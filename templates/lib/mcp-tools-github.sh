#!/bin/bash
# templates/lib/mcp-tools-github.sh
#
# MCP Server GitHub Tools
#
# Provides GitHub operations for Model Context Protocol integration.

# starforge_list_issues - List GitHub issues with filtering
#
# Wraps `gh issue list` with MCP-friendly JSON output.
#
# Args:
#   --state <open|closed|all>  Filter by issue state (default: open)
#   --label <labels>           Filter by labels (comma-separated)
#   --limit <N>                Limit number of results (default: 30)
#
# Returns:
#   JSON array of issues with fields:
#   - number: Issue number
#   - title: Issue title
#   - labels: Array of label objects with name
#   - state: Issue state (open/closed)
#
# Example:
#   starforge_list_issues --state open --label "bug,P1" --limit 10
#
starforge_list_issues() {
    local state="open"
    local labels=""
    local limit="30"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --state)
                state="$2"
                shift 2
                ;;
            --label)
                labels="$2"
                shift 2
                ;;
            --limit)
                limit="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1" >&2
                return 1
                ;;
        esac
    done

    # Validate state parameter (prevent command injection)
    case "$state" in
        open|closed|all)
            # Valid state
            ;;
        *)
            echo "Invalid state: $state (must be open, closed, or all)" >&2
            return 1
            ;;
    esac

    # Validate limit is a number
    if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
        echo "Invalid limit: $limit (must be a number)" >&2
        return 1
    fi

    # Build command safely without eval
    # Use array to avoid injection
    local gh_args=(
        "issue"
        "list"
        "--json" "number,title,labels,state"
        "--limit" "$limit"
        "--state" "$state"
    )

    # Add label filter if provided
    if [ -n "$labels" ]; then
        gh_args+=("--label" "$labels")
    fi

    # Execute safely (no eval)
    gh "${gh_args[@]}" 2>&1
}

# starforge_run_gh_command - Execute arbitrary gh commands safely
#
# Generic wrapper for gh CLI with safety checks to prevent command injection.
#
# Args:
#   $1: gh command string (without "gh" prefix)
#       Examples: "issue list --limit 10", "api user", "repo view --json name"
#
# Returns:
#   Command output (stdout/stderr combined)
#   Exit code: 0 on success, 1 on validation failure, gh exit code otherwise
#
# Security:
#   - Validates input is not empty
#   - Blocks command injection attempts (;, |, &, $(), ``, etc.)
#   - Only executes gh commands (no arbitrary shell commands)
#
# Example:
#   starforge_run_gh_command "issue list --limit 5"
#   starforge_run_gh_command "api repos/owner/repo/issues"
#
starforge_run_gh_command() {
    local gh_args="$1"

    # Validate: Command must not be empty
    if [ -z "$gh_args" ] || [ -z "${gh_args// /}" ]; then
        echo '{"error": "Command cannot be empty"}' >&2
        return 1
    fi

    # Security: Block command injection attempts
    # Check for dangerous characters/patterns
    if echo "$gh_args" | grep -qE '[;&|`$()]|\$\{|<|>'; then
        echo '{"error": "Invalid command: contains forbidden characters"}' >&2
        return 1
    fi

    # Security: Ensure we're only running gh commands
    # The function should only accept gh subcommands, not full commands
    # We prepend "gh" ourselves to ensure safety

    # Execute gh command and capture output
    # Note: We use $gh_args unquoted to allow argument splitting
    # This is safe because we've validated no injection chars exist
    gh $gh_args 2>&1
}


# starforge_create_issue - Create a new GitHub issue
#
# Wraps `gh issue create` with MCP-friendly JSON output.
#
# Args:
#   --title <title>        Issue title (required)
#   --body <body>          Issue body/description (required)
#   --label <labels>       Comma-separated labels (optional)
#   --assignee <users>     Comma-separated assignees (optional)
#
# Returns:
#   JSON object with fields:
#   - number: Created issue number
#   - url: Issue URL
#
# Example:
#   starforge_create_issue --title "Bug fix" --body "Fix the thing" --label "bug,P1"
#
starforge_create_issue() {
    local title=""
    local body=""
    local labels=""
    local assignees=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --title)
                title="$2"
                shift 2
                ;;
            --body)
                body="$2"
                shift 2
                ;;
            --label)
                labels="$2"
                shift 2
                ;;
            --assignee)
                assignees="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown argument: $1" >&2
                return 1
                ;;
        esac
    done

    # Validate required parameters
    if [ -z "$title" ]; then
        echo "Error: --title is required" >&2
        return 1
    fi

    if [ -z "$body" ]; then
        echo "Error: --body is required" >&2
        return 1
    fi

    # Build gh issue create command
    local cmd="gh issue create --title \"$title\" --body \"$body\""

    # Add optional parameters
    if [ -n "$labels" ]; then
        cmd="$cmd --label \"$labels\""
    fi

    if [ -n "$assignees" ]; then
        cmd="$cmd --assignee \"$assignees\""
    fi

    # Execute and capture URL
    local issue_url
    issue_url=$(eval "$cmd" 2>&1)

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create issue: $issue_url" >&2
        return 1
    fi

    # Extract issue number from URL
    # URL format: https://github.com/owner/repo/issues/123
    local issue_number
    issue_number=$(echo "$issue_url" | sed 's/.*\/issues\///' | tr -d '[:space:]')

    if [ -z "$issue_number" ]; then
        echo "Error: Failed to extract issue number from: $issue_url" >&2
        return 1
    fi

    # Return JSON
    jq -n \
        --arg number "$issue_number" \
        --arg url "$issue_url" \
        '{number: ($number | tonumber), url: $url}'
}

# Export functions for MCP server use
export -f starforge_list_issues
export -f starforge_run_gh_command
export -f starforge_create_issue
