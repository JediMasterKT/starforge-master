#!/bin/bash
# Integration test for MCP JSON-RPC 2.0 Protocol Handler
# Tests end-to-end functionality with real stdin/stdout I/O

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_SERVER="$PROJECT_ROOT/templates/bin/mcp-server.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "========================================"
echo "MCP JSON-RPC 2.0 Integration Tests"
echo "========================================"
echo ""

# Test 1: End-to-end valid request/response
echo "Test 1: End-to-end valid JSON-RPC request"
request='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
response=$(echo "$request" | timeout 2 "$MCP_SERVER" | head -1)

# Verify response is valid JSON
if ! echo "$response" | jq empty 2>/dev/null; then
    echo -e "${RED}✗ FAIL: Response is not valid JSON${NC}"
    echo "Response: $response"
    exit 1
fi

# Verify response has correct structure
jsonrpc=$(echo "$response" | jq -r '.jsonrpc')
if [ "$jsonrpc" != "2.0" ]; then
    echo -e "${RED}✗ FAIL: Response doesn't have jsonrpc: 2.0${NC}"
    exit 1
fi

id=$(echo "$response" | jq -r '.id')
if [ "$id" != "1" ]; then
    echo -e "${RED}✗ FAIL: Response ID doesn't match request${NC}"
    exit 1
fi

has_result=$(echo "$response" | jq 'has("result")')
if [ "$has_result" != "true" ]; then
    echo -e "${RED}✗ FAIL: Success response doesn't have result${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: End-to-end valid request works${NC}"
echo ""

# Test 2: Multiple requests in sequence
echo "Test 2: Multiple sequential requests"
{
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
    echo '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
    echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"test"}}'
} | timeout 2 "$MCP_SERVER" > /tmp/mcp_test_output.txt

# Should have 3 responses
response_count=$(wc -l < /tmp/mcp_test_output.txt | tr -d ' ')
if [ "$response_count" != "3" ]; then
    echo -e "${RED}✗ FAIL: Expected 3 responses, got $response_count${NC}"
    cat /tmp/mcp_test_output.txt
    exit 1
fi

# Verify all responses are valid JSON
while IFS= read -r line; do
    if ! echo "$line" | jq empty 2>/dev/null; then
        echo -e "${RED}✗ FAIL: Invalid JSON in multi-request response${NC}"
        echo "Line: $line"
        exit 1
    fi
done < /tmp/mcp_test_output.txt

echo -e "${GREEN}✓ PASS: Multiple sequential requests work${NC}"
echo ""

# Test 3: Error handling with invalid JSON
echo "Test 3: Error handling with malformed JSON"
invalid_request='{"jsonrpc":"2.0","id":1,INVALID}'
error_response=$(echo "$invalid_request" | timeout 2 "$MCP_SERVER" | head -1)

# Should be valid JSON error response
if ! echo "$error_response" | jq empty 2>/dev/null; then
    echo -e "${RED}✗ FAIL: Error response is not valid JSON${NC}"
    exit 1
fi

# Should have error code -32700
error_code=$(echo "$error_response" | jq -r '.error.code')
if [ "$error_code" != "-32700" ]; then
    echo -e "${RED}✗ FAIL: Expected error code -32700, got $error_code${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Error handling works correctly${NC}"
echo ""

# Test 4: Unknown method handling
echo "Test 4: Unknown method error"
unknown_request='{"jsonrpc":"2.0","id":99,"method":"unknown/method","params":{}}'
error_response=$(echo "$unknown_request" | timeout 2 "$MCP_SERVER" | head -1)

error_code=$(echo "$error_response" | jq -r '.error.code')
if [ "$error_code" != "-32601" ]; then
    echo -e "${RED}✗ FAIL: Expected method not found error (-32601), got $error_code${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Unknown method handling works${NC}"
echo ""

# Test 5: Performance - response time for batch of requests
echo "Test 5: Performance - 10 requests"
start=$(date +%s%N)

for i in {1..10}; do
    echo "{\"jsonrpc\":\"2.0\",\"id\":$i,\"method\":\"initialize\",\"params\":{}}"
done | timeout 5 "$MCP_SERVER" > /dev/null

end=$(date +%s%N)
duration_ms=$(( (end - start) / 1000000 ))
per_request_ms=$(( duration_ms / 10 ))

echo "  ℹ INFO: 10 requests took ${duration_ms}ms (${per_request_ms}ms per request)"

# Single MCP server handles all requests in one process
# Target: <2s for 10 requests (realistic for bash+jq)
if [ "$duration_ms" -lt 2000 ]; then
    echo -e "${GREEN}✓ PASS: Performance acceptable (<2s for 10 requests)${NC}"
else
    echo -e "${RED}✗ FAIL: Performance too slow (${duration_ms}ms for 10 requests)${NC}"
    exit 1
fi

echo ""

# Cleanup
rm -f /tmp/mcp_test_output.txt

echo "========================================"
echo "All Integration Tests Passed!"
echo "========================================"
exit 0
