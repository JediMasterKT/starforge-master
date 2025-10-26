#!/bin/bash
# Unit tests for notify_pr_created function in router.sh
#
# Tests verify that the function correctly wraps Discord notification
# and sends appropriate embed with PR details.
#

set -e

# Test utilities
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$actual" = "$expected" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✅ PASS: $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ❌ FAIL: $message"
    echo "     Expected: '$expected'"
    echo "     Got: '$actual'"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✅ PASS: $message"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ❌ FAIL: $message"
    echo "     Expected to find: '$needle'"
    echo "     In: '$haystack'"
    return 1
  fi
}

# Test 1: Function exists and is callable
test_notify_pr_created_exists() {
  echo ""
  echo "Test 1: Function exists and is callable"

  # Source router.sh
  source templates/lib/router.sh

  # Check if function exists
  if type notify_pr_created &>/dev/null; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  ✅ PASS: notify_pr_created function exists"
    return 0
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ❌ FAIL: notify_pr_created function does not exist"
    return 1
  fi
}

# Test 2: Function builds correct embed structure
test_notify_pr_created_embed() {
  echo ""
  echo "Test 2: Function builds correct embed structure"

  # Mock send_discord_daemon_notification to capture args
  send_discord_daemon_notification() {
    # Save all args delimited by |
    echo "$1|$2|$3|$4|$5" > /tmp/test-notification-$$.txt
  }
  export -f send_discord_daemon_notification

  # Source router.sh AFTER mocking
  source templates/lib/router.sh

  # Call function
  notify_pr_created "167" "https://github.com/user/repo/pull/167" "42" "junior-dev-a"

  # Verify arguments
  local captured=$(cat /tmp/test-notification-$$.txt 2>/dev/null || echo "")

  if [ -z "$captured" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  ❌ FAIL: send_discord_daemon_notification was not called"
    return 1
  fi

  # Check agent name (arg 1)
  assert_contains "$captured" "junior-dev-a" "Should include agent name"

  # Check title (arg 2)
  assert_contains "$captured" "PR Ready for Review" "Should have correct title"
  assert_contains "$captured" "📋" "Title should include emoji"

  # Check description (arg 3)
  assert_contains "$captured" "\*\*junior-dev-a\*\*" "Description should bold agent name"
  assert_contains "$captured" "PR #167" "Description should include PR number"
  assert_contains "$captured" "https://github.com/user/repo/pull/167" "Description should include PR URL"

  # Check color (arg 4) - should be COLOR_INFO (3447003)
  assert_contains "$captured" "3447003" "Should use COLOR_INFO (blue)"

  # Check fields (arg 5) - should include ticket and PR
  assert_contains "$captured" "Ticket" "Fields should include Ticket"
  assert_contains "$captured" "#42" "Fields should include ticket number"
  assert_contains "$captured" "PR" "Fields should include PR field"
  assert_contains "$captured" "#167" "Fields should include PR number"

  # Cleanup
  rm -f /tmp/test-notification-$$.txt
}

# Test 3: Function handles missing parameters gracefully
test_notify_pr_created_missing_params() {
  echo ""
  echo "Test 3: Function handles missing parameters gracefully"

  # Mock send_discord_daemon_notification
  send_discord_daemon_notification() {
    echo "$1|$2|$3|$4|$5" > /tmp/test-notification-$$.txt
  }
  export -f send_discord_daemon_notification

  source templates/lib/router.sh

  # Call with empty params - should not crash
  notify_pr_created "" "" "" ""
  local exit_code=$?

  assert_equals "$exit_code" "0" "Should handle empty params gracefully (exit 0)"

  # Cleanup
  rm -f /tmp/test-notification-$$.txt
}

# Test 4: Function uses correct parameters
test_notify_pr_created_parameters() {
  echo ""
  echo "Test 4: Function uses correct parameters in order"

  # Mock to capture exact order
  send_discord_daemon_notification() {
    local agent=$1
    local title=$2
    local description=$3
    local color=$4
    local fields=$5

    echo "AGENT:$agent" > /tmp/test-params-$$.txt
    echo "TITLE:$title" >> /tmp/test-params-$$.txt
    echo "DESC:$description" >> /tmp/test-params-$$.txt
    echo "COLOR:$color" >> /tmp/test-params-$$.txt
    echo "FIELDS:$fields" >> /tmp/test-params-$$.txt
  }
  export -f send_discord_daemon_notification

  source templates/lib/router.sh

  # Call with test values
  notify_pr_created "200" "https://github.com/test/repo/pull/200" "99" "junior-dev-b"

  local output=$(cat /tmp/test-params-$$.txt 2>/dev/null || echo "")

  # Verify parameter order
  assert_contains "$output" "AGENT:junior-dev-b" "Agent should be first parameter"
  assert_contains "$output" "TITLE:📋 PR Ready for Review" "Title should be second parameter"
  assert_contains "$output" "DESC:" "Description should be third parameter"
  assert_contains "$output" "junior-dev-b" "Description should mention agent"
  assert_contains "$output" "PR #200" "Description should mention PR number"
  assert_contains "$output" "COLOR:3447003" "Color should be fourth parameter (COLOR_INFO)"
  assert_contains "$output" "FIELDS:" "Fields should be fifth parameter"

  # Cleanup
  rm -f /tmp/test-params-$$.txt
}

# Run all tests
echo "========================================"
echo "Testing notify_pr_created function"
echo "========================================"

test_notify_pr_created_exists || true
test_notify_pr_created_embed || true
test_notify_pr_created_missing_params || true
test_notify_pr_created_parameters || true

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo "========================================"

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
