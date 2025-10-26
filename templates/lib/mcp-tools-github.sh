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

    # Build gh issue list command
    local cmd="gh issue list --json number,title,labels,state --limit $limit --state $state"

    # Add label filter if provided
    if [ -n "$labels" ]; then
        cmd="$cmd --label \"$labels\""
    fi

    # Execute and return JSON
    eval "$cmd" 2>&1
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

# Export functions for MCP server use
export -f starforge_list_issues
export -f starforge_run_gh_command
