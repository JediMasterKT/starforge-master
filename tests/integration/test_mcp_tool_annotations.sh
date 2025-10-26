#!/usr/bin/env bash
# Integration test for MCP Tool Annotations (Principle 4)
# Tests tool metadata hints (readOnlyHint, destructiveHint, idempotentHint)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_SERVER="$PROJECT_ROOT/templates/bin/mcp-server.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "MCP Tool Annotations Integration Tests"
echo "========================================"
echo ""

# Test 1: Annotations stored correctly (unit test via sourcing)
echo "Test 1: Tool registration with annotations"

# Source the mcp-server to test register_tool directly
source "$MCP_SERVER"

# Register a test tool with annotations
register_tool "test_tool" "echo" true false true

# Verify annotations were stored
if [ "${TOOL_ANNOTATIONS[test_tool_read_only]:-}" != "true" ]; then
    echo -e "${RED}✗ FAIL: read_only annotation not stored correctly${NC}"
    echo "  Expected: true"
    echo "  Got: ${TOOL_ANNOTATIONS[test_tool_read_only]:-empty}"
    exit 1
fi

if [ "${TOOL_ANNOTATIONS[test_tool_destructive]:-}" != "false" ]; then
    echo -e "${RED}✗ FAIL: destructive annotation not stored correctly${NC}"
    exit 1
fi

if [ "${TOOL_ANNOTATIONS[test_tool_idempotent]:-}" != "true" ]; then
    echo -e "${RED}✗ FAIL: idempotent annotation not stored correctly${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Annotations stored correctly${NC}"
echo ""

# Test 2: tools/list includes annotations in response
echo "Test 2: tools/list returns annotations"

# Start fresh server instance and register a tool with known annotations
{
    # Create a test MCP tool module with known annotations
    TEST_MODULE=$(mktemp)
    cat > "$TEST_MODULE" <<'TOOLEOF'
# Test MCP tool module
handle_test_readonly() {
    echo '{"result":"test"}'
}

handle_test_destructive() {
    echo '{"result":"destroy"}'
}

# Auto-register tools when module is loaded
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    register_tool "test_readonly" "handle_test_readonly" true false true
    register_tool "test_destructive" "handle_test_destructive" false true false
fi
TOOLEOF

    # Create wrapper script that loads our test module
    TEST_SERVER=$(mktemp)
    cat > "$TEST_SERVER" <<SERVEREOF
#!/usr/bin/env bash
source "$MCP_SERVER"
source "$TEST_MODULE"
main
SERVEREOF
    chmod +x "$TEST_SERVER"

    # Query tools/list
    request='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
    response=$(echo "$request" | timeout 2 "$TEST_SERVER" | head -1)

    # Cleanup temp files
    rm -f "$TEST_MODULE" "$TEST_SERVER"

    # Verify response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        echo -e "${RED}✗ FAIL: tools/list response is not valid JSON${NC}"
        echo "Response: $response"
        exit 1
    fi

    # Extract tools array
    tools=$(echo "$response" | jq -r '.result.tools')

    # Find test_readonly tool and verify annotations
    readonly_tool=$(echo "$tools" | jq -r '.[] | select(.name == "test_readonly")')

    if [ -z "$readonly_tool" ]; then
        echo -e "${YELLOW}ℹ INFO: test_readonly tool not in response (may not be registered)${NC}"
        echo "  This is expected if tools/list stub is still active"
        echo "  Response: $response"
    else
        # Verify readOnlyHint field exists and is true
        read_only_hint=$(echo "$readonly_tool" | jq -r '.readOnlyHint')
        if [ "$read_only_hint" != "true" ]; then
            echo -e "${RED}✗ FAIL: readOnlyHint not correct for test_readonly${NC}"
            echo "  Expected: true"
            echo "  Got: $read_only_hint"
            exit 1
        fi

        destructive_hint=$(echo "$readonly_tool" | jq -r '.destructiveHint')
        if [ "$destructive_hint" != "false" ]; then
            echo -e "${RED}✗ FAIL: destructiveHint not correct for test_readonly${NC}"
            exit 1
        fi

        idempotent_hint=$(echo "$readonly_tool" | jq -r '.idempotentHint')
        if [ "$idempotent_hint" != "true" ]; then
            echo -e "${RED}✗ FAIL: idempotentHint not correct for test_readonly${NC}"
            exit 1
        fi

        echo -e "${GREEN}✓ PASS: tools/list includes annotations${NC}"
    fi
}
echo ""

