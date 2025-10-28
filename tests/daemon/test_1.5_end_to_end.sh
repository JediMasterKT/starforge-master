#!/bin/bash
# Test 1.5: End-to-End Agent Execution
# Validates agents actually execute and produce real work output

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

TEST_NAME="Test 1.5: End-to-End Agent Execution"
LOG_FILE="/tmp/test_daemon_e2e_$$.log"
DAEMON_LOG=".claude/logs/daemon.log"
TEST_OUTPUT_FILE="test-e2e-output.txt"
EXPECTED_CONTENT="E2E test successful"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup() {
  echo -e "${BLUE}Setting up test environment...${NC}"

  # Ensure we're in the project root
  cd "$PROJECT_ROOT"

  # Clean up old test output
  rm -f "$TEST_OUTPUT_FILE"

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
  rm -f "$TEST_OUTPUT_FILE"
  rm -f .claude/triggers/test-*.trigger
  rm -f "$LOG_FILE"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_end_to_end_execution() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$TEST_NAME${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check prerequisites
  if [ ! -f ".claude/bin/daemon-runner.sh" ]; then
    echo -e "${RED}✗ Daemon runner not found${NC}"
    return 1
  fi

  # Check if claude CLI is available
  if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}⚠ Claude CLI not found - skipping real execution test${NC}"
    echo -e "${YELLOW}   This test requires Claude CLI for end-to-end validation${NC}"
    return 0  # Skip, not a failure
  fi

  echo -e "${GREEN}✓ Claude CLI found: $(which claude)${NC}"

  # Start daemon
  echo -e "${BLUE}Starting daemon...${NC}"
  if [ -f "bin/starforge" ]; then
    ./bin/starforge daemon start
  elif [ -f ".claude/bin/daemon-runner.sh" ]; then
    bash .claude/bin/daemon-runner.sh &
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

  # Create a test trigger that produces actual output
  echo -e "${BLUE}Creating end-to-end test trigger...${NC}"
  cat > .claude/triggers/test-e2e-execution.trigger << EOF
{
  "to_agent": "junior-engineer",
  "from_agent": "test-harness",
  "action": "create_test_file",
  "message": "Using the Write tool, create a file named $TEST_OUTPUT_FILE with the exact content: $EXPECTED_CONTENT",
  "ticket": "#TEST-E2E",
  "context": {
    "file_path": "$TEST_OUTPUT_FILE",
    "content": "$EXPECTED_CONTENT",
    "verification": "Test will check if this exact file and content exists"
  }
}
EOF

  echo -e "${GREEN}✓ Test trigger created${NC}"

  # Wait for agent to execute and produce output (up to 120 seconds for real execution)
  echo -e "${BLUE}Waiting for agent execution (max 120s)...${NC}"
  timeout=120
  elapsed=0
  execution_complete=false

  while [ $elapsed -lt $timeout ]; do
    # Check if output file was created (proof of real execution)
    if [ -f "$TEST_OUTPUT_FILE" ]; then
      execution_complete=true
      echo -e "${GREEN}✓ Agent produced output file${NC}"
      break
    fi

    # Also check daemon log for completion
    if [ -f "$DAEMON_LOG" ]; then
      if grep -q "COMPLETE.*junior-engineer" "$DAEMON_LOG"; then
        echo -e "${GREEN}✓ Agent reported completion${NC}"
        # Give a bit more time for file to appear
        sleep 3
        if [ -f "$TEST_OUTPUT_FILE" ]; then
          execution_complete=true
          break
        fi
      fi
    fi

    sleep 2
    elapsed=$((elapsed + 2))

    # Show progress
    if [ $((elapsed % 10)) -eq 0 ]; then
      echo -e "${YELLOW}  Waiting... ${elapsed}s${NC}"
    fi
  done

  # Validate results
  echo -e "${BLUE}Validating execution results...${NC}"

  # REMOVED: Simulation-specific assertions
  # if grep -q "Simulating agent execution" "$DAEMON_LOG"; then

  # NEW: Real execution validation
  if [ "$execution_complete" = false ]; then
    echo -e "${RED}✗ Agent did not complete execution within ${timeout}s${NC}"
    echo -e "${YELLOW}Daemon log:${NC}"
    tail -50 "$DAEMON_LOG"
    return 1
  fi

  # Verify output file exists
  if [ ! -f "$TEST_OUTPUT_FILE" ]; then
    echo -e "${RED}✗ Output file not created: $TEST_OUTPUT_FILE${NC}"
    echo -e "${RED}   Agent may have run but did not produce expected output${NC}"
    return 1
  fi

  echo -e "${GREEN}✓ Output file exists: $TEST_OUTPUT_FILE${NC}"

  # Verify output file content
  actual_content=$(cat "$TEST_OUTPUT_FILE")
  if [ "$actual_content" = "$EXPECTED_CONTENT" ]; then
    echo -e "${GREEN}✓ Output file contains expected content${NC}"
  else
    echo -e "${RED}✗ Output file content mismatch${NC}"
    echo -e "${YELLOW}Expected: $EXPECTED_CONTENT${NC}"
    echo -e "${YELLOW}Actual: $actual_content${NC}"
    return 1
  fi

  # Verify no simulation mode was used
  if grep -q "Simulating" "$DAEMON_LOG"; then
    echo -e "${RED}✗ FAIL: Simulation mode detected (should use real execution)${NC}"
    return 1
  fi

  echo -e "${GREEN}✓ No simulation detected (real execution confirmed)${NC}"

  # Check for REAL_AGENT_INVOCATION flag behavior
  echo -e "${BLUE}Checking REAL_AGENT_INVOCATION flag behavior...${NC}"

  # The daemon should use real invocation by default (or when flag is true)
  # We've confirmed:
  # 1. Real output file was created
  # 2. No simulation logs present
  # 3. Agent completed and produced actual work

  if grep -q "REAL_AGENT_INVOCATION" "$DAEMON_LOG"; then
    if grep -q "REAL_AGENT_INVOCATION.*true\|REAL_AGENT_INVOCATION=true" "$DAEMON_LOG"; then
      echo -e "${GREEN}✓ REAL_AGENT_INVOCATION flag set to true${NC}"
    elif grep -q "REAL_AGENT_INVOCATION.*false\|REAL_AGENT_INVOCATION=false" "$DAEMON_LOG"; then
      echo -e "${RED}✗ REAL_AGENT_INVOCATION flag set to false (but real execution happened)${NC}"
      echo -e "${YELLOW}   This indicates flag behavior may be incorrect${NC}"
    fi
  else
    echo -e "${YELLOW}⚠ REAL_AGENT_INVOCATION flag not found in logs${NC}"
    echo -e "${YELLOW}   Real execution confirmed by output, flag may not be logged${NC}"
  fi

  # Check trigger was processed (archived)
  sleep 3

  if ls .claude/triggers/processed/*test-e2e-execution* &>/dev/null; then
    echo -e "${GREEN}✓ Trigger processed and archived${NC}"
  else
    echo -e "${YELLOW}⚠ Trigger not yet archived${NC}"
  fi

  # Final validation summary
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Results:${NC}"
  echo -e "  Daemon started: ${GREEN}✓${NC}"
  echo -e "  Trigger created: ${GREEN}✓${NC}"
  echo -e "  Agent executed: ${GREEN}✓${NC}"
  echo -e "  Output file created: ${GREEN}✓${NC}"
  echo -e "  Output content correct: ${GREEN}✓${NC}"
  echo -e "  Simulation mode: ${GREEN}✓ NOT USED${NC}"
  echo -e "  Real work produced: ${GREEN}✓ CONFIRMED${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Execution
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  trap teardown EXIT

  setup

  if test_end_to_end_execution; then
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
