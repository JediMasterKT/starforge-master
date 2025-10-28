#!/bin/bash
# Integration test for stop hook compatibility with trigger format
#
# Verifies that triggers created by starforge_create_trigger can be
# processed by the stop hook without errors.

set -e

TEST_DIR=$(mktemp -d)
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
export STARFORGE_AGENT_ID="test-agent"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers/processed"

# Source the trigger creation library
source "/Users/krunaaltavkar/starforge-master/templates/lib/mcp-tools-trigger.sh"

echo "=========================================="
echo "TEST: Stop Hook Compatibility"
echo "=========================================="
echo ""

# Test 1: Create trigger
echo "Test 1: Create trigger"
result=$(starforge_create_trigger "qa-engineer" "review_pr" '{"pr": 42, "ticket": 100}')
trigger_file=$(echo "$result" | jq -r '.trigger_file')
echo "Created: $trigger_file"
echo ""

# Test 2: Verify trigger has all required fields
echo "Test 2: Verify required fields for stop hook"
required_fields=("from_agent" "to_agent" "action" "command" "message" "timestamp" "context")

for field in "${required_fields[@]}"; do
  value=$(jq -r ".$field" "$trigger_file")

  if [ "$value" = "null" ] || [ -z "$value" ]; then
    echo "FAIL: Field '$field' is missing or null"
    exit 1
  fi

  echo "  $field: $value"
done

echo ""
echo "PASS: All required fields present"
echo ""

# Test 3: Simulate what stop hook does
echo "Test 3: Simulate stop hook processing"

# Extract fields like stop hook does (lines 148-149 of stop.py)
from_agent=$(jq -r '.from_agent' "$trigger_file")
to_agent=$(jq -r '.to_agent' "$trigger_file")
command=$(jq -r '.command' "$trigger_file")
message=$(jq -r '.message' "$trigger_file")

# Verify all fields extracted successfully (no KeyError)
if [ -z "$from_agent" ] || [ -z "$to_agent" ] || [ -z "$command" ] || [ -z "$message" ]; then
  echo "FAIL: Stop hook would fail to extract fields"
  exit 1
fi

echo "Stop hook would process:"
echo "  from_agent: $from_agent"
echo "  to_agent: $to_agent"
echo "  command: $command"
echo "  message: $message"
echo ""
echo "PASS: Stop hook can process trigger without errors"
echo ""

# Test 4: Verify command format for human consumption
echo "Test 4: Verify command format for human notification"

if [[ ! "$command" =~ ^Use\ [a-z-]+\..* ]]; then
  echo "FAIL: command format not suitable for human notification"
  echo "  Got: $command"
  exit 1
fi

echo "  Command: $command"
echo "PASS: Command format suitable for human notification"
echo ""

# Test 5: Verify message is human-readable
echo "Test 5: Verify message is human-readable"

if [ ${#message} -lt 3 ]; then
  echo "FAIL: message too short to be meaningful"
  echo "  Got: $message"
  exit 1
fi

echo "  Message: $message"
echo "PASS: Message is human-readable"
echo ""

# Cleanup
rm -rf "$TEST_DIR"

echo "=========================================="
echo "ALL COMPATIBILITY TESTS PASSED"
echo "=========================================="
echo ""
echo "Trigger format is compatible with stop hook:"
echo "  - All required fields present"
echo "  - No KeyError will occur"
echo "  - Human-readable notifications possible"
echo "  - Ready for daemon and manual modes"
