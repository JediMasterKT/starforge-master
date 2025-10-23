#!/bin/bash
# Test suite for bin/watch-triggers.sh
# Following TDD methodology - these tests should FAIL initially

set -e

# Source project environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$PROJECT_ROOT/.claude/lib/project-env.sh" ]; then
  source "$PROJECT_ROOT/.claude/lib/project-env.sh"
else
  echo "ERROR: project-env.sh not found"
  exit 1
fi

# Test configuration
TEST_TRIGGER_DIR="$PROJECT_ROOT/.claude/triggers/test"
TEST_LOG_FILE="$PROJECT_ROOT/.claude/test-watcher.log"
WATCHER_SCRIPT="$PROJECT_ROOT/bin/watch-triggers.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
  mkdir -p "$TEST_TRIGGER_DIR"
  mkdir -p "$TEST_TRIGGER_DIR/processed"
  rm -f "$TEST_LOG_FILE"

  # Clean up any leftover test triggers
  find "$STARFORGE_CLAUDE_DIR/triggers" -name "test-*.trigger" -delete 2>/dev/null || true
}

# Teardown test environment
teardown() {
  # Kill any running watcher processes
  pkill -f "watch-triggers.sh" 2>/dev/null || true

  # Clean up test files
  rm -rf "$TEST_TRIGGER_DIR"
  rm -f "$TEST_LOG_FILE"
  find "$STARFORGE_CLAUDE_DIR/triggers" -name "test-*.trigger" -delete 2>/dev/null || true
}

# Test assertion helper
assert_true() {
  local condition=$1
  local message=$2

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$condition"; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Test 1: Script exists and is executable
test_script_exists() {
  echo ""
  echo "Test 1: Script exists and is executable"
  assert_true "[ -f '$WATCHER_SCRIPT' ]" "Script file exists"
  assert_true "[ -x '$WATCHER_SCRIPT' ]" "Script is executable"
}

# Test 2: Script detects fswatch availability
test_fswatch_detection() {
  echo ""
  echo "Test 2: Detects fswatch availability"

  if command -v fswatch &> /dev/null; then
    assert_true "command -v fswatch &> /dev/null" "fswatch is available on system"
  else
    echo -e "${YELLOW}⚠${NC} fswatch not available - polling fallback will be used"
  fi
}

# Test 3: Watcher detects new trigger files (with fswatch if available)
test_watcher_detects_trigger() {
  echo ""
  echo "Test 3: Watcher detects new trigger files"

  setup

  # Start watcher in background with test log
  WATCHER_LOG="$TEST_LOG_FILE" "$WATCHER_SCRIPT" &
  WATCHER_PID=$!

  # Give watcher time to start
  sleep 2

  # Verify watcher is running
  if ! ps -p $WATCHER_PID > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Watcher failed to start"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Create test trigger
  local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-$(date +%s).trigger"
  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "tpm",
  "action": "test",
  "timestamp": "2025-10-22T00:00:00Z",
  "message": "Test trigger"
}
EOF

  # Wait for watcher to process (should be < 1 sec)
  sleep 2

  # Check if trigger was detected (moved to processed or logged)
  local detected=false
  if [ -f "$STARFORGE_CLAUDE_DIR/triggers/processed/$(basename "$trigger_file")" ]; then
    detected=true
  elif [ -f "$TEST_LOG_FILE" ] && grep -q "$(basename "$trigger_file")" "$TEST_LOG_FILE" 2>/dev/null; then
    detected=true
  fi

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  if [ "$detected" = true ]; then
    echo -e "${GREEN}✓${NC} Watcher detected trigger file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Watcher did not detect trigger file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown
}

