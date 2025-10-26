#!/usr/bin/env bash
#
# test_discord_notify.sh - Unit tests for Discord notification system
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Mock curl to avoid actual HTTP calls
curl() { return 0; }
export -f curl

# Unset any existing Discord webhooks
unset DISCORD_WEBHOOK_URL
unset DISCORD_USER_ID

# Load the Discord notify library
source "$SCRIPT_DIR/../../templates/lib/discord-notify.sh"

echo "========================================"
echo "Discord Notify Unit Tests"
echo "========================================"

PASSED=0
FAILED=0

# Test 1: send_pr_ready_notification exists
echo ""
echo "Test 1: send_pr_ready_notification exists"
if type send_pr_ready_notification > /dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

# Test 2: send_qa_approved_notification exists
echo ""
echo "Test 2: send_qa_approved_notification exists"
if type send_qa_approved_notification > /dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

# Test 3: send_tests_failed_notification exists
echo ""
echo "Test 3: send_tests_failed_notification exists"
if type send_tests_failed_notification > /dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

# Test 4: send_feature_complete_notification exists
echo ""
echo "Test 4: send_feature_complete_notification exists"
if type send_feature_complete_notification > /dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

# Test 5: Functions handle missing webhook gracefully
echo ""
echo "Test 5: send_pr_ready_notification handles missing webhook"
send_pr_ready_notification "junior-dev-a" "200" "Test" "10/10" "80% → 85%" "https://test.com" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

# Test 6: Rate limiting works
echo ""
echo "Test 6: Rate limiting prevents spam"
TEST_WEBHOOK="https://test.com/webhook"
for i in {1..5}; do
  check_rate_limit "$TEST_WEBHOOK" > /dev/null 2>&1
done
# 6th should be rate limited
if ! check_rate_limit "$TEST_WEBHOOK" > /dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

# Clean up rate limit file
rm -f /tmp/discord-rate-limit-*.log

echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
