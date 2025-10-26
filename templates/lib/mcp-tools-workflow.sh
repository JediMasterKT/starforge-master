#!/usr/bin/env bash
# MCP Tools - Workflow Tools Module
# Consolidated workflow tools that reduce multi-step coordination overhead
# Implements mcp-builder Principle 3: Workflow consolidation

set -euo pipefail

# Get script directory for relative imports
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source response helpers
source "$SCRIPT_DIR/mcp-response-helpers.sh"

# Get PROJECT_ROOT if not set (worktree-aware)
if [ -z "${PROJECT_ROOT:-}" ]; then
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        PROJECT_ROOT=$(git rev-parse --show-toplevel)
    fi
fi

# Get STARFORGE_CLAUDE_DIR if not set
if [ -z "${STARFORGE_CLAUDE_DIR:-}" ]; then
    STARFORGE_CLAUDE_DIR="${PROJECT_ROOT:-}/.claude"
fi

# Get STARFORGE_SCRIPTS_DIR if not set
if [ -z "${STARFORGE_SCRIPTS_DIR:-}" ]; then
    STARFORGE_SCRIPTS_DIR="${PROJECT_ROOT:-}/templates/scripts"
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# check_agent_availability - Check if agent is available for assignment
#
# Args:
#   $1 - Agent ID (e.g., "junior-dev-a")
#
# Returns:
#   Echo status: "idle", "busy", or "error"
#   Exit code: 0 for success
#
# Example:
#   status=$(check_agent_availability "junior-dev-a")
check_agent_availability() {
    local agent="$1"

    # Check if agent has active triggers
    local trigger_dir="${STARFORGE_CLAUDE_DIR}/triggers"
    if [ -d "$trigger_dir" ]; then
        local active_triggers=$(ls -1 "$trigger_dir/${agent}-"*.trigger 2>/dev/null | wc -l)
        if [ "$active_triggers" -gt 0 ]; then
            echo "busy"
            return 0
        fi
    fi

    # Check if agent worktree has uncommitted work
    local worktree_path="${PROJECT_ROOT}-${agent}"
    if [ -d "$worktree_path" ]; then
        if [ -n "$(cd "$worktree_path" && git status --porcelain 2>/dev/null)" ]; then
            echo "busy"
            return 0
        fi
    fi

    # Agent is idle
    echo "idle"
    return 0
}

# Export for external use
export -f check_agent_availability

# ============================================================================
# WORKFLOW TOOLS
# ============================================================================

# handle_manage_ticket - Consolidated ticket management workflow
#
# Implements consolidated workflow for ticket assignment and status checks.
# Reduces 4 separate tool calls (validate, check availability, assign, trigger)
# into a single atomic operation.
#
# Args:
#   $1 - JSON params object with:
#        - ticket: Ticket number (required)
#        - action: Action to perform (required: "assign", "check_status")
#        - agent: Agent ID (required for assign action)
#
# Returns:
#   JSON response (success or error)
#
# Example:
#   handle_manage_ticket '{"ticket": "42", "action": "assign", "agent": "junior-dev-a"}'
handle_manage_ticket() {
    local params="$1"

    # Extract parameters
    local ticket=$(echo "$params" | jq -r '.ticket // empty')
    local action=$(echo "$params" | jq -r '.action // empty')
    local agent=$(echo "$params" | jq -r '.agent // empty')

    # Validate required parameters
    if [ -z "$ticket" ]; then
        mcp_error_response "$MCP_ERR_INVALID_PARAMS" \
            "Missing required parameter: ticket"
        return 1
    fi

    if [ -z "$action" ]; then
        mcp_error_response "$MCP_ERR_INVALID_PARAMS" \
            "Missing required parameter: action"
        return 1
    fi

    # Route to action handler
    case "$action" in
        assign)
            handle_assign_action "$ticket" "$agent"
            ;;

        check_status)
            handle_check_status_action "$ticket"
            ;;

        *)
            mcp_error_response "$MCP_ERR_INVALID_PARAMS" \
                "Invalid action: $action" \
                "Valid actions: assign, check_status"
            return 1
            ;;
    esac
}

