#!/usr/bin/env bash
#
# test_discord_agent_start_rich.sh - Tests for enhanced send_agent_start_notification()
#
# Tests rich context support: PR links, message, description
#

# Note: NOT using 'set -e' because ((PASSED++)) returns 1 when PASSED=0, causing early exit
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load the Discord notify library
source "$SCRIPT_DIR/../../templates/lib/discord-notify.sh"

# Mock gh to return repo name
# gh repo view --json nameWithOwner -q .nameWithOwner
gh() {
  if [ "$1" = "repo" ] && [ "$2" = "view" ]; then
    # Check if -q flag present (means we should output just the value, not JSON)
    local output_json=true
    for arg in "$@"; do
      if [ "$arg" = "-q" ]; then
        output_json=false
        break
      fi
    done

    if [ "$output_json" = true ]; then
      echo '{"nameWithOwner":"JediMasterKT/starforge-master"}'
    else
      # -q .nameWithOwner means extract just the value
      echo "JediMasterKT/starforge-master"
    fi
  fi
}
export -f gh

# Variables to capture send_discord_daemon_notification calls
CAPTURED_AGENT=""
CAPTURED_TITLE=""
CAPTURED_DESC=""
CAPTURED_COLOR=""
CAPTURED_FIELDS=""

# Override send_discord_daemon_notification to capture parameters
send_discord_daemon_notification() {
  CAPTURED_AGENT=$1
  CAPTURED_TITLE=$2
  CAPTURED_DESC=$3
  CAPTURED_COLOR=$4
  CAPTURED_FIELDS=$5
}

echo "========================================"
echo "Discord Agent Start Rich Context Tests"
echo "========================================"

PASSED=0
FAILED=0

# Test 1: Basic notification with all parameters (PR included)
echo ""
echo "Test 1: Notification with PR and full context"
send_agent_start_notification "qa-engineer" "review_pr" "main-claude" "310" \
  "Reviewing PR #304: daemon.sh nested path fix" "304" "Critical daemon.sh path bug fix"

# Verify title
if [ "$CAPTURED_TITLE" = "🚀 Agent Started" ]; then
  echo "✅ PASS: Title correct"
  ((PASSED++))
else
  echo "❌ FAIL: Title incorrect - got '$CAPTURED_TITLE'"
  ((FAILED++))
fi

# Verify description uses message parameter
if [ "$CAPTURED_DESC" = "Reviewing PR #304: daemon.sh nested path fix" ]; then
  echo "✅ PASS: Description uses message parameter"
  ((PASSED++))
else
  echo "❌ FAIL: Description incorrect - got '$CAPTURED_DESC'"
  ((FAILED++))
fi

# Verify PR field exists in fields JSON
if echo "$CAPTURED_FIELDS" | grep -q '"name":"PR"'; then
  echo "✅ PASS: PR field exists"
  ((PASSED++))
else
  echo "❌ FAIL: PR field missing from: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Verify PR link format
if echo "$CAPTURED_FIELDS" | grep -q '#304' && echo "$CAPTURED_FIELDS" | grep -q 'https://github.com/JediMasterKT/starforge-master/pull/304'; then
  echo "✅ PASS: PR link format correct"
  ((PASSED++))
else
  echo "❌ FAIL: PR link format incorrect in: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Verify Context field exists
if echo "$CAPTURED_FIELDS" | grep -q '"name":"Context"'; then
  echo "✅ PASS: Context field exists"
  ((PASSED++))
else
  echo "❌ FAIL: Context field missing from: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Verify Context value
if echo "$CAPTURED_FIELDS" | grep -q 'Critical daemon.sh path bug fix'; then
  echo "✅ PASS: Context value correct"
  ((PASSED++))
else
  echo "❌ FAIL: Context value incorrect in: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Test 2: Notification without PR (backward compatibility)
echo ""
echo "Test 2: Notification without PR (backward compatibility)"
send_agent_start_notification "orchestrator" "process_tickets" "main-claude" "310" \
  "Processing ready tickets" "" ""

# Verify no PR field
if ! echo "$CAPTURED_FIELDS" | grep -q '"name":"PR"'; then
  echo "✅ PASS: No PR field when PR empty"
  ((PASSED++))
else
  echo "❌ FAIL: PR field should not exist in: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Verify Action field still exists
if echo "$CAPTURED_FIELDS" | grep -q '"name":"Action"' && echo "$CAPTURED_FIELDS" | grep -q '"value":"process_tickets"'; then
  echo "✅ PASS: Action field exists"
  ((PASSED++))
else
  echo "❌ FAIL: Action field missing or incorrect"
  ((FAILED++))
fi

# Verify description uses message
if [ "$CAPTURED_DESC" = "Processing ready tickets" ]; then
  echo "✅ PASS: Description uses message parameter"
  ((PASSED++))
else
  echo "❌ FAIL: Description incorrect - got '$CAPTURED_DESC'"
  ((FAILED++))
fi

# Test 3: Fallback to generic message when message param empty
echo ""
echo "Test 3: Fallback message when message parameter empty"
send_agent_start_notification "junior-dev-a" "implement_feature" "orchestrator" "123" \
  "" "" ""

if [[ "$CAPTURED_DESC" == *"junior-dev-a"* ]] && [[ "$CAPTURED_DESC" == *"working"* ]]; then
  echo "✅ PASS: Fallback message correct"
  ((PASSED++))
