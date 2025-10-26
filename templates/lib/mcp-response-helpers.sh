#!/usr/bin/env bash
# MCP Response Helpers - Standardized response formatting
# Provides consistent JSON response formatting for MCP tools

set -euo pipefail

# ============================================================================
# JSON-RPC 2.0 ERROR CODES
# ============================================================================

readonly MCP_ERR_PARSE_ERROR=-32700
readonly MCP_ERR_INVALID_REQUEST=-32600
readonly MCP_ERR_METHOD_NOT_FOUND=-32601
readonly MCP_ERR_INVALID_PARAMS=-32602
readonly MCP_ERR_INTERNAL_ERROR=-32603

# ============================================================================
# RESPONSE BUILDERS
# ============================================================================

# mcp_success_response - Format successful MCP response
#
# Args:
#   $1 - Response data (JSON string or plain text)
#
# Returns:
#   JSON formatted MCP success response
#
# Example:
#   mcp_success_response "Operation completed"
#   mcp_success_response '{"result": "success"}'
mcp_success_response() {
    local data="$1"

    # Check if data is already JSON
    if echo "$data" | jq empty 2>/dev/null; then
        # Already JSON, use as-is
        echo "$data"
    else
        # Plain text, wrap in JSON
        jq -n --arg text "$data" '{"message": $text}'
    fi

    return 0
}

# mcp_error_response - Format error MCP response
#
# Args:
#   $1 - Error code (JSON-RPC error code)
#   $2 - Error message (brief description)
#   $3 - Error details (optional, additional context)
#
# Returns:
#   JSON formatted MCP error response
#
# Example:
#   mcp_error_response -32602 "Invalid parameter" "Parameter 'ticket' is required"
mcp_error_response() {
    local code="$1"
    local message="$2"
    local details="${3:-}"

    if [ -z "$details" ]; then
        jq -n \
            --arg code "$code" \
            --arg message "$message" \
            '{
                "error": {
                    "code": ($code | tonumber),
                    "message": $message
                }
            }' >&2
    else
        jq -n \
            --arg code "$code" \
            --arg message "$message" \
            --arg details "$details" \
            '{
                "error": {
                    "code": ($code | tonumber),
                    "message": $message,
                    "details": $details
                }
            }' >&2
    fi

    return 1
}

# mcp_content_response - Format MCP content response (for text/data)
#
# Args:
#   $1 - Content text or JSON
#
# Returns:
#   JSON formatted MCP content response
#
# Example:
#   mcp_content_response "File contents here"
mcp_content_response() {
    local content="$1"

    # Convert content to JSON string
    local content_json=$(echo "$content" | jq -Rs .)

    # Return MCP content format
    echo "{\"content\": [{\"type\": \"text\", \"text\": $content_json}]}"

    return 0
}

# Export functions for use in tool modules
export -f mcp_success_response
export -f mcp_error_response
export -f mcp_content_response
