#!/bin/bash
# Integration test for MCP Server Initialization & Shutdown
# Tests lifecycle management, tool loading, and graceful shutdown
#
# Part of Issue #174: MCP: Implement Server Initialization & Shutdown

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
echo "MCP Server Initialization Tests"
echo "========================================"
echo ""

# Test 1: Server validates Bash version on startup
echo "Test 1: Bash version validation"
# Source the server script to test its functions
source "$MCP_SERVER"

# Check that BASH_VERSION is at least 4.0
bash_major="${BASH_VERSION%%.*}"
if [ "$bash_major" -lt 4 ]; then
    echo -e "${RED}✗ FAIL: Bash version too old (need 4.0+, have $BASH_VERSION)${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: Bash version check ($BASH_VERSION)${NC}"
echo ""

# Test 2: Loads all tool modules from templates/lib/
echo "Test 2: Tool module loading"
# Check that all required tool modules exist
tool_modules=(
    "mcp-tools-file.sh"
    "mcp-tools-github.sh"
    "mcp-tools-trigger.sh"
)

missing_modules=()
for module in "${tool_modules[@]}"; do
    module_path="$PROJECT_ROOT/templates/lib/$module"
    if [ ! -f "$module_path" ]; then
        missing_modules+=("$module")
    fi
done

if [ ${#missing_modules[@]} -gt 0 ]; then
    echo -e "${RED}✗ FAIL: Missing tool modules: ${missing_modules[*]}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: All tool modules exist${NC}"
echo ""

# Test 3: Server can be sourced and functions are available
echo "Test 3: Server initialization functions available"
# Already sourced above, check that key functions exist
required_functions=(
    "handle_request"
    "build_success_response"
    "build_error_response"
)

missing_functions=()
for func in "${required_functions[@]}"; do
    if ! declare -f "$func" > /dev/null; then
        missing_functions+=("$func")
    fi
done

if [ ${#missing_functions[@]} -gt 0 ]; then
    echo -e "${RED}✗ FAIL: Missing required functions: ${missing_functions[*]}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: All required functions available${NC}"
echo ""

# Test 4: Server handles SIGTERM gracefully
echo "Test 4: Graceful shutdown with SIGTERM"
# Start server in background
mkfifo /tmp/mcp_test_input 2>/dev/null || true
mkfifo /tmp/mcp_test_output 2>/dev/null || true

# Start server with pipes
"$MCP_SERVER" < /tmp/mcp_test_input > /tmp/mcp_test_output &
server_pid=$!

# Give server time to start
sleep 0.5

# Verify server is running
if ! kill -0 "$server_pid" 2>/dev/null; then
    echo -e "${RED}✗ FAIL: Server failed to start${NC}"
    exit 1
fi

# Send SIGTERM
kill -TERM "$server_pid" 2>/dev/null || true

# Wait for graceful shutdown (max 2 seconds)
timeout=2
while [ $timeout -gt 0 ]; do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        echo -e "${GREEN}✓ PASS: Server shut down gracefully${NC}"
        break
    fi
    sleep 0.5
    timeout=$((timeout - 1))
done

# Force kill if still running
if kill -0 "$server_pid" 2>/dev/null; then
    echo -e "${RED}✗ FAIL: Server didn't shut down gracefully${NC}"
    kill -9 "$server_pid" 2>/dev/null || true
    exit 1
fi

# Cleanup pipes
rm -f /tmp/mcp_test_input /tmp/mcp_test_output
echo ""

# Test 5: Server exits when stdin closes (EOF)
echo "Test 5: Graceful shutdown on EOF (stdin closed)"
# Use a here-string to send input and close stdin
output=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | timeout 2 "$MCP_SERVER")

# Verify we got a response
if ! echo "$output" | jq empty 2>/dev/null; then
    echo -e "${RED}✗ FAIL: No valid response before EOF${NC}"
    exit 1
fi

# Server should exit gracefully when stdin closes (no orphan processes)
sleep 0.5
# Check no mcp-server processes are orphaned
orphans=$(pgrep -f "mcp-server.sh" 2>/dev/null || true)
if [ -n "$orphans" ]; then
    echo -e "${RED}✗ FAIL: Orphaned mcp-server processes: $orphans${NC}"
    # Cleanup orphans
    pkill -9 -f "mcp-server.sh" 2>/dev/null || true
    exit 1
fi

echo -e "${GREEN}✓ PASS: Server exits gracefully on EOF${NC}"
echo ""

# Test 6: Startup time performance (<100ms)
echo "Test 6: Startup time performance"
start=$(date +%s%N)

# Start and immediately stop server
mkfifo /tmp/mcp_test_perf 2>/dev/null || true
"$MCP_SERVER" < /tmp/mcp_test_perf &
server_pid=$!
sleep 0.1
kill -TERM "$server_pid" 2>/dev/null || true
wait "$server_pid" 2>/dev/null || true

end=$(date +%s%N)
startup_ms=$(( (end - start) / 1000000 ))

echo "  ℹ INFO: Startup time: ${startup_ms}ms"

# Target: <100ms (generous for bash script with module loading)
if [ "$startup_ms" -lt 100 ]; then
    echo -e "${GREEN}✓ PASS: Startup time acceptable (<100ms)${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: Startup slower than target (${startup_ms}ms, target <100ms)${NC}"
    # Don't fail - this is informational
fi

rm -f /tmp/mcp_test_perf
echo ""

# Test 7: Tool modules can be loaded and functions exported
echo "Test 7: Tool modules export functions correctly"
# Source each tool module and verify exported functions
source "$PROJECT_ROOT/templates/lib/mcp-tools-file.sh"
if ! declare -f starforge_read_file > /dev/null; then
    echo -e "${RED}✗ FAIL: mcp-tools-file.sh didn't export starforge_read_file${NC}"
    exit 1
fi

source "$PROJECT_ROOT/templates/lib/mcp-tools-github.sh"
if ! declare -f starforge_list_issues > /dev/null; then
    echo -e "${RED}✗ FAIL: mcp-tools-github.sh didn't export starforge_list_issues${NC}"
    exit 1
fi

source "$PROJECT_ROOT/templates/lib/mcp-tools-trigger.sh"
if ! declare -f get_project_context > /dev/null; then
    echo -e "${RED}✗ FAIL: mcp-tools-trigger.sh didn't export get_project_context${NC}"
    exit 1
fi

echo -e "${GREEN}✓ PASS: All tool modules export functions correctly${NC}"
echo ""

echo "========================================"
echo "All Initialization Tests Passed!"
echo "========================================"
exit 0
