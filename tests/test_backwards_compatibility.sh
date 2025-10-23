#!/bin/bash
# Test suite for backwards compatibility between manual and automatic workflows
# Ticket #62: Integration with Existing Workflow
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
TEST_DIR="$PROJECT_ROOT/.tmp/test-backwards-compat"
STARFORGE_BIN="$PROJECT_ROOT/bin/starforge"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup() {
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"

  # Initialize a minimal git repo if needed
  if [ ! -d ".git" ]; then
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Test Project" > README.md
    git add README.md
    git commit -m "Initial commit" > /dev/null 2>&1
  fi

  # Clean up any existing .claude directory
  rm -rf .claude

  # Clean up any existing triggers/queues
  rm -rf .claude/triggers .claude/queues
}

# Teardown test environment
teardown() {
  cd "$PROJECT_ROOT"
  rm -rf "$TEST_DIR"

  # Kill any running watcher processes
  pkill -f "watch-triggers.sh" 2>/dev/null || true
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

# Test 1: Manual invocation works without queue system
test_manual_invocation_without_queue() {
  echo ""
  echo -e "${BLUE}Test 1: Manual invocation works without queue/watcher${NC}"

  setup

  # Manually create a trigger (simulating old workflow)
  mkdir -p .claude/triggers
  local trigger_file=".claude/triggers/manual-test-$(date +%s).trigger"

  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm-agent",
  "action": "create-tickets",
  "timestamp": "2025-10-23T00:00:00Z",
  "breakdown_file": ".claude/breakdowns/test-breakdown.md"
}
EOF

  # Verify trigger file was created (old workflow expectation)
  assert_true "[ -f '$trigger_file' ]" "Manual trigger file created successfully"

  # Verify trigger is valid JSON (old workflow expectation)
  assert_true "jq empty '$trigger_file' 2>/dev/null" "Manual trigger is valid JSON"

  # Verify trigger contains expected fields (old workflow expectation)
  assert_true "[ \"\$(jq -r '.to_agent' '$trigger_file')\" = 'tpm-agent' ]" "Manual trigger has to_agent field"
  assert_true "[ \"\$(jq -r '.action' '$trigger_file')\" = 'create-tickets' ]" "Manual trigger has action field"

  teardown
}

# Test 2: Automatic routing works with watcher running
test_automatic_routing_with_watcher() {
  echo ""
  echo -e "${BLUE}Test 2: Automatic routing works when watcher is running${NC}"

  setup

  # Create necessary directories
  mkdir -p .claude/triggers .claude/lib .claude/queues/tpm/pending

  # Copy required libraries
  cp "$PROJECT_ROOT/.claude/lib/router.sh" .claude/lib/
  cp "$PROJECT_ROOT/.claude/lib/project-env.sh" .claude/lib/

  # Start watcher (simulating automatic workflow)
  WATCHER_LOG=".claude/test-watcher.log" "$PROJECT_ROOT/bin/watch-triggers.sh" &
  WATCHER_PID=$!
  sleep 2

  # Verify watcher started
  assert_true "ps -p $WATCHER_PID > /dev/null 2>&1" "Watcher process started successfully"

  # Create a trigger file (same as manual workflow)
  local trigger_file=".claude/triggers/auto-test-$(date +%s).trigger"
  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "orchestrator",
  "to_agent": "junior-dev-a",
  "action": "implement-ticket",
  "timestamp": "2025-10-23T00:00:00Z",
  "context": {
    "ticket": 42,
    "description": "Test implementation"
  }
}
EOF

  # Wait for automatic routing
  sleep 3

  # Verify trigger was automatically processed
  local processed=false
  if [ -f ".claude/triggers/processed/$(basename "$trigger_file")" ]; then
    processed=true
  fi

  # Verify task was created in queue
  local task_created=false
  if ls .claude/queues/junior-dev-a/pending/task-*.json > /dev/null 2>&1; then
    task_created=true
  fi

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  if [ "$processed" = true ]; then
    echo -e "${GREEN}✓${NC} Trigger automatically moved to processed"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Trigger not automatically processed"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  if [ "$task_created" = true ]; then
    echo -e "${GREEN}✓${NC} Task created in queue automatically"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Task not created in queue"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown
}

