#!/bin/bash
# MCP Server - JSON-RPC 2.0 Protocol Handler
# Implements Model Context Protocol server over stdin/stdout
# Spec: https://spec.modelcontextprotocol.io/

set -euo pipefail

# JSON-RPC 2.0 error codes
readonly ERR_PARSE_ERROR=-32700
readonly ERR_INVALID_REQUEST=-32600
readonly ERR_METHOD_NOT_FOUND=-32601
readonly ERR_INVALID_PARAMS=-32602
readonly ERR_INTERNAL_ERROR=-32603

# Parse JSON-RPC request
# Input: JSON string
# Output: Parsed JSON object
parse_jsonrpc_request() {
    local request="$1"

    # Validate it's valid JSON
    if ! echo "$request" | jq empty 2>/dev/null; then
        return 1
    fi

    # Return the parsed request (jq validates and formats it)
    echo "$request" | jq -c '.'
}

# Build JSON-RPC success response
# Args: request_id, result_data
# Output: JSON-RPC 2.0 success response
build_success_response() {
    local request_id="$1"
    local result_data="$2"

    jq -nc \
        --arg id "$request_id" \
        --argjson result "$result_data" \
        '{
            jsonrpc: "2.0",
            id: ($id | tonumber),
            result: $result
        }'
}

# Build JSON-RPC error response
# Args: request_id, error_code, error_message, [error_data]
# Output: JSON-RPC 2.0 error response
build_error_response() {
    local request_id="$1"
    local error_code="$2"
    local error_message="$3"
    local error_data="${4:-null}"

    # Handle null request ID (parse errors where we can't extract ID)
    if [ "$error_data" = "null" ]; then
        if [ "$request_id" = "null" ]; then
            jq -nc \
                --arg code "$error_code" \
                --arg message "$error_message" \
                '{
                    jsonrpc: "2.0",
                    id: null,
                    error: {
                        code: ($code | tonumber),
                        message: $message
                    }
                }'
        else
            jq -nc \
                --arg id "$request_id" \
                --arg code "$error_code" \
                --arg message "$error_message" \
                '{
                    jsonrpc: "2.0",
                    id: ($id | tonumber),
                    error: {
                        code: ($code | tonumber),
                        message: $message
                    }
                }'
        fi
    else
        if [ "$request_id" = "null" ]; then
            jq -nc \
                --arg code "$error_code" \
                --arg message "$error_message" \
                --argjson data "$error_data" \
                '{
                    jsonrpc: "2.0",
                    id: null,
                    error: {
                        code: ($code | tonumber),
                        message: $message,
                        data: $data
                    }
                }'
        else
            jq -nc \
                --arg id "$request_id" \
                --arg code "$error_code" \
                --arg message "$error_message" \
                --argjson data "$error_data" \
                '{
                    jsonrpc: "2.0",
                    id: ($id | tonumber),
                    error: {
                        code: ($code | tonumber),
                        message: $message,
                        data: $data
                    }
                }'
        fi
    fi
}

# Validate JSON-RPC request structure
# Args: parsed_request
# Returns: 0 if valid, 1 if invalid
validate_request_structure() {
    local request="$1"

    # Check required fields
    local jsonrpc
    jsonrpc=$(echo "$request" | jq -r '.jsonrpc // empty')
    if [ "$jsonrpc" != "2.0" ]; then
        return 1
    fi

    local method
    method=$(echo "$request" | jq -r '.method // empty')
    if [ -z "$method" ]; then
        return 1
    fi

    local id
    id=$(echo "$request" | jq -r '.id // empty')
    if [ -z "$id" ]; then
        return 1
    fi

    return 0
}

# Handle a single JSON-RPC request
# Args: request_json
# Output: JSON-RPC response
handle_request() {
    local request_json="$1"

    # Try to parse the JSON
    local parsed_request
    if ! parsed_request=$(parse_jsonrpc_request "$request_json" 2>/dev/null); then
        # Parse error - can't extract ID, use null
        build_error_response "null" "$ERR_PARSE_ERROR" "Parse error"
        return 0
    fi

    # Extract request ID for error responses
    local request_id
    request_id=$(echo "$parsed_request" | jq -r '.id // "null"')

    # Validate request structure
    if ! validate_request_structure "$parsed_request"; then
        build_error_response "$request_id" "$ERR_INVALID_REQUEST" "Invalid Request"
        return 0
    fi

    # Extract method
    local method
    method=$(echo "$parsed_request" | jq -r '.method')

    # Route to appropriate handler based on method
    case "$method" in
        tools/call)
            handle_tools_call "$parsed_request"
            ;;
        tools/list)
            handle_tools_list "$parsed_request"
            ;;
        initialize)
            handle_initialize "$parsed_request"
            ;;
        *)
            build_error_response "$request_id" "$ERR_METHOD_NOT_FOUND" "Method not found"
            ;;
    esac
}

# Handle tools/call method (stub for now - will be implemented in later tickets)
handle_tools_call() {
    local request="$1"
    local request_id
    request_id=$(echo "$request" | jq -r '.id')

    # Stub response - real implementation in later tickets
    build_success_response "$request_id" '{"content":[{"type":"text","text":"stub"}]}'
}

# Handle tools/list method (stub for now - will be implemented in later tickets)
handle_tools_list() {
    local request="$1"
    local request_id
    request_id=$(echo "$request" | jq -r '.id')

    # Stub response - real implementation in later tickets
    build_success_response "$request_id" '{"tools":[]}'
}

# Handle initialize method (stub for now - will be implemented in later tickets)
handle_initialize() {
    local request="$1"
    local request_id
    request_id=$(echo "$request" | jq -r '.id')

    # Stub response - real implementation in later tickets
    build_success_response "$request_id" '{
        "protocolVersion": "2024-11-05",
        "capabilities": {
            "tools": {}
        },
        "serverInfo": {
            "name": "starforge-mcp",
            "version": "0.1.0"
        }
    }'
}

# Main server loop
# Reads JSON-RPC requests from stdin, writes responses to stdout
main() {
    # Line-buffered mode for real-time I/O
    stty -icanon 2>/dev/null || true

    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue

        # Handle request and write response
        response=$(handle_request "$line")
        echo "$response"
    done
}

# If script is executed directly (not sourced), run main loop
if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
    main "$@"
fi
