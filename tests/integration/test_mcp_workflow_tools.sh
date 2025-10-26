#!/bin/bash
# Integration test for MCP workflow tools
# Tests consolidated workflow operations that reduce multi-step coordination

set -e

TEST_NAME="MCP Workflow Tools Integration Test"
echo "========================================="
echo "$TEST_NAME"
echo "========================================="
echo ""

# Setup: Use real repository structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT
export STARFORGE_CLAUDE_DIR="$PROJECT_ROOT/.claude"
export STARFORGE_AGENT_ID="test-orchestrator"
export STARFORGE_SCRIPTS_DIR="$PROJECT_ROOT/templates/scripts"

# Create test environment
TEST_TRIGGER_DIR="$STARFORGE_CLAUDE_DIR/triggers"
TEST_COORDINATION_DIR="$STARFORGE_CLAUDE_DIR/coordination"
mkdir -p "$TEST_TRIGGER_DIR"
mkdir -p "$TEST_COORDINATION_DIR"

# Mock gh command for testing
gh() {
    case "$1" in
        issue)
            case "$2" in
                view)
                    # Mock ticket data
                    local ticket="$3"
                    if [ "$ticket" = "42" ]; then
                        echo '{"labels": [{"name": "ready"}, {"name": "P1"}]}'
                    elif [ "$ticket" = "99" ]; then
                        echo '{"labels": [{"name": "in-progress"}]}'
                    else
                        echo '{"labels": []}'
                    fi
                    ;;
                edit)
                    # Mock successful assignment
                    return 0
                    ;;
            esac
            ;;
        api)
            # Mock user API call
            echo '{"login": "test-user"}'
            ;;
    esac
}
export -f gh

# Mock create_trigger.py script
mkdir -p "$STARFORGE_SCRIPTS_DIR"
cat > "$STARFORGE_SCRIPTS_DIR/create_trigger.py" << 'EOFPY'
#!/usr/bin/env python3
import sys
import json
import argparse
from datetime import datetime

parser = argparse.ArgumentParser()
parser.add_argument('--from-agent', required=True)
parser.add_argument('--to-agent', required=True)
parser.add_argument('--action', required=True)
parser.add_argument('--ticket', required=True)
args = parser.parse_args()

# Create trigger file
trigger_id = f"{args.to_agent}-{args.action}-{int(datetime.now().timestamp() * 1000000)}"
trigger_file = f".claude/triggers/{trigger_id}.trigger"

trigger_data = {
    "from_agent": args.from_agent,
    "to_agent": args.to_agent,
    "action": args.action,
    "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "context": {"ticket": args.ticket}
}

with open(trigger_file, 'w') as f:
    json.dump(trigger_data, f)

print(json.dumps({"trigger_file": trigger_file, "trigger_id": trigger_id}))
EOFPY
chmod +x "$STARFORGE_SCRIPTS_DIR/create_trigger.py"

# Source the workflow tools module
source "$PROJECT_ROOT/templates/lib/mcp-tools-workflow.sh"

# Test 1: Assign action - happy path
echo "Test 1: starforge_manage_ticket - assign action (happy path)"
params='{"ticket": "42", "action": "assign", "agent": "junior-dev-a"}'
result=$(handle_manage_ticket "$params")
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "❌ FAIL: handle_manage_ticket returned error"
    echo "   Exit code: $exit_code"
    echo "   Output: $result"
    exit 1
fi

# Verify success message contains expected text
if ! echo "$result" | grep -q "assigned to junior-dev-a"; then
    echo "❌ FAIL: Response should mention 'assigned to junior-dev-a'"
    echo "   Output: $result"
    exit 1
fi

if ! echo "$result" | grep -q "Trigger created"; then
    echo "❌ FAIL: Response should mention 'Trigger created'"
    echo "   Output: $result"
    exit 1
fi

