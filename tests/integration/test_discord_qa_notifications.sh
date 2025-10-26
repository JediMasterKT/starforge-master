#!/usr/bin/env bash
#
# Integration tests for Discord QA review notifications
#
# Tests notify_qa_approved() and notify_qa_rejected() functions
# in router.sh
#

set -e

# Setup test environment
TEST_DIR=$(mktemp -d)
cd "$(git rev-parse --show-toplevel)"

# Color codes (from discord-notify.sh)
COLOR_SUCCESS=5763719   # Green
COLOR_WARNING=16776960  # Yellow

# Test helpers
pass_count=0
fail_count=0

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$expected" = "$actual" ]; then
    echo "  ✅ $message"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ $message"
    echo "     Expected: $expected"
    echo "     Actual: $actual"
    fail_count=$((fail_count + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ $message"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ $message"
    echo "     Expected to contain: $needle"
    echo "     Actual: $haystack"
    fail_count=$((fail_count + 1))
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if ! echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ $message"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ $message"
    echo "     Expected NOT to contain: $needle"
    echo "     Actual: $haystack"
    fail_count=$((fail_count + 1))
  fi
}

# Mock send_discord_daemon_notification to capture calls
mock_discord_notification() {
  # Save call arguments to temp file for assertion
  echo "agent=$1" >> "$TEST_DIR/discord-calls.txt"
  echo "title=$2" >> "$TEST_DIR/discord-calls.txt"
  echo "description=$3" >> "$TEST_DIR/discord-calls.txt"
  echo "color=$4" >> "$TEST_DIR/discord-calls.txt"
  echo "fields=$5" >> "$TEST_DIR/discord-calls.txt"
  echo "---" >> "$TEST_DIR/discord-calls.txt"
}

# Export mock
export -f mock_discord_notification

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: notify_qa_approved sends green notification
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notify_qa_approved() {
  echo ""
  echo "Test 1: notify_qa_approved sends green notification"

  # Setup
  rm -f "$TEST_DIR/discord-calls.txt"

  # Redefine send_discord_daemon_notification
  send_discord_daemon_notification() {
    mock_discord_notification "$@"
  }
  export -f send_discord_daemon_notification

  # Load router functions
  source templates/lib/router.sh

  # Execute
  notify_qa_approved "167" "https://github.com/user/repo/pull/167"

  # Assert
  local captured=$(cat "$TEST_DIR/discord-calls.txt")

  assert_contains "$captured" "QA Approved" "Should have 'QA Approved' in title"
  assert_contains "$captured" "color=$COLOR_SUCCESS" "Should use green color (success)"
  assert_contains "$captured" "PR #167" "Should include PR number"
  assert_contains "$captured" "https://github.com/user/repo/pull/167" "Should include PR URL"
  assert_contains "$captured" "Ready to merge" "Should mention ready to merge"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: notify_qa_rejected sends yellow notification with feedback
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notify_qa_rejected() {
  echo ""
  echo "Test 2: notify_qa_rejected sends yellow notification with feedback"

  # Setup
  rm -f "$TEST_DIR/discord-calls.txt"

  # Redefine send_discord_daemon_notification
  send_discord_daemon_notification() {
    mock_discord_notification "$@"
  }
  export -f send_discord_daemon_notification

  # Load router functions
  source templates/lib/router.sh

  # Execute
  notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "Please add integration tests"

  # Assert
  local captured=$(cat "$TEST_DIR/discord-calls.txt")

  assert_contains "$captured" "QA Changes Requested" "Should have 'QA Changes Requested' in title"
  assert_contains "$captured" "color=$COLOR_WARNING" "Should use yellow color (warning)"
  assert_contains "$captured" "PR #167" "Should include PR number"
  assert_contains "$captured" "https://github.com/user/repo/pull/167" "Should include PR URL"
  assert_contains "$captured" "Please add integration tests" "Should include feedback"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Long feedback is truncated to 200 chars
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notify_qa_rejected_long_feedback() {
  echo ""
  echo "Test 3: Long feedback is truncated to 200 chars"

  # Setup
  rm -f "$TEST_DIR/discord-calls.txt"

  # Redefine send_discord_daemon_notification
  send_discord_daemon_notification() {
    mock_discord_notification "$@"
  }
  export -f send_discord_daemon_notification

  # Load router functions
  source templates/lib/router.sh

  # Generate 500 character feedback
  local long_feedback=$(python3 -c "print('A' * 500)")

  # Execute
  notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "$long_feedback"

  # Assert
  local captured=$(cat "$TEST_DIR/discord-calls.txt")

  # Extract description field
  local description=$(echo "$captured" | grep "^description=" | cut -d'=' -f2-)

  # Check length (should be truncated with "...")
  local length=${#description}

  if [ $length -lt 250 ]; then
    echo "  ✅ Feedback truncated (length: $length < 250)"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ Feedback not truncated (length: $length >= 250)"
    fail_count=$((fail_count + 1))
  fi

  assert_contains "$captured" "..." "Should include ellipsis to indicate truncation"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Empty feedback handled gracefully
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notify_qa_rejected_empty_feedback() {
  echo ""
  echo "Test 4: Empty feedback handled gracefully"

  # Setup
  rm -f "$TEST_DIR/discord-calls.txt"

  # Redefine send_discord_daemon_notification
  send_discord_daemon_notification() {
    mock_discord_notification "$@"
  }
  export -f send_discord_daemon_notification

  # Load router functions
  source templates/lib/router.sh

  # Execute with empty feedback
  notify_qa_rejected "167" "https://github.com/user/repo/pull/167" ""

  # Assert
  local captured=$(cat "$TEST_DIR/discord-calls.txt")

  assert_contains "$captured" "No feedback provided" "Should show default message for empty feedback"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Functions exist and are exported
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_functions_exported() {
  echo ""
  echo "Test 5: Functions exist and are exported"

  # Load router
  source templates/lib/router.sh

  # Check if functions exist
  if type notify_qa_approved > /dev/null 2>&1; then
    echo "  ✅ notify_qa_approved function exists"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ notify_qa_approved function not found"
    fail_count=$((fail_count + 1))
  fi

  if type notify_qa_rejected > /dev/null 2>&1; then
    echo "  ✅ notify_qa_rejected function exists"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ notify_qa_rejected function not found"
    fail_count=$((fail_count + 1))
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Performance target (<100ms per notification)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_performance() {
  echo ""
  echo "Test 6: Performance target (<100ms per notification)"

  # Setup
  send_discord_daemon_notification() {
    # No-op for performance test
    return 0
  }
  export -f send_discord_daemon_notification

  # Load router
  source templates/lib/router.sh

  # Measure approved notification
  local start=$(date +%s%N)
  notify_qa_approved "999" "https://github.com/test/repo/pull/999"
  local end=$(date +%s%N)
  local duration_ms=$(( (end - start) / 1000000 ))

  if [ $duration_ms -lt 100 ]; then
    echo "  ✅ notify_qa_approved: ${duration_ms}ms (< 100ms)"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ notify_qa_approved: ${duration_ms}ms (>= 100ms)"
    fail_count=$((fail_count + 1))
  fi

  # Measure rejected notification
  start=$(date +%s%N)
  notify_qa_rejected "999" "https://github.com/test/repo/pull/999" "Test feedback"
  end=$(date +%s%N)
  duration_ms=$(( (end - start) / 1000000 ))

  if [ $duration_ms -lt 100 ]; then
    echo "  ✅ notify_qa_rejected: ${duration_ms}ms (< 100ms)"
    pass_count=$((pass_count + 1))
  else
    echo "  ❌ notify_qa_rejected: ${duration_ms}ms (>= 100ms)"
    fail_count=$((fail_count + 1))
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run all tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "================================"
echo "Discord QA Notifications Tests"
echo "================================"

test_functions_exported
test_notify_qa_approved
test_notify_qa_rejected
test_notify_qa_rejected_long_feedback
test_notify_qa_rejected_empty_feedback
test_performance

# Cleanup
rm -rf "$TEST_DIR"

# Summary
echo ""
echo "================================"
echo "Test Results"
echo "================================"
echo "Passed: $pass_count"
echo "Failed: $fail_count"
echo ""

if [ $fail_count -eq 0 ]; then
  echo "✅ ALL TESTS PASSED"
  exit 0
else
  echo "❌ TESTS FAILED"
  exit 1
fi
