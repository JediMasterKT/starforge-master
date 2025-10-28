#!/bin/bash
set -euo pipefail
# MCP Tools - Trigger-based tool implementations
# These tools are called by the MCP server to access StarForge context

# Get PROJECT_ROOT if not set (worktree-aware)
if [ -z "${PROJECT_ROOT:-}" ]; then
  # Check if we're in a worktree
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel)
  fi
fi

# Get STARFORGE_CLAUDE_DIR if not set
if [ -z "${STARFORGE_CLAUDE_DIR:-}" ]; then
  STARFORGE_CLAUDE_DIR="${PROJECT_ROOT:-}/.claude"
fi

# ============================================================================
# CONTEXT TOOLS
# ============================================================================

# get_project_context - Returns PROJECT_CONTEXT.md contents
#
# Returns:
#   JSON object with MCP response format containing project context
#
# Exit codes:
#   0 - Success
#   1 - File not found or error
#
# Example:
#   get_project_context
#   {"content": [{"type": "text", "text": "# Project Context..."}]}
get_project_context() {
  local context_file="$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md"

  # Check if file exists
  if [ ! -f "$context_file" ]; then
    echo '{"error": "PROJECT_CONTEXT.md not found"}' >&2
    return 1
  fi

  # Read file and convert to JSON string
  local content=$(cat "$context_file" | jq -Rs .)

  # Return MCP response format
  echo "{\"content\": [{\"type\": \"text\", \"text\": $content}]}"
  return 0
}

# get_tech_stack - Returns TECH_STACK.md contents
#
# Returns:
#   JSON object with MCP response format containing tech stack information
#
# Exit codes:
#   0 - Success
#   1 - File not found or error
#
# Example:
#   get_tech_stack
#   {"content": [{"type": "text", "text": "# Tech Stack..."}]}
get_tech_stack() {
  local tech_stack_file="$STARFORGE_CLAUDE_DIR/TECH_STACK.md"

  # Check if file exists
  if [ ! -f "$tech_stack_file" ]; then
    echo '{"error": "TECH_STACK.md not found"}' >&2
    return 1
  fi

  # Read file and convert to JSON string
  local content=$(cat "$tech_stack_file" | jq -Rs .)

  # Return MCP response format
  echo "{\"content\": [{\"type\": \"text\", \"text\": $content}]}"
  return 0
}

# ============================================================================
# METADATA TOOLS (D-stream)
# ============================================================================

# get_agent_learnings - Returns agent-specific learnings
#
# Args:
#   $1 - Agent ID (e.g., "junior-engineer", "senior-engineer")
#
# Returns:
#   JSON object with MCP response format containing agent learnings
#
# Exit codes:
#   0 - Success (even if file doesn't exist, returns empty/default message)
#   1 - Error (invalid parameters)
#
# Example:
#   get_agent_learnings "junior-engineer"
#   {"content": [{"type": "text", "text": "# Agent Learnings..."}]}
get_agent_learnings() {
  local agent=$1

  # Validate agent parameter
  if [ -z "$agent" ]; then
    echo '{"error": "agent parameter is required"}' >&2
    return 1
  fi

  local learnings_file="$STARFORGE_CLAUDE_DIR/agents/agent-learnings/$agent/learnings.md"

  # Check if file exists
  if [ ! -f "$learnings_file" ]; then
    # Return empty learnings message (graceful handling)
    local empty_content=$(cat <<EOF
---
name: "$agent"
description: "No learnings recorded yet"
---

# Agent Learnings

No learnings have been recorded for this agent yet.
EOF
)
    local content_json=$(echo "$empty_content" | jq -Rs .)
    echo "{\"content\": [{\"type\": \"text\", \"text\": $content_json}]}"
    return 0
  fi

  # Read file and convert to JSON string
  local content=$(cat "$learnings_file" | jq -Rs .)

  # Return MCP response format
  echo "{\"content\": [{\"type\": \"text\", \"text\": $content}]}"
  return 0
}

# ============================================================================
# TRIGGER CREATION TOOLS
# ============================================================================

