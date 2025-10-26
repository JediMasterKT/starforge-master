#!/usr/bin/env bash
#
# Integration tests for Discord Agent Blocked notifications
#
# Tests notify_agent_blocked() function with @mention support
#

set -e

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper: Assert equals
assert_equals() {
  local expected=$1
  local actual=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Expected: $expected"
    echo "  Got: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Assert contains
assert_contains() {
  local haystack=$1
  local needle=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Expected to find: $needle"
    echo "  In: $haystack"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Assert not contains
assert_not_contains() {
  local haystack=$1
  local needle=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! echo "$haystack" | grep -q "$needle"; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Should NOT contain: $needle"
    echo "  But found in: $haystack"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Notification without user ID (no @mention)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_notify_agent_blocked_no_mention() {
  echo ""
  echo -e "${YELLOW}Test 1: Notification without DISCORD_USER_ID (no @mention)${NC}"

  # Unset user ID
  unset DISCORD_USER_ID

  # Load discord-notify.sh first to get COLOR_WARNING
  source templates/lib/discord-notify.sh

  # Mock send_discord_daemon_notification AFTER loading discord-notify.sh
  send_discord_daemon_notification() {
    echo "$1" > /tmp/test-blocked-agent.txt
    echo "$2" > /tmp/test-blocked-title.txt
    echo "$3" > /tmp/test-blocked-description.txt
    echo "$4" > /tmp/test-blocked-color.txt
    echo "$5" > /tmp/test-blocked-fields.txt
  }
  export -f send_discord_daemon_notification

  # Load router.sh (should have notify_agent_blocked function)
  source templates/lib/router.sh

  # Call notify_agent_blocked
  notify_agent_blocked "junior-dev-a" "Should I use REST or GraphQL?" "42"

  # Verify description does NOT contain @mention
  local description=$(cat /tmp/test-blocked-description.txt)
  assert_not_contains "$description" "<@" "Should not include @mention if DISCORD_USER_ID not set"

  # Verify question is in description
  assert_contains "$description" "Should I use REST or GraphQL?" "Should include question in description"

  # Clean up
  rm -f /tmp/test-blocked-*.txt
  unset -f send_discord_daemon_notification
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Notification with user ID (has @mention)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_notify_agent_blocked_with_mention() {
  echo ""
  echo -e "${YELLOW}Test 2: Notification with DISCORD_USER_ID (@mention enabled)${NC}"

  # Set user ID
  export DISCORD_USER_ID="123456789012345678"

  # Load discord-notify.sh first
  source templates/lib/discord-notify.sh

  # Mock send_discord_daemon_notification AFTER loading discord-notify.sh
  send_discord_daemon_notification() {
    echo "$3" > /tmp/test-blocked-mention-description.txt
  }
  export -f send_discord_daemon_notification

  # Load router.sh
  source templates/lib/router.sh

  # Call notify_agent_blocked
  notify_agent_blocked "junior-dev-a" "Should I use REST or GraphQL?" "42"

  # Verify description contains @mention
  local description=$(cat /tmp/test-blocked-mention-description.txt)
  assert_contains "$description" "<@123456789012345678>" "Should include @mention if DISCORD_USER_ID set"

  # Clean up
  rm -f /tmp/test-blocked-mention-*.txt
  unset -f send_discord_daemon_notification
  unset DISCORD_USER_ID
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Long question truncation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_notify_agent_blocked_long_question() {
  echo ""
  echo -e "${YELLOW}Test 3: Long question truncation (200 char limit)${NC}"

  # Create 500 character question
  local long_question=$(python3 -c "print('Q' * 500)")

  # Load discord-notify.sh first
  source templates/lib/discord-notify.sh

  # Mock send_discord_daemon_notification AFTER loading discord-notify.sh
  send_discord_daemon_notification() {
    echo "$5" > /tmp/test-blocked-fields.txt
  }
  export -f send_discord_daemon_notification

  # Load router.sh
  source templates/lib/router.sh

  # Call notify_agent_blocked
  notify_agent_blocked "junior-dev-a" "$long_question" "42"

  # Verify fields contain truncated question
  local fields=$(cat /tmp/test-blocked-fields.txt)

  # Extract question value from JSON
  local question_value=$(echo "$fields" | python3 -c "import sys, json; fields=json.load(sys.stdin); print([f['value'] for f in fields if f['name']=='Question'][0])")

  local length=${#question_value}

  # Should be truncated to ~200 chars (plus "...")
  if [ $length -lt 250 ]; then
    echo -e "${GREEN}✓${NC} Question truncated to $length chars (< 250)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Question not truncated (still $length chars)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))

  # Clean up
  rm -f /tmp/test-blocked-fields.txt
  unset -f send_discord_daemon_notification
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Verify color is warning (yellow)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_notify_agent_blocked_warning_color() {
  echo ""
  echo -e "${YELLOW}Test 4: Uses COLOR_WARNING (yellow)${NC}"

  # Load discord-notify.sh to get COLOR_WARNING constant
  source templates/lib/discord-notify.sh

  # Mock send_discord_daemon_notification AFTER loading constants
  send_discord_daemon_notification() {
    echo "$4" > /tmp/test-blocked-color.txt
  }
  export -f send_discord_daemon_notification

  # Load router.sh
  source templates/lib/router.sh

  # Call notify_agent_blocked
  notify_agent_blocked "junior-dev-a" "Need help" "42"

  # Verify color is COLOR_WARNING (16776960)
  local color=$(cat /tmp/test-blocked-color.txt)
  assert_equals "16776960" "$color" "Should use COLOR_WARNING (yellow)"

  # Clean up
  rm -f /tmp/test-blocked-color.txt
  unset -f send_discord_daemon_notification
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Verify fields include Question, Ticket, Action
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_notify_agent_blocked_fields() {
  echo ""
  echo -e "${YELLOW}Test 5: Fields include Question, Ticket, Action${NC}"

  # Load discord-notify.sh first
  source templates/lib/discord-notify.sh

  # Mock send_discord_daemon_notification AFTER loading discord-notify.sh
  send_discord_daemon_notification() {
    echo "$5" > /tmp/test-blocked-fields.txt
  }
  export -f send_discord_daemon_notification

  # Load router.sh
  source templates/lib/router.sh

  # Call notify_agent_blocked
  notify_agent_blocked "junior-dev-a" "Which library?" "42"

  # Verify fields contain required keys
  local fields=$(cat /tmp/test-blocked-fields.txt)

  assert_contains "$fields" '"name":"Question"' "Should have Question field"
  assert_contains "$fields" '"name":"Ticket"' "Should have Ticket field"
  assert_contains "$fields" '"name":"Action"' "Should have Action field"

  assert_contains "$fields" '"value":"Which library?"' "Question field should have correct value"
  assert_contains "$fields" '"value":"#42"' "Ticket field should have correct value"

  # Clean up
  rm -f /tmp/test-blocked-fields.txt
  unset -f send_discord_daemon_notification
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Function is exported
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
test_notify_agent_blocked_exported() {
  echo ""
  echo -e "${YELLOW}Test 6: Function is exported${NC}"

  # Load router.sh
  source templates/lib/router.sh

  # Check if function exists
  if type notify_agent_blocked > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} notify_agent_blocked function exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} notify_agent_blocked function NOT found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run All Tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "========================================="
echo "Discord Agent Blocked Notification Tests"
echo "========================================="

test_notify_agent_blocked_no_mention
test_notify_agent_blocked_with_mention
test_notify_agent_blocked_long_question
test_notify_agent_blocked_warning_color
test_notify_agent_blocked_fields
test_notify_agent_blocked_exported

echo ""
echo "========================================="
echo "Test Results"
echo "========================================="
echo -e "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
  echo ""
  echo -e "${GREEN}✅ All tests passed!${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}❌ Some tests failed${NC}"
  exit 1
fi