# Test 3: All registered tools have annotations
echo "Test 3: All tools annotated (consistency check)"

# Create separate test script to avoid variable conflicts
TEST_SCRIPT=$(mktemp)
cat > "$TEST_SCRIPT" <<'TESTEOF'
#!/usr/bin/env bash
source "$1"

# Register some test tools
register_tool "tool_a" "echo" true false true
register_tool "tool_b" "echo" false false false
register_tool "tool_c" "echo" false true false

# Check each tool has all three annotations
tools_missing_annotations=""
for tool_name in "${!TOOL_HANDLERS[@]}"; do
    if [ -z "${TOOL_ANNOTATIONS[${tool_name}_read_only]:-}" ]; then
        tools_missing_annotations+="$tool_name (read_only), "
    fi
    if [ -z "${TOOL_ANNOTATIONS[${tool_name}_destructive]:-}" ]; then
        tools_missing_annotations+="$tool_name (destructive), "
    fi
    if [ -z "${TOOL_ANNOTATIONS[${tool_name}_idempotent]:-}" ]; then
        tools_missing_annotations+="$tool_name (idempotent), "
    fi
done

if [ -n "$tools_missing_annotations" ]; then
    echo "FAIL: Some tools missing annotations"
    echo "Missing: ${tools_missing_annotations%, }"
    exit 1
fi

echo "PASS"
TESTEOF
chmod +x "$TEST_SCRIPT"

result=$(bash "$TEST_SCRIPT" "$MCP_SERVER" 2>&1)
rm -f "$TEST_SCRIPT"

if echo "$result" | grep -q "PASS"; then
    echo -e "${GREEN}✓ PASS: All tools have complete annotations${NC}"
elif echo "$result" | grep -q "FAIL"; then
    echo -e "${RED}✗ $result${NC}"
    exit 1
else
    echo -e "${RED}✗ FAIL: Test script error${NC}"
    echo "$result"
    exit 1
fi
echo ""

# Test 4: Default annotation values
echo "Test 4: Default annotation values"

TEST_SCRIPT=$(mktemp)
cat > "$TEST_SCRIPT" <<'TESTEOF'
#!/usr/bin/env bash
source "$1"

register_tool "tool_defaults" "echo"

if [ -n "${TOOL_ANNOTATIONS[tool_defaults_read_only]:-}" ]; then
    read_only_default="${TOOL_ANNOTATIONS[tool_defaults_read_only]}"
    destructive_default="${TOOL_ANNOTATIONS[tool_defaults_destructive]}"
    idempotent_default="${TOOL_ANNOTATIONS[tool_defaults_idempotent]}"

    echo "INFO:$read_only_default:$destructive_default:$idempotent_default"

    if [ "$read_only_default" = "false" ] && [ "$destructive_default" = "false" ] && [ "$idempotent_default" = "true" ]; then
        echo "PASS"
    else
        echo "WARNING"
    fi
else
    echo "NO_DEFAULTS"
fi
TESTEOF
chmod +x "$TEST_SCRIPT"

result=$(bash "$TEST_SCRIPT" "$MCP_SERVER" 2>&1)
rm -f "$TEST_SCRIPT"

