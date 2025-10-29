#!/usr/bin/env bash
# Integration Test: Atomic Trigger Claim
# Tests the .trigger → .processing atomic claim mechanism

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the library
source "$PROJECT_ROOT/templates/lib/atomic-triggers.sh"

# Test setup
TEST_DIR=$(mktemp -d)
export STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "═══════════════════════════════════════════════════════"
echo "Test 1: Basic Trigger Claim"
echo "═══════════════════════════════════════════════════════"

# Create a .trigger file manually
TRIGGER_FILE="$STARFORGE_CLAUDE_DIR/triggers/test-claim.trigger"
echo '{"test": "claim"}' > "$TRIGGER_FILE"

# Claim it
claim_trigger_for_processing "$TRIGGER_FILE"

# Verify .processing file exists
if [ ! -f "$STARFORGE_CLAUDE_DIR/triggers/test-claim.processing" ]; then
  echo "❌ FAIL: .processing file was not created"
  exit 1
fi

# Verify .trigger file no longer exists
if [ -f "$TRIGGER_FILE" ]; then
  echo "❌ FAIL: .trigger file still exists after claim"
  exit 1
fi

# Verify PROCESSING_FILE_PATH was set
if [ -z "$PROCESSING_FILE_PATH" ]; then
  echo "❌ FAIL: PROCESSING_FILE_PATH not set"
  exit 1
fi

echo "✅ PASS: Basic trigger claim works"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 2: Concurrent Claim Attempt (Race Condition)"
echo "═══════════════════════════════════════════════════════"

# Create a trigger
TRIGGER_FILE="$STARFORGE_CLAUDE_DIR/triggers/race-test.trigger"
echo '{"test": "race"}' > "$TRIGGER_FILE"

# Launch 5 concurrent claim attempts
SUCCESS_COUNT=0
PIDS=()
RESULTS_DIR=$(mktemp -d)

for i in {1..5}; do
  (
    if claim_trigger_for_processing "$TRIGGER_FILE" 2>/dev/null; then
      echo "SUCCESS" > "$RESULTS_DIR/result-$i"
    else
      echo "FAIL" > "$RESULTS_DIR/result-$i"
    fi
  ) &
  PIDS+=($!)
done

# Wait for all to complete
for pid in "${PIDS[@]}"; do
  wait "$pid" || true
done

# Count successes
SUCCESS_COUNT=$(grep -l "SUCCESS" "$RESULTS_DIR"/result-* 2>/dev/null | wc -l | tr -d ' ')

if [ "$SUCCESS_COUNT" -ne 1 ]; then
  echo "❌ FAIL: Expected exactly 1 successful claim, got $SUCCESS_COUNT"
  rm -rf "$RESULTS_DIR"
  exit 1
fi

# Verify only .processing exists (not .trigger)
if [ -f "$TRIGGER_FILE" ]; then
  echo "❌ FAIL: Original .trigger file still exists"
  rm -rf "$RESULTS_DIR"
  exit 1
fi

if [ ! -f "$STARFORGE_CLAUDE_DIR/triggers/race-test.processing" ]; then
  echo "❌ FAIL: .processing file doesn't exist"
  rm -rf "$RESULTS_DIR"
  exit 1
fi

rm -rf "$RESULTS_DIR"
echo "✅ PASS: Only one daemon won the race (atomic claim works)"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 3: Claim Non-Existent Trigger"
echo "═══════════════════════════════════════════════════════"

# Try to claim a trigger that doesn't exist
if claim_trigger_for_processing "$STARFORGE_CLAUDE_DIR/triggers/nonexistent.trigger" 2>/dev/null; then
  echo "❌ FAIL: Claim succeeded for non-existent trigger"
  exit 1
fi

echo "✅ PASS: Claim correctly fails for non-existent trigger"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ All atomic trigger claim tests passed!"
echo "═══════════════════════════════════════════════════════"
