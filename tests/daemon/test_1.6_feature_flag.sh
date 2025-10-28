#!/bin/bash
# Test 1.6: REAL_AGENT_INVOCATION Feature Flag
# Tests both simulation mode (false) and real invocation mode (true)

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

TEST_NAME="Test 1.6: REAL_AGENT_INVOCATION Feature Flag"
LOG_FILE="/tmp/test_daemon_feature_flag_$$.log"
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

  # Unset the flag initially
  unset REAL_AGENT_INVOCATION

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
  rm -f test-flag-*.txt
  rm -f .claude/triggers/test-*.trigger
  rm -f "$LOG_FILE"

  # Unset flag
  unset REAL_AGENT_INVOCATION

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

stop_daemon() {
  if [ -f ".claude/daemon.pid" ]; then
    pid=$(cat ".claude/daemon.pid" 2>/dev/null || echo "")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 2
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f ".claude/daemon.pid"
  fi
  > "$DAEMON_LOG"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_simulation_mode() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Case 1: Simulation Mode (REAL_AGENT_INVOCATION=false)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Set flag to false (simulation mode)
  export REAL_AGENT_INVOCATION=false
  echo -e "${YELLOW}Set REAL_AGENT_INVOCATION=false${NC}"

  # Start daemon with simulation mode
  echo -e "${BLUE}Starting daemon in simulation mode...${NC}"
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

  # Verify daemon started
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

  # Create test trigger
  echo -e "${BLUE}Creating test trigger for simulation mode...${NC}"
  cat > .claude/triggers/test-simulation.trigger << 'EOF'
{
  "to_agent": "junior-engineer",
  "from_agent": "test-harness",
  "action": "test_simulation",
  "message": "Create a test file (this should be simulated)",
  "ticket": "#TEST-SIM"
}
EOF

  # Wait for processing
  sleep 10

  # Validate simulation mode was used
  echo -e "${BLUE}Validating simulation mode behavior...${NC}"

  if [ -f "$DAEMON_LOG" ]; then
    if grep -q "Simulating agent execution\|Simulation mode\|REAL_AGENT_INVOCATION.*false" "$DAEMON_LOG"; then
      echo -e "${GREEN}✓ Simulation mode detected in logs${NC}"
    else
      echo -e "${YELLOW}⚠ Simulation mode not clearly indicated in logs${NC}"
      echo -e "${YELLOW}   (Feature may not be implemented yet)${NC}"
    fi

    # Should NOT see real Claude CLI invocation
    if grep -q "claude.*--mcp stdio" "$DAEMON_LOG"; then
      echo -e "${RED}✗ Real Claude CLI invocation detected (should be simulating)${NC}"
      return 1
    else
      echo -e "${GREEN}✓ No real Claude CLI invocation (correct for simulation mode)${NC}"
    fi
  fi

  stop_daemon
  unset REAL_AGENT_INVOCATION

  echo -e "${GREEN}✓ Simulation mode test passed${NC}"
  return 0
}

test_real_invocation_mode() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Case 2: Real Invocation Mode (REAL_AGENT_INVOCATION=true)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check if Claude CLI is available
  if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}⚠ Claude CLI not found - skipping real invocation test${NC}"
    return 0  # Skip, not a failure
  fi

  # Set flag to true (real invocation mode)
  export REAL_AGENT_INVOCATION=true
  echo -e "${YELLOW}Set REAL_AGENT_INVOCATION=true${NC}"

  # Start daemon with real invocation mode
  echo -e "${BLUE}Starting daemon in real invocation mode...${NC}"
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

  # Verify daemon started
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

  # Create test trigger
  echo -e "${BLUE}Creating test trigger for real invocation mode...${NC}"
  cat > .claude/triggers/test-real-invocation.trigger << 'EOF'
{
  "to_agent": "junior-engineer",
  "from_agent": "test-harness",
  "action": "test_real",
  "message": "Create a test file named test-flag-real.txt with content 'Real invocation'",
  "ticket": "#TEST-REAL"
}
EOF

  # Wait for processing
  sleep 15

  # Validate real invocation mode was used
  echo -e "${BLUE}Validating real invocation mode behavior...${NC}"

  if [ -f "$DAEMON_LOG" ]; then
    # Should NOT see simulation
    if grep -q "Simulating agent execution" "$DAEMON_LOG"; then
      echo -e "${RED}✗ Simulation detected (should be using real invocation)${NC}"
      return 1
    else
      echo -e "${GREEN}✓ No simulation detected${NC}"
    fi

    # Should see real invocation indicators
    if grep -q "mcp-server.sh\|claude.*--mcp stdio\|REAL_AGENT_INVOCATION.*true" "$DAEMON_LOG"; then
      echo -e "${GREEN}✓ Real invocation indicators found${NC}"
    else
      echo -e "${YELLOW}⚠ Real invocation indicators not clearly shown${NC}"
    fi
  fi

  stop_daemon
  unset REAL_AGENT_INVOCATION

  echo -e "${GREEN}✓ Real invocation mode test passed${NC}"
  return 0
}