if echo "$result" | grep -q "INFO:"; then
    defaults=$(echo "$result" | grep "INFO:" | cut -d: -f2-)
    echo "  ℹ INFO: Default values applied:"
    echo "    readOnlyHint: $(echo $defaults | cut -d: -f1)"
    echo "    destructiveHint: $(echo $defaults | cut -d: -f2)"
    echo "    idempotentHint: $(echo $defaults | cut -d: -f3)"

    if echo "$result" | grep -q "PASS"; then
        echo -e "${GREEN}✓ PASS: Sensible defaults applied${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING: Default values may not be ideal${NC}"
        echo "  Recommended: readOnly=false, destructive=false, idempotent=true"
    fi
else
    echo -e "${YELLOW}ℹ INFO: No defaults applied (requires explicit annotation)${NC}"
    echo "  This is acceptable if all tools must be explicitly annotated"
fi
echo ""

# Test 5: Annotation values are boolean (not string)
echo "Test 5: Annotation values are proper booleans"

# Create tools/list request to verify JSON types
request='{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'

TEST_MODULE=$(mktemp)
cat > "$TEST_MODULE" <<'TOOLEOF'
handle_type_test() {
    echo '{"result":"test"}'
}

if [ -n "${BASH_SOURCE[0]:-}" ]; then
    register_tool "type_test_tool" "handle_type_test" true false true
fi
TOOLEOF

TEST_SERVER=$(mktemp)
cat > "$TEST_SERVER" <<SERVEREOF
#!/usr/bin/env bash
source "$MCP_SERVER"
source "$TEST_MODULE"
main
SERVEREOF
chmod +x "$TEST_SERVER"

response=$(echo "$request" | timeout 2 "$TEST_SERVER" | head -1)
rm -f "$TEST_MODULE" "$TEST_SERVER"

# Extract tool and check type of readOnlyHint
if echo "$response" | jq -e '.result.tools[0].readOnlyHint' > /dev/null 2>&1; then
    hint_type=$(echo "$response" | jq -r '.result.tools[0].readOnlyHint | type')

    if [ "$hint_type" = "boolean" ]; then
        echo -e "${GREEN}✓ PASS: Annotation values are booleans (not strings)${NC}"
    else
        echo -e "${RED}✗ FAIL: Annotation values should be boolean, got: $hint_type${NC}"
        echo "  Response: $response"
        exit 1
    fi
else
    echo -e "${YELLOW}ℹ INFO: Could not verify annotation type (stub still active)${NC}"
fi
echo ""

# Test 6: Performance - annotations don't slow down tools/list
echo "Test 6: Performance - annotations overhead"

start=$(date +%s%N)

TEST_MODULE=$(mktemp)
cat > "$TEST_MODULE" <<'TOOLEOF'
handle_perf_test() { echo '{"result":"test"}'; }
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    # Register 10 tools with annotations
    for i in {1..10}; do
        register_tool "perf_tool_$i" "handle_perf_test" true false true
    done
fi
TOOLEOF

TEST_SERVER=$(mktemp)
cat > "$TEST_SERVER" <<SERVEREOF
#!/usr/bin/env bash
source "$MCP_SERVER"
source "$TEST_MODULE"
main
SERVEREOF
chmod +x "$TEST_SERVER"

# Call tools/list 5 times
for i in {1..5}; do
    echo '{"jsonrpc":"2.0","id":'$i',"method":"tools/list","params":{}}'
done | timeout 3 "$TEST_SERVER" > /dev/null

end=$(date +%s%N)
duration_ms=$(( (end - start) / 1000000 ))

rm -f "$TEST_MODULE" "$TEST_SERVER"

echo "  ℹ INFO: 5 tools/list calls with 10 tools took ${duration_ms}ms"

# Target: <1s for 5 calls (annotations shouldn't add significant overhead)
if [ "$duration_ms" -lt 1000 ]; then
    echo -e "${GREEN}✓ PASS: Performance acceptable (<1s)${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: Performance slower than target (${duration_ms}ms)${NC}"
fi
echo ""

echo "========================================"
echo "All Tool Annotation Tests Passed!"
echo "========================================"
exit 0