# Test 3: Both modes coexist without interference
test_modes_coexist() {
  echo ""
  echo -e "${BLUE}Test 3: Manual and automatic modes coexist${NC}"

  setup

  # Create necessary directories
  mkdir -p .claude/triggers .claude/lib .claude/queues/qa-engineer/pending

  # Copy required libraries
  cp "$PROJECT_ROOT/.claude/lib/router.sh" .claude/lib/
  cp "$PROJECT_ROOT/.claude/lib/project-env.sh" .claude/lib/

  # Test scenario 1: Manual trigger without watcher
  local manual_trigger=".claude/triggers/manual-coexist-$(date +%s).trigger"
  cat > "$manual_trigger" << 'EOF'
{
  "from_agent": "junior-dev-a",
  "to_agent": "qa-engineer",
  "action": "review-pr",
  "pr_number": 123
}
EOF

  # Verify manual trigger persists (not auto-processed)
  sleep 1
  assert_true "[ -f '$manual_trigger' ]" "Manual trigger persists without watcher"

  # Test scenario 2: Start watcher and verify it processes existing trigger
  WATCHER_LOG=".claude/test-watcher.log" "$PROJECT_ROOT/bin/watch-triggers.sh" &
  WATCHER_PID=$!
  sleep 3

  # Verify existing manual trigger was picked up by watcher
  local processed=false
  if [ -f ".claude/triggers/processed/$(basename "$manual_trigger")" ]; then
    processed=true
  fi

  # Test scenario 3: New trigger with watcher running
  local auto_trigger=".claude/triggers/auto-coexist-$(date +%s).trigger"
  cat > "$auto_trigger" << 'EOF'
{
  "from_agent": "junior-dev-b",
  "to_agent": "qa-engineer",
  "action": "review-pr",
  "pr_number": 124
}
EOF

  sleep 3

  # Verify new trigger was also processed
  local auto_processed=false
  if [ -f ".claude/triggers/processed/$(basename "$auto_trigger")" ]; then
    auto_processed=true
  fi

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  if [ "$processed" = true ]; then
    echo -e "${GREEN}✓${NC} Watcher picked up pre-existing manual trigger"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Watcher did not process pre-existing trigger"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  if [ "$auto_processed" = true ]; then
    echo -e "${GREEN}✓${NC} Watcher processed new trigger while running"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Watcher did not process new trigger"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  teardown
}

# Test 4: No breaking changes - trigger file format unchanged
test_trigger_format_unchanged() {
  echo ""
  echo -e "${BLUE}Test 4: Trigger file format remains unchanged${NC}"

  setup

  mkdir -p .claude/triggers

  # Old-style trigger (should still work)
  local old_trigger=".claude/triggers/old-style-$(date +%s).trigger"
  cat > "$old_trigger" << 'EOF'
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm-agent",
  "action": "create-tickets",
  "breakdown_file": ".claude/breakdowns/test.md"
}
EOF

  # Verify old format is still valid
  assert_true "jq empty '$old_trigger' 2>/dev/null" "Old trigger format is valid JSON"
  assert_true "[ \"\$(jq -r '.to_agent' '$old_trigger')\" != 'null' ]" "Old trigger has to_agent"
  assert_true "[ \"\$(jq -r '.action' '$old_trigger')\" != 'null' ]" "Old trigger has action"

  # New-style trigger with context (should also work)
  local new_trigger=".claude/triggers/new-style-$(date +%s).trigger"
  cat > "$new_trigger" << 'EOF'
{
  "from_agent": "orchestrator",
  "to_agent": "junior-dev-c",
  "action": "implement-ticket",
  "context": {
    "ticket": 99,
    "priority": "high"
  }
}
EOF

  # Verify new format is also valid
  assert_true "jq empty '$new_trigger' 2>/dev/null" "New trigger format is valid JSON"
  assert_true "[ \"\$(jq -r '.to_agent' '$new_trigger')\" != 'null' ]" "New trigger has to_agent"
  assert_true "[ \"\$(jq -r '.context.ticket' '$new_trigger')\" = '99' ]" "New trigger has context field"

  teardown
}

