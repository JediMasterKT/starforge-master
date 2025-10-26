#!/bin/bash
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
