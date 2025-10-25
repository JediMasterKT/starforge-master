#!/bin/bash
# Test suite for parallel daemon execution
# Tests parallel trigger processing and agent slot management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
  export TEST_DIR=$(mktemp -d)
  export PROJECT_ROOT="$TEST_DIR"
  export CLAUDE_DIR="$PROJECT_ROOT/.claude"
  export TRIGGER_DIR="$CLAUDE_DIR/triggers"
  export SLOTS_FILE="$CLAUDE_DIR/daemon/agent-slots.json"

  mkdir -p "$TRIGGER_DIR"
  mkdir -p "$CLAUDE_DIR/daemon"
  mkdir -p "$CLAUDE_DIR/logs"

  echo '{}' > "$SLOTS_FILE"

  # Source libraries
  source "$(dirname "$0")/../templates/lib/agent-slots.sh"
}

# Cleanup test environment
cleanup_test_env() {
  rm -rf "$TEST_DIR"
}

# Test assertion helper
assert_equals() {
  local expected=$1
  local actual=$2
  local test_name=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name"
    echo -e "  Expected: $expected"
    echo -e "  Actual:   $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

assert_true() {
  local condition=$1
  local test_name=$2

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$condition"; then
    echo -e "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

assert_file_exists() {
  local file_path=$1
  local test_name=$2

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -f "$file_path" ]; then
    echo -e "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name (file not found: $file_path)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Cases
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_parallel_execution_different_agents() {
  setup_test_env

  # Create triggers for different agents
  cat > "$TRIGGER_DIR/junior-dev-a_ticket-52.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {
    "ticket": 52
  }
}
EOF

  cat > "$TRIGGER_DIR/junior-dev-b_ticket-84.trigger" << 'EOF'
{
  "to_agent": "junior-dev-b",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {
    "ticket": 84
  }
}
EOF

  cat > "$TRIGGER_DIR/qa-engineer_review-pr.trigger" << 'EOF'
{
  "to_agent": "qa-engineer",
  "from_agent": "junior-dev-a",
  "action": "review_pr",
  "context": {
    "pr": 161
  }
}
EOF

  # Simulate marking agents as busy (parallel execution)
  mark_agent_busy "junior-dev-a" "10001" "52"
  mark_agent_busy "junior-dev-b" "10002" "84"
  mark_agent_busy "qa-engineer" "10003" ""

  # Verify all three agents are busy simultaneously
  assert_true "is_agent_busy 'junior-dev-a'" "junior-dev-a is busy"
  assert_true "is_agent_busy 'junior-dev-b'" "junior-dev-b is busy"
  assert_true "is_agent_busy 'qa-engineer'" "qa-engineer is busy"

  # Verify count
  local busy_count=$(get_agent_count_busy)
  assert_equals "3" "$busy_count" "3 agents running in parallel"

  cleanup_test_env
}

test_sequential_execution_same_agent() {
  setup_test_env

  # First task for junior-dev-a
  mark_agent_busy "junior-dev-a" "10001" "52"

  # Try to assign second task to same agent (should check if busy first)
  if is_agent_busy "junior-dev-a"; then
    # Agent is busy, cannot assign new task
    assert_true "true" "Agent slot prevents duplicate assignment"
  else
    assert_true "false" "Agent slot should prevent duplicate assignment"
  fi

  # Finish first task
  mark_agent_idle "junior-dev-a"

  # Now agent should be available for second task
  assert_true "! is_agent_busy 'junior-dev-a'" "Agent available after completion"

  # Assign second task
  mark_agent_busy "junior-dev-a" "10002" "84"
  assert_true "is_agent_busy 'junior-dev-a'" "Agent accepts second task after first completes"

  cleanup_test_env
}

test_orphaned_pid_cleanup() {
  setup_test_env

  # Mark agent with fake PID (process doesn't exist)
  mark_agent_busy "junior-dev-a" "999999" "52"

  # Verify agent is marked as busy
  assert_true "is_agent_busy 'junior-dev-a'" "Agent marked as busy"

  # Run cleanup (should detect PID doesn't exist)
  cleanup_orphaned_pids 2>/dev/null

  # Verify agent is now idle
  assert_true "! is_agent_busy 'junior-dev-a'" "Orphaned PID cleaned up"

  cleanup_test_env
}

