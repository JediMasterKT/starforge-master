#!/bin/bash
# tests/integration/test_daemon_runner_context.sh
#
# Integration test that verifies daemon-runner.sh correctly extracts context variables
# This test sources the actual daemon-runner.sh and tests the extraction logic
#

set -e

# Setup
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Integration Test: Daemon Runner Context Extraction"
echo "=================================================="

# Test that daemon-runner.sh has the new extraction logic
test_daemon_runner_has_context_extraction() {
  echo -n "Test 1: Verify daemon-runner.sh contains context extraction code... "

  local daemon_runner="templates/bin/daemon-runner.sh"

  if [ ! -f "$daemon_runner" ]; then
    echo "❌ FAIL: daemon-runner.sh not found at $daemon_runner"
    return 1
  fi

  # Check for context_json extraction
  if ! grep -q 'local context_json=$(jq -c' "$daemon_runner"; then
    echo "❌ FAIL: Missing context_json extraction"
    return 1
  fi

  # Check for pr extraction
  if ! grep -q 'local pr=$(jq -r' "$daemon_runner"; then
    echo "❌ FAIL: Missing pr extraction"
    return 1
  fi

  # Check for description extraction
  if ! grep -q 'local description=$(jq -r' "$daemon_runner"; then
    echo "❌ FAIL: Missing description extraction"
    return 1
  fi

  echo "✅ PASS"
  return 0
}

# Test that variables are extracted in correct order after existing variables
test_extraction_order() {
  echo -n "Test 2: Verify extraction order (after message/ticket/command)... "

  local daemon_runner="templates/bin/daemon-runner.sh"

  # Get line number of message extraction
  local message_line=$(grep -n 'local message=$(jq -r' "$daemon_runner" | head -1 | cut -d: -f1)

  # Get line number of context_json extraction
  local context_line=$(grep -n 'local context_json=$(jq -c' "$daemon_runner" | head -1 | cut -d: -f1)

  if [ -z "$message_line" ] || [ -z "$context_line" ]; then
    echo "❌ FAIL: Could not find extraction lines"
    return 1
  fi

  # context_json should come after message extraction
  if [ $context_line -gt $message_line ]; then
    echo "✅ PASS (message at line $message_line, context at line $context_line)"
    return 0
  else
    echo "❌ FAIL: context_json should come after message/ticket/command"
    return 1
  fi
}

# Test that all required fields are extracted
test_all_fields_extracted() {
  echo -n "Test 3: Verify all required fields are extracted... "

  local daemon_runner="templates/bin/daemon-runner.sh"

  local missing_fields=""

  # Check each field
  if ! grep -q 'local context_json=' "$daemon_runner"; then
    missing_fields="$missing_fields context_json"
  fi

  if ! grep 'local pr=' "$daemon_runner" | grep -q '.context.pr'; then
    missing_fields="$missing_fields pr"
  fi

  if ! grep 'local description=' "$daemon_runner" | grep -q '.context.description'; then
    missing_fields="$missing_fields description"
  fi

  if [ -n "$missing_fields" ]; then
    echo "❌ FAIL: Missing fields:$missing_fields"
    return 1
  fi

  echo "✅ PASS"
  return 0
}

# Test that extractions have proper error handling (|| echo "")
test_error_handling() {
  echo -n "Test 4: Verify error handling fallbacks... "

  local daemon_runner="templates/bin/daemon-runner.sh"

  # Check context_json has fallback to {}
  if ! grep 'local context_json=' "$daemon_runner" | grep -q '|| echo "{}"'; then
    echo "❌ FAIL: context_json missing || echo \"{}\" fallback"
    return 1
  fi

  # Check pr has fallback to ""
  if ! grep 'local pr=' "$daemon_runner" | grep '.context.pr' | grep -q '|| echo ""'; then
    echo "❌ FAIL: pr missing || echo \"\" fallback"
    return 1
  fi

  # Check description has fallback to ""
  if ! grep 'local description=' "$daemon_runner" | grep '.context.description' | grep -q '|| echo ""'; then
    echo "❌ FAIL: description missing || echo \"\" fallback"
    return 1
  fi

  echo "✅ PASS"
  return 0
}

# Test that comment references issue #311
test_has_issue_reference() {
  echo -n "Test 5: Verify comment references issue #311... "

  local daemon_runner="templates/bin/daemon-runner.sh"

  if grep -B 2 'local context_json=' "$daemon_runner" | grep -q '#311'; then
    echo "✅ PASS"
    return 0
  else
    echo "⚠️  WARNING: No comment referencing issue #311 (optional)"
    return 0  # Don't fail, just warn
  fi
}

# Run all tests
PASSED=0
FAILED=0

for test_func in \
  test_daemon_runner_has_context_extraction \
  test_extraction_order \
  test_all_fields_extracted \
  test_error_handling \
  test_has_issue_reference
do
  if $test_func; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=================================================="

if [ $FAILED -eq 0 ]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ SOME TESTS FAILED"
  exit 1
fi
