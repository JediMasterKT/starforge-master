#!/bin/bash
# TDD tests for senior-engineer.md updates (Ticket #21)
# Tests that all hard-coded "empowerai" references are replaced with dynamic variables

# Note: NOT using 'set -e' since we handle exit codes manually

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
    local actual=$2
    local test_name=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$actual" -eq "$expected" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected exit code: $expected, got: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_true() {
    local condition=$1
    local test_name=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$condition" = "true" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected true, got: $condition"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: No hard-coded "empowerai" references
test_senior_engineer_no_hardcoded_paths() {
    echo ""
    echo "Test 1: No hard-coded 'empowerai' references"

    set +e  # Temporarily disable exit-on-error
    grep -q "empowerai" templates/agents/senior-engineer.md
    local result=$?
    set -e  # Re-enable if needed

    # grep returns 1 when pattern NOT found (which is what we want)
    assert_exit_code 1 $result "senior-engineer.md contains no 'empowerai' references"
}

# Test 2: Sources project-env.sh in pre-flight checks
test_senior_engineer_sources_project_env() {
    echo ""
    echo "Test 2: Pre-flight checks source project-env.sh"

    set +e
    grep -q "source.*project-env.sh" templates/agents/senior-engineer.md
    local result=$?
    set -e

    # grep returns 0 when pattern IS found
    assert_exit_code 0 $result "senior-engineer.md sources project-env.sh"
}

# Test 3: Uses $STARFORGE_MAIN_REPO variable
test_senior_engineer_uses_main_repo_var() {
    echo ""
    echo "Test 3: Uses \$STARFORGE_MAIN_REPO variable"

    set +e
    grep -q '\$STARFORGE_MAIN_REPO' templates/agents/senior-engineer.md
    local result=$?
    set -e

    assert_exit_code 0 $result "senior-engineer.md uses \$STARFORGE_MAIN_REPO"
}

# Test 4: Uses $STARFORGE_CLAUDE_DIR variable
test_senior_engineer_uses_claude_dir_var() {
    echo ""
    echo "Test 4: Uses \$STARFORGE_CLAUDE_DIR variable"

    set +e
    grep -q '\$STARFORGE_CLAUDE_DIR' templates/agents/senior-engineer.md
    local result=$?
    set -e

    assert_exit_code 0 $result "senior-engineer.md uses \$STARFORGE_CLAUDE_DIR"
}

# Test 5: Uses $STARFORGE_PROJECT_NAME variable
test_senior_engineer_uses_project_name_var() {
    echo ""
    echo "Test 5: Uses \$STARFORGE_PROJECT_NAME variable"

    set +e
    grep -q '\$STARFORGE_PROJECT_NAME' templates/agents/senior-engineer.md
    local result=$?
    set -e

    assert_exit_code 0 $result "senior-engineer.md uses \$STARFORGE_PROJECT_NAME"
}

# Test 6: Spike folder creation uses dynamic path
test_senior_engineer_spike_folder_dynamic() {
    echo ""
    echo "Test 6: Spike folder creation uses dynamic path"

    # Check that spike folder commands use $STARFORGE_MAIN_REPO (check context before and after)
    set +e
    grep -B 2 -A 5 "mkdir.*spikes" templates/agents/senior-engineer.md | grep -q '\$STARFORGE_MAIN_REPO'
    local result=$?
    set -e

    assert_exit_code 0 $result "Spike folder creation uses \$STARFORGE_MAIN_REPO"
}

# Test 7: Handoff protocol uses dynamic paths
test_senior_engineer_handoff_dynamic() {
    echo ""
    echo "Test 7: Handoff protocol uses dynamic paths"

    # Check that handoff protocol uses $STARFORGE_MAIN_REPO
    set +e
    grep -A 10 "Agent Handoff Protocol" templates/agents/senior-engineer.md | grep -q '\$STARFORGE_MAIN_REPO'
    local result=$?
    set -e

    assert_exit_code 0 $result "Handoff protocol uses \$STARFORGE_MAIN_REPO"
}

# Main test runner
main() {
    echo "========================================="
    echo "TDD Tests for Ticket #21"
    echo "Senior Engineer Agent Updates"
    echo "========================================="

    # Run all tests
    test_senior_engineer_no_hardcoded_paths
    test_senior_engineer_sources_project_env
    test_senior_engineer_uses_main_repo_var
    test_senior_engineer_uses_claude_dir_var
    test_senior_engineer_uses_project_name_var
    test_senior_engineer_spike_folder_dynamic
    test_senior_engineer_handoff_dynamic

    # Summary
    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo "========================================="

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    fi

    exit 0
}

# Run tests
main