else
  echo "❌ FAIL: Fallback message incorrect - got '$CAPTURED_DESC'"
  ((FAILED++))
fi

# Test 4: No Context field when description empty
echo ""
echo "Test 4: No Context field when description empty"
send_agent_start_notification "qa-engineer" "review_pr" "main-claude" "310" \
  "Reviewing PR #304" "304" ""

if ! echo "$CAPTURED_FIELDS" | grep -q '"name":"Context"'; then
  echo "✅ PASS: No Context field when description empty"
  ((PASSED++))
else
  echo "❌ FAIL: Context field should not exist in: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# But PR field should exist
if echo "$CAPTURED_FIELDS" | grep -q '"name":"PR"'; then
  echo "✅ PASS: PR field exists (description independent)"
  ((PASSED++))
else
  echo "❌ FAIL: PR field missing"
  ((FAILED++))
fi

# Test 5: Truncate very long description
echo ""
echo "Test 5: Truncate very long description (>1000 chars)"
LONG_DESC=$(printf 'a%.0s' {1..2000})  # 2000 chars

send_agent_start_notification "qa" "test" "main" "1" "Test message" "123" "$LONG_DESC"

# Extract context value from fields JSON
CONTEXT_VALUE=$(echo "$CAPTURED_FIELDS" | grep -o '"name":"Context","value":"[^"]*"' | sed 's/.*"value":"\([^"]*\)".*/\1/')
CONTEXT_LEN=${#CONTEXT_VALUE}

if [ $CONTEXT_LEN -le 1024 ]; then
  echo "✅ PASS: Description truncated to $CONTEXT_LEN chars"
  ((PASSED++))
else
  echo "❌ FAIL: Description not truncated - $CONTEXT_LEN chars"
  ((FAILED++))
fi

# Verify truncation indicator
if echo "$CAPTURED_FIELDS" | grep -q '\.\.\.'; then
  echo "✅ PASS: Truncation indicator present"
  ((PASSED++))
else
  echo "❌ FAIL: Truncation indicator missing in: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Test 6: Old function signature still works (4 params only)
echo ""
echo "Test 6: Backward compatibility - old 4-parameter signature"
send_agent_start_notification "junior-dev-b" "implement" "orchestrator" "200"

# Should not crash
if [ $? -eq 0 ]; then
  echo "✅ PASS: Old signature works"
  ((PASSED++))
else
  echo "❌ FAIL: Old signature failed"
  ((FAILED++))
fi

# Verify basic fields still present and description uses fallback
if [[ "$CAPTURED_DESC" == *"junior-dev-b"* ]] && [[ "$CAPTURED_DESC" == *"working"* ]]; then
  echo "✅ PASS: Fallback description with old signature"
  ((PASSED++))
else
  echo "❌ FAIL: Fallback description incorrect"
  ((FAILED++))
fi

if echo "$CAPTURED_FIELDS" | grep -q '"value":"implement"'; then
  echo "✅ PASS: Action field correct with old signature"
  ((PASSED++))
else
  echo "❌ FAIL: Action field incorrect"
  ((FAILED++))
fi

# Test 7: Invalid PR number (non-numeric) should skip PR link
echo ""
echo "Test 7: Invalid PR number handled gracefully"
send_agent_start_notification "qa" "review" "main" "1" "Test" "invalid" "desc"

# Should still work without crashing
if [ $? -eq 0 ]; then
  echo "✅ PASS: Invalid PR handled gracefully"
  ((PASSED++))
else
  echo "❌ FAIL: Invalid PR caused failure"
  ((FAILED++))
fi

# Should not have PR field
if ! echo "$CAPTURED_FIELDS" | grep -q '"name":"PR"'; then
  echo "✅ PASS: No PR field for invalid PR number"
  ((PASSED++))
else
  echo "❌ FAIL: PR field exists for invalid PR"
  ((FAILED++))
fi

# Test 8: Verify JSON is valid
echo ""
echo "Test 8: Generated fields JSON is valid"
send_agent_start_notification "qa" "review" "main" "310" "Test" "123" "Context"

echo "$CAPTURED_FIELDS" | jq . > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ PASS: Fields JSON is valid"
  ((PASSED++))
else
  echo "❌ FAIL: Fields JSON is invalid: $CAPTURED_FIELDS"
  ((FAILED++))
fi

# Test 9: Verify all standard fields present
echo ""
echo "Test 9: All standard fields present (Action, From, Ticket)"
send_agent_start_notification "qa" "review_pr" "main-claude" "310" "msg" "123" "desc"

if echo "$CAPTURED_FIELDS" | jq -e '.[] | select(.name == "Action")' > /dev/null 2>&1; then
  echo "✅ PASS: Action field present"
  ((PASSED++))
else
  echo "❌ FAIL: Action field missing"
  ((FAILED++))
fi

if echo "$CAPTURED_FIELDS" | jq -e '.[] | select(.name == "From")' > /dev/null 2>&1; then
  echo "✅ PASS: From field present"
  ((PASSED++))
else
  echo "❌ FAIL: From field missing"
  ((FAILED++))
fi

if echo "$CAPTURED_FIELDS" | jq -e '.[] | select(.name == "Ticket")' > /dev/null 2>&1; then
  echo "✅ PASS: Ticket field present"
  ((PASSED++))
else
  echo "❌ FAIL: Ticket field missing"
  ((FAILED++))
fi

echo ""
echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
