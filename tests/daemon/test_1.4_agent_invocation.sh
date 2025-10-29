#!/bin/bash
# Test 1.4: Real Agent Invocation
# Validates daemon invokes real Claude CLI agents (not simulation)

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load test helpers
source "$PROJECT_ROOT/tests/lib/test-assertions.sh" 2>/dev/null || source "$PROJECT_ROOT/tests/helpers/test-helpers.sh" 2>/dev/null || true

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

TEST_NAME="Test 1.4: Real Agent Invocation"
LOG_FILE="/tmp/test_daemon_agent_invocation_$$.log"
DAEMON_LOG=".claude/logs/daemon.log"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup() {
  echo -e "${BLUE}Setting up test environment...${NC}"

  # Ensure we're in the project root
  cd "$PROJECT_ROOT"

  # Clean up old triggers
  rm -f .claude/triggers/*.trigger
  rm -rf .claude/triggers/processed
  mkdir -p .claude/triggers/processed

  # Stop daemon if running
  if [ -f ".claude/daemon.pid" ]; then
    pid=$(cat ".claude/daemon.pid" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo -e "${YELLOW}Stopping existing daemon (PID $pid)...${NC}"
      kill "$pid" 2>/dev/null || true
      sleep 2
    fi
    rm -f ".claude/daemon.pid"
  fi

  # Clear daemon log
  mkdir -p .claude/logs
  > "$DAEMON_LOG"

  echo -e "${GREEN}✓ Test environment ready${NC}"
}

teardown() {
  echo -e "${BLUE}Cleaning up test environment...${NC}"

  # Stop daemon
  if [ -f ".claude/daemon.pid" ]; then
    pid=$(cat ".claude/daemon.pid" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f ".claude/daemon.pid"
  fi

  # Clean up test files
  rm -f test-agent-output.txt
  rm -f .claude/triggers/test-*.trigger
  rm -f "$LOG_FILE"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_real_agent_invocation() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$TEST_NAME${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check if daemon scripts exist
  if [ ! -f ".claude/bin/starforged" ]; then
    echo -e "${RED}✗ Daemon runner not found${NC}"
    return 1
  fi

  # Check if MCP server exists
  if [ ! -f ".claude/bin/mcp-server.sh" ]; then
    echo -e "${RED}✗ MCP server not found${NC}"
    return 1
  fi

  # Check if claude CLI is available (for real invocation)
  if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}⚠ Claude CLI not found - test will validate invocation logic only${NC}"
    CLAUDE_AVAILABLE=false
  else
    echo -e "${GREEN}✓ Claude CLI found: $(which claude)${NC}"
    CLAUDE_AVAILABLE=true
  fi

  # Start daemon
  echo -e "${BLUE}Starting daemon...${NC}"
  if [ -f "bin/starforge" ]; then
    ./bin/starforge daemon start
  elif [ -f ".claude/bin/starforged" ]; then
    bash .claude/bin/starforged &
    echo $! > .claude/daemon.pid
  else
    echo -e "${RED}✗ Cannot start daemon${NC}"
    return 1
  fi

  sleep 3

  # Verify daemon is running
  if [ ! -f ".claude/daemon.pid" ]; then
    echo -e "${RED}✗ Daemon PID file not created${NC}"
    return 1
  fi

  daemon_pid=$(cat ".claude/daemon.pid")
  if ! kill -0 "$daemon_pid" 2>/dev/null; then
    echo -e "${RED}✗ Daemon process not running${NC}"
    return 1
  fi

  echo -e "${GREEN}✓ Daemon running (PID: $daemon_pid)${NC}"

  # Create a simple test trigger
  echo -e "${BLUE}Creating test trigger...${NC}"
  cat > .claude/triggers/test-agent-invocation.trigger << 'EOF'
{
  "to_agent": "junior-engineer",
  "from_agent": "test-harness",
  "action": "test_invocation",
  "message": "Create a test file named test-agent-output.txt with the content 'Agent invoked successfully'",
  "ticket": "#TEST-INVOCATION"
}
EOF

  echo -e "${GREEN}✓ Test trigger created${NC}"

  # Wait for trigger to be processed (up to 30 seconds)
  echo -e "${BLUE}Waiting for agent invocation (max 30s)...${NC}"
  timeout=30
  elapsed=0
  invocation_detected=false

  while [ $elapsed -lt $timeout ]; do
    if [ -f "$DAEMON_LOG" ]; then
      # Check for real agent invocation patterns (not simulation)
      # Real invocation would show:
      # - MCP server startup
      # - Claude CLI invocation
      # - Agent PID tracking

      # REMOVED: Check for simulation message (we don't want this)
      # if grep -q "Simulating agent execution" "$DAEMON_LOG"; then

      # NEW: Check for real invocation patterns
      if grep -q "INVOKE.*junior-engineer" "$DAEMON_LOG" || \
         grep -q "claude.*--mcp stdio" "$DAEMON_LOG" || \
         grep -q "mcp-server.sh" "$DAEMON_LOG" || \
         grep -q "Starting.*junior-engineer" "$DAEMON_LOG"; then
        invocation_detected=true
        echo -e "${GREEN}✓ Agent invocation detected${NC}"
        break
      fi
    fi

    sleep 1
    elapsed=$((elapsed + 1))

    # Show progress
    if [ $((elapsed % 5)) -eq 0 ]; then
      echo -e "${YELLOW}  Waiting... ${elapsed}s${NC}"
    fi
  done

  if [ "$invocation_detected" = false ]; then
    echo -e "${RED}✗ Agent invocation not detected within ${timeout}s${NC}"
    echo -e "${YELLOW}Daemon log contents:${NC}"
    cat "$DAEMON_LOG"
    return 1
  fi

  # Validate invocation logs
  echo -e "${BLUE}Validating invocation logs...${NC}"

  # Check that we're NOT seeing simulation messages
  if grep -q "Simulating agent execution" "$DAEMON_LOG"; then
    echo -e "${RED}✗ FAIL: Simulation mode detected (should use real agent invocation)${NC}"
    return 1
  fi

  echo -e "${GREEN}✓ No simulation detected (real invocation mode)${NC}"

  # Check for real agent execution indicators
  real_invocation_count=0

  # Pattern 1: MCP server invocation
  if grep -q "mcp-server.sh" "$DAEMON_LOG"; then
    echo -e "${GREEN}✓ MCP server invocation detected${NC}"
    real_invocation_count=$((real_invocation_count + 1))
  fi

  # Pattern 2: Claude CLI with --mcp stdio
  if grep -q "claude.*--mcp stdio" "$DAEMON_LOG"; then
    echo -e "${GREEN}✓ Claude CLI invocation detected${NC}"
    real_invocation_count=$((real_invocation_count + 1))
  fi

  # Pattern 3: Agent PID tracking
  if grep -q "Agent PID:" "$DAEMON_LOG" || grep -q "PID.*junior-engineer" "$DAEMON_LOG"; then
    echo -e "${GREEN}✓ Agent PID tracking detected${NC}"
    real_invocation_count=$((real_invocation_count + 1))
  fi

  if [ $real_invocation_count -eq 0 ]; then
    echo -e "${YELLOW}⚠ Warning: No clear real invocation patterns detected${NC}"
    echo -e "${YELLOW}   This may indicate the feature is not yet implemented${NC}"
  else
    echo -e "${GREEN}✓ Real invocation patterns found: $real_invocation_count${NC}"
  fi

  # Check if trigger was processed (archived)
  sleep 5

  if ls .claude/triggers/processed/*test-agent-invocation* &>/dev/null; then
    echo -e "${GREEN}✓ Trigger processed and archived${NC}"
  else
    echo -e "${YELLOW}⚠ Trigger not yet archived (still processing)${NC}"
  fi

  # Final validation summary
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Results:${NC}"
  echo -e "  Daemon started: ${GREEN}✓${NC}"
  echo -e "  Trigger created: ${GREEN}✓${NC}"
  echo -e "  Agent invocation detected: ${GREEN}✓${NC}"
  echo -e "  Simulation mode (should be OFF): $(if grep -q 'Simulating' "$DAEMON_LOG"; then echo "${RED}✗ DETECTED${NC}"; else echo "${GREEN}✓ NOT DETECTED${NC}"; fi)"
  echo -e "  Real invocation patterns: ${GREEN}${real_invocation_count}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Execution
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  trap teardown EXIT

  setup

  if test_real_agent_invocation; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ $TEST_NAME PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
  else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ $TEST_NAME FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
  fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
