#!/bin/bash
#
# Integration tests for agent blocker detection and management
#
# Tests the full blocker lifecycle:
# - mark_agent_blocked
# - clear_agent_blocked
# - is_agent_blocked
# - get_blocker_* functions
# - detect_agent_blocker (pattern matching)
# - Discord notifications
#

set -e

# Setup test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="/tmp/starforge-blocker-test-$$"
CLAUDE_DIR="$TEST_DIR/.claude"
BLOCKERS_DIR="$CLAUDE_DIR/blockers"

# Create test directory structure
mkdir -p "$CLAUDE_DIR"/{blockers,logs}

# Set environment
export STARFORGE_CLAUDE_DIR="$CLAUDE_DIR"

# Source blocker library
source "$PROJECT_ROOT/templates/lib/blockers.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    echo "  ✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  ❌ FAIL: $message"
    echo "     Expected: $expected"
    echo "     Actual:   $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_true() {
  local condition="$1"
  local message="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$condition"; then
    echo "  ✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  ❌ FAIL: $message"
    echo "     Condition: $condition"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_false() {
  local condition="$1"
  local message="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! eval "$condition"; then
    echo "  ✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  ❌ FAIL: $message"
    echo "     Condition should be false: $condition"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file_exists() {
  local file="$1"
  local message="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -f "$file" ]; then
    echo "  ✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  ❌ FAIL: $message"
    echo "     File not found: $file"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_file_not_exists() {
  local file="$1"
  local message="$2"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ ! -f "$file" ]; then
    echo "  ✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  ❌ FAIL: $message"
    echo "     File exists: $file"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    echo "  ✅ PASS: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo "  ❌ FAIL: $message"
    echo "     Expected to contain: $needle"
    echo "     Actual: $haystack"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Mock Discord notification function (capture calls)
NOTIFIED_AGENTS=()
send_agent_blocked_notification() {
  local agent=$1
  local reason=$2
  local ticket=$3
  NOTIFIED_AGENTS+=("$agent:$reason:$ticket")
}
export -f send_agent_blocked_notification

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Suite
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🧪 Agent Blocker Integration Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 1: mark_agent_blocked creates blocker file
echo ""
echo "Test 1: mark_agent_blocked creates blocker file"
mark_agent_blocked "junior-dev-a" "Tests failing" "{\"test\":\"tests/test.sh\"}"
assert_file_exists "$BLOCKERS_DIR/junior-dev-a-blocked.json" "Blocker file created"

# Test 2: Blocker file contains correct JSON structure
echo ""
echo "Test 2: Blocker file contains correct JSON structure"
BLOCKER_JSON=$(cat "$BLOCKERS_DIR/junior-dev-a-blocked.json")
assert_contains "$BLOCKER_JSON" '"agent": "junior-dev-a"' "Agent field present"
assert_contains "$BLOCKER_JSON" '"status": "blocked"' "Status field present"
assert_contains "$BLOCKER_JSON" '"reason":' "Reason field present"
assert_contains "$BLOCKER_JSON" '"needs_human": true' "needs_human field present"
assert_contains "$BLOCKER_JSON" '"timestamp":' "Timestamp field present"

# Test 3: is_agent_blocked returns true for blocked agent
echo ""
echo "Test 3: is_agent_blocked returns true for blocked agent"
assert_true "is_agent_blocked junior-dev-a" "is_agent_blocked returns true"

# Test 4: is_agent_blocked returns false for non-blocked agent
echo ""
echo "Test 4: is_agent_blocked returns false for non-blocked agent"
assert_false "is_agent_blocked junior-dev-b" "is_agent_blocked returns false"

# Test 5: get_blocker_reason returns correct reason
echo ""
echo "Test 5: get_blocker_reason returns correct reason"
REASON=$(get_blocker_reason "junior-dev-a")
assert_equals "Tests failing" "$REASON" "Blocker reason retrieved"

# Test 6: get_blocker_timestamp returns valid timestamp
echo ""
echo "Test 6: get_blocker_timestamp returns valid timestamp"
TIMESTAMP=$(get_blocker_timestamp "junior-dev-a")
assert_contains "$TIMESTAMP" "T" "Timestamp in ISO 8601 format"

# Test 7: get_blocker_age returns human-readable age
echo ""
echo "Test 7: get_blocker_age returns human-readable age"
AGE=$(get_blocker_age "junior-dev-a")
assert_contains "$AGE" "ago" "Age format includes 'ago'"

# Test 8: list_blocked_agents returns blocked agent
echo ""
echo "Test 8: list_blocked_agents returns blocked agent"
BLOCKED_LIST=$(list_blocked_agents)
assert_contains "$BLOCKED_LIST" "junior-dev-a" "Blocked agent in list"

# Test 9: count_blocked_agents returns correct count
echo ""
echo "Test 9: count_blocked_agents returns correct count"
mark_agent_blocked "junior-dev-b" "Merge conflict" '{"file":"src/app.js"}'
COUNT=$(count_blocked_agents)
assert_equals "2" "$COUNT" "Blocker count is 2"

# Test 10: get_blocker_context returns context value
echo ""
echo "Test 10: get_blocker_context returns context value"
CONTEXT_VAL=$(get_blocker_context "junior-dev-a" "test")
assert_equals "tests/test.sh" "$CONTEXT_VAL" "Context value retrieved"

# Test 11: clear_agent_blocked removes blocker file
echo ""
echo "Test 11: clear_agent_blocked removes blocker file"
clear_agent_blocked "junior-dev-a"
assert_file_not_exists "$BLOCKERS_DIR/junior-dev-a-blocked.json" "Blocker file removed"
assert_false "is_agent_blocked junior-dev-a" "is_agent_blocked returns false after clear"

# Test 12: Discord notification sent when marking blocked
echo ""
echo "Test 12: Discord notification sent when marking blocked"
NOTIFIED_AGENTS=()  # Reset
mark_agent_blocked "qa-engineer" "Permission denied" '{"ticket":"42"}'
assert_equals "1" "${#NOTIFIED_AGENTS[@]}" "Notification sent"
assert_contains "${NOTIFIED_AGENTS[0]}" "qa-engineer" "Correct agent notified"

# Test 13: detect_agent_blocker detects test failures
echo ""
echo "Test 13: detect_agent_blocker detects test failures"
LOG_FILE="$CLAUDE_DIR/logs/test-agent.log"
echo "FAILED tests/integration/test.sh - AssertionError on line 45" > "$LOG_FILE"
detect_agent_blocker "test-agent" 1 "$LOG_FILE"
REASON=$(get_blocker_reason "test-agent")
assert_contains "$REASON" "Tests failing" "Test failure detected"

# Test 14: detect_agent_blocker detects permission errors
echo ""
echo "Test 14: detect_agent_blocker detects permission errors"
LOG_FILE="$CLAUDE_DIR/logs/perm-agent.log"
echo "bash: /usr/bin/script.sh: Permission denied" > "$LOG_FILE"
detect_agent_blocker "perm-agent" 1 "$LOG_FILE"
REASON=$(get_blocker_reason "perm-agent")
assert_contains "$REASON" "Permission error" "Permission error detected"

# Test 15: detect_agent_blocker detects merge conflicts
echo ""
echo "Test 15: detect_agent_blocker detects merge conflicts"
LOG_FILE="$CLAUDE_DIR/logs/merge-agent.log"
echo "CONFLICT (content): Merge conflict in src/app.js" > "$LOG_FILE"
detect_agent_blocker "merge-agent" 1 "$LOG_FILE"
REASON=$(get_blocker_reason "merge-agent")
assert_contains "$REASON" "Merge conflict" "Merge conflict detected"

# Test 16: detect_agent_blocker detects missing dependencies
echo ""
echo "Test 16: detect_agent_blocker detects missing dependencies"
LOG_FILE="$CLAUDE_DIR/logs/dep-agent.log"
echo "bash: jq: command not found" > "$LOG_FILE"
detect_agent_blocker "dep-agent" 1 "$LOG_FILE"
REASON=$(get_blocker_reason "dep-agent")
assert_contains "$REASON" "Missing dependency" "Missing dependency detected"

# Test 17: detect_agent_blocker detects network errors
echo ""
echo "Test 17: detect_agent_blocker detects network errors"
LOG_FILE="$CLAUDE_DIR/logs/net-agent.log"
echo "curl: (7) Failed to connect: Connection refused" > "$LOG_FILE"
detect_agent_blocker "net-agent" 1 "$LOG_FILE"
REASON=$(get_blocker_reason "net-agent")
assert_contains "$REASON" "Network error" "Network error detected"

# Test 18: detect_agent_blocker detects ambiguity
echo ""
echo "Test 18: detect_agent_blocker detects ambiguity"
LOG_FILE="$CLAUDE_DIR/logs/amb-agent.log"
echo "Ambiguous requirement: which database should I use?" > "$LOG_FILE"
detect_agent_blocker "amb-agent" 1 "$LOG_FILE"
REASON=$(get_blocker_reason "amb-agent")
assert_contains "$REASON" "Ambiguous" "Ambiguity detected"

# Test 19: detect_agent_blocker handles generic failures
echo ""
echo "Test 19: detect_agent_blocker handles generic failures"
LOG_FILE="$CLAUDE_DIR/logs/generic-agent.log"
echo "Some random error that doesn't match patterns" > "$LOG_FILE"
detect_agent_blocker "generic-agent" 42 "$LOG_FILE"
REASON=$(get_blocker_reason "generic-agent")
assert_contains "$REASON" "exit code 42" "Generic failure detected"

# Test 20: detect_agent_blocker doesn't mark success as blocker
echo ""
echo "Test 20: detect_agent_blocker doesn't mark success as blocker"
detect_agent_blocker "success-agent" 0 "$LOG_FILE"
assert_false "is_agent_blocked success-agent" "Success not marked as blocker"

# Test 21: JSON escaping in reason
echo ""
echo "Test 21: JSON escaping in reason"
mark_agent_blocked "escape-agent" 'Reason with "quotes" and special chars' '{}'
BLOCKER_JSON=$(cat "$BLOCKERS_DIR/escape-agent-blocked.json")
assert_true "jq empty \"$BLOCKERS_DIR/escape-agent-blocked.json\" 2>/dev/null" "JSON is valid despite special chars"

# Test 22: Long reason truncation
echo ""
echo "Test 22: Long reason truncation"
LONG_REASON="This is a very long reason that exceeds the maximum length and should be truncated to ensure it doesn't break the notification system or cause display issues in Discord or other interfaces. It just keeps going and going and going and going."
# Note: Truncation happens in send_agent_blocked_notification, not mark_agent_blocked
mark_agent_blocked "long-agent" "$LONG_REASON" '{}'
STORED_REASON=$(get_blocker_reason "long-agent")
# Stored reason should be full (truncation only for notifications)
assert_true "[ ${#STORED_REASON} -gt 200 ]" "Full reason stored in file"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Results
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Results:"
echo "  Total:  $TESTS_RUN"
echo "  Passed: $TESTS_PASSED"
echo "  Failed: $TESTS_FAILED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cleanup
rm -rf "$TEST_DIR"

# Exit with failure if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
fi

echo ""
echo "✅ All tests passed!"
exit 0
