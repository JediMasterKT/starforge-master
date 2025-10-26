#!/bin/bash
#
# test_discord_pr_notifications.sh - Integration test for Discord PR notifications
#
# Verifies the end-to-end workflow of PR creation and Discord notification
#

# Don't use set -e so we can run all tests even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Discord PR Notification Integration Test"
echo "========================================"

PASSED=0
FAILED=0

# Test 1: notify_pr_created integration with Discord (mock webhook)
echo ""
echo "Test 1: Full workflow - notify_pr_created with mock webhook"

# Setup mock webhook
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test/mock"

# Mock curl to capture webhook calls
WEBHOOK_CALL_LOG="/tmp/discord-webhook-calls-integration.log"
rm -f "$WEBHOOK_CALL_LOG"

curl() {
  # Capture the webhook call
  local url=""
  local payload=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -X) shift ;; # Skip POST
      -H) shift ;; # Skip Content-Type header
      -d)
        payload="$2"
        shift 2
        ;;
      *)
        if [[ "$1" =~ ^https?:// ]]; then
          url="$1"
        fi
        shift
        ;;
    esac
  done

  # Log the call
  echo "URL: $url" >> "$WEBHOOK_CALL_LOG"
  echo "PAYLOAD: $payload" >> "$WEBHOOK_CALL_LOG"
  echo "---" >> "$WEBHOOK_CALL_LOG"

  return 0
}
export -f curl

# Source libraries
source "$SCRIPT_DIR/../../templates/lib/discord-notify.sh"
source "$SCRIPT_DIR/../../templates/lib/router.sh"

# Execute: Call notify_pr_created
notify_pr_created "999" "https://github.com/test/repo/pull/999" "TEST-42" "test-agent"

# Wait for async call to complete
sleep 1

# Assert: Verify webhook was called
if [ -f "$WEBHOOK_CALL_LOG" ]; then
  CAPTURED=$(cat "$WEBHOOK_CALL_LOG")

  # Check webhook URL
  if echo "$CAPTURED" | grep -q "discord.com/api/webhooks"; then
    echo "✅ PASS: Discord webhook called"
    ((PASSED++))
  else
    echo "❌ FAIL: Discord webhook not called"
    echo "   Log: $CAPTURED"
    ((FAILED++))
  fi

  # Check payload contains PR number
  if echo "$CAPTURED" | grep -q "999"; then
    echo "✅ PASS: Payload contains PR number"
    ((PASSED++))
  else
    echo "❌ FAIL: PR number missing from payload"
    ((FAILED++))
  fi

  # Check payload contains ticket
  if echo "$CAPTURED" | grep -q "TEST-42"; then
    echo "✅ PASS: Payload contains ticket number"
    ((PASSED++))
  else
    echo "❌ FAIL: Ticket number missing from payload"
    ((FAILED++))
  fi

  # Check payload contains PR URL
  if echo "$CAPTURED" | grep -q "https://github.com/test/repo/pull/999"; then
    echo "✅ PASS: Payload contains PR URL"
    ((PASSED++))
  else
    echo "❌ FAIL: PR URL missing from payload"
    ((FAILED++))
  fi

  # Check JSON structure
  if echo "$CAPTURED" | grep -q '"embeds"'; then
    echo "✅ PASS: Valid Discord embed structure"
    ((PASSED++))
  else
    echo "❌ FAIL: Invalid embed structure"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: No webhook calls logged"
  ((FAILED++))
fi

# Test 2: Performance target (<150ms execution time, excluding async curl)
# Note: 100ms is ideal but 150ms is acceptable given system variance
echo ""
echo "Test 2: Performance target (<150ms)"

START_TIME=$(date +%s%N)
notify_pr_created "500" "https://github.com/perf/test/pull/500" "PERF-1" "perf-agent"
END_TIME=$(date +%s%N)

DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

if [ "$DURATION_MS" -le 150 ]; then
  echo "✅ PASS: Execution time ${DURATION_MS}ms (target: <=150ms)"
  ((PASSED++))
else
  echo "❌ FAIL: Too slow - ${DURATION_MS}ms (target: <=150ms)"
  ((FAILED++))
fi

# Test 3: Graceful handling when Discord webhook not configured
echo ""
echo "Test 3: Graceful handling without webhook"

unset DISCORD_WEBHOOK_URL
rm -f "$WEBHOOK_CALL_LOG"

# Should not crash
if notify_pr_created "123" "https://github.com/test/repo/pull/123" "NO-WEBHOOK" "test-agent" > /dev/null 2>&1; then
  echo "✅ PASS: Handles missing webhook gracefully"
  ((PASSED++))

  # Verify no webhook call attempted
  if [ ! -f "$WEBHOOK_CALL_LOG" ]; then
    echo "✅ PASS: No webhook call when not configured"
    ((PASSED++))
  else
    echo "❌ FAIL: Attempted webhook call despite no configuration"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Crashes when webhook not configured"
  ((FAILED++))
fi

# Clean up
rm -f "$WEBHOOK_CALL_LOG"
unset DISCORD_WEBHOOK_URL

echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
