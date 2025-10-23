#!/bin/bash
# Test suite for queue infrastructure creation
# Ticket #52: Create Queue Infrastructure
# Following TDD methodology - RED phase (tests should FAIL initially)

set -e

# Source project environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
TEST_DIR="$PROJECT_ROOT/.tmp/test-queue-infra"
INSTALL_SCRIPT="$PROJECT_ROOT/bin/install.sh"

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

# All agents that need queues
AGENTS=(
  "tpm"
  "senior-engineer"
  "orchestrator"
  "qa-engineer"
  "junior-dev-a"
  "junior-dev-b"
  "junior-dev-c"
)

# Queue subdirectories
QUEUE_SUBDIRS=(
  "pending"
  "processing"
  "completed"
  "failed"
  "logs"
)

# Setup test environment
setup() {
  echo -e "${BLUE}Setting up test environment...${NC}"
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"

  # Initialize git repo (required for install.sh)
  git init > /dev/null 2>&1
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "# Test Project" > README.md
  git add README.md
  git commit -m "Initial commit" > /dev/null 2>&1

  # Add remote to skip interactive prompts
  git remote add origin https://github.com/test/test.git > /dev/null 2>&1 || true
}

# Teardown test environment
teardown() {
  cd "$PROJECT_ROOT"
  rm -rf "$TEST_DIR"
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

# Test 1: Queue directories created for all agents
test_queue_structure_created() {
  echo ""
  echo -e "${BLUE}Test 1: Queue directories created for all agents${NC}"

  setup

  # Run installer non-interactively in background with timeout
  # Skip worktree creation by answering 'n' to proceed
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  local install_pid=$!

  # Wait up to 10 seconds for installation
  local count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done

  # Kill if still running
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Verify queue root exists
  assert_true "[ -d '.claude/queues' ]" "Queue root directory created"

  # Verify each agent has queue directory
  for agent in "${AGENTS[@]}"; do
    assert_true "[ -d '.claude/queues/$agent' ]" "Queue directory for $agent created"
  done

  teardown
}

# Test 2: Queue subdirectories created for all agents
test_queue_subdirectories_created() {
  echo ""
  echo -e "${BLUE}Test 2: Queue subdirectories created for all agents${NC}"

  setup

  # Run installer non-interactively in background with timeout
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  local install_pid=$!
  local count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Verify all subdirectories exist for each agent
  for agent in "${AGENTS[@]}"; do
    for subdir in "${QUEUE_SUBDIRS[@]}"; do
      assert_true "[ -d '.claude/queues/$agent/$subdir' ]" "$agent/$subdir created"
    done
  done

  teardown
}

# Test 3: Gitignore excludes completed and logs
test_gitignore_updated() {
  echo ""
  echo -e "${BLUE}Test 3: Gitignore excludes queue completed and logs${NC}"

  setup

  # Run installer non-interactively in background with timeout
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  local install_pid=$!
  local count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Verify gitignore exists
  assert_true "[ -f '.gitignore' ]" ".gitignore file created"

  # Verify queue completed directories are ignored
  assert_true "grep -q '.claude/queues/.*/completed/' '.gitignore' 2>/dev/null || grep -q 'queues/.*/completed' '.gitignore' 2>/dev/null" "Gitignore excludes completed directories"

  # Verify queue logs directories are ignored
  assert_true "grep -q '.claude/queues/.*/logs/' '.gitignore' 2>/dev/null || grep -q 'queues/.*/logs' '.gitignore' 2>/dev/null" "Gitignore excludes logs directories"

  teardown
}

# Test 4: Queue structure is idempotent (can run install multiple times)
test_queue_creation_idempotent() {
  echo ""
  echo -e "${BLUE}Test 4: Queue creation is idempotent${NC}"

  setup

  # Run installer first time
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  local install_pid=$!
  local count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Create a test file in a queue
  mkdir -p .claude/queues/tpm/pending
  echo "test" > .claude/queues/tpm/pending/test-task.json

  # Run installer second time
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  install_pid=$!
  count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Verify test file still exists (directories not recreated)
  assert_true "[ -f '.claude/queues/tpm/pending/test-task.json' ]" "Existing queue files preserved"

  # Verify structure still complete
  assert_true "[ -d '.claude/queues/orchestrator/pending' ]" "Queue structure still complete"

  teardown
}

# Test 5: All 7 agents supported
test_all_seven_agents_supported() {
  echo ""
  echo -e "${BLUE}Test 5: All 7 agents have queue support${NC}"

  setup

  # Run installer non-interactively in background with timeout
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  local install_pid=$!
  local count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Count agent directories
  local agent_count=$(find .claude/queues -maxdepth 1 -type d | grep -v '^.claude/queues$' | wc -l | tr -d ' ')

  assert_true "[ '$agent_count' -eq 7 ]" "Exactly 7 agent queues created (found: $agent_count)"

  # Verify specific agents
  assert_true "[ -d '.claude/queues/tpm' ]" "tpm queue exists"
  assert_true "[ -d '.claude/queues/senior-engineer' ]" "senior-engineer queue exists"
  assert_true "[ -d '.claude/queues/orchestrator' ]" "orchestrator queue exists"
  assert_true "[ -d '.claude/queues/qa-engineer' ]" "qa-engineer queue exists"
  assert_true "[ -d '.claude/queues/junior-dev-a' ]" "junior-dev-a queue exists"
  assert_true "[ -d '.claude/queues/junior-dev-b' ]" "junior-dev-b queue exists"
  assert_true "[ -d '.claude/queues/junior-dev-c' ]" "junior-dev-c queue exists"

  teardown
}

# Test 6: Queue directories have correct permissions
test_queue_permissions() {
  echo ""
  echo -e "${BLUE}Test 6: Queue directories are writable${NC}"

  setup

  # Run installer non-interactively in background with timeout
  (echo -e "n\nn\nn" | bash "$INSTALL_SCRIPT" > /dev/null 2>&1) &
  local install_pid=$!
  local count=0
  while [ $count -lt 10 ] && kill -0 $install_pid 2>/dev/null; do
    sleep 1
    count=$((count + 1))
  done
  kill $install_pid 2>/dev/null || true
  wait $install_pid 2>/dev/null || true

  # Test write access to each queue type
  assert_true "touch .claude/queues/tpm/pending/test.json && rm .claude/queues/tpm/pending/test.json" "tpm pending is writable"
  assert_true "touch .claude/queues/orchestrator/processing/test.json && rm .claude/queues/orchestrator/processing/test.json" "orchestrator processing is writable"
  assert_true "touch .claude/queues/junior-dev-a/completed/test.json && rm .claude/queues/junior-dev-a/completed/test.json" "junior-dev-a completed is writable"

  teardown
}

# Run all tests
main() {
  echo "======================================================="
  echo "  Test Suite: Queue Infrastructure (Ticket #52)"
  echo "======================================================="
  echo ""
  echo "Testing queue directory structure creation"
  echo ""

  test_queue_structure_created
  test_queue_subdirectories_created
  test_gitignore_updated
  test_queue_creation_idempotent
  test_all_seven_agents_supported
  test_queue_permissions

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
    echo "Queue infrastructure validated:"
    echo "  - All 7 agents supported"
    echo "  - 5 subdirectories per agent"
    echo "  - Gitignore configured"
    echo "  - Idempotent installation"
    exit 0
  else
    echo -e "${RED}✗ Some tests failed.${NC}"
    echo ""
    echo "Review failures above to fix queue infrastructure."
    exit 1
  fi
}

# Run tests
main