test_trigger_validation() {
  setup_test_env

  # Valid trigger
  cat > "$TRIGGER_DIR/valid.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {
    "ticket": 52
  }
}
EOF

  # Validate JSON
  if jq empty "$TRIGGER_DIR/valid.trigger" 2>/dev/null; then
    assert_true "true" "Valid trigger passes JSON validation"
  else
    assert_true "false" "Valid trigger should pass JSON validation"
  fi

  # Invalid trigger (malformed JSON)
  cat > "$TRIGGER_DIR/invalid.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator"
  "action": "implement_ticket"
}
EOF

  # Validate JSON (should fail)
  if ! jq empty "$TRIGGER_DIR/invalid.trigger" 2>/dev/null; then
    assert_true "true" "Invalid trigger fails JSON validation"
  else
    assert_true "false" "Invalid trigger should fail JSON validation"
  fi

  cleanup_test_env
}

test_fifo_queue_ordering() {
  setup_test_env

  # Create triggers with timestamp order
  sleep 0.1
  cat > "$TRIGGER_DIR/first.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {"ticket": 1}
}
EOF

  sleep 0.1
  cat > "$TRIGGER_DIR/second.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {"ticket": 2}
}
EOF

  sleep 0.1
  cat > "$TRIGGER_DIR/third.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {"ticket": 3}
}
EOF

  # Get next trigger (should be first.trigger - oldest)
  # This tests the get_next_trigger function from daemon-runner.sh
  # We'll simulate it here with find and ls
  local next_trigger=$(ls -t "$TRIGGER_DIR"/*.trigger 2>/dev/null | tail -1)

  local trigger_name=$(basename "$next_trigger")
  assert_equals "first.trigger" "$trigger_name" "FIFO queue returns oldest trigger first"

  cleanup_test_env
}

test_agent_status_display() {
  setup_test_env

  # Mark some agents as busy
  mark_agent_busy "junior-dev-a" "10001" "52"
  mark_agent_busy "qa-engineer" "10002" ""

  # Test status display function
  local status_output=$(print_agent_status 2>&1)

  # Verify output contains agent information
  if echo "$status_output" | grep -q "junior-dev-a"; then
    assert_true "true" "Status display includes junior-dev-a"
  else
    assert_true "false" "Status display should include junior-dev-a"
  fi

  cleanup_test_env
}

test_backward_compatibility_trigger_format() {
  setup_test_env

  # Old-style trigger (still should work)
  cat > "$TRIGGER_DIR/old-style.trigger" << 'EOF'
{
  "to_agent": "orchestrator",
  "from_agent": "daemon",
  "action": "check_work"
}
EOF

  # Verify can be parsed
  local to_agent=$(jq -r '.to_agent' "$TRIGGER_DIR/old-style.trigger")
  assert_equals "orchestrator" "$to_agent" "Backward compatible trigger format"

  cleanup_test_env
}

test_concurrent_agent_limit() {
  setup_test_env

  # Mark 4 agents as busy
  mark_agent_busy "junior-dev-a" "10001" "52"
  mark_agent_busy "junior-dev-b" "10002" "84"
  mark_agent_busy "junior-dev-c" "10003" "91"
  mark_agent_busy "qa-engineer" "10004" ""

  # Count should be 4
  local count=$(get_agent_count_busy)
  assert_equals "4" "$count" "4 agents running concurrently"

  cleanup_test_env
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run all tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "=========================================="
echo "Parallel Daemon Execution Tests"
echo "=========================================="
echo ""

test_parallel_execution_different_agents
test_sequential_execution_same_agent
test_orphaned_pid_cleanup
test_trigger_validation
test_fifo_queue_ordering
test_agent_status_display
test_backward_compatibility_trigger_format
test_concurrent_agent_limit

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
