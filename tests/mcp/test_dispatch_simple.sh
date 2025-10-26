#!/usr/bin/env bash
# Simple tests for MCP tool registry and dispatch
# Tests for ticket #173

set -euo pipefail

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Tool Registry - Associative array for O(1) tool lookup
declare -A TOOL_HANDLERS

# Register a tool with its handler function
# Args: tool_name, handler_function
# Returns: 0 on success, 1 on error
register_tool() {
    local tool_name="$1"
    local handler_function="$2"

    # Validate inputs
    if [ -z "$tool_name" ] || [ -z "$handler_function" ]; then
        echo "ERROR: register_tool requires tool_name and handler_function" >&2
        return 1
    fi

    # Validate handler function exists
    if ! type "$handler_function" &>/dev/null; then
        echo "ERROR: Handler function '$handler_function' not found" >&2
        return 1
    fi

    # Warn on overwrite
    if [ -n "${TOOL_HANDLERS[$tool_name]:-}" ]; then
        echo "WARNING: Overwriting handler for '$tool_name' (was: ${TOOL_HANDLERS[$tool_name]}, now: $handler_function)" >&2
    fi

    # Register in associative array
    TOOL_HANDLERS["$tool_name"]="$handler_function"
}

# Dispatch tool call to registered handler
# Args: tool_name, params_json
# Output: Tool response or error
dispatch_tool() {
    local tool_name="$1"
    local params_json="$2"

    # Check if tool is registered
    if [ -z "${TOOL_HANDLERS[$tool_name]:-}" ]; then
        echo "ERROR: Tool '$tool_name' not found in registry" >&2
        return 1
    fi

    # Get handler function
    local handler="${TOOL_HANDLERS[$tool_name]}"

    # Dispatch to handler
    "$handler" "$params_json"
}

# Test helper functions
pass() {
    echo "  ✓ PASS: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo "  ✗ FAIL: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    echo "Running: $1"
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Mock handler functions for testing
mock_handler_read() {
    echo '{"content":"file_content"}'
}

mock_handler_write() {
    echo '{"success":true}'
}

# Test 1: Basic tool registration
test_registers_tool() {
    run_test "test_registers_tool"

    # Register a tool
    if register_tool "read_file" "mock_handler_read" 2>/dev/null; then
        # Check if tool is registered
        if [ "${TOOL_HANDLERS[read_file]:-}" = "mock_handler_read" ]; then
            pass "Tool registered successfully"
        else
            fail "Tool not found in registry"
        fi
    else
        fail "register_tool failed"
    fi
}

# Test 2: Validates handler function exists
test_validates_handler_exists() {
    run_test "test_validates_handler_exists"

    # Try to register with non-existent handler
    if register_tool "invalid_tool" "nonexistent_handler" 2>/dev/null; then
        fail "Should reject non-existent handler"
    else
        pass "Correctly rejected non-existent handler"
    fi
}

# Test 3: Warns on overwrite
test_warns_on_overwrite() {
    run_test "test_warns_on_overwrite"

    # Register tool twice and check for warning
    register_tool "overwrite_test" "mock_handler_read" 2>/dev/null

    local output
    output=$(register_tool "overwrite_test" "mock_handler_write" 2>&1)

    if echo "$output" | grep -q "WARNING.*Overwriting"; then
        pass "Warning issued on overwrite"
    else
        fail "No warning on overwrite"
    fi
}

# Test 4: Rejects empty parameters
test_rejects_empty_params() {
    run_test "test_rejects_empty_params"

    # Try to register with empty tool name
    if register_tool "" "mock_handler_read" 2>/dev/null; then
        fail "Should reject empty tool name"
    else
        pass "Correctly rejected empty tool name"
    fi

    # Try to register with empty handler
    if register_tool "test_tool" "" 2>/dev/null; then
        fail "Should reject empty handler"
    else
        pass "Correctly rejected empty handler"
    fi
}

# Test 5: Dispatches to registered tool
test_dispatches_registered_tool() {
    run_test "test_dispatches_registered_tool"

    # Clear registry for clean test
    unset TOOL_HANDLERS
    declare -A TOOL_HANDLERS

    # Register tool
    register_tool "read_file" "mock_handler_read" 2>/dev/null

    # Dispatch to it
    local result
    result=$(dispatch_tool "read_file" '{}' 2>/dev/null)

    if [ "$result" = '{"content":"file_content"}' ]; then
        pass "Dispatched to correct handler"
    else
        fail "Dispatch returned wrong result: $result"
    fi
}

# Test 6: Returns error for unknown tool
test_returns_error_for_unknown_tool() {
    run_test "test_returns_error_for_unknown_tool"
    echo "DEBUG: In test 6, about to dispatch" >&2

    # Try to dispatch to unregistered tool
    if dispatch_tool "unknown_tool" '{}' 2>/dev/null; then
        echo "DEBUG: dispatch succeeded (unexpected)" >&2
        fail "Should fail for unknown tool"
    else
        echo "DEBUG: dispatch failed (expected)" >&2
        pass "Correctly failed for unknown tool"
    fi
    echo "DEBUG: Test 6 complete" >&2
}

# Run all tests
echo "========================================"
echo "MCP Tool Registry & Dispatch Tests"
echo "========================================"
echo ""

test_registers_tool
test_validates_handler_exists
test_warns_on_overwrite
test_rejects_empty_params
test_dispatches_registered_tool
test_returns_error_for_unknown_tool
echo "DEBUG: All tests completed" >&2

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✓ SUCCESS: All tests passed!"
    exit 0
else
    echo "✗ FAILURE: $TESTS_FAILED test(s) failed"
    exit 1
fi
