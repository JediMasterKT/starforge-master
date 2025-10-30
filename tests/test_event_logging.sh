#!/bin/bash
# Test event logging system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing Event Logging System"
echo "=============================="

# Setup test environment
TEST_DIR="/tmp/starforge-event-test-$$"
mkdir -p "$TEST_DIR/.claude/events"
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"

# Test 1: Load library
echo "Test 1: Load event log library"
source "$PROJECT_ROOT/templates/lib/event-log.sh"
echo -e "${GREEN}✓ Library loaded${NC}"

# Test 2: Log simple event
echo "Test 2: Log simple event"
log_event "test-agent" "test_action" key1=value1 key2=value2
if [ -f "$TEST_DIR/.claude/events/$(date +%Y-%m-%d).jsonl" ]; then
  echo -e "${GREEN}✓ Event file created${NC}"
else
  echo -e "${RED}✗ Event file not created${NC}"
  exit 1
fi

# Test 3: Verify JSONL format
echo "Test 3: Verify JSONL format"
if jq empty "$TEST_DIR/.claude/events/$(date +%Y-%m-%d).jsonl" 2>/dev/null; then
  echo -e "${GREEN}✓ Valid JSON${NC}"
else
  echo -e "${RED}✗ Invalid JSON${NC}"
  exit 1
fi

# Test 4: Verify event structure
echo "Test 4: Verify event structure"
EVENT=$(cat "$TEST_DIR/.claude/events/$(date +%Y-%m-%d).jsonl" | head -1)
AGENT=$(echo "$EVENT" | jq -r '.agent')
ACTION=$(echo "$EVENT" | jq -r '.action')

if [ "$AGENT" = "test-agent" ] && [ "$ACTION" = "test_action" ]; then
  echo -e "${GREEN}✓ Event structure correct${NC}"
else
  echo -e "${RED}✗ Event structure incorrect${NC}"
  exit 1
fi

# Test 5: Log multiple events
echo "Test 5: Log multiple events"
log_event "agent1" "action1" ticket=42
log_event "agent2" "action2" ticket=43
EVENT_COUNT=$(cat "$TEST_DIR/.claude/events/$(date +%Y-%m-%d).jsonl" | wc -l | tr -d ' ')
if [ "$EVENT_COUNT" = "3" ]; then
  echo -e "${GREEN}✓ Multiple events logged${NC}"
else
  echo -e "${RED}✗ Expected 3 events, got $EVENT_COUNT${NC}"
  exit 1
fi

# Test 6: Verify context data
echo "Test 6: Verify context data"
EVENT=$(cat "$TEST_DIR/.claude/events/$(date +%Y-%m-%d).jsonl" | sed -n '2p')
TICKET=$(echo "$EVENT" | jq -r '.context.ticket')
if [ "$TICKET" = "42" ]; then
  echo -e "${GREEN}✓ Context data preserved${NC}"
else
  echo -e "${RED}✗ Context data incorrect: $TICKET${NC}"
  exit 1
fi

# Test 7: Verify timestamp format
echo "Test 7: Verify timestamp format"
TIMESTAMP=$(echo "$EVENT" | jq -r '.timestamp')
if [[ "$TIMESTAMP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]]; then
  echo -e "${GREEN}✓ Timestamp format correct${NC}"
else
  echo -e "${RED}✗ Timestamp format incorrect: $TIMESTAMP${NC}"
  exit 1
fi

# Cleanup
rm -rf "$TEST_DIR"

echo ""
echo -e "${GREEN}All event logging tests passed!${NC}"
