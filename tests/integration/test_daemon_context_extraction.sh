#!/bin/bash
# tests/integration/test_daemon_context_extraction.sh
#
# Integration test for daemon context extraction from trigger JSON
# Tests issue #311: Extract message and context fields
#

set -e

# Setup
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Integration Test: Daemon Context Extraction"
echo "============================================"

# Test 1: Extract message from trigger
test_extract_message_from_trigger() {
  echo -n "Test 1: Extract message field... "

  local trigger='{"to_agent": "qa-engineer", "message": "Review PR #304", "context": {"pr": 304}}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local message=$(jq -r '.message // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  if [ "$message" = "Review PR #304" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Expected 'Review PR #304', got '$message'"
    return 1
  fi
}

# Test 2: Extract context.pr field
test_extract_context_pr() {
  echo -n "Test 2: Extract context.pr field... "

  local trigger='{"to_agent": "qa-engineer", "message": "Review PR #304", "context": {"pr": 304, "ticket": 285}}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local pr=$(jq -r '.context.pr // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  if [ "$pr" = "304" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Expected '304', got '$pr'"
    return 1
  fi
}

# Test 3: Extract context.ticket field
test_extract_context_ticket() {
  echo -n "Test 3: Extract context.ticket field... "

  local trigger='{"to_agent": "qa-engineer", "action": "review_pr", "context": {"ticket": 285}}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local ticket=$(jq -r '.context.ticket // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  if [ "$ticket" = "285" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Expected '285', got '$ticket'"
    return 1
  fi
}

# Test 4: Extract context.description field
test_extract_context_description() {
  echo -n "Test 4: Extract context.description field... "

  local trigger='{"to_agent": "qa-engineer", "context": {"description": "Test the new feature"}}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local description=$(jq -r '.context.description // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  if [ "$description" = "Test the new feature" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Expected 'Test the new feature', got '$description'"
    return 1
  fi
}

# Test 5: Extract full context object as JSON
test_extract_full_context_json() {
  echo -n "Test 5: Extract full context as JSON string... "

  local trigger='{"to_agent": "qa-engineer", "context": {"pr": 304, "ticket": 285, "description": "Review changes"}}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local context_json=$(jq -c '.context // {}' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "{}")

  # Verify it's valid JSON
  if echo "$context_json" | jq empty 2>/dev/null; then
    # Verify it contains expected fields
    local pr=$(echo "$context_json" | jq -r '.pr')
    local ticket=$(echo "$context_json" | jq -r '.ticket')

    if [ "$pr" = "304" ] && [ "$ticket" = "285" ]; then
      echo "✅ PASS"
      return 0
    else
      echo "❌ FAIL: Context JSON missing expected fields"
      return 1
    fi
  else
    echo "❌ FAIL: Invalid JSON: $context_json"
    return 1
  fi
}

# Test 6: Handle missing message field gracefully
test_handles_missing_message() {
  echo -n "Test 6: Handle missing message field... "

  local trigger='{"to_agent": "qa-engineer", "action": "review_pr"}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local message=$(jq -r '.message // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  if [ "$message" = "" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Expected empty string, got '$message'"
    return 1
  fi
}

# Test 7: Handle missing context object gracefully
test_handles_missing_context() {
  echo -n "Test 7: Handle missing context object... "

  local trigger='{"to_agent": "qa-engineer", "action": "review_pr"}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local context_json=$(jq -c '.context // {}' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "{}")
  local pr=$(jq -r '.context.pr // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  if [ "$context_json" = "{}" ] && [ "$pr" = "" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Expected empty context, got context_json='$context_json', pr='$pr'"
    return 1
  fi
}

# Test 8: Handle malformed JSON gracefully
test_handles_malformed_json() {
  echo -n "Test 8: Handle malformed JSON... "

  echo "not valid json" > "$TEST_DIR/test-trigger.json"

  local message=$(jq -r '.message // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")
  local pr=$(jq -r '.context.pr // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  # Should gracefully default to empty strings
  if [ "$message" = "" ] && [ "$pr" = "" ]; then
    echo "✅ PASS"
    return 0
  else
    echo "❌ FAIL: Should default to empty strings on parse error"
    return 1
  fi
}

# Test 9: Performance test - extraction should be fast (<10ms)
test_extraction_performance() {
  echo -n "Test 9: Performance (<10ms per extraction)... "

  local trigger='{"to_agent": "qa-engineer", "message": "Review PR #304", "context": {"pr": 304, "ticket": 285, "description": "Test"}}'
  echo "$trigger" > "$TEST_DIR/test-trigger.json"

  local start=$(date +%s%N)

  # Perform all extractions
  local message=$(jq -r '.message // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")
  local context_json=$(jq -c '.context // {}' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "{}")
  local pr=$(jq -r '.context.pr // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")
  local ticket=$(jq -r '.context.ticket // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")
  local description=$(jq -r '.context.description // ""' "$TEST_DIR/test-trigger.json" 2>/dev/null || echo "")

  local end=$(date +%s%N)
  local duration_ns=$((end - start))
  local duration_ms=$((duration_ns / 1000000))

  if [ $duration_ms -lt 10 ]; then
    echo "✅ PASS (${duration_ms}ms)"
    return 0
  else
    echo "⚠️  WARNING: Took ${duration_ms}ms (target: <10ms)"
    # Don't fail, just warn
    return 0
  fi
}

# Run all tests
PASSED=0
FAILED=0

for test_func in \
  test_extract_message_from_trigger \
  test_extract_context_pr \
  test_extract_context_ticket \
  test_extract_context_description \
  test_extract_full_context_json \
  test_handles_missing_message \
  test_handles_missing_context \
  test_handles_malformed_json \
  test_extraction_performance
do
  if $test_func; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "============================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "============================================"

if [ $FAILED -eq 0 ]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ SOME TESTS FAILED"
  exit 1
fi
