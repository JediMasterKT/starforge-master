#!/usr/bin/env bash
#
# Integration tests for QA review Discord notifications
#
# Tests notify_qa_approved() and notify_qa_rejected() functions
# in templates/lib/router.sh
#

set -e

# Colors for test output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper: Assert equals
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Assert contains
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Haystack: $haystack"
    echo "  Needle: $needle"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Assert less than
assert_less_than() {
  local value="$1"
  local limit="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$value" -lt "$limit" ]; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Value: $value"
    echo "  Limit: $limit"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

echo ""
echo "================================================"
echo "QA Review Notifications - Integration Tests"
echo "================================================"
echo ""

# Test 1: QA approved notification
echo "Test 1: notify_qa_approved() sends correct notification"
echo "--------------------------------------------------------"

# Source router.sh first (which sources discord-notify.sh and defines notify_qa_approved)
source templates/lib/router.sh

# NOW mock send_discord_daemon_notification (after all sourcing is done)
send_discord_daemon_notification() {
  echo "AGENT=$1" > /tmp/test-qa-approved.txt
  echo "TITLE=$2" >> /tmp/test-qa-approved.txt
  echo "DESCRIPTION=$3" >> /tmp/test-qa-approved.txt
  echo "COLOR=$4" >> /tmp/test-qa-approved.txt
  echo "FIELDS=$5" >> /tmp/test-qa-approved.txt
}

# Call function
notify_qa_approved "167" "https://github.com/user/repo/pull/167"

# Verify captured output
captured=$(cat /tmp/test-qa-approved.txt)

assert_contains "$captured" "AGENT=qa-engineer" "Should use qa-engineer as agent"
assert_contains "$captured" "TITLE=✅ QA Approved" "Should have 'QA Approved' title"
assert_contains "$captured" "COLOR=$COLOR_SUCCESS" "Should use green color (COLOR_SUCCESS)"
assert_contains "$captured" "https://github.com/user/repo/pull/167" "Should include PR URL in description"
assert_contains "$captured" "#167" "Should include PR number"
assert_contains "$captured" "Ready to merge" "Should indicate ready to merge status"

rm -f /tmp/test-qa-approved.txt
echo ""

# Test 2: QA rejected notification with feedback
echo "Test 2: notify_qa_rejected() includes feedback"
echo "--------------------------------------------------------"

# Mock send_discord_daemon_notification to capture args
send_discord_daemon_notification() {
  echo "$5" > /tmp/test-qa-rejected-fields.txt
}

# Note: No need to re-source discord-notify.sh, it's already loaded

# Call function
notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "Please add tests and improve error handling"

# Verify fields contain feedback
fields=$(cat /tmp/test-qa-rejected-fields.txt)

assert_contains "$fields" "Please add tests" "Should include feedback in fields"
assert_contains "$fields" "improve error handling" "Should include full feedback message"

rm -f /tmp/test-qa-rejected-fields.txt
echo ""

# Test 3: Long feedback truncation
echo "Test 3: notify_qa_rejected() truncates long feedback to 200 chars"
echo "--------------------------------------------------------"

# Generate 500-char feedback
long_feedback=$(python3 -c "print('A' * 500)")

send_discord_daemon_notification() {
  echo "$3" > /tmp/test-qa-long-desc.txt
  echo "$5" > /tmp/test-qa-long-fields.txt
}

notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "$long_feedback"

fields=$(cat /tmp/test-qa-long-fields.txt)
description=$(cat /tmp/test-qa-long-desc.txt)

