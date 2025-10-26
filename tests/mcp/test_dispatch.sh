#!/bin/bash
# Unit tests for MCP Tool Registry & Dispatch
# Tests tool registration and dispatch mechanism

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the mcp-server to get functions
source "$PROJECT_ROOT/templates/bin/mcp-server.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "MCP Tool Registry & Dispatch Unit Tests"
echo "========================================"
echo ""

# Test helper: Compare actual vs expected
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓ PASS: $test_name${NC}"
        return 0
    else
        echo -e "${RED}✗ FAIL: $test_name${NC}"
        echo "  Expected: $expected"
        echo "  Got: $actual"
        exit 1
    fi
}

# Test 1: Register a tool
echo "Test 1: register_tool() - Registers tool with handler"

# Create a mock handler (must exist before registration)
handle_test_tool() {
    echo '{"result": "test_success"}'
}

register_tool "test_tool" "handle_test_tool"

# Check if tool is registered
if [ "${TOOL_HANDLERS[test_tool]:-}" = "handle_test_tool" ]; then
    echo -e "${GREEN}✓ PASS: Tool registered successfully${NC}"
else
    echo -e "${RED}✗ FAIL: Tool not registered correctly${NC}"
    exit 1
fi
echo ""

# Test 2: Dispatch to registered tool
echo "Test 2: dispatch_tool() - Dispatches to correct handler"

# Dispatch to the tool
result=$(dispatch_tool "test_tool" '{"param": "value"}')
expected='{"result": "test_success"}'
assert_equals "$expected" "$result" "Dispatch returns handler result"
echo ""

# Test 3: Return error for unknown tool
echo "Test 3: dispatch_tool() - Returns error for unknown tool"

# Try to dispatch to non-existent tool
result=$(dispatch_tool "nonexistent_tool" '{}')

# Should contain error code -32601 (Method not found)
if echo "$result" | jq -e '.error.code == -32601' > /dev/null; then
    echo -e "${GREEN}✓ PASS: Returns correct error code for unknown tool${NC}"
else
    echo -e "${RED}✗ FAIL: Did not return error -32601${NC}"
    echo "  Got: $result"
    exit 1
fi

# Verify error message
error_msg=$(echo "$result" | jq -r '.error.message')
if [[ "$error_msg" == *"not found"* ]] || [[ "$error_msg" == *"Unknown tool"* ]]; then
    echo -e "${GREEN}✓ PASS: Error message is descriptive${NC}"
else
    echo -e "${RED}✗ FAIL: Error message not descriptive${NC}"
    echo "  Got: $error_msg"
    exit 1
fi
echo ""

# Test 4: Bash version check
echo "Test 4: check_bash_version() - Validates Bash >= 4.0"

# This function should return 0 if Bash >= 4.0
if check_bash_version; then
    echo -e "${GREEN}✓ PASS: Bash version check passes (>= 4.0)${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: Bash version < 4.0 detected${NC}"
    echo "  This test environment may not support associative arrays"
fi

# Verify current bash version is sufficient
bash_version="${BASH_VERSINFO[0]}"
if [ "$bash_version" -ge 4 ]; then
    echo -e "${GREEN}✓ PASS: Running on Bash $bash_version (supports associative arrays)${NC}"
else
    echo -e "${RED}✗ FAIL: Bash version too old: $bash_version${NC}"
    exit 1
fi
echo ""

# Test 5: Performance - dispatch overhead
echo "Test 5: Performance - dispatch overhead < 1ms"

# Register a simple handler
handle_perf_test() {
    echo '{"fast": true}'
}
register_tool "perf_test" "handle_perf_test"

# Measure dispatch time (10 iterations for average)
start=$(date +%s%N)
for i in {1..10}; do
    dispatch_tool "perf_test" '{}' > /dev/null
done
end=$(date +%s%N)

duration_ns=$((end - start))
duration_ms=$((duration_ns / 1000000))
per_call_us=$((duration_ns / 10000))  # microseconds per call

echo "  ℹ INFO: 10 dispatches took ${duration_ms}ms (${per_call_us}μs per dispatch)"

# Target: <1ms per dispatch (i.e., <10ms for 10 calls)
if [ "$duration_ms" -lt 10 ]; then
    echo -e "${GREEN}✓ PASS: Dispatch overhead acceptable (<1ms per call)${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: Dispatch overhead high (${per_call_us}μs per call)${NC}"
    # Don't fail on performance in CI - different machines have different speeds
fi
echo ""

# Test 6: Multiple tool registrations
echo "Test 6: Multiple tools - Can register and dispatch to multiple tools"

# Create mock handlers (must exist before registration)
handle_a() { echo '{"tool": "a"}'; }
handle_b() { echo '{"tool": "b"}'; }
handle_c() { echo '{"tool": "c"}'; }

# Register multiple tools
register_tool "tool_a" "handle_a"
register_tool "tool_b" "handle_b"
register_tool "tool_c" "handle_c"

# Verify all registered
if [ "${TOOL_HANDLERS[tool_a]:-}" = "handle_a" ] && \
   [ "${TOOL_HANDLERS[tool_b]:-}" = "handle_b" ] && \
   [ "${TOOL_HANDLERS[tool_c]:-}" = "handle_c" ]; then
    echo -e "${GREEN}✓ PASS: Multiple tools registered successfully${NC}"
else
    echo -e "${RED}✗ FAIL: Not all tools registered${NC}"
    exit 1
fi

# Count registered tools
tool_count="${#TOOL_HANDLERS[@]}"
if [ "$tool_count" -ge 3 ]; then
    echo -e "${GREEN}✓ PASS: Tool count correct (>= 3 tools)${NC}"
else
    echo -e "${RED}✗ FAIL: Expected >= 3 tools, got $tool_count${NC}"
    exit 1
fi
echo ""

# Test 7: Handler validation - reject non-existent handler
echo "Test 7: register_tool() - Rejects non-existent handler function"

# Try to register a tool with non-existent handler
if register_tool "invalid_tool" "nonexistent_handler" 2>/dev/null; then
    echo -e "${RED}✗ FAIL: Should reject non-existent handler${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASS: Correctly rejects non-existent handler${NC}"
fi
echo ""

# Test 8: Overwrite warning - warn when re-registering tool
echo "Test 8: register_tool() - Warns when overwriting existing tool"

# Register a tool
handle_overwrite_test() { echo '{"version": "1"}'; }
register_tool "overwrite_test" "handle_overwrite_test" 2>/dev/null

# Re-register the same tool with different handler (capture warning to temp file)
handle_overwrite_test_v2() { echo '{"version": "2"}'; }
warning_file=$(mktemp)
register_tool "overwrite_test" "handle_overwrite_test_v2" 2>"$warning_file"
warning_output=$(cat "$warning_file")
rm -f "$warning_file"

# Check if warning was issued
if echo "$warning_output" | grep -q "WARNING.*Overwriting"; then
    echo -e "${GREEN}✓ PASS: Warning issued on tool overwrite${NC}"
else
    echo -e "${RED}✗ FAIL: No warning on tool overwrite${NC}"
    echo "  Output: $warning_output"
    exit 1
fi

# Verify the handler was actually overwritten
if [ "${TOOL_HANDLERS[overwrite_test]:-}" = "handle_overwrite_test_v2" ]; then
    echo -e "${GREEN}✓ PASS: Tool handler successfully overwritten${NC}"
else
    echo -e "${RED}✗ FAIL: Tool handler not overwritten${NC}"
    exit 1
fi
echo ""

echo "========================================"
echo "All Unit Tests Passed!"
echo "========================================"
exit 0