# starforge_create_trigger - Create a StarForge trigger file
#
# Creates a trigger file for agent handoffs with validation and atomic write.
# Auto-populates from_agent from STARFORGE_AGENT_ID environment variable.
# Auto-generates command and message fields required by stop hook.
#
# Args:
#   $1 - to_agent (required): Target agent to receive trigger
#   $2 - action (required): Action for target agent to perform (e.g., "review_pr")
#   $3 - context (optional): JSON object with metadata (default: {})
#
# Generated Fields:
#   - message: Auto-generated from action (e.g., "review_pr" → "Review Pr")
#   - command: Auto-generated as "Use <agent>. <message>." for human invocation
#   - from_agent: Auto-populated from STARFORGE_AGENT_ID environment variable
#   - timestamp: Auto-generated ISO 8601 UTC timestamp
#
# Returns:
#   JSON object with:
#   - {"trigger_file": "/path/to/trigger", "trigger_id": "unique-id"} on success
#   - {"error": "error message"} on failure
#
# Exit codes:
#   0 - Success
#   1 - Validation error or write failure
#
# Examples:
#   starforge_create_trigger "qa-engineer" "review_pr" '{"pr": 42, "ticket": 100}'
#   # => Creates trigger with:
#   #    - message: "Review Pr"
#   #    - command: "Use qa-engineer. Review Pr."
#   #    - context: {"pr": 42, "ticket": 100}
#
#   starforge_create_trigger "orchestrator" "assign_tickets" '{}'
#   # => Creates trigger with:
#   #    - message: "Assign Tickets"
#   #    - command: "Use orchestrator. Assign Tickets."
#   #    - context: {}
#
starforge_create_trigger() {
  local to_agent="$1"
  local action="$2"
  local context="$3"

  # Validate required fields
  if [ -z "$to_agent" ]; then
    echo '{"error": "to_agent is required"}'
    return 1
  fi

  if [ -z "$action" ]; then
    echo '{"error": "action is required"}'
    return 1
  fi

  # Set default context if not provided
  if [ -z "$context" ]; then
    context="{}"
  fi

  # Get from_agent from environment
  local from_agent="${STARFORGE_AGENT_ID:-unknown}"

  # Generate message field (human-readable description)
  # Format action as human-readable message (replace underscores with spaces, capitalize first letter of each word)
  local message=$(echo "$action" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

  # Generate command field (instruction for human to invoke next agent)
  # Format: "Use <agent>. <brief instruction>."
  local command="Use ${to_agent}. ${message}."

  # Generate unique trigger ID with epoch timestamp in nanoseconds for uniqueness
  # Using nanoseconds ensures uniqueness even for rapid consecutive calls
  local epoch_ns=$(date +%s%N)
  local trigger_id="${to_agent}-${action}-${epoch_ns}"

  # Ensure trigger directory exists (only once, cached by filesystem)
  local trigger_dir="${STARFORGE_CLAUDE_DIR}/triggers"
  mkdir -p "$trigger_dir"

  # Generate trigger file path
  local trigger_file="${trigger_dir}/${trigger_id}.trigger"

  # Create and write trigger JSON in one jq call (validates context and creates output)
  # This combines validation + generation for better performance
  # Note: Generate timestamp in jq to avoid separate date call
  if ! jq -n \
    --arg from "$from_agent" \
    --arg to "$to_agent" \
    --arg act "$action" \
    --arg msg "$message" \
    --arg cmd "$command" \
    --argjson ctx "$context" \
    '{
      "from_agent": $from,
      "to_agent": $to,
      "action": $act,
      "message": $msg,
      "command": $cmd,
      "timestamp": (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
      "context": $ctx
    }' > "$trigger_file" 2>/dev/null; then
    # If jq fails, it's either invalid JSON context or write failure
    echo '{"error": "context must be valid JSON or write failed"}'
    rm -f "$trigger_file" 2>/dev/null  # Clean up partial file
    return 1
  fi

  # Return success response with trigger file path and ID
  echo "{\"trigger_file\": \"$trigger_file\", \"trigger_id\": \"$trigger_id\"}"
  return 0
}

# Export function for use in other scripts
export -f starforge_create_trigger

# Auto-register tools with MCP server when module is loaded
# Only register if register_tool function exists (i.e., we're being sourced by mcp-server)
if declare -f register_tool > /dev/null 2>&1; then
    # Trigger creation (modifies state by creating files, not destructive, not idempotent)
    # Each call creates a new trigger file even with same params (timestamped)
    register_tool "starforge_create_trigger" "starforge_create_trigger" false false false
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# return_success - Format successful MCP response
#
# Args:
#   $1 - JSON response content
#
# Returns:
#   Formatted JSON response
return_success() {
  local response=$1
  echo "$response"
  return 0
}

# return_error - Format error MCP response
#
# Args:
#   $1 - Error message
#
# Returns:
#   Formatted JSON error response
return_error() {
  local message=$1
  echo "{\"error\": \"$message\"}" >&2
  return 1
}
