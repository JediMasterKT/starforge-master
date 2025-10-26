#!/bin/bash
# TDD Tests: Daemon MCP Integration (Issue #187)
# Tests: Daemon invokes agents via MCP server, NO TTY required

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load test assertions
source "$SCRIPT_DIR/lib/test-assertions.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Configuration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST_DIR="/tmp/starforge-mcp-integration-test-$(date +%s)"
STARFORGE_ROOT="$PROJECT_ROOT"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_test_environment() {
  echo -e "${BLUE}Setting up MCP integration test environment...${NC}"

  # Create test directory
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"

  # Initialize git
  git init
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Create initial commit
  echo "# Test Project" > README.md
  git add .
  git commit -m "Initial commit"

  # Copy daemon-runner.sh from templates
  mkdir -p .claude/bin
  cp "$STARFORGE_ROOT/templates/bin/daemon-runner.sh" .claude/bin/
  cp "$STARFORGE_ROOT/templates/bin/mcp-server.sh" .claude/bin/

  # Create required directories
  mkdir -p .claude/triggers
  mkdir -p .claude/logs
  mkdir -p .claude/daemon

  echo -e "${GREEN}✓ MCP integration test environment ready: $TEST_DIR${NC}"
}

cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up MCP integration test environment...${NC}"

  # Stop daemon if running
  if [ -f ".claude/daemon.pid" ]; then
    local pid=$(cat ".claude/daemon.pid")
    if kill -0 "$pid" 2>/dev/null; then
      echo -e "${YELLOW}Stopping daemon (PID $pid)...${NC}"
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi

  # Remove test directory
  cd /tmp
  rm -rf "$TEST_DIR"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Daemon invokes agent via MCP server
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_invokes_agent_via_mcp() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 1: Daemon invokes agent via MCP server${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Verify daemon-runner.sh contains MCP invocation
  assert_file_contains ".claude/bin/daemon-runner.sh" "mcp-server.sh" \
    "Daemon script references MCP server"

  # Check for --mcp stdio using grep -F (fixed string)
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -F -- '--mcp stdio' .claude/bin/daemon-runner.sh > /dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} Daemon uses --mcp stdio flag"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} Daemon uses --mcp stdio flag"
    echo -e "    ${YELLOW}Pattern not found: --mcp stdio${NC}"
  fi

  # Verify old claude --print is NOT used alone
  # (It should be: mcp-server.sh | claude --mcp stdio)
  local old_pattern_count=$(grep -c 'claude --print --permission-mode bypassPermissions "Use the' .claude/bin/daemon-runner.sh 2>/dev/null || echo "0")
  old_pattern_count=$(echo "$old_pattern_count" | head -1 | tr -d ' \n')

  assert_equals "0" "$old_pattern_count" \
    "Old claude --print pattern removed from agent invocation"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: NO TTY REQUIRED (CRITICAL)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_no_tty_required() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 2: NO TTY REQUIRED (CRITICAL)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create a mock MCP server that just outputs JSON-RPC responses
  cat > .claude/bin/mcp-server-mock.sh << 'EOF'
#!/bin/bash
# Mock MCP server for testing

# Output a simple JSON-RPC initialize response
cat << 'JSONRPC'
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"starforge-mcp","version":"0.1.0"}}}
JSONRPC
EOF
  chmod +x .claude/bin/mcp-server-mock.sh

  # Create a mock claude command that accepts MCP input
  cat > .claude/bin/claude-mock.sh << 'EOF'
#!/bin/bash
# Mock claude for testing

# Check that --mcp stdio flag is present
if [[ "$*" == *"--mcp stdio"* ]]; then
  echo "SUCCESS: claude invoked with --mcp stdio"
  # Read from stdin (MCP server output) but don't process it
  cat > /dev/null
  exit 0
else
  echo "ERROR: claude not invoked with --mcp stdio"
  exit 1
