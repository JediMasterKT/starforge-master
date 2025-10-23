#!/bin/bash
# TDD Tests for Script Files Dynamic Environment Detection
# Tests that helper scripts use project-env.sh instead of hard-coded paths

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
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

# Test files
TRIGGER_HELPERS="templates/scripts/trigger-helpers.sh"
TRIGGER_MONITOR="templates/scripts/trigger-monitor.sh"
WATCH_TRIGGERS="templates/scripts/watch-triggers.sh"

echo "Running TDD tests for script dynamic environment detection..."
echo ""

# Test 1: trigger-helpers.sh should source project-env.sh
echo "Test 1: trigger-helpers.sh sources project-env.sh"
assert_contains "$TRIGGER_HELPERS" "source.*project-env.sh"

# Test 2: trigger-helpers.sh uses STARFORGE environment variables
echo ""
echo "Test 2: trigger-helpers.sh uses STARFORGE environment variables (CLAUDE_DIR)"
assert_contains "$TRIGGER_HELPERS" '\$STARFORGE_CLAUDE_DIR'

# Test 3: trigger-helpers.sh has no hard-coded empowerai references
echo ""
echo "Test 3: No hard-coded 'empowerai' references in trigger-helpers.sh"
assert_not_contains "$TRIGGER_HELPERS" "empowerai"

# Test 4: trigger-monitor.sh sources project-env.sh
echo ""
echo "Test 4: trigger-monitor.sh sources project-env.sh"
assert_contains "$TRIGGER_MONITOR" "source.*project-env.sh"

# Test 5: trigger-monitor.sh uses dynamic TRIGGER_DIR
echo ""
echo "Test 5: trigger-monitor.sh uses dynamic TRIGGER_DIR from project-env.sh"
# Should use STARFORGE_CLAUDE_DIR instead of hard-coded path
assert_contains "$TRIGGER_MONITOR" '\$STARFORGE_CLAUDE_DIR'

# Test 6: trigger-monitor.sh has no hard-coded empowerai references
echo ""
echo "Test 6: No hard-coded 'empowerai' path in trigger-monitor.sh"
assert_not_contains "$TRIGGER_MONITOR" "~/empowerai"

# Test 7: watch-triggers.sh sources project-env.sh
echo ""
echo "Test 7: watch-triggers.sh sources project-env.sh"
assert_contains "$WATCH_TRIGGERS" "source.*project-env.sh"

# Test 8: watch-triggers.sh uses dynamic TRIGGER_DIR
echo ""
echo "Test 8: watch-triggers.sh uses dynamic TRIGGER_DIR"
assert_contains "$WATCH_TRIGGERS" '\$STARFORGE_CLAUDE_DIR'

# Test 9: watch-triggers.sh has no hard-coded empowerai references
echo ""
echo "Test 9: No hard-coded 'empowerai' references in watch-triggers.sh"
assert_not_contains "$WATCH_TRIGGERS" "empowerai"

# Test 10: trigger-helpers.sh no longer auto-detects (uses project-env.sh instead)
echo ""
echo "Test 10: trigger-helpers.sh doesn't duplicate auto-detection logic"
# Should not have its own git worktree detection since project-env.sh provides it
if grep -q "git worktree list.*MAIN_REPO=" "$TRIGGER_HELPERS"; then
    echo -e "${RED}✗${NC} Still has duplicate auto-detection logic (should use project-env.sh)"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    echo -e "${GREEN}✓${NC} No duplicate auto-detection (relies on project-env.sh)"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

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
