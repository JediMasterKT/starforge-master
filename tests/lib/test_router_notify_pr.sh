#!/usr/bin/env bash
#
# test_router_notify_pr.sh - Unit tests for notify_pr_created in router.sh
#

# Don't use set -e so we can run all tests even if some fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Track test results
PASSED=0
FAILED=0

echo "========================================"
echo "Router notify_pr_created Unit Tests"
echo "========================================"

# Mock color constants
COLOR_INFO=3447003

# Mock log functions
log_info() { return 0; }
log_error() { return 0; }
log_warn() { return 0; }
export -f log_info
export -f log_error
export -f log_warn

# Mock Discord notify library (prevent actual notifications)
send_discord_daemon_notification() {
  # Capture arguments for verification
  echo "MOCK_CALL:$1|$2|$3|$4|$5" >> /tmp/test-router-discord-calls.txt
  return 0
}
export -f send_discord_daemon_notification

# Source the router library
source "$SCRIPT_DIR/../../templates/lib/router.sh"

# Test 1: notify_pr_created function exists
echo ""
echo "Test 1: notify_pr_created function exists"
if type notify_pr_created > /dev/null 2>&1; then
  echo "✅ PASS"
  ((PASSED++))
else
  echo "❌ FAIL: notify_pr_created not found"
  ((FAILED++))
fi

# Test 2: notify_pr_created accepts correct parameters
echo ""
echo "Test 2: notify_pr_created calls Discord with correct structure"
rm -f /tmp/test-router-discord-calls.txt

notify_pr_created "167" "https://github.com/user/repo/pull/167" "42" "junior-dev-a"

if [ -f /tmp/test-router-discord-calls.txt ]; then
  CAPTURED=$(cat /tmp/test-router-discord-calls.txt)

  # Verify agent name
  if echo "$CAPTURED" | grep -q "junior-dev-a"; then
    echo "✅ PASS: Agent name included"
    ((PASSED++))
  else
    echo "❌ FAIL: Agent name missing from Discord call"
    echo "   Got: $CAPTURED"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Discord notification not called"
  ((FAILED++))
fi

# Test 3: notify_pr_created includes PR number in fields
echo ""
echo "Test 3: notify_pr_created includes PR number"
rm -f /tmp/test-router-discord-calls.txt

notify_pr_created "200" "https://github.com/test/repo/pull/200" "99" "test-agent"

if [ -f /tmp/test-router-discord-calls.txt ]; then
  CAPTURED=$(cat /tmp/test-router-discord-calls.txt)

  # Verify PR number in fields (5th parameter)
  if echo "$CAPTURED" | grep -q "200"; then
    echo "✅ PASS: PR number included"
    ((PASSED++))
  else
    echo "❌ FAIL: PR number missing"
    echo "   Got: $CAPTURED"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Discord notification not called"
  ((FAILED++))
fi

# Test 4: notify_pr_created includes ticket number in fields
echo ""
echo "Test 4: notify_pr_created includes ticket number"
rm -f /tmp/test-router-discord-calls.txt

notify_pr_created "150" "https://github.com/test/repo/pull/150" "42" "junior-dev-b"

if [ -f /tmp/test-router-discord-calls.txt ]; then
  CAPTURED=$(cat /tmp/test-router-discord-calls.txt)

  # Verify ticket number
  if echo "$CAPTURED" | grep -q "#42"; then
    echo "✅ PASS: Ticket number included"
    ((PASSED++))
  else
    echo "❌ FAIL: Ticket number missing"
    echo "   Got: $CAPTURED"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Discord notification not called"
  ((FAILED++))
fi

# Test 5: notify_pr_created uses INFO color (blue)
echo ""
echo "Test 5: notify_pr_created uses INFO color"
rm -f /tmp/test-router-discord-calls.txt

notify_pr_created "100" "https://github.com/test/repo/pull/100" "10" "qa-engineer"

if [ -f /tmp/test-router-discord-calls.txt ]; then
  CAPTURED=$(cat /tmp/test-router-discord-calls.txt)

  # Verify COLOR_INFO (3447003 - 4th parameter)
  if echo "$CAPTURED" | grep -q "3447003"; then
    echo "✅ PASS: Uses COLOR_INFO (blue)"
    ((PASSED++))
  else
    echo "❌ FAIL: Wrong color code"
    echo "   Got: $CAPTURED"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Discord notification not called"
  ((FAILED++))
fi

# Test 6: notify_pr_created handles empty parameters gracefully
echo ""
echo "Test 6: notify_pr_created handles empty parameters"
rm -f /tmp/test-router-discord-calls.txt

# Should not crash with empty params
if notify_pr_created "" "" "" "" > /dev/null 2>&1; then
  echo "✅ PASS: Handles empty params gracefully"
  ((PASSED++))
else
  echo "❌ FAIL: Crashes with empty params (exit code: $?)"
  ((FAILED++))
fi

# Test 7: notify_pr_created includes correct title
echo ""
echo "Test 7: notify_pr_created uses correct title"
rm -f /tmp/test-router-discord-calls.txt

notify_pr_created "250" "https://github.com/test/repo/pull/250" "88" "orchestrator"

if [ -f /tmp/test-router-discord-calls.txt ]; then
  CAPTURED=$(cat /tmp/test-router-discord-calls.txt)

  # Verify title (2nd parameter)
  if echo "$CAPTURED" | grep -q "PR Ready for Review"; then
    echo "✅ PASS: Title is 'PR Ready for Review'"
    ((PASSED++))
  else
    echo "❌ FAIL: Wrong title"
    echo "   Got: $CAPTURED"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Discord notification not called"
  ((FAILED++))
fi

# Test 8: notify_pr_created includes clickable PR link in description
echo ""
echo "Test 8: notify_pr_created includes PR URL"
rm -f /tmp/test-router-discord-calls.txt

notify_pr_created "175" "https://github.com/example/test/pull/175" "55" "junior-dev-c"

if [ -f /tmp/test-router-discord-calls.txt ]; then
  CAPTURED=$(cat /tmp/test-router-discord-calls.txt)

  # Verify PR URL in description (3rd parameter)
  if echo "$CAPTURED" | grep -q "https://github.com/example/test/pull/175"; then
    echo "✅ PASS: PR URL included in description"
    ((PASSED++))
  else
    echo "❌ FAIL: PR URL missing"
    echo "   Got: $CAPTURED"
    ((FAILED++))
  fi
else
  echo "❌ FAIL: Discord notification not called"
  ((FAILED++))
fi

# Clean up
rm -f /tmp/test-router-discord-calls.txt

echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
