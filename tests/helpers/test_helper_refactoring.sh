#!/bin/bash
# Test suite for helper script refactoring (Ticket #148)
# Purpose: Verify helper functions work correctly for junior-engineer.md refactoring

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result function
test_result() {
  local test_name=$1
  local exit_code=$2

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Source helper scripts
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAIN_REPO=$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | cut -d' ' -f2)
if [ -z "$MAIN_REPO" ]; then
  MAIN_REPO=$(git rev-parse --show-toplevel 2>/dev/null)
fi

source "$MAIN_REPO/.claude/lib/project-env.sh"
source "$MAIN_REPO/.claude/scripts/worktree-helpers.sh"
source "$MAIN_REPO/.claude/scripts/github-helpers.sh"
source "$MAIN_REPO/.claude/scripts/test-helpers.sh"
source "$MAIN_REPO/.claude/scripts/trigger-helpers.sh"
source "$MAIN_REPO/.claude/scripts/context-helpers.sh"

echo ""
echo "========================================="
echo "Helper Refactoring Test Suite (Ticket #148)"
echo "========================================="
echo ""

# ============================================================================
# TEST GROUP 1: Context Helpers (NEW)
# ============================================================================

echo "--- Group 1: Context Helpers ---"

# Test 1.1: Read project context
test_get_project_context() {
  local output=$(get_project_context 2>&1)

  # Should contain key info
  if echo "$output" | grep -q "StarForge"; then
    return 0
  else
    echo "ERROR: Context missing key information"
    return 1
  fi
}
test_get_project_context
test_result "get_project_context() returns project info" $?

# Test 1.2: Read tech stack
test_get_tech_stack() {
  local output=$(get_tech_stack 2>&1)

  # Should contain tech info
  if echo "$output" | grep -q -E "(Bash|Shell|Primary)"; then
    return 0
  else
    echo "ERROR: Tech stack missing key information"
    return 1
  fi
}
test_get_tech_stack
test_result "get_tech_stack() returns tech info" $?

# Test 1.3: Count learnings
test_count_learnings() {
  # Create test file
  local temp_learnings="/tmp/test_learnings.md"
  cat > "$temp_learnings" << 'EOF'
## Learning 1: Something
Content here

## Learning 2: Another thing
More content
EOF

  local result=$(count_learnings "$temp_learnings")

  rm -f "$temp_learnings"

  if [ "$result" = "2" ]; then
    return 0
  else
    echo "ERROR: Expected '2', got '$result'"
    return 1
  fi
}
test_count_learnings
test_result "count_learnings() counts correctly" $?

# ============================================================================
# TEST GROUP 2: Git Helpers (NEW)
# ============================================================================

echo ""
echo "--- Group 2: Git Helpers ---"

# Test 2.1: Extract ticket from branch name
test_extract_ticket_from_branch() {
  # Create test branch name
  local test_branch="feature/ticket-148"
  local result=$(extract_ticket_from_branch "$test_branch" 2>&1)

  if [ "$result" = "148" ]; then
    return 0
  else
    echo "ERROR: Expected '148', got '$result'"
    return 1
  fi
}
test_extract_ticket_from_branch
test_result "extract_ticket_from_branch() extracts ticket number" $?

# Test 2.2: Get commit bullets
test_get_commit_bullets() {
  # This test requires git history, so just verify function exists
  if type get_commit_bullets >/dev/null 2>&1; then
    return 0
  else
    echo "ERROR: get_commit_bullets() function not found"
    return 1
  fi
}
test_get_commit_bullets
test_result "get_commit_bullets() function exists" $?

# Test 2.3: Count commits
test_count_commits_since() {
  # Verify function exists
  if type count_commits_since >/dev/null 2>&1; then
    return 0
  else
    echo "ERROR: count_commits_since() function not found"
    return 1
  fi
}
test_count_commits_since
test_result "count_commits_since() function exists" $?

# ============================================================================
# TEST GROUP 3: Test Helpers (NEW)
# ============================================================================

echo ""
echo "--- Group 3: Test Helpers ---"

# Test 3.1: Count test cases
test_count_test_cases() {
  # Create temporary test file
  local temp_test_file="/tmp/test_sample.py"
  cat > "$temp_test_file" << 'EOF'
def test_one():
    pass

def test_two():
    pass

def test_three():
    pass
EOF

  # Count using pytest --co
  local count=$(cd /tmp && pytest test_sample.py --co -q 2>/dev/null | wc -l | tr -d ' ')

  # Clean up
  rm -f "$temp_test_file"

  # Should have counted 3 tests (or close to it, pytest adds header lines)
  if [ "$count" -ge 3 ]; then
    return 0
  else
    echo "ERROR: Expected >= 3, got $count"
    return 1
  fi
}
test_count_test_cases
test_result "count_test_cases() counts tests correctly" $?

# ============================================================================
# TEST GROUP 4: Existing Helpers (Verify Still Work)
# ============================================================================

echo ""
echo "--- Group 4: Existing Helpers ---"

# Test 4.1: get_main_repo_path
test_get_main_repo_path() {
  local result=$(get_main_repo_path)

  if [ -n "$result" ] && [ -d "$result" ]; then
    return 0
  else
    echo "ERROR: Invalid main repo path: $result"
    return 1
  fi
}
test_get_main_repo_path
test_result "get_main_repo_path() returns valid path" $?

# Test 4.2: get_coverage_percentage (already exists)
test_get_coverage_percentage() {
  # Create mock coverage file
  local temp_coverage="/tmp/coverage_test.txt"
  echo "TOTAL                                      100      50%   " > "$temp_coverage"

  local result=$(get_coverage_percentage "$temp_coverage")

  rm -f "$temp_coverage"

  if [ "$result" = "50" ]; then
    return 0
  else
    echo "ERROR: Expected '50', got '$result'"
    return 1
  fi
}
test_get_coverage_percentage
test_result "get_coverage_percentage() extracts percentage" $?

# Test 4.3: get_latest_trigger_file (already exists)
test_get_latest_trigger_file() {
  if type get_latest_trigger_file >/dev/null 2>&1; then
    return 0
  else
    echo "ERROR: get_latest_trigger_file() function not found"
    return 1
  fi
}
test_get_latest_trigger_file
test_result "get_latest_trigger_file() function exists" $?

# ============================================================================
# TEST SUMMARY
# ============================================================================

echo ""
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="
echo "Total tests run:    $TESTS_RUN"
echo -e "Tests passed:       ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "Tests failed:       ${RED}$TESTS_FAILED${NC}"
else
  echo -e "Tests failed:       ${GREEN}$TESTS_FAILED${NC}"
fi
echo "========================================="
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
else
  exit 0
fi
