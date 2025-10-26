#!/usr/bin/env bash
#
# test_discord_notify_simple.sh - Simplified unit tests for Discord notification system
#

set -e

# Test framework setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_PASSED=0
TEST_FAILED=0

# Mock curl to avoid actual HTTP calls and prevent hanging
curl() {
  return 0
}
export -f curl

# Unset any existing Discord webhooks to avoid using real ones
unset DISCORD_WEBHOOK_URL
unset DISCORD_WEBHOOK_JUNIOR_DEV_A
unset DISCORD_USER_ID

# Load the Discord notify library
source "$SCRIPT_DIR/../../templates/lib/discord-notify.sh"

echo "========================================"
echo "Discord Notify Unit Tests (Simplified)"
echo "========================================"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test: Function Existence
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "TEST: Checking if new notification functions exist"

if type send_pr_ready_notification > /dev/null 2>&1; then
  echo "✅ PASS: send_pr_ready_notification exists"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_pr_ready_notification not found"
  ((TEST_FAILED++))
fi

if type send_qa_approved_notification > /dev/null 2>&1; then
  echo "✅ PASS: send_qa_approved_notification exists"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_qa_approved_notification not found"
  ((TEST_FAILED++))
fi

if type send_tests_failed_notification > /dev/null 2>&1; then
  echo "✅ PASS: send_tests_failed_notification exists"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_tests_failed_notification not found"
  ((TEST_FAILED++))
fi

if type send_feature_complete_notification > /dev/null 2>&1; then
  echo "✅ PASS: send_feature_complete_notification exists"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_feature_complete_notification not found"
  ((TEST_FAILED++))
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test: Graceful Handling Without Webhook
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "TEST: Functions handle missing webhook gracefully"

# These should all return 0 even without webhook configured
send_pr_ready_notification "junior-dev-a" "200" "Test PR" "10/10" "80% → 85%" "https://github.com/test/pr/200"
wait  # Wait for background processes
if [ $? -eq 0 ]; then
  echo "✅ PASS: send_pr_ready_notification handles missing webhook"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_pr_ready_notification failed without webhook"
  ((TEST_FAILED++))
fi

send_qa_approved_notification "qa-engineer" "200" "All checks passed" "gh pr merge 200"
wait  # Wait for background processes
if [ $? -eq 0 ]; then
  echo "✅ PASS: send_qa_approved_notification handles missing webhook"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_qa_approved_notification failed without webhook"
  ((TEST_FAILED++))
fi

send_tests_failed_notification "junior-dev-b" "201" "Error message" "at file.ts:42" "starforge logs junior-dev-b"
wait  # Wait for background processes
if [ $? -eq 0 ]; then
  echo "✅ PASS: send_tests_failed_notification handles missing webhook"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_tests_failed_notification failed without webhook"
  ((TEST_FAILED++))
fi

send_feature_complete_notification "orchestrator" "3" "80% → 90%" "2h 30m" "Merge commands here"
wait  # Wait for background processes
if [ $? -eq 0 ]; then
  echo "✅ PASS: send_feature_complete_notification handles missing webhook"
  ((TEST_PASSED++))
else
  echo "❌ FAIL: send_feature_complete_notification failed without webhook"
  ((TEST_FAILED++))
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo "✅ Passed: $TEST_PASSED"
echo "❌ Failed: $TEST_FAILED"
echo "========================================"

# Exit with failure if any tests failed
[ "$TEST_FAILED" -eq 0 ] && exit 0 || exit 1