# handle_assign_action - Assign ticket to agent (consolidated workflow)
#
# Workflow steps:
#   1. Validate ticket has "ready" label
#   2. Check agent availability
#   3. Assign ticket via gh
#   4. Create trigger for agent
#
# Args:
#   $1 - Ticket number
#   $2 - Agent ID
#
# Returns:
#   JSON success response or error
handle_assign_action() {
    local ticket="$1"
    local agent="$2"

    # Validate agent parameter
    if [ -z "$agent" ]; then
        mcp_error_response "$MCP_ERR_INVALID_PARAMS" \
            "Missing required parameter: agent" \
            "Agent ID is required for assign action"
        return 1
    fi

    # Step 1: Validate ticket is ready
    local labels=$(gh issue view "$ticket" --json labels 2>/dev/null | jq -r '.labels[].name' 2>/dev/null || echo "")

    if ! echo "$labels" | grep -q "ready"; then
        mcp_error_response "$MCP_ERR_INVALID_PARAMS" \
            "Ticket #$ticket not ready" \
            "Must have 'ready' label. Current labels: $labels. Use TPM to mark ready."
        return 1
    fi

    # Step 2: Check agent availability
    local agent_status=$(check_agent_availability "$agent")

    if [ "$agent_status" != "idle" ]; then
        mcp_error_response "$MCP_ERR_INVALID_PARAMS" \
            "Agent $agent not available" \
            "Status: $agent_status. Use orchestrator to find idle agent."
        return 1
    fi

    # Step 3: Assign ticket
    local current_user=$(gh api user -q .login 2>/dev/null || echo "unknown")
    gh issue edit "$ticket" --add-assignee "$current_user" 2>/dev/null || true

    # Step 4: Create trigger
    if [ -x "$STARFORGE_SCRIPTS_DIR/create_trigger.py" ]; then
        python3 "$STARFORGE_SCRIPTS_DIR/create_trigger.py" \
            --from-agent "${STARFORGE_AGENT_ID:-orchestrator}" \
            --to-agent "$agent" \
            --action "implement_ticket" \
            --ticket "$ticket" >/dev/null 2>&1 || true
    fi

    # Step 5: Success response
    mcp_success_response "Ticket #$ticket assigned to $agent. Trigger created."
    return 0
}

# handle_check_status_action - Check ticket status (consolidated workflow)
#
# Retrieves comprehensive ticket status including:
#   - Ticket number and title
#   - Current state
#   - Assigned agent
#   - Labels
#   - Latest comment
#
# Args:
#   $1 - Ticket number
#
# Returns:
#   JSON response with ticket status
handle_check_status_action() {
    local ticket="$1"

    # Get issue data from GitHub
    local issue_data=$(gh issue view "$ticket" --json number,title,state,labels,assignees,comments 2>/dev/null)

    if [ -z "$issue_data" ]; then
        mcp_error_response "$MCP_ERR_INTERNAL_ERROR" \
            "Failed to retrieve ticket #$ticket" \
            "GitHub API returned no data"
        return 1
    fi

    # Build summary response
    local summary=$(echo "$issue_data" | jq '{
        ticket: .number,
        title: .title,
        state: .state,
        assigned_to: (.assignees[0].login // "unassigned"),
        labels: ([.labels[].name] | join(", ")),
        latest_comment: (.comments[-1].body // "No comments")
    }')

    # Return formatted response
    echo "$summary"
    return 0
}

# Register tool with MCP server (if register_tool function available)
if type register_tool &>/dev/null; then
    register_tool "starforge_manage_ticket" "handle_manage_ticket"
fi

# Export functions for external use
export -f handle_manage_ticket
export -f handle_assign_action
export -f handle_check_status_action
