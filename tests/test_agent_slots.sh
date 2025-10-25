#!/bin/bash
# Test suite for agent slot management
# Tests the agent-slots.sh library functions

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
  export CLAUDE_DIR="$TEST_DIR/.claude"
  export SLOTS_FILE="$CLAUDE_DIR/daemon/agent-slots.json"

  mkdir -p "$CLAUDE_DIR/daemon"
  echo '{}' > "$SLOTS_FILE"

  # Source the library
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

assert_false() {
  local condition=$1
  local test_name=$2

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! eval "$condition"; then
    echo -e "${GREEN}✓${NC} $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Cases
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_is_agent_busy_returns_false_for_idle_agent() {
  setup_test_env

  # Test: New agent should be idle
  assert_false "is_agent_busy 'junior-dev-a'" "is_agent_busy returns false for new agent"

  cleanup_test_env
}

test_mark_agent_busy_sets_status() {
  setup_test_env

  # Test: Mark agent as busy
  mark_agent_busy "junior-dev-a" "12345" "52"

  local status=$(jq -r '."junior-dev-a".status' "$SLOTS_FILE")
  assert_equals "busy" "$status" "mark_agent_busy sets status to busy"

  cleanup_test_env
}

test_mark_agent_busy_sets_pid() {
  setup_test_env

  # Test: Mark agent with PID
  mark_agent_busy "junior-dev-a" "12345" "52"

  local pid=$(jq -r '."junior-dev-a".pid' "$SLOTS_FILE")
  assert_equals "12345" "$pid" "mark_agent_busy sets PID"

  cleanup_test_env
}

test_mark_agent_busy_sets_ticket() {
  setup_test_env

  # Test: Mark agent with ticket
  mark_agent_busy "junior-dev-a" "12345" "52"

  local ticket=$(jq -r '."junior-dev-a".ticket' "$SLOTS_FILE")
  assert_equals "52" "$ticket" "mark_agent_busy sets ticket number"

  cleanup_test_env
}

test_is_agent_busy_returns_true_for_busy_agent() {
  setup_test_env

  # Setup: Mark agent as busy
  mark_agent_busy "junior-dev-a" "12345" "52"

  # Test: Agent should now be busy
  assert_true "is_agent_busy 'junior-dev-a'" "is_agent_busy returns true for busy agent"

  cleanup_test_env
}

test_mark_agent_idle_clears_status() {
  setup_test_env

  # Setup: Mark agent as busy first
  mark_agent_busy "junior-dev-a" "12345" "52"

  # Test: Mark agent as idle
  mark_agent_idle "junior-dev-a"

  local status=$(jq -r '."junior-dev-a".status // "idle"' "$SLOTS_FILE")
  assert_equals "idle" "$status" "mark_agent_idle sets status to idle"

  cleanup_test_env
}

test_mark_agent_idle_clears_pid() {
  setup_test_env

  # Setup: Mark agent as busy first
  mark_agent_busy "junior-dev-a" "12345" "52"

  # Test: Mark agent as idle
  mark_agent_idle "junior-dev-a"

  local pid=$(jq -r '."junior-dev-a".pid // "null"' "$SLOTS_FILE")
  assert_equals "null" "$pid" "mark_agent_idle clears PID"

  cleanup_test_env
}

test_get_agent_pid_returns_pid() {
  setup_test_env

  # Setup: Mark agent as busy
  mark_agent_busy "junior-dev-a" "12345" "52"

  # Test: Get agent PID
  local pid=$(get_agent_pid "junior-dev-a")
  assert_equals "12345" "$pid" "get_agent_pid returns correct PID"

  cleanup_test_env
}

test_get_agent_pid_returns_empty_for_idle() {
  setup_test_env

  # Test: Get PID for idle agent
  local pid=$(get_agent_pid "junior-dev-a")
  assert_equals "" "$pid" "get_agent_pid returns empty for idle agent"

  cleanup_test_env
}

test_get_agent_ticket_returns_ticket() {
  setup_test_env

  # Setup: Mark agent as busy with ticket
  mark_agent_busy "junior-dev-a" "12345" "52"

  # Test: Get agent ticket
  local ticket=$(get_agent_ticket "junior-dev-a")
  assert_equals "52" "$ticket" "get_agent_ticket returns correct ticket"

  cleanup_test_env
}

test_multiple_agents_independent() {
  setup_test_env

  # Setup: Mark multiple agents
  mark_agent_busy "junior-dev-a" "11111" "52"
  mark_agent_busy "junior-dev-b" "22222" "84"
  mark_agent_busy "qa-engineer" "33333" ""

  # Test: Verify each agent independently
  assert_true "is_agent_busy 'junior-dev-a'" "junior-dev-a is busy"
  assert_true "is_agent_busy 'junior-dev-b'" "junior-dev-b is busy"
  assert_true "is_agent_busy 'qa-engineer'" "qa-engineer is busy"

  local pid_a=$(get_agent_pid "junior-dev-a")
  local pid_b=$(get_agent_pid "junior-dev-b")
  local pid_qa=$(get_agent_pid "qa-engineer")

  assert_equals "11111" "$pid_a" "junior-dev-a has correct PID"
  assert_equals "22222" "$pid_b" "junior-dev-b has correct PID"
  assert_equals "33333" "$pid_qa" "qa-engineer has correct PID"

  cleanup_test_env
}

test_mark_agent_idle_only_affects_target_agent() {
  setup_test_env

  # Setup: Mark multiple agents
  mark_agent_busy "junior-dev-a" "11111" "52"
  mark_agent_busy "junior-dev-b" "22222" "84"

  # Test: Mark only one agent as idle
  mark_agent_idle "junior-dev-a"

  assert_false "is_agent_busy 'junior-dev-a'" "junior-dev-a is idle"
  assert_true "is_agent_busy 'junior-dev-b'" "junior-dev-b still busy"

  cleanup_test_env
}

test_timestamp_recorded() {
  setup_test_env

  # Test: Mark agent busy and check timestamp exists
  mark_agent_busy "junior-dev-a" "12345" "52"

  local started_at=$(jq -r '."junior-dev-a".started_at' "$SLOTS_FILE")

  # Verify timestamp is not null and matches ISO format pattern
  if [ "$started_at" != "null" ] && [[ "$started_at" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
    echo -e "${GREEN}✓${NC} mark_agent_busy records timestamp"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} mark_agent_busy records timestamp"
    echo -e "  Got: $started_at"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))

  cleanup_test_env
}

test_slots_file_is_valid_json() {
  setup_test_env

  # Test: Perform multiple operations and verify JSON validity
  mark_agent_busy "junior-dev-a" "11111" "52"
  mark_agent_busy "junior-dev-b" "22222" "84"
  mark_agent_idle "junior-dev-a"

  # Verify JSON is valid
  if jq empty "$SLOTS_FILE" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} slots file maintains valid JSON"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} slots file maintains valid JSON"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))

  cleanup_test_env
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run all tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "=========================================="
echo "Agent Slot Management Tests"
echo "=========================================="
echo ""

test_is_agent_busy_returns_false_for_idle_agent
test_mark_agent_busy_sets_status
test_mark_agent_busy_sets_pid
test_mark_agent_busy_sets_ticket
test_is_agent_busy_returns_true_for_busy_agent
test_mark_agent_idle_clears_status
test_mark_agent_idle_clears_pid
test_get_agent_pid_returns_pid
test_get_agent_pid_returns_empty_for_idle
test_get_agent_ticket_returns_ticket
test_multiple_agents_independent
test_mark_agent_idle_only_affects_target_agent
test_timestamp_recorded
test_slots_file_is_valid_json

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