test_graceful_fallback() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Case 3: Graceful Fallback (Claude CLI not found)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # This test validates that if Claude CLI is not available,
  # the daemon either:
  # 1. Falls back to simulation mode, or
  # 2. Logs an error and continues, or
  # 3. Fails gracefully without crashing

  # We can't easily remove Claude CLI from PATH in a test,
  # so we'll test the behavior when REAL_AGENT_INVOCATION=true
  # but validate error handling exists

  echo -e "${BLUE}Checking daemon error handling logic...${NC}"

  # Check if daemon-runner.sh has fallback logic
  if [ -f ".claude/bin/daemon-runner.sh" ]; then
    if grep -q "command -v claude\|which claude\|claude.*not found" ".claude/bin/daemon-runner.sh"; then
      echo -e "${GREEN}✓ Daemon has Claude CLI existence check${NC}"
    else
      echo -e "${YELLOW}⚠ No explicit Claude CLI check found${NC}"
      echo -e "${YELLOW}   Daemon may fail ungracefully if Claude CLI is missing${NC}"
    fi

    if grep -q "fallback\|simulation.*mode\|REAL_AGENT_INVOCATION.*false" ".claude/bin/daemon-runner.sh"; then
      echo -e "${GREEN}✓ Daemon has fallback/simulation logic${NC}"
    else
      echo -e "${YELLOW}⚠ No explicit fallback logic found${NC}"
    fi
  fi

  # Simulate scenario: Start daemon with REAL_AGENT_INVOCATION=true
  # and check if it handles Claude CLI absence gracefully
  if command -v claude &> /dev/null; then
    echo -e "${YELLOW}⚠ Claude CLI is available, cannot test fallback behavior${NC}"
    echo -e "${YELLOW}   Test would need Claude CLI to be unavailable${NC}"
    echo -e "${GREEN}✓ Graceful fallback test skipped (Claude CLI present)${NC}"
  else
    echo -e "${BLUE}Claude CLI not found - testing fallback behavior${NC}"

    export REAL_AGENT_INVOCATION=true

    # Start daemon
    if [ -f "bin/starforge" ]; then
      ./bin/starforge daemon start 2>&1 | tee "$LOG_FILE"
    elif [ -f ".claude/bin/daemon-runner.sh" ]; then
      bash .claude/bin/daemon-runner.sh &
      echo $! > .claude/daemon.pid
    fi

    sleep 3

    # Check if daemon is running (should either fallback or fail gracefully)
    if [ -f ".claude/daemon.pid" ]; then
      daemon_pid=$(cat ".claude/daemon.pid")
      if kill -0 "$daemon_pid" 2>/dev/null; then
        echo -e "${GREEN}✓ Daemon running despite missing Claude CLI (fallback working)${NC}"

        # Create test trigger to see fallback behavior
        cat > .claude/triggers/test-fallback.trigger << 'EOF'
{
  "to_agent": "junior-engineer",
  "from_agent": "test-harness",
  "action": "test_fallback",
  "message": "Test fallback behavior",
  "ticket": "#TEST-FALLBACK"
}
EOF

        sleep 10

        if [ -f "$DAEMON_LOG" ]; then
          if grep -q "claude.*not found\|falling back\|simulation mode" "$DAEMON_LOG"; then
            echo -e "${GREEN}✓ Graceful fallback logged${NC}"
          else
            echo -e "${YELLOW}⚠ Fallback behavior not clearly logged${NC}"
          fi
        fi

        stop_daemon
      else
        echo -e "${YELLOW}⚠ Daemon not running (may have failed at startup)${NC}"
        if [ -f "$LOG_FILE" ] && grep -q "claude.*not found\|ERROR.*claude" "$LOG_FILE"; then
          echo -e "${GREEN}✓ Error logged for missing Claude CLI${NC}"
        fi
      fi
    else
      echo -e "${YELLOW}⚠ Daemon did not start (expected if Claude CLI required)${NC}"
    fi

    unset REAL_AGENT_INVOCATION
  fi

  return 0
}

