#!/usr/bin/env bash
#
# test_discord_integration.sh - Integration tests for Discord notification system
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."

echo "========================================"
echo "Discord Integration Tests"
echo "========================================"

PASSED=0
FAILED=0

# Mock curl
curl() { return 0; }
export -f curl
unset DISCORD_WEBHOOK_URL

# Load Discord library
source "$PROJECT_ROOT/templates/lib/discord-notify.sh"

echo ""
echo "Test 1: All PR notification functions exist"
if type send_pr_ready_notification >/dev/null 2>&1 && \
   type send_qa_approved_notification >/dev/null 2>&1 && \
   type send_tests_failed_notification >/dev/null 2>&1 && \
   type send_feature_complete_notification >/dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

echo ""
echo "Test 2: Rate limiting prevents spam"
rm -f /tmp/discord-rate-limit-*.log
TEST_WEBHOOK="https://test.com/webhook"
for i in {1..5}; do
  check_rate_limit "$TEST_WEBHOOK" >/dev/null 2>&1
done
# 6th should be rate limited
if ! check_rate_limit "$TEST_WEBHOOK" >/dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi
rm -f /tmp/discord-rate-limit-*.log

echo ""
echo "Test 3: Webhook routing for agents"
export DISCORD_WEBHOOK_URL="https://generic.webhook"
export DISCORD_WEBHOOK_JUNIOR_DEV_A="https://specific.webhook"
generic=$(get_webhook_for_agent "orchestrator")
specific=$(get_webhook_for_agent "junior-dev-a")
if [ "$generic" = "https://generic.webhook" ] && [ "$specific" = "https://specific.webhook" ]; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL (generic=$generic, specific=$specific)"
  ((FAILED++))
fi

echo ""
echo "Test 4: Existing daemon notifications still work"
if type send_agent_start_notification >/dev/null 2>&1 && \
   type send_agent_complete_notification >/dev/null 2>&1 && \
   type send_agent_error_notification >/dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL"
  ((FAILED++))
fi

echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
