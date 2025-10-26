#!/bin/bash
# MCP Tools - Trigger-based tool implementations
# These tools are called by the MCP server to access StarForge context

# Get PROJECT_ROOT if not set (worktree-aware)
if [ -z "$PROJECT_ROOT" ]; then
  # Check if we're in a worktree
  if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel)
  fi
fi

# Get STARFORGE_CLAUDE_DIR if not set
if [ -z "$STARFORGE_CLAUDE_DIR" ]; then
  STARFORGE_CLAUDE_DIR="$PROJECT_ROOT/.claude"
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
