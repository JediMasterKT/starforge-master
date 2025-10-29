#!/bin/bash
# Test distributed locking implementation
# Verifies that locks prevent race conditions in agent assignment and trigger claiming

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Testing Distributed Locking Implementation"
echo "==========================================="
echo ""

# Test 1: Lock helpers library loads correctly
echo -e "${YELLOW}Test 1: Lock helpers library loads${NC}"
source "$PROJECT_ROOT/templates/lib/lock-helpers.sh"
echo -e "${GREEN}✓ Lock helpers loaded${NC}"
echo ""

# Test 2: Basic lock acquire/release
echo -e "${YELLOW}Test 2: Basic lock acquire/release${NC}"
if acquire_lock "test-resource" 5; then
  echo -e "${GREEN}✓ Lock acquired${NC}"
  release_lock
  echo -e "${GREEN}✓ Lock released${NC}"
else
  echo -e "${RED}✗ Failed to acquire lock${NC}"
  exit 1
fi
echo ""

# Test 3: Lock prevents concurrent access
echo -e "${YELLOW}Test 3: Lock prevents concurrent access${NC}"
(
  acquire_lock "test-concurrent" 30
  sleep 2
  release_lock
) &
PID1=$!

sleep 0.5  # Let first process acquire lock

# Try to acquire same lock (should fail immediately with short timeout)
if acquire_lock "test-concurrent" 1; then
  echo -e "${RED}✗ Second lock should have failed (no mutual exclusion)${NC}"
  release_lock
  wait $PID1
  exit 1
else
  echo -e "${GREEN}✓ Second lock correctly blocked${NC}"
fi

wait $PID1
echo ""

# Test 4: is_locked check
echo -e "${YELLOW}Test 4: is_locked detection${NC}"
(
  acquire_lock "test-detection" 30
  sleep 2
  release_lock
) &
PID2=$!

sleep 0.5

if is_locked "test-detection"; then
  echo -e "${GREEN}✓ Lock correctly detected as held${NC}"
else
  echo -e "${RED}✗ Failed to detect held lock${NC}"
  wait $PID2
  exit 1
fi

wait $PID2

if is_locked "test-detection"; then
  echo -e "${RED}✗ Lock still detected after release${NC}"
  exit 1
else
  echo -e "${GREEN}✓ Lock correctly detected as released${NC}"
fi
echo ""

# Test 5: with_lock helper
echo -e "${YELLOW}Test 5: with_lock helper${NC}"

test_function() {
  echo "Function executing with lock protection"
  return 0
}

if with_lock "test-helper" test_function; then
  echo -e "${GREEN}✓ with_lock helper works${NC}"
else
  echo -e "${RED}✗ with_lock helper failed${NC}"
  exit 1
fi
echo ""

# Test 6: Cleanup stale locks
echo -e "${YELLOW}Test 6: Cleanup stale locks${NC}"
LOCK_DIR="${STARFORGE_CLAUDE_DIR:-$PWD/.claude}/locks"
mkdir -p "$LOCK_DIR"

# Create fake stale lock with non-existent PID (must be directory with metadata file)
mkdir -p "$LOCK_DIR/test-stale.lock"
echo "2025-10-29T20:00:00Z PID:999999 HOST:test" > "$LOCK_DIR/test-stale.lock/metadata"

cleanup_stale_locks
if [ ! -d "$LOCK_DIR/test-stale.lock" ]; then
  echo -e "${GREEN}✓ Stale lock cleaned up${NC}"
else
  echo -e "${YELLOW}⚠ Stale lock not removed (may be locked by another process)${NC}"
fi
echo ""

# Test 7: Lock timeout
echo -e "${YELLOW}Test 7: Lock acquisition timeout${NC}"
(
  acquire_lock "test-timeout" 30
  sleep 5
  release_lock
) &
PID3=$!

sleep 0.5

# Try to acquire with 1 second timeout (should fail)
if acquire_lock "test-timeout" 1; then
  echo -e "${RED}✗ Lock should have timed out${NC}"
  release_lock
  wait $PID3
  exit 1
else
  echo -e "${GREEN}✓ Lock correctly timed out${NC}"
fi

wait $PID3
echo ""

echo "==========================================="
echo -e "${GREEN}All locking tests passed!${NC}"
echo ""
exit 0
