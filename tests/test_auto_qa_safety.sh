#!/bin/bash
# Unit tests for Auto-QA safety mechanisms
# Tests: Idempotent detection, duplicate prevention, trigger validation

set -e

# Setup test environment
TEST_DIR=$(mktemp -d)
TRIGGER_DIR="$TEST_DIR/.claude/triggers"
TRIGGER_DIR_PROCESSED="$TRIGGER_DIR/processed"
mkdir -p "$TRIGGER_DIR" "$TRIGGER_DIR_PROCESSED"

# Mock project environment
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
export STARFORGE_PROJECT_NAME="test-project"
mkdir -p "$TEST_DIR/.claude/metrics"

# Source the helpers
source templates/scripts/auto-qa-helpers.sh

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
  echo "✅ PASS: $1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
  echo "❌ FAIL: $1"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  TESTS_RUN=$((TESTS_RUN + 1))
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Idempotent Detection - No Trigger Exists
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_no_trigger_exists() {
  # Should return 1 (false) = safe to create
  if trigger_exists_for_pr 123; then
    fail "test_no_trigger_exists: Should return false when no trigger exists"
  else
    pass "test_no_trigger_exists: Correctly detects no existing trigger"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Idempotent Detection - Active Trigger Exists
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_active_trigger_exists() {
  # Create a trigger file
  touch "$TRIGGER_DIR/qa-engineer-review_pr_123-1234567890.trigger"

  # Should return 0 (true) = trigger exists
  if trigger_exists_for_pr 123; then
    pass "test_active_trigger_exists: Correctly detects active trigger"
  else
    fail "test_active_trigger_exists: Should return true when active trigger exists"
  fi

  # Cleanup
  rm -f "$TRIGGER_DIR"/*
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Idempotent Detection - Processed Trigger Exists
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_processed_trigger_exists() {
  # Create a processed trigger file
  touch "$TRIGGER_DIR_PROCESSED/20251028-123456-qa-engineer-review_pr_124-1234567890.trigger"

  # Should return 0 (true) = trigger exists
  if trigger_exists_for_pr 124; then
    pass "test_processed_trigger_exists: Correctly detects processed trigger"
  else
    fail "test_processed_trigger_exists: Should return true when processed trigger exists"
  fi

  # Cleanup
  rm -f "$TRIGGER_DIR_PROCESSED"/*
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Trigger Creation - Valid JSON
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_trigger_creation_valid_json() {
  # Create trigger
  if create_qa_trigger_for_pr 125 "test-agent"; then
    # Find the created trigger
    local trigger_file=$(ls "$TRIGGER_DIR"/qa-engineer-review_pr_125-*.trigger 2>/dev/null | head -1)

    if [ -f "$trigger_file" ]; then
      # Validate JSON
      if jq empty "$trigger_file" 2>/dev/null; then
        pass "test_trigger_creation_valid_json: Trigger has valid JSON"
      else
        fail "test_trigger_creation_valid_json: Trigger has invalid JSON"
      fi
    else
      fail "test_trigger_creation_valid_json: Trigger file not created"
    fi
  else
    fail "test_trigger_creation_valid_json: Trigger creation failed"
  fi

  # Cleanup
  rm -f "$TRIGGER_DIR"/*
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Trigger Creation - Required Fields
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_trigger_required_fields() {
  # Create trigger
  create_qa_trigger_for_pr 126 "test-agent" >/dev/null 2>&1

  local trigger_file=$(ls "$TRIGGER_DIR"/qa-engineer-review_pr_126-*.trigger 2>/dev/null | head -1)

  if [ -f "$trigger_file" ]; then
    local from_agent=$(jq -r '.from_agent' "$trigger_file")
    local to_agent=$(jq -r '.to_agent' "$trigger_file")
    local action=$(jq -r '.action' "$trigger_file")
    local pr=$(jq -r '.context.pr' "$trigger_file")
    local message=$(jq -r '.message' "$trigger_file")
    local command=$(jq -r '.command' "$trigger_file")

    if [ "$from_agent" = "test-agent" ] && \
       [ "$to_agent" = "qa-engineer" ] && \
       [ "$action" = "review_pr" ] && \
       [ "$pr" = "126" ] && \
       [ -n "$message" ] && \
       [ -n "$command" ]; then
      pass "test_trigger_required_fields: All required fields present and correct"
    else
      fail "test_trigger_required_fields: Missing or incorrect fields (from=$from_agent, to=$to_agent, action=$action, pr=$pr)"
    fi
  else
    fail "test_trigger_required_fields: Trigger file not created"
  fi

  # Cleanup
  rm -f "$TRIGGER_DIR"/*
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Unique Trigger IDs (Multi-Instance Safety)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_unique_trigger_ids() {
  # Create 3 triggers for same PR rapidly
  create_qa_trigger_for_pr 127 "agent1" >/dev/null 2>&1
  create_qa_trigger_for_pr 127 "agent2" >/dev/null 2>&1
  create_qa_trigger_for_pr 127 "agent3" >/dev/null 2>&1

  local trigger_count=$(ls "$TRIGGER_DIR"/qa-engineer-review_pr_127-*.trigger 2>/dev/null | wc -l | tr -d ' ')

  if [ "$trigger_count" -eq 3 ]; then
    # Check all filenames are unique
    local unique_count=$(ls "$TRIGGER_DIR"/qa-engineer-review_pr_127-*.trigger 2>/dev/null | sort -u | wc -l | tr -d ' ')
    if [ "$unique_count" -eq 3 ]; then
      pass "test_unique_trigger_ids: All triggers have unique IDs"
    else
      fail "test_unique_trigger_ids: Duplicate trigger IDs detected"
    fi
  else
    fail "test_unique_trigger_ids: Expected 3 triggers, got $trigger_count"
  fi

  # Cleanup
  rm -f "$TRIGGER_DIR"/*
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: Auto-QA Log Creation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_auto_qa_logging() {
  log_auto_qa "TEST" "Test log entry"

  if [ -f "$TEST_DIR/.claude/metrics/auto-qa.log" ]; then
    if grep -q "Test log entry" "$TEST_DIR/.claude/metrics/auto-qa.log"; then
      pass "test_auto_qa_logging: Log entry created successfully"
    else
      fail "test_auto_qa_logging: Log entry not found in log file"
    fi
  else
    fail "test_auto_qa_logging: Log file not created"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run All Tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "========================================"
echo "Auto-QA Safety Tests"
echo "========================================"
echo ""

test_no_trigger_exists
test_active_trigger_exists
test_processed_trigger_exists
test_trigger_creation_valid_json
test_trigger_required_fields
test_unique_trigger_ids
test_auto_qa_logging

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo "Tests run:    $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================"

# Cleanup
rm -rf "$TEST_DIR"

# Exit with failure if any tests failed
if [ "$TESTS_FAILED" -gt 0 ]; then
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