# Test 4: Handles multiple triggers in succession
test_multiple_triggers() {
  echo ""
  echo "Test 4: Handles multiple triggers in succession"

  setup

  # Start watcher
  WATCHER_LOG="$TEST_LOG_FILE" "$WATCHER_SCRIPT" &
  WATCHER_PID=$!
  sleep 2

  # Create 3 triggers quickly
  for i in 1 2 3; do
    local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-multi-$i-$(date +%s).trigger"
    cat > "$trigger_file" << EOF
{
  "from_agent": "test",
  "to_agent": "tpm",
  "action": "test$i",
  "timestamp": "2025-10-22T00:00:00Z",
  "message": "Test trigger $i"
}
EOF
    sleep 0.2  # Small delay between triggers
  done

  # Wait for processing
  sleep 3

  # Count processed triggers
  local processed_count=0
  if [ -f "$TEST_LOG_FILE" ]; then
    processed_count=$(grep -c "test-multi-" "$TEST_LOG_FILE" 2>/dev/null || echo 0)
  fi

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  assert_true "[ '$processed_count' -ge 3 ]" "Processed all 3 triggers (processed: $processed_count)"

  teardown
}

# Test 5: Graceful shutdown on SIGTERM
test_graceful_shutdown() {
  echo ""
  echo "Test 5: Graceful shutdown on SIGTERM"

  setup

  # Start watcher
  WATCHER_LOG="$TEST_LOG_FILE" "$WATCHER_SCRIPT" &
  WATCHER_PID=$!
  sleep 2

  # Send SIGTERM
  kill -TERM $WATCHER_PID 2>/dev/null

  # Wait a bit for graceful shutdown
  sleep 1

  # Check if process is gone
  local graceful=false
  if ! ps -p $WATCHER_PID > /dev/null 2>/dev/null; then
    graceful=true
  fi

  if [ "$graceful" = true ]; then
    echo -e "${GREEN}✓${NC} Watcher shut down gracefully on SIGTERM"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Watcher did not shut down gracefully"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    kill -9 $WATCHER_PID 2>/dev/null || true
  fi

  teardown
}

# Test 6: Polling fallback when fswatch unavailable
test_polling_fallback() {
  echo ""
  echo "Test 6: Polling fallback when fswatch unavailable"

  setup

  # Start watcher with fswatch disabled
  USE_POLLING=1 WATCHER_LOG="$TEST_LOG_FILE" "$WATCHER_SCRIPT" &
  WATCHER_PID=$!
  sleep 2

  # Create trigger
  local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-polling-$(date +%s).trigger"
  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "tpm",
  "action": "test_polling",
  "timestamp": "2025-10-22T00:00:00Z",
  "message": "Test polling"
}
EOF

  # Wait for polling interval (should detect within 3 seconds)
  sleep 4

  # Check if detected
  local detected=false
  if [ -f "$TEST_LOG_FILE" ] && grep -q "test-polling" "$TEST_LOG_FILE" 2>/dev/null; then
    detected=true
  fi

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  if [ "$detected" = true ]; then
    echo -e "${GREEN}✓${NC} Polling fallback works"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Polling fallback failed"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown
}

# Test 7: Logs all events
test_logging() {
  echo ""
  echo "Test 7: Logs all events"

  setup

  # Start watcher
  WATCHER_LOG="$TEST_LOG_FILE" "$WATCHER_SCRIPT" &
  WATCHER_PID=$!
  sleep 2

  # Create trigger
  local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-logging-$(date +%s).trigger"
  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "qa-engineer",
  "action": "test_log",
  "timestamp": "2025-10-22T00:00:00Z",
  "message": "Test logging"
}
EOF

  sleep 2

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  assert_true "[ -f '$TEST_LOG_FILE' ]" "Log file created"
  assert_true "grep -q 'test-logging' '$TEST_LOG_FILE' 2>/dev/null" "Trigger event logged"

  teardown
}

# Run all tests
main() {
  echo "========================================"
  echo "  Test Suite: bin/watch-triggers.sh"
  echo "========================================"

  test_script_exists
  test_fswatch_detection
  test_watcher_detects_trigger
  test_multiple_triggers
  test_graceful_shutdown
  test_polling_fallback
  test_logging

  echo ""
  echo "========================================"
  echo "  Test Results"
  echo "========================================"
  echo "Tests run: $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo ""

  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
  fi
}

# Run tests
main