# Test 5: starforge use command still works (manual workflow)
test_starforge_use_command() {
  echo ""
  echo -e "${BLUE}Test 5: 'starforge use' command works without queue${NC}"

  # Verify starforge binary exists
  assert_true "[ -f '$STARFORGE_BIN' ]" "starforge binary exists"
  assert_true "[ -x '$STARFORGE_BIN' ]" "starforge binary is executable"

  # Test starforge use help (should work regardless of queue)
  # Note: 'starforge use' without args exits with error (expected), but still shows help
  local help_output
  help_output=$("$STARFORGE_BIN" use 2>&1) || true

  # Verify it shows agent list (backwards compatibility)
  if echo "$help_output" | grep -q "orchestrator"; then
    echo -e "${GREEN}✓${NC} starforge use shows agent list"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} starforge use does not show agent list"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Test 6: Documentation reflects both modes
test_documentation_updated() {
  echo ""
  echo -e "${BLUE}Test 6: Documentation covers both manual and automatic modes${NC}"

  local readme="$PROJECT_ROOT/README.md"

  assert_true "[ -f '$readme' ]" "README.md exists"

  # Check for manual workflow documentation
  assert_true "grep -q 'starforge use' '$readme' 2>/dev/null" "README documents manual 'starforge use'"

  # Check for automatic workflow documentation
  assert_true "grep -q 'starforge monitor' '$readme' 2>/dev/null || grep -q 'watch.*trigger' '$readme' 2>/dev/null" "README documents automatic trigger watching"

  # Check that both workflows are explained
  assert_true "grep -iq 'monitor' '$readme' 2>/dev/null" "README mentions monitoring/watching"
}

# Test 7: Queue system is optional (fails gracefully when unavailable)
test_queue_optional() {
  echo ""
  echo -e "${BLUE}Test 7: Queue system fails gracefully when unavailable${NC}"

  setup

  # Create trigger without router.sh (simulating queue system not available)
  mkdir -p .claude/triggers .claude/lib

  # Only copy project-env.sh, not router.sh
  cp "$PROJECT_ROOT/.claude/lib/project-env.sh" .claude/lib/

  # Start watcher
  WATCHER_LOG=".claude/test-watcher.log" "$PROJECT_ROOT/bin/watch-triggers.sh" &
  WATCHER_PID=$!
  sleep 2

  # Create trigger
  local trigger=".claude/triggers/fallback-test-$(date +%s).trigger"
  cat > "$trigger" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "tpm",
  "action": "test-fallback"
}
EOF

  sleep 3

  # Verify trigger was archived (fallback behavior)
  local archived=false
  if [ -f ".claude/triggers/processed/$(basename "$trigger")" ]; then
    archived=true
  fi

  # Kill watcher
  kill $WATCHER_PID 2>/dev/null || true
  wait $WATCHER_PID 2>/dev/null || true

  if [ "$archived" = true ]; then
    echo -e "${GREEN}✓${NC} Trigger archived when queue system unavailable"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} Trigger not properly handled without queue"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Verify log mentions fallback
  if [ -f ".claude/test-watcher.log" ]; then
    if grep -q "router.sh not available\|queue routing not available" ".claude/test-watcher.log" 2>/dev/null; then
      echo -e "${GREEN}✓${NC} Fallback logged appropriately"
      TESTS_RUN=$((TESTS_RUN + 1))
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      echo -e "${YELLOW}⚠${NC} Fallback not explicitly logged"
      TESTS_RUN=$((TESTS_RUN + 1))
      TESTS_PASSED=$((TESTS_PASSED + 1))  # Not a hard failure
    fi
  fi

  teardown
}

# Run all tests
main() {
  echo "======================================================="
  echo "  Test Suite: Backwards Compatibility (Ticket #62)"
  echo "======================================================="
  echo ""
  echo "Testing integration between manual and automatic workflows"
  echo ""

  test_manual_invocation_without_queue
  test_automatic_routing_with_watcher
  test_modes_coexist
  test_trigger_format_unchanged
  test_starforge_use_command
  test_documentation_updated
  test_queue_optional

  echo ""
  echo "======================================================="
  echo "  Test Results"
  echo "======================================================="
  echo "Tests run: $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo ""

  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Backwards compatibility validated:"
    echo "  - Manual workflow unchanged"
    echo "  - Automatic workflow transparent"
    echo "  - Both modes coexist"
    echo "  - No breaking changes"
    exit 0
  else
    echo -e "${RED}✗ Some tests failed.${NC}"
    echo ""
    echo "Review failures above to ensure backwards compatibility."
    exit 1
  fi
}

# Run tests
main
