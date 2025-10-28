#!/bin/bash
# Integration test for trigger creation format
#
# Verifies that triggers include required 'command' and 'message' fields
# for compatibility with stop hook.

set -e

# Setup test environment
TEST_DIR=$(mktemp -d)
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
export STARFORGE_AGENT_ID="test-agent"
export STARFORGE_PROJECT_NAME="test-project"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"

# Source the trigger creation library
SOURCE_FILE="/Users/krunaaltavkar/starforge-master/templates/lib/mcp-tools-trigger.sh"
if [ ! -f "$SOURCE_FILE" ]; then
  echo "ERROR: Source file not found: $SOURCE_FILE"
  exit 1
fi

source "$SOURCE_FILE"

echo "=========================================="
echo "TEST: Trigger Creation Format"
echo "=========================================="
echo ""

# Test 1: Create trigger with starforge_create_trigger function
echo "Test 1: Create trigger using starforge_create_trigger"
RESULT=$(starforge_create_trigger "qa-engineer" "review_pr" '{"pr": 42, "ticket": 100}')

if [ $? -ne 0 ]; then
  echo "FAIL: starforge_create_trigger returned error"
  exit 1
fi

TRIGGER_FILE=$(echo "$RESULT" | jq -r '.trigger_file')

if [ ! -f "$TRIGGER_FILE" ]; then
  echo "FAIL: Trigger file not created: $TRIGGER_FILE"
  exit 1
fi

echo "Created trigger: $TRIGGER_FILE"
echo ""

# Test 2: Verify trigger is valid JSON
echo "Test 2: Verify trigger is valid JSON"
if ! jq empty "$TRIGGER_FILE" 2>/dev/null; then
  echo "FAIL: Trigger is not valid JSON"
  cat "$TRIGGER_FILE"
  exit 1
fi
echo "PASS: Trigger is valid JSON"
echo ""

# Test 3: Verify required fields exist
echo "Test 3: Verify required fields exist"
FIELDS_TO_CHECK=("from_agent" "to_agent" "action" "timestamp" "context" "command" "message")

for field in "${FIELDS_TO_CHECK[@]}"; do
  VALUE=$(jq -r ".$field" "$TRIGGER_FILE")

  if [ "$VALUE" = "null" ] || [ -z "$VALUE" ]; then
    echo "FAIL: Field '$field' is missing or null"
    echo "Trigger contents:"
    jq . "$TRIGGER_FILE"
    exit 1
  fi

  echo "  $field: $VALUE"
done

echo "PASS: All required fields present"
echo ""

# Test 4: Verify field values are non-empty strings
echo "Test 4: Verify field values are non-empty strings"
COMMAND=$(jq -r '.command' "$TRIGGER_FILE")
MESSAGE=$(jq -r '.message' "$TRIGGER_FILE")

if [ -z "$COMMAND" ]; then
  echo "FAIL: command field is empty"
  exit 1
fi

if [ -z "$MESSAGE" ]; then
  echo "FAIL: message field is empty"
  exit 1
fi

echo "  command: $COMMAND"
echo "  message: $MESSAGE"
echo "PASS: command and message are non-empty"
echo ""

# Test 5: Verify command format matches stop hook expectations
echo "Test 5: Verify command format"
# Command should be like "Use qa-engineer. Review Pr."
# (auto-generated from action "review_pr")
EXPECTED_MESSAGE="Review Pr"  # action "review_pr" → "Review Pr"
EXPECTED_COMMAND="Use qa-engineer. ${EXPECTED_MESSAGE}."

if [ "$COMMAND" != "$EXPECTED_COMMAND" ]; then
  echo "FAIL: command does not match expected auto-generated format"
  echo "  Expected: $EXPECTED_COMMAND"
  echo "  Got: $COMMAND"
  exit 1
fi
echo "PASS: command format correct (auto-generated from action)"
echo ""

# Test 6: Verify message is human-readable
echo "Test 6: Verify message is human-readable"
# Message should be a brief description of the handoff
if [ ${#MESSAGE} -lt 5 ]; then
  echo "FAIL: message too short to be meaningful"
  echo "  Got: $MESSAGE"
  exit 1
fi
echo "PASS: message is meaningful"
echo ""

# Test 7: Test compatibility with stop hook
echo "Test 7: Test compatibility with stop hook"
# Simulate what stop hook does (parse required fields)
FROM_AGENT=$(jq -r '.from_agent' "$TRIGGER_FILE")
TO_AGENT=$(jq -r '.to_agent' "$TRIGGER_FILE")
COMMAND=$(jq -r '.command' "$TRIGGER_FILE")
MESSAGE=$(jq -r '.message' "$TRIGGER_FILE")

if [ "$FROM_AGENT" != "test-agent" ]; then
  echo "FAIL: from_agent incorrect (expected: test-agent, got: $FROM_AGENT)"
  exit 1
fi

if [ "$TO_AGENT" != "qa-engineer" ]; then
  echo "FAIL: to_agent incorrect (expected: qa-engineer, got: $TO_AGENT)"
  exit 1
fi

echo "PASS: Trigger compatible with stop hook"
echo ""

# Cleanup
rm -rf "$TEST_DIR"

echo "=========================================="
echo "ALL TESTS PASSED"
echo "=========================================="
echo ""
echo "Trigger format validation complete:"
echo "  - Valid JSON"
echo "  - All required fields present"
echo "  - command and message fields included"
echo "  - Compatible with stop hook expectations"
