#!/bin/bash
#
# Integration test for stop hook error handling (Task 4.2)
#
# Tests that malformed triggers are handled gracefully in real-world scenario
# with actual .claude/triggers/ directory structure.
#

set -e

echo "=========================================="
echo "Integration Test: Stop Hook Error Handling"
echo "=========================================="

# Setup: Create test environment
TEST_DIR=$(mktemp -d)
echo "✓ Created test directory: $TEST_DIR"

cd "$TEST_DIR"

# Create .claude/triggers directory structure
mkdir -p .claude/triggers
mkdir -p logs

# Get path to stop hook
STOP_HOOK="$OLDPWD/templates/hooks/stop.py"

# Test 1: Missing command field
echo ""
echo "Test 1: Missing 'command' field"
echo "--------------------------------"

cat > .claude/triggers/test-missing-command.trigger << 'EOF'
{
  "from_agent": "test-agent",
  "to_agent": "qa-engineer",
  "message": "Test message"
}
EOF

# Run stop hook
echo '{"conversation_id": "test"}' | "$STOP_HOOK" 2> error.txt

# Verify error message
if ! grep -q "Malformed trigger" error.txt; then
  echo "❌ FAIL: Error message missing 'Malformed trigger'"
  cat error.txt
  exit 1
fi

if ! grep -q "command" error.txt; then
  echo "❌ FAIL: Error message doesn't mention 'command' field"
  cat error.txt
  exit 1
fi

if ! grep -q "Required fields" error.txt; then
  echo "❌ FAIL: Error message doesn't list required fields"
  cat error.txt
  exit 1
fi

# Verify trigger moved to failed/
if [ ! -d .claude/triggers/failed ]; then
  echo "❌ FAIL: failed/ directory not created"
  exit 1
fi

if [ ! -f .claude/triggers/failed/malformed-test-missing-command.trigger ]; then
  echo "❌ FAIL: Trigger not moved to failed/"
  ls -la .claude/triggers/failed/
  exit 1
fi

# Verify original trigger removed
if [ -f .claude/triggers/test-missing-command.trigger ]; then
  echo "❌ FAIL: Original trigger not removed"
  exit 1
fi

echo "✅ PASS: Missing 'command' field handled correctly"

# Test 2: Valid trigger (no regression)
echo ""
echo "Test 2: Valid trigger (no regression)"
echo "--------------------------------------"

cat > .claude/triggers/test-valid.trigger << 'EOF'
{
  "from_agent": "test-agent",
  "to_agent": "qa-engineer",
  "command": "Use qa-engineer. Review PR #123.",
  "message": "PR ready for review"
}
EOF

echo '{"conversation_id": "test2"}' | "$STOP_HOOK" 2> error2.txt

# Verify no error message
if grep -q "Malformed trigger" error2.txt; then
  echo "❌ FAIL: Valid trigger incorrectly flagged as malformed"
  cat error2.txt
  exit 1
fi

# Verify handoff notification
if ! grep -q "AGENT HANDOFF READY" error2.txt; then
  echo "❌ FAIL: Handoff notification not printed"
  cat error2.txt
  exit 1
fi

# Verify trigger moved to processed/ (not failed/)
if [ ! -d .claude/triggers/processed ]; then
  echo "❌ FAIL: processed/ directory not created"
  exit 1
fi

if [ ! -f .claude/triggers/processed/test-valid.trigger ]; then
  echo "❌ FAIL: Valid trigger not moved to processed/"
  ls -la .claude/triggers/processed/
  exit 1
fi

# Verify NOT in failed/
FAILED_COUNT=$(ls -1 .claude/triggers/failed/*.trigger 2>/dev/null | wc -l)
if [ "$FAILED_COUNT" -ne 1 ]; then
  echo "❌ FAIL: Unexpected files in failed/ directory"
  ls -la .claude/triggers/failed/
  exit 1
fi

echo "✅ PASS: Valid trigger processed correctly (no regression)"

# Test 3: Multiple malformed triggers
echo ""
echo "Test 3: Multiple malformed triggers"
echo "------------------------------------"

cat > .claude/triggers/test-missing-message.trigger << 'EOF'
{
  "from_agent": "test-agent",
  "to_agent": "qa-engineer",
  "command": "Use qa-engineer. Review PR."
}
EOF

cat > .claude/triggers/test-missing-to-agent.trigger << 'EOF'
{
  "from_agent": "test-agent",
  "command": "Use qa-engineer. Review PR.",
  "message": "Test message"
}
EOF

# Process first trigger
echo '{"conversation_id": "test3a"}' | "$STOP_HOOK" 2> /dev/null

# Process second trigger
echo '{"conversation_id": "test3b"}' | "$STOP_HOOK" 2> /dev/null

# Verify both moved to failed/
FAILED_COUNT=$(ls -1 .claude/triggers/failed/*.trigger 2>/dev/null | wc -l)
if [ "$FAILED_COUNT" -ne 3 ]; then
  echo "❌ FAIL: Expected 3 malformed triggers in failed/"
  ls -la .claude/triggers/failed/
  exit 1
fi

echo "✅ PASS: Multiple malformed triggers handled correctly"

# Cleanup
cd - > /dev/null
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "✅ All integration tests PASSED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Missing fields detected and clearly reported"
echo "  - Malformed triggers moved to failed/ directory"
echo "  - Valid triggers still work correctly"
echo "  - Multiple malformed triggers handled sequentially"
echo ""
