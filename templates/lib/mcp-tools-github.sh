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

# Export functions for MCP server use
export -f starforge_list_issues