# Verify trigger file was created
trigger_count=$(ls -1 "$TEST_TRIGGER_DIR"/*.trigger 2>/dev/null | wc -l)
if [ "$trigger_count" -eq 0 ]; then
    echo "❌ FAIL: No trigger file created"
    exit 1
fi

echo "✅ PASS: Assign action completed successfully"
echo ""

# Cleanup for next test
rm -f "$TEST_TRIGGER_DIR"/*.trigger

# Test 2: Assign action - ticket not ready
echo "Test 2: starforge_manage_ticket - assign action (ticket not ready)"
set +e
params='{"ticket": "99", "action": "assign", "agent": "junior-dev-a"}'
result=$(handle_manage_ticket "$params" 2>&1)
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "❌ FAIL: Should return error when ticket not ready"
    exit 1
fi

if ! echo "$result" | grep -iq "not ready"; then
    echo "❌ FAIL: Error should mention 'not ready'"
    echo "   Output: $result"
    exit 1
fi

if ! echo "$result" | grep -iq "Use TPM"; then
    echo "❌ FAIL: Error should suggest using TPM"
    echo "   Output: $result"
    exit 1
fi

echo "✅ PASS: Validates ticket is ready"
echo ""

# Test 3: Assign action - agent not available
echo "Test 3: starforge_manage_ticket - assign action (agent busy)"

# Create a trigger file to make junior-dev-b appear busy
cat > "$TEST_TRIGGER_DIR/junior-dev-b-implement_ticket-12345.trigger" << 'EOF'
{
  "from_agent": "orchestrator",
  "to_agent": "junior-dev-b",
  "action": "implement_ticket",
  "timestamp": "2024-01-01T00:00:00Z",
  "context": {"ticket": "999"}
}
EOF

set +e
params='{"ticket": "42", "action": "assign", "agent": "junior-dev-b"}'
result=$(handle_manage_ticket "$params" 2>&1)
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "❌ FAIL: Should return error when agent busy"
    exit 1
fi

if ! echo "$result" | grep -iq "not available"; then
    echo "❌ FAIL: Error should mention 'not available'"
    echo "   Output: $result"
    exit 1
fi

if ! echo "$result" | grep -iq "Status: busy"; then
    echo "❌ FAIL: Error should show agent status"
    echo "   Output: $result"
    exit 1
fi

# Cleanup trigger
rm -f "$TEST_TRIGGER_DIR/junior-dev-b-implement_ticket-12345.trigger"

echo "✅ PASS: Validates agent availability"
echo ""

# Test 4: Check status action
echo "Test 4: starforge_manage_ticket - check_status action"

# Mock gh issue view for check_status
gh() {
    case "$1" in
        issue)
            case "$2" in
                view)
                    if [ "$3" = "42" ]; then
                        cat << 'EOF'
{
  "number": 42,
  "title": "Test ticket",
  "state": "OPEN",
  "labels": [{"name": "ready"}, {"name": "P1"}],
  "assignees": [{"login": "junior-dev-a"}],
  "comments": [
    {"body": "First comment"},
    {"body": "Latest comment"}
  ]
}
EOF
                    fi
                    ;;
            esac
            ;;
    esac
}
export -f gh

params='{"ticket": "42", "action": "check_status"}'
result=$(handle_manage_ticket "$params")
exit_code=$?

if [ $exit_code -ne 0 ]; then
    echo "❌ FAIL: check_status returned error"
    echo "   Exit code: $exit_code"
    echo "   Output: $result"
    exit 1
fi

# Verify JSON structure
if ! echo "$result" | jq -e '.ticket' > /dev/null 2>&1; then
    echo "❌ FAIL: Response should contain ticket number"
    echo "   Output: $result"
    exit 1
fi

if ! echo "$result" | jq -e '.assigned_to' > /dev/null 2>&1; then
    echo "❌ FAIL: Response should contain assigned_to"
    echo "   Output: $result"
    exit 1
fi

# Verify values
ticket=$(echo "$result" | jq -r '.ticket')
if [ "$ticket" != "42" ]; then
    echo "❌ FAIL: Incorrect ticket number"
    echo "   Expected: 42, Got: $ticket"
    exit 1
fi

echo "✅ PASS: Check status action works correctly"
echo ""

# Test 5: Invalid action
echo "Test 5: starforge_manage_ticket - invalid action"
set +e
params='{"ticket": "42", "action": "invalid_action"}'
result=$(handle_manage_ticket "$params" 2>&1)
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
    echo "❌ FAIL: Should return error for invalid action"
    exit 1
fi

if ! echo "$result" | grep -iq "Invalid action"; then
    echo "❌ FAIL: Error should mention 'Invalid action'"
    echo "   Output: $result"
    exit 1
fi

if ! echo "$result" | grep -iq "Valid.*assign.*check_status"; then
    echo "❌ FAIL: Error should list valid actions"
    echo "   Output: $result"
    exit 1
fi

echo "✅ PASS: Validates action parameter"
echo ""

# Test 6: Workflow reduces coordination steps
echo "Test 6: Workflow consolidation verification"
# Without workflow: 4 separate calls needed
# - Check ticket labels (gh issue view)
# - Check agent availability
# - Assign ticket (gh issue edit)
# - Create trigger
# With workflow: 1 call to handle_manage_ticket

params='{"ticket": "42", "action": "assign", "agent": "junior-dev-a"}'
result=$(handle_manage_ticket "$params")

# Verify all steps completed in single call
if [ $? -ne 0 ]; then
    echo "❌ FAIL: Workflow should complete all steps"
    exit 1
fi

# Verify trigger created (final step)
trigger_count=$(ls -1 "$TEST_TRIGGER_DIR"/*.trigger 2>/dev/null | wc -l)
if [ "$trigger_count" -eq 0 ]; then
    echo "❌ FAIL: Workflow should create trigger (final step)"
    exit 1
fi

echo "✅ PASS: Workflow consolidates 4 steps into 1 call"
echo ""

# Cleanup
rm -f "$TEST_TRIGGER_DIR"/*.trigger
rm -rf "$STARFORGE_CLAUDE_DIR"
rm -f "$STARFORGE_SCRIPTS_DIR/create_trigger.py"

# Summary
echo "========================================="
echo "✅ ALL WORKFLOW INTEGRATION TESTS PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Assign happy path: ✅"
echo "  - Ticket ready validation: ✅"
echo "  - Agent availability check: ✅"
echo "  - Check status action: ✅"
echo "  - Invalid action handling: ✅"
echo "  - Multi-step consolidation: ✅"
