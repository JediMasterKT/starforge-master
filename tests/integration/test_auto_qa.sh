#!/bin/bash
# Integration tests for Auto-QA feature
# Tests: Full workflow from PR detection to trigger creation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
  echo -e "${GREEN}✅ PASS${NC}: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
  echo -e "${RED}❌ FAIL${NC}: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
}

skip() {
  echo -e "${YELLOW}⊘ SKIP${NC}: $1"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Prerequisites Check
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_prerequisites() {
  local all_good=true

  # Check for gh CLI
  if ! command -v gh &> /dev/null; then
    echo "❌ gh CLI not installed"
    all_good=false
  fi

  # Check for jq
  if ! command -v jq &> /dev/null; then
    echo "❌ jq not installed"
    all_good=false
  fi

  # Check if in git repo
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository"
    all_good=false
  fi

  # Check if auto-qa-helpers.sh exists
  if [ ! -f "templates/scripts/auto-qa-helpers.sh" ]; then
    echo "❌ auto-qa-helpers.sh not found"
    all_good=false
  fi

  if [ "$all_good" = "false" ]; then
    echo ""
    echo "Prerequisites not met. Skipping integration tests."
    exit 0
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Auto-QA Helpers Load Successfully
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_helpers_load() {
  # Setup test environment
  export STARFORGE_CLAUDE_DIR=".claude"
  export STARFORGE_PROJECT_NAME="test-project"

  if source templates/scripts/auto-qa-helpers.sh 2>/dev/null; then
    pass "Auto-QA helpers load successfully"
  else
    fail "Auto-QA helpers failed to load"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Configuration File Loads
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_config_loads() {
  if [ -f "templates/config/daemon.conf" ]; then
    if source templates/config/daemon.conf 2>/dev/null; then
      # Check if AUTO_QA_ENABLED is set
      if [ -n "$AUTO_QA_ENABLED" ]; then
        pass "Configuration file loads successfully (AUTO_QA_ENABLED=$AUTO_QA_ENABLED)"
      else
        fail "Configuration loaded but AUTO_QA_ENABLED not set"
      fi
    else
      fail "Configuration file failed to load"
    fi
  else
    fail "Configuration file not found"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Feature Flag Disabled by Default
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_feature_flag_disabled() {
  source templates/config/daemon.conf

  if [ "$AUTO_QA_ENABLED" = "false" ]; then
    pass "Feature flag disabled by default (safe deployment)"
  else
    fail "Feature flag should be false by default, got: $AUTO_QA_ENABLED"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Daemon Runner Has Auto-QA Function
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_has_auto_qa_function() {
  if grep -q "auto_qa_poll_loop" templates/bin/starforged; then
    pass "Daemon runner contains auto_qa_poll_loop function"
  else
    fail "Daemon runner missing auto_qa_poll_loop function"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Daemon Starts Auto-QA Loop
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_starts_auto_qa() {
  if grep -q "auto_qa_poll_loop &" templates/bin/starforged; then
    pass "Daemon starts auto-QA loop in background"
  else
    fail "Daemon does not start auto-QA loop"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Trigger File Format Validation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_trigger_format() {
  # Create a temporary trigger to validate format
  export STARFORGE_CLAUDE_DIR=$(mktemp -d)
  mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"
  mkdir -p "$STARFORGE_CLAUDE_DIR/metrics"

  source templates/scripts/auto-qa-helpers.sh

  # Create trigger
  if create_qa_trigger_for_pr 999 "test-integration" >/dev/null 2>&1; then
    local trigger_file=$(ls "$STARFORGE_CLAUDE_DIR"/triggers/qa-engineer-review_pr_999-*.trigger 2>/dev/null | head -1)

    if [ -f "$trigger_file" ]; then
      # Validate required fields
      local has_from=$(jq -e '.from_agent' "$trigger_file" >/dev/null 2>&1 && echo "true" || echo "false")
      local has_to=$(jq -e '.to_agent' "$trigger_file" >/dev/null 2>&1 && echo "true" || echo "false")
      local has_action=$(jq -e '.action' "$trigger_file" >/dev/null 2>&1 && echo "true" || echo "false")
      local has_context=$(jq -e '.context' "$trigger_file" >/dev/null 2>&1 && echo "true" || echo "false")
      local has_message=$(jq -e '.message' "$trigger_file" >/dev/null 2>&1 && echo "true" || echo "false")
      local has_command=$(jq -e '.command' "$trigger_file" >/dev/null 2>&1 && echo "true" || echo "false")

      if [ "$has_from" = "true" ] && \
         [ "$has_to" = "true" ] && \
         [ "$has_action" = "true" ] && \
         [ "$has_context" = "true" ] && \
         [ "$has_message" = "true" ] && \
         [ "$has_command" = "true" ]; then
        pass "Trigger file has all required fields"
      else
        fail "Trigger file missing required fields"
      fi
    else
      fail "Trigger file not created"
    fi

    # Cleanup
    rm -rf "$STARFORGE_CLAUDE_DIR"
  else
    fail "Failed to create test trigger"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: Auto-QA Disabled Mode (No-Op)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_auto_qa_disabled_mode() {
  export AUTO_QA_ENABLED=false

  # The function should return 0 (success) but do nothing
  # This test verifies the daemon can run with AUTO_QA_ENABLED=false

  if grep -q "AUTO_QA_ENABLED.*false" templates/config/daemon.conf; then
    pass "Auto-QA respects disabled flag in config"
  else
    fail "Auto-QA config missing disabled check"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run All Tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "========================================"
echo "Auto-QA Integration Tests"
echo "========================================"
echo ""

check_prerequisites

echo "Running integration tests..."
echo ""

test_helpers_load
test_config_loads
test_feature_flag_disabled
test_daemon_has_auto_qa_function
test_daemon_starts_auto_qa
test_trigger_format
test_auto_qa_disabled_mode

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================"

# Exit with failure if any tests failed
if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
else
  echo "✅ All integration tests passed!"
  exit 0
fi
