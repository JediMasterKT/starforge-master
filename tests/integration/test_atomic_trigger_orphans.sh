#!/usr/bin/env bash
# Integration Test: Orphan Detection and Cleanup
# Tests detection and cleanup of abandoned .pending and .processing files

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
mkdir -p "$STARFORGE_CLAUDE_DIR/triggers/processed/failed"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "═══════════════════════════════════════════════════════"
echo "Test 1: Detect Orphaned .pending Files"
echo "═══════════════════════════════════════════════════════"

# Create an old .pending file (simulate with touch -t)
OLD_PENDING="$STARFORGE_CLAUDE_DIR/triggers/staging/old-pending.pending"
echo '{"test": "old"}' > "$OLD_PENDING"

# Make it look 10 minutes old
# Using touch -A to adjust time (macOS) or touch -d (Linux)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: subtract 10 minutes (600 seconds)
  touch -A -600 "$OLD_PENDING" 2>/dev/null || touch -t 202501010000 "$OLD_PENDING"
else
  # Linux
  touch -d "10 minutes ago" "$OLD_PENDING"
fi

# Create a recent .pending file
RECENT_PENDING="$STARFORGE_CLAUDE_DIR/triggers/staging/recent-pending.pending"
echo '{"test": "recent"}' > "$RECENT_PENDING"

# Detect orphans (default: 5+ minutes)
ORPHANED=$(detect_orphaned_pending 5)
ORPHAN_COUNT=$(echo "$ORPHANED" | grep -c "old-pending" || echo "0")

if [ "$ORPHAN_COUNT" -ne 1 ]; then
  echo "❌ FAIL: Expected 1 orphaned .pending file, found $ORPHAN_COUNT"
  exit 1
fi

# Verify recent file is NOT detected as orphan
if echo "$ORPHANED" | grep -q "recent-pending"; then
  echo "❌ FAIL: Recent .pending file incorrectly detected as orphan"
  exit 1
fi

echo "✅ PASS: Orphaned .pending detection works"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 2: Detect Orphaned .processing Files"
echo "═══════════════════════════════════════════════════════"

# Create an old .processing file
OLD_PROCESSING="$STARFORGE_CLAUDE_DIR/triggers/old-processing.processing"
echo '{"test": "hung_daemon"}' > "$OLD_PROCESSING"

# Make it 35 minutes old
if [[ "$OSTYPE" == "darwin"* ]]; then
  touch -A -2100 "$OLD_PROCESSING" 2>/dev/null || touch -t 202501010000 "$OLD_PROCESSING"
else
  touch -d "35 minutes ago" "$OLD_PROCESSING"
fi

# Create a recent .processing file
RECENT_PROCESSING="$STARFORGE_CLAUDE_DIR/triggers/recent-processing.processing"
echo '{"test": "active"}' > "$RECENT_PROCESSING"

# Detect orphans (default: 30+ minutes)
ORPHANED=$(detect_orphaned_processing 30)
ORPHAN_COUNT=$(echo "$ORPHANED" | grep -c "old-processing" || echo "0")

if [ "$ORPHAN_COUNT" -ne 1 ]; then
  echo "❌ FAIL: Expected 1 orphaned .processing file, found $ORPHAN_COUNT"
  exit 1
fi

# Verify recent file is NOT detected
if echo "$ORPHANED" | grep -q "recent-processing"; then
  echo "❌ FAIL: Recent .processing file incorrectly detected as orphan"
  exit 1
fi

echo "✅ PASS: Orphaned .processing detection works"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 3: Cleanup Orphaned Files"
echo "═══════════════════════════════════════════════════════"

# Cleanup should move orphaned files to failed/ directory
CLEANED_COUNT=$(cleanup_orphaned_files)

if [ "$CLEANED_COUNT" -lt 2 ]; then
  echo "❌ FAIL: Expected at least 2 files cleaned, got $CLEANED_COUNT"
  exit 1
fi

# Verify orphaned files were moved to failed/
FAILED_COUNT=$(find "$STARFORGE_CLAUDE_DIR/triggers/processed/failed" -name "orphaned-*" | wc -l | tr -d ' ')

if [ "$FAILED_COUNT" -lt 2 ]; then
  echo "❌ FAIL: Expected at least 2 files in failed/, found $FAILED_COUNT"
  exit 1
fi

# Verify original locations are cleaned
if [ -f "$OLD_PENDING" ]; then
  echo "❌ FAIL: Old .pending file not moved"
  exit 1
fi

if [ -f "$OLD_PROCESSING" ]; then
  echo "❌ FAIL: Old .processing file not moved"
  exit 1
fi

# Verify recent files still exist
if [ ! -f "$RECENT_PENDING" ]; then
  echo "❌ FAIL: Recent .pending file was incorrectly removed"
  exit 1
fi

if [ ! -f "$RECENT_PROCESSING" ]; then
  echo "❌ FAIL: Recent .processing file was incorrectly removed"
  exit 1
fi

echo "✅ PASS: Orphan cleanup works correctly"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Test 4: No False Positives"
echo "═══════════════════════════════════════════════════════"

# Clean slate
rm -f "$RECENT_PENDING" "$RECENT_PROCESSING"

# Create only recent files
echo '{"test": "1"}' > "$STARFORGE_CLAUDE_DIR/triggers/staging/new1.pending"
echo '{"test": "2"}' > "$STARFORGE_CLAUDE_DIR/triggers/new2.processing"

# Run cleanup
CLEANED=$(cleanup_orphaned_files)

if [ "$CLEANED" -ne 0 ]; then
  echo "❌ FAIL: Cleanup removed recent files (false positive)"
  exit 1
fi

echo "✅ PASS: No false positives in cleanup"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ All orphan detection and cleanup tests passed!"
echo "═══════════════════════════════════════════════════════"
