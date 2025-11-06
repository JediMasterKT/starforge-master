#!/usr/bin/env bash
#
# test_progress_notification.sh - TDD tests for send_agent_progress_notification
#
# Tests that progress notifications include PR context (issue #314)
#

set -euo pipefail

# Setup test environment
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="${TEST_DIR}/../templates"

# Source the discord-notify.sh to test
source "${TEMPLATES_DIR}/lib/discord-notify.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper: assert equals
assert_equals() {
  local expected=$1
  local actual=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" == "$actual" ]; then
    echo "✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo "❌ FAIL: $message"
    echo "   Expected: $expected"
    echo "   Got:      $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Test helper: assert contains
assert_contains() {
  local haystack=$1
  local needle=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    echo "✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo "❌ FAIL: $message"
    echo "   Expected to find: $needle"
    echo "   In: $haystack"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Mock curl to capture payload (writes to temp file since curl runs in background)
CURL_PAYLOAD_FILE="/tmp/test_discord_payload_$$.txt"
curl() {
  # Capture the JSON payload (last argument)
  while [ $# -gt 0 ]; do
    if [ "$1" == "-d" ]; then
      echo "$2" > "$CURL_PAYLOAD_FILE"
      break
    fi
    shift
  done
}
export -f curl

# Helper to get payload
get_curl_payload() {
  # Wait a moment for background curl to finish
  sleep 0.1
  if [ -f "$CURL_PAYLOAD_FILE" ]; then
    cat "$CURL_PAYLOAD_FILE"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Function accepts new parameters
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_function_signature() {
  echo ""
  echo "Test 1: Function accepts new parameters"
  echo "========================================"

  # Mock webhook
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  # Call with new signature (should not error)
  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR #304: daemon fix" \
    "304" \
    "Add daemon monitoring" \
    "https://github.com/user/repo/pull/304"

  local exit_code=$?
  assert_equals 0 $exit_code "Function should accept 7 parameters without error"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: PR field exists in payload when PR provided
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_pr_field_exists() {
  echo ""
  echo "Test 2: PR field exists when PR provided"
  echo "========================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR #304" \
    "304" \
    "Add daemon monitoring" \
    "https://github.com/user/repo/pull/304"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Check if PR field exists in JSON
  if echo "$CURL_PAYLOAD" | jq -e '.embeds[0].fields[] | select(.name == "PR")' > /dev/null 2>&1; then
    echo "✅ PASS: PR field exists in payload"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "❌ FAIL: PR field missing in payload"
    echo "Payload: $CURL_PAYLOAD"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: PR field contains clickable link
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_pr_field_link() {
  echo ""
  echo "Test 3: PR field contains clickable link"
  echo "========================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR #304" \
    "304" \
    "Add daemon monitoring" \
    "https://github.com/user/repo/pull/304"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Extract PR field value
  local pr_value=$(echo "$CURL_PAYLOAD" | jq -r '.embeds[0].fields[] | select(.name == "PR") | .value' 2>/dev/null || echo "")

  assert_contains "$pr_value" "#304" "PR value should contain PR number"
  assert_contains "$pr_value" "https://github.com/user/repo/pull/304" "PR value should contain PR URL"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Elapsed time field still present
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_elapsed_field() {
  echo ""
  echo "Test 4: Elapsed time field still present"
  echo "========================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR #304" \
    "304" \
    "Add daemon monitoring" \
    "https://github.com/user/repo/pull/304"

  local CURL_PAYLOAD=$(get_curl_payload)
  local elapsed=$(echo "$CURL_PAYLOAD" | jq -r '.embeds[0].fields[] | select(.name == "Elapsed") | .value' 2>/dev/null || echo "")

  assert_equals "15m" "$elapsed" "Elapsed field should show 15m"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Backward compatible (works without PR info)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_backward_compatible() {
  echo ""
  echo "Test 5: Backward compatible (no PR info)"
  echo "========================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  # Call with old signature (only 3 params)
  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310"

  local exit_code=$?
  assert_equals 0 $exit_code "Function should work with 3 parameters (backward compatible)"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Should NOT have PR field
  if echo "$CURL_PAYLOAD" | jq -e '.embeds[0].fields[] | select(.name == "PR")' > /dev/null 2>&1; then
    echo "❌ FAIL: PR field should NOT exist when PR info not provided"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    echo "✅ PASS: PR field correctly omitted when not provided"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Message field displayed when provided
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_message_field() {
  echo ""
  echo "Test 6: Message field displayed when provided"
  echo "=============================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR #304: daemon fix"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Check if message appears in description
  assert_contains "$CURL_PAYLOAD" "Review PR #304: daemon fix" "Message should appear in notification"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: Security - PR title with double quotes
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_security_double_quotes() {
  echo ""
  echo "Test 7: Security - PR title with double quotes"
  echo "=============================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR" \
    "304" \
    'Fix "quoted" bug' \
    "https://github.com/user/repo/pull/304"

  local exit_code=$?
  assert_equals 0 $exit_code "Function should handle PR title with double quotes"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Verify payload is valid JSON
  if echo "$CURL_PAYLOAD" | jq . > /dev/null 2>&1; then
    echo "✅ PASS: Payload is valid JSON despite double quotes in PR title"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "❌ FAIL: Payload is invalid JSON (JSON injection vulnerability)"
    echo "Payload: $CURL_PAYLOAD"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))

  # Verify PR title is correctly escaped
  local pr_value=$(echo "$CURL_PAYLOAD" | jq -r '.embeds[0].fields[] | select(.name == "PR") | .value' 2>/dev/null || echo "")
  assert_contains "$pr_value" "Fix \"quoted\" bug" "PR title with quotes should be correctly escaped"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 8: Security - PR title with newlines
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_security_newlines() {
  echo ""
  echo "Test 8: Security - PR title with newlines"
  echo "=========================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR" \
    "304" \
    $'Fix\nbug' \
    "https://github.com/user/repo/pull/304"

  local exit_code=$?
  assert_equals 0 $exit_code "Function should handle PR title with newlines"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Verify payload is valid JSON
  if echo "$CURL_PAYLOAD" | jq . > /dev/null 2>&1; then
    echo "✅ PASS: Payload is valid JSON despite newlines in PR title"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "❌ FAIL: Payload is invalid JSON (JSON injection vulnerability)"
    echo "Payload: $CURL_PAYLOAD"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 9: Security - PR title with backslashes
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_security_backslashes() {
  echo ""
  echo "Test 9: Security - PR title with backslashes"
  echo "============================================="

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR" \
    "304" \
    'Fix \\ bug' \
    "https://github.com/user/repo/pull/304"

  local exit_code=$?
  assert_equals 0 $exit_code "Function should handle PR title with backslashes"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Verify payload is valid JSON
  if echo "$CURL_PAYLOAD" | jq . > /dev/null 2>&1; then
    echo "✅ PASS: Payload is valid JSON despite backslashes in PR title"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "❌ FAIL: Payload is invalid JSON (JSON injection vulnerability)"
    echo "Payload: $CURL_PAYLOAD"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 10: Security - PR title with single quotes
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_security_single_quotes() {
  echo ""
  echo "Test 10: Security - PR title with single quotes"
  echo "================================================"

  rm -f "$CURL_PAYLOAD_FILE"
  export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"

  send_agent_progress_notification \
    "qa-engineer" \
    15 \
    "310" \
    "Review PR" \
    "304" \
    "Fix 'bug'" \
    "https://github.com/user/repo/pull/304"

  local exit_code=$?
  assert_equals 0 $exit_code "Function should handle PR title with single quotes"

  local CURL_PAYLOAD=$(get_curl_payload)

  # Verify payload is valid JSON
  if echo "$CURL_PAYLOAD" | jq . > /dev/null 2>&1; then
    echo "✅ PASS: Payload is valid JSON despite single quotes in PR title"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "❌ FAIL: Payload is invalid JSON (JSON injection vulnerability)"
    echo "Payload: $CURL_PAYLOAD"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))

  # Verify PR title is correctly rendered
  local pr_value=$(echo "$CURL_PAYLOAD" | jq -r '.embeds[0].fields[] | select(.name == "PR") | .value' 2>/dev/null || echo "")
  assert_contains "$pr_value" "Fix 'bug'" "PR title with single quotes should be correctly rendered"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run all tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "=========================================="
echo "TDD Tests: send_agent_progress_notification"
echo "=========================================="

test_function_signature
test_pr_field_exists
test_pr_field_link
test_elapsed_field
test_backward_compatible
test_message_field
test_security_double_quotes
test_security_newlines
test_security_backslashes
test_security_single_quotes

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total:  $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  echo "❌ TESTS FAILED"
  exit 1
else
  echo "✅ ALL TESTS PASSED"
  exit 0
fi
