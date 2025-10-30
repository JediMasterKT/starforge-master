#!/bin/bash
# Test Compensation Transactions (Saga Pattern)
# Tests: Rollback on partial failures in orchestrator assignment

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

TEST_DIR="/tmp/starforge-compensation-test-$(date +%s)"
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
export STARFORGE_MAIN_REPO="$TEST_DIR"
export STARFORGE_PROJECT_NAME="test-project"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_test_environment() {
  echo -e "${BLUE}Setting up compensation test environment...${NC}"

  # Create test directory
  mkdir -p "$TEST_DIR"
  mkdir -p "$STARFORGE_CLAUDE_DIR/logs"
  mkdir -p "$STARFORGE_CLAUDE_DIR/coordination"
  mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"
  mkdir -p "$STARFORGE_CLAUDE_DIR/scripts"

  # Create lib directory and copy compensation library
  mkdir -p "$TEST_DIR/lib"
  cp "$PROJECT_ROOT/templates/lib/compensation.sh" "$TEST_DIR/lib/"

  echo -e "${GREEN}✓ Test environment ready: $TEST_DIR${NC}"
}

cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up test environment...${NC}"
  rm -rf "$TEST_DIR"
  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Helpers
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_equals() {
  local expected="$1"
  local actual="$2"
  local description="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} $description"
    echo -e "    ${YELLOW}Expected: $expected${NC}"
    echo -e "    ${YELLOW}Actual: $actual${NC}"
  fi
}

assert_file_exists() {
  local file_path="$1"
  local description="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -f "$file_path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} $description"
    echo -e "    ${YELLOW}File not found: $file_path${NC}"
  fi
}

assert_file_not_exists() {
  local file_path="$1"
  local description="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ ! -f "$file_path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} $description"
    echo -e "    ${YELLOW}File should not exist: $file_path${NC}"
  fi
}

assert_log_contains() {
  local pattern="$1"
  local description="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if grep -q "$pattern" "$STARFORGE_CLAUDE_DIR/logs/compensation.log" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} $description"
    echo -e "    ${YELLOW}Pattern not found in log: $pattern${NC}"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Compensation library loads
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_compensation_library_loads() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 1: Compensation library loads${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Load library
  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  # Check functions exist
  TESTS_RUN=$((TESTS_RUN + 1))
  if declare -f register_compensation >/dev/null && \
     declare -f execute_compensations >/dev/null && \
     declare -f clear_compensations >/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} All compensation functions loaded"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} Compensation functions missing"
  fi

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Basic compensation registration and execution
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_basic_compensation() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 2: Basic compensation registration${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  # Create test file
  local test_file="$TEST_DIR/test_action.txt"
  echo "test" > "$test_file"

  # Register compensation
  register_compensation "Test file deletion" "rm -f $test_file"

  # Execute compensations
  execute_compensations "test rollback"

  # Verify file deleted
  assert_file_not_exists "$test_file" "Test file deleted by compensation"
  assert_log_contains "ROLLBACK_START" "Rollback logged"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Multiple compensations execute in LIFO order
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_lifo_execution() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 3: LIFO execution order${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  local order_file="$TEST_DIR/order.txt"
  rm -f "$order_file"

  # Register 3 actions
  register_compensation "Action 1" "echo 1 >> $order_file"
  register_compensation "Action 2" "echo 2 >> $order_file"
  register_compensation "Action 3" "echo 3 >> $order_file"

  # Execute (should be 3, 2, 1)
  execute_compensations "LIFO test" >/dev/null 2>&1

  # Verify order
  local order=$(cat "$order_file" | tr '\n' ' ' | sed 's/ //g')
  assert_equals "321" "$order" "Compensations executed in LIFO order (3,2,1)"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Failed compensation logs error
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_failed_compensation() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 4: Failed compensation handling${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  # Register compensation that will fail (no -f flag, so it will fail on nonexistent file)
  register_compensation "Failing action" "rm /nonexistent/path/that/does/not/exist"

  # Execute (should log failure)
  execute_compensations "failed compensation test" >/dev/null 2>&1

  # Verify failure logged
  assert_log_contains "ROLLBACK_FAILED" "Failed compensation logged"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Clear compensations
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_clear_compensations() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 5: Clear compensations (success case)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  local test_file="$TEST_DIR/should_not_delete.txt"
  echo "test" > "$test_file"

  # Register compensation
  register_compensation "File deletion" "rm -f $test_file"

  # Clear (success case - don't execute compensations)
  clear_compensations

  # Verify file NOT deleted
  assert_file_exists "$test_file" "File not deleted after clear_compensations"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Integration test - Simulated assignment failure
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_simulated_assignment_failure() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 6: Simulated assignment failure${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  # Simulate multi-step assignment
  local github_label="$TEST_DIR/github_label.txt"
  local status_file="$TEST_DIR/status.json"
  local trigger_file="$TEST_DIR/trigger.json"

  # Step 1: GitHub label (SUCCESS)
  echo "in-progress" > "$github_label"
  register_compensation "GitHub label" "rm -f $github_label"

  # Step 2: Status file (SUCCESS)
  echo "{\"status\":\"working\"}" > "$status_file"
  register_compensation "Status file" "rm -f $status_file"

  # Step 3: Trigger creation (FAILURE)
  # Simulate failure - don't create trigger, execute compensation
  echo "❌ Trigger creation failed (simulated)"
  execute_compensations "Trigger creation failed"

  # Verify rollback
  assert_file_not_exists "$github_label" "GitHub label rolled back"
  assert_file_not_exists "$status_file" "Status file rolled back"
  assert_file_not_exists "$trigger_file" "Trigger file never created"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: Compensation logging
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_compensation_logging() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 7: Compensation logging${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  source "$PROJECT_ROOT/templates/lib/compensation.sh"

  # Log operation failure
  log_failure "test_operation" "42" "test-agent" "simulated failure"

  # Verify failure logged
  assert_log_contains "OPERATION_FAILURE" "Operation failure logged"
  assert_log_contains "test_operation" "Operation name logged"
  assert_log_contains "Ticket: 42" "Ticket logged"
  assert_log_contains "test-agent" "Agent logged"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Runner
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  Compensation Transactions Test Suite         ║${NC}"
  echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
  echo ""

  # Setup
  setup_test_environment

  # Run tests
  test_compensation_library_loads
  test_basic_compensation
  test_lifo_execution
  test_failed_compensation
  test_clear_compensations
  test_simulated_assignment_failure
  test_compensation_logging

  # Results
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test Results${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Tests run:    $TESTS_RUN"
  echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Cleanup
  cleanup_test_environment

  # Exit code
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All compensation tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
  fi
}

# Run tests
main "$@"