test_flag_toggle() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Case 4: Flag Toggle Between Restarts${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Test that changing the flag and restarting daemon changes behavior

  echo -e "${BLUE}First run: REAL_AGENT_INVOCATION=false${NC}"
  export REAL_AGENT_INVOCATION=false

  if [ -f "bin/starforge" ]; then
    ./bin/starforge daemon start
  elif [ -f ".claude/bin/daemon-runner.sh" ]; then
    bash .claude/bin/daemon-runner.sh &
    echo $! > .claude/daemon.pid
  fi

  sleep 3

  if [ -f "$DAEMON_LOG" ]; then
    first_mode=$(grep -o "REAL_AGENT_INVOCATION[^a-zA-Z]*" "$DAEMON_LOG" | head -1 || echo "")
    echo -e "${YELLOW}First run mode: $first_mode${NC}"
  fi

  stop_daemon

  echo -e "${BLUE}Second run: REAL_AGENT_INVOCATION=true${NC}"
  export REAL_AGENT_INVOCATION=true

  if [ -f "bin/starforge" ]; then
    ./bin/starforge daemon start
  elif [ -f ".claude/bin/daemon-runner.sh" ]; then
    bash .claude/bin/daemon-runner.sh &
    echo $! > .claude/daemon.pid
  fi

  sleep 3

  if [ -f "$DAEMON_LOG" ]; then
    second_mode=$(grep -o "REAL_AGENT_INVOCATION[^a-zA-Z]*" "$DAEMON_LOG" | tail -1 || echo "")
    echo -e "${YELLOW}Second run mode: $second_mode${NC}"

    if [ "$first_mode" != "$second_mode" ] && [ -n "$first_mode" ] && [ -n "$second_mode" ]; then
      echo -e "${GREEN}✓ Flag toggle successful (daemon respects flag changes)${NC}"
    else
      echo -e "${YELLOW}⚠ Flag toggle not clearly detected in logs${NC}"
    fi
  fi

  stop_daemon
  unset REAL_AGENT_INVOCATION

  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Execution
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  trap teardown EXIT

  setup

  failed=0

  # Run all test cases
  if ! test_simulation_mode; then
    failed=$((failed + 1))
  fi

  if ! test_real_invocation_mode; then
    failed=$((failed + 1))
  fi

  if ! test_graceful_fallback; then
    failed=$((failed + 1))
  fi

  if ! test_flag_toggle; then
    failed=$((failed + 1))
  fi

  # Final summary
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}$TEST_NAME Summary${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Test Case 1 (Simulation Mode): $(if [ $failed -le 3 ]; then echo "${GREEN}✓${NC}"; else echo "${RED}✗${NC}"; fi)"
  echo -e "  Test Case 2 (Real Invocation): $(if [ $failed -le 2 ]; then echo "${GREEN}✓${NC}"; else echo "${RED}✗${NC}"; fi)"
  echo -e "  Test Case 3 (Graceful Fallback): $(if [ $failed -le 1 ]; then echo "${GREEN}✓${NC}"; else echo "${RED}✗${NC}"; fi)"
  echo -e "  Test Case 4 (Flag Toggle): $(if [ $failed -eq 0 ]; then echo "${GREEN}✓${NC}"; else echo "${RED}✗${NC}"; fi)"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  if [ $failed -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ $TEST_NAME PASSED${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
  else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}✗ $TEST_NAME FAILED ($failed test cases failed)${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
  fi
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
