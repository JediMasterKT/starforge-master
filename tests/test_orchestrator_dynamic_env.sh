#!/bin/bash
# TDD Tests for Orchestrator Dynamic Environment Detection
# Tests that orchestrator.md uses project-env.sh instead of hard-coded paths

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
assert_exit_code() {
    local expected=$1
    local actual=$?
    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$actual" -eq "$expected" ]; then
        echo -e "${GREEN}✓${NC} Test passed (exit code: $actual)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} Test failed (expected: $expected, got: $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local file=$1
    local pattern=$2
    TESTS_RUN=$((TESTS_RUN + 1))

    if grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} Found pattern: $pattern"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} Pattern not found: $pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    local file=$1
    local pattern=$2
    TESTS_RUN=$((TESTS_RUN + 1))

    if ! grep -q "$pattern" "$file"; then
        echo -e "${GREEN}✓${NC} Pattern not found (as expected): $pattern"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} Pattern found (should not be): $pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test file
ORCHESTRATOR_FILE="templates/agents/orchestrator.md"

echo "Running TDD tests for orchestrator dynamic environment detection..."
echo ""

# Test 1: orchestrator.md should source project-env.sh
echo "Test 1: Orchestrator sources project-env.sh in pre-flight checks"
assert_contains "$ORCHESTRATOR_FILE" "source.*project-env.sh"

# Test 2: No hard-coded "empowerai" references
echo ""
echo "Test 2: No hard-coded 'empowerai' references in orchestrator.md"
grep "empowerai" "$ORCHESTRATOR_FILE" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${RED}✗${NC} Found hard-coded 'empowerai' references:"
    grep -n "empowerai" "$ORCHESTRATOR_FILE"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} No hard-coded 'empowerai' references found"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Test 3: Uses is_worktree function
echo ""
echo "Test 3: Uses is_worktree function for location check"
assert_contains "$ORCHESTRATOR_FILE" "is_worktree"

# Test 4: Uses STARFORGE_MAIN_REPO variable
echo ""
echo "Test 4: Uses \$STARFORGE_MAIN_REPO for main repo path"
assert_contains "$ORCHESTRATOR_FILE" '\$STARFORGE_MAIN_REPO'

# Test 5: Uses STARFORGE_PROJECT_NAME variable
echo ""
echo "Test 5: Uses \$STARFORGE_PROJECT_NAME for worktree naming"
assert_contains "$ORCHESTRATOR_FILE" '\$STARFORGE_PROJECT_NAME'

# Test 6: Uses STARFORGE_CLAUDE_DIR variable
echo ""
echo "Test 6: Uses \$STARFORGE_CLAUDE_DIR for file paths"
assert_contains "$ORCHESTRATOR_FILE" '\$STARFORGE_CLAUDE_DIR'

# Test 7: Pre-flight checks include project name output
echo ""
echo "Test 7: Pre-flight checks output includes project name"
assert_contains "$ORCHESTRATOR_FILE" 'Project:.*STARFORGE_PROJECT_NAME'

# Summary
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo "All tests passed!"
    exit 0
fi
