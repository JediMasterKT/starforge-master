#!/usr/bin/env bash
# Integration Test: Atomic Trigger Creation
# Tests the .pending → .trigger atomic rename pattern

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the library
source "$PROJECT_ROOT/templates/lib/atomic-triggers.sh"

# Test setup
TEST_DIR=$(mktemp -d)
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers/staging"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "═══════════════════════════════════════════════════════"
echo "Test 1: Basic Atomic Trigger Creation"
echo "═══════════════════════════════════════════════════════"

TRIGGER_JSON='{"from": "test", "to": "agent", "action": "test"}'
TRIGGER_FILENAME="test-trigger-$(date +%s)"

# Create trigger
create_trigger_atomic "$TRIGGER_JSON" "$TRIGGER_FILENAME"

# Verify .trigger file exists
if [ ! -f "$STARFORGE_CLAUDE_DIR/triggers/${TRIGGER_FILENAME}.trigger" ]; then
  echo "❌ FAIL: .trigger file was not created"
  exit 1
fi

# Verify .pending file does NOT exist (should be renamed)
if [ -f "$STARFORGE_CLAUDE_DIR/triggers/staging/${TRIGGER_FILENAME}.pending" ]; then
  echo "❌ FAIL: .pending file still exists (not renamed)"
  exit 1
fi

# Verify content is correct
CONTENT=$(cat "$STARFORGE_CLAUDE_DIR/triggers/${TRIGGER_FILENAME}.trigger")
if [ "$CONTENT" != "$TRIGGER_JSON" ]; then
  echo "❌ FAIL: Trigger content doesn't match"
  exit 1
fi

echo "✅ PASS: Basic atomic trigger creation works"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 2: Concurrent Trigger Creation (Race Condition)"
echo "═══════════════════════════════════════════════════════"

# Create 5 triggers concurrently
PIDS=()
for i in {1..5}; do
  (
    TRIGGER_JSON='{"from": "test", "to": "agent", "action": "concurrent_test", "id": "'$i'"}'
    TRIGGER_FILENAME="concurrent-test-$i-$(date +%s)"
    create_trigger_atomic "$TRIGGER_JSON" "$TRIGGER_FILENAME" > /dev/null 2>&1
  ) &
  PIDS+=($!)
done

# Wait for all to complete
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

# Verify all 5 triggers were created
TRIGGER_COUNT=$(find "$STARFORGE_CLAUDE_DIR/triggers" -name "concurrent-test-*.trigger" | wc -l | tr -d ' ')
if [ "$TRIGGER_COUNT" -ne 5 ]; then
  echo "❌ FAIL: Expected 5 triggers, found $TRIGGER_COUNT"
  exit 1
fi

# Verify no .pending files remain
PENDING_COUNT=$(find "$STARFORGE_CLAUDE_DIR/triggers/staging" -name "*.pending" | wc -l | tr -d ' ')
if [ "$PENDING_COUNT" -ne 0 ]; then
  echo "❌ FAIL: Found $PENDING_COUNT orphaned .pending files"
  exit 1
fi

echo "✅ PASS: Concurrent trigger creation works without race conditions"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 3: STARFORGE_CLAUDE_DIR Override"
echo "═══════════════════════════════════════════════════════"

# Create alternate directory
ALT_DIR=$(mktemp -d)
export STARFORGE_CLAUDE_DIR="$ALT_DIR"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers/staging"

TRIGGER_JSON='{"test": "alternate_dir"}'
TRIGGER_FILENAME="alt-dir-test-$(date +%s)"

create_trigger_atomic "$TRIGGER_JSON" "$TRIGGER_FILENAME"

# Verify trigger was created in alternate directory
if [ ! -f "$ALT_DIR/triggers/${TRIGGER_FILENAME}.trigger" ]; then
  echo "❌ FAIL: Trigger not created in alternate directory"
  rm -rf "$ALT_DIR"
  exit 1
fi

rm -rf "$ALT_DIR"
echo "✅ PASS: STARFORGE_CLAUDE_DIR override works"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ All atomic trigger creation tests passed!"
echo "═══════════════════════════════════════════════════════"