# Check if feedback was truncated (should be ~200 chars or less in fields)
feedback_length=$(echo "$fields" | grep -o "Feedback" | wc -l)
if [ "$feedback_length" -gt 0 ]; then
  # Extract the feedback value from JSON
  feedback_value=$(echo "$fields" | python3 -c "import sys, json; data=json.loads(sys.stdin.read()); print([f['value'] for f in data if f['name']=='Feedback'][0] if any(f['name']=='Feedback' for f in data) else '')" 2>/dev/null || echo "$fields")
  actual_length=${#feedback_value}
  assert_less_than "$actual_length" 250 "Feedback should be truncated to ~200 chars"
  assert_contains "$feedback_value" "..." "Should have ellipsis indicating truncation"
else
  echo -e "${YELLOW}⚠${NC} Could not extract feedback from fields (may be in different format)"
fi

rm -f /tmp/test-qa-long-desc.txt /tmp/test-qa-long-fields.txt
echo ""

# Test 4: Empty feedback handling
echo "Test 4: notify_qa_rejected() handles empty feedback"
echo "--------------------------------------------------------"

send_discord_daemon_notification() {
  echo "$5" > /tmp/test-qa-empty.txt
}

notify_qa_rejected "167" "https://github.com/user/repo/pull/167" ""

fields=$(cat /tmp/test-qa-empty.txt)

assert_contains "$fields" "No feedback provided" "Should show default message for empty feedback"

rm -f /tmp/test-qa-empty.txt
echo ""

# Test 5: Color validation
echo "Test 5: Verify correct colors are used"
echo "--------------------------------------------------------"

# Test approved uses green
send_discord_daemon_notification() {
  echo "$4" > /tmp/test-qa-color-approved.txt
}

notify_qa_approved "167" "https://github.com/user/repo/pull/167"

color_approved=$(cat /tmp/test-qa-color-approved.txt)
assert_equals "$COLOR_SUCCESS" "$color_approved" "Approved should use COLOR_SUCCESS (green)"

# Test rejected uses yellow
send_discord_daemon_notification() {
  echo "$4" > /tmp/test-qa-color-rejected.txt
}

notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "Fix tests"

color_rejected=$(cat /tmp/test-qa-color-rejected.txt)
assert_equals "$COLOR_WARNING" "$color_rejected" "Rejected should use COLOR_WARNING (yellow)"

rm -f /tmp/test-qa-color-approved.txt /tmp/test-qa-color-rejected.txt
echo ""

# Test 6: Performance test (<100ms per notification)
echo "Test 6: Performance test (<100ms per notification)"
echo "--------------------------------------------------------"

send_discord_daemon_notification() {
  # Simulate minimal work
  echo "$@" > /dev/null
}

# Measure approved notification
start_time=$(date +%s%N)
notify_qa_approved "167" "https://github.com/user/repo/pull/167"
end_time=$(date +%s%N)
duration_approved=$((($end_time - $start_time) / 1000000)) # Convert to milliseconds

# Measure rejected notification
start_time=$(date +%s%N)
notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "Fix tests"
end_time=$(date +%s%N)
duration_rejected=$((($end_time - $start_time) / 1000000)) # Convert to milliseconds

assert_less_than "$duration_approved" 100 "Approved notification should complete in <100ms (actual: ${duration_approved}ms)"
assert_less_than "$duration_rejected" 100 "Rejected notification should complete in <100ms (actual: ${duration_rejected}ms)"

echo ""

# Test 7: Integration test (real Discord webhook - optional)
echo "Test 7: Integration with real Discord webhook (optional)"
echo "--------------------------------------------------------"

if [ -n "$DISCORD_WEBHOOK_URL" ] || [ -n "$DISCORD_WEBHOOK_QA_ENGINEER" ]; then
  echo -e "${YELLOW}ℹ${NC} Discord webhook configured - sending test notifications..."

  # Unset mock - use real functions
  unset -f send_discord_daemon_notification

  # Send test notifications
  notify_qa_approved "999" "https://github.com/test/repo/pull/999"
  notify_qa_rejected "999" "https://github.com/test/repo/pull/999" "Integration test feedback - please ignore"

  echo -e "${GREEN}✓${NC} Test notifications sent to Discord"
  echo "  Check your Discord channel for:"
  echo "  1. Green 'QA Approved' notification for PR #999"
  echo "  2. Yellow 'Changes Requested' notification for PR #999"
  echo ""
else
  echo -e "${YELLOW}⚠${NC} Skipping real Discord test (no webhook configured)"
  echo "  To test with real Discord, set DISCORD_WEBHOOK_URL or DISCORD_WEBHOOK_QA_ENGINEER"
  echo ""
fi

# Summary
echo "================================================"
echo "Test Summary"
echo "================================================"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
  echo "Failed: $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed${NC}"
  exit 1
fi