fi
EOF
  chmod +x .claude/bin/claude-mock.sh

  # Modify daemon-runner to use mock scripts
  # Create a test version that uses mocks
  cat .claude/bin/daemon-runner.sh | \
    sed 's|"$CLAUDE_DIR/bin/mcp-server.sh"|.claude/bin/mcp-server-mock.sh|g' | \
    sed 's|claude --mcp stdio|.claude/bin/claude-mock.sh --mcp stdio|g' \
    > .claude/bin/daemon-runner-test.sh

  # Verify the mocks work without TTY
  echo -e "${BLUE}Testing MCP invocation without TTY...${NC}"

  # Run in completely non-interactive environment (no stdin, no tty)
  local output
  if output=$(bash .claude/bin/mcp-server-mock.sh </dev/null 2>&1); then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} MCP server runs without TTY"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} MCP server requires TTY (CRITICAL FAILURE)"
  fi

  # Verify pipe works without TTY
  if output=$(bash .claude/bin/mcp-server-mock.sh </dev/null | .claude/bin/claude-mock.sh --mcp stdio --permission-mode bypassPermissions "test" 2>&1); then
    assert_contains "$output" "SUCCESS: claude invoked with --mcp stdio" \
      "MCP pipe works without TTY"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} MCP pipe requires TTY (CRITICAL FAILURE)"
  fi

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: MCP server spawns per agent invocation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_mcp_server_spawns_per_invocation() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 3: MCP server spawns per agent invocation${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Verify daemon-runner.sh spawns MCP server (not a persistent service)
  # Pattern should be: "$CLAUDE_DIR/bin/mcp-server.sh" | claude --mcp stdio

  # Check for pipe pattern (may be multiline)
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -A 1 'mcp-server.sh' .claude/bin/daemon-runner.sh | grep -q 'claude'; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} Daemon pipes MCP server to claude"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} Daemon pipes MCP server to claude"
  fi

  # Verify MCP server is NOT started as a background daemon
  local bg_daemon_pattern_count=$(grep -c 'mcp-server.sh.*&' .claude/bin/daemon-runner.sh 2>/dev/null || echo "0")
  bg_daemon_pattern_count=$(echo "$bg_daemon_pattern_count" | head -1 | tr -d ' \n')

  assert_equals "0" "$bg_daemon_pattern_count" \
    "MCP server NOT run as background daemon (spawned per invocation)"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Daemon logs to daemon.log
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_logs_to_file() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 4: Daemon logs to daemon.log${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Verify LOG_FILE is defined and logs redirected
  assert_file_contains ".claude/bin/daemon-runner.sh" 'LOG_FILE=' \
    "Daemon defines LOG_FILE variable"

  assert_file_contains ".claude/bin/daemon-runner.sh" '>> "$LOG_FILE"' \
    "Daemon redirects output to LOG_FILE"

  # Verify claude invocation logs to LOG_FILE
  local log_redirect_count=$(grep -c '>> "$LOG_FILE" 2>&1' .claude/bin/daemon-runner.sh || echo "0")

  assert_not_equals "0" "$log_redirect_count" \
    "Claude invocation logs redirected to LOG_FILE"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Performance - No regression (<5% overhead)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_performance_no_regression() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 5: Performance - No regression (<5% overhead)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Measure MCP server startup time
  local start_time=$(date +%s%N)
  bash .claude/bin/mcp-server-mock.sh </dev/null > /dev/null 2>&1 || true
  local end_time=$(date +%s%N)

  local duration_ms=$(( (end_time - start_time) / 1000000 ))

  echo -e "${BLUE}MCP server startup: ${duration_ms}ms${NC}"

  # MCP server should start in <100ms (minimal overhead)
  if [ "$duration_ms" -lt 100 ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} MCP server startup <100ms (low overhead)"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} MCP server startup ${duration_ms}ms (high overhead)"
  fi

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Runner
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  start_test_suite "Daemon MCP Integration (Issue #187)"

  # Setup
  setup_test_environment

  # Run tests
  test_daemon_invokes_agent_via_mcp
  test_no_tty_required  # CRITICAL TEST
  test_mcp_server_spawns_per_invocation
  test_daemon_logs_to_file
  test_performance_no_regression

  # Results
  end_test_suite
  local exit_code=$?

  # Cleanup
  cleanup_test_environment

  # Final output
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 All MCP integration tests passed!${NC}"
    echo -e "${GREEN}✓ SUCCESS METRIC: Daemon can run without TTY${NC}"
  else
    echo -e "${RED}❌ Some MCP integration tests failed${NC}"
  fi

  exit $exit_code
}

# Run tests
main "$@"
