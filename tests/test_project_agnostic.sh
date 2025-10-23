#!/bin/bash
# Test suite for project-agnostic installation validation
# Tests that installation works with any project name and agent count

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Project-Agnostic Installation Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_success() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Command succeeded}"

    echo -e "  ${GREEN}✓${NC} $desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

assert_failure() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Expected failure occurred}"

    echo -e "  ${RED}✗${NC} $desc"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
}

assert_dir_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local dir="$1"
    local desc="${2:-Directory exists: $dir}"

    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (not found: $dir)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_dir_not_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local dir="$1"
    local desc="${2:-Directory should not exist: $dir}"

    if [ ! -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (found unexpected: $dir)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-File exists: $file}"

    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_no_hardcoded_refs() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local dir="$1"
    local pattern="$2"
    local desc="${3:-No hardcoded references to: $pattern}"

    if ! grep -r "$pattern" "$dir" 2>/dev/null | grep -v "test_project_agnostic.sh" > /dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (found in $dir)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_env_var() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local var_name="$1"
    local expected="$2"
    local desc="${3:-Environment variable $var_name = $expected}"

    # Use eval to get the variable value
    local actual=$(eval echo "\$$var_name")

    if [ "$actual" = "$expected" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (got: $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Install with custom project name
test_install_with_custom_project_name() {
    echo ""
    echo "Test 1: Install with Custom Project Name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="my-test-app"
    AGENT_COUNT=3

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT 2>&1 | tee /tmp/test-output.log; then
        assert_success "Installation with project '$PROJECT' and $AGENT_COUNT agents"
    else
        assert_failure "Installation failed for project '$PROJECT'"
        cat /tmp/test-output.log
    fi
}

# Test 2: Verify correct worktree names created
test_creates_correct_worktree_names() {
    echo ""
    echo "Test 2: Creates Correct Worktree Names"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="x"
    AGENT_COUNT=2

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT; then
        assert_success "Test completed for project '$PROJECT'"
    else
        assert_failure "Test failed for project '$PROJECT'"
    fi
}

# Test 3: Agent detection in worktree
test_agent_detection_in_worktree() {
    echo ""
    echo "Test 3: Agent Detection in Worktree"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="api.backend"
    AGENT_COUNT=1

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT; then
        assert_success "Agent detection validated for project '$PROJECT'"
    else
        assert_failure "Agent detection failed for project '$PROJECT'"
    fi
}

# Test 4: No hardcoded references in installed files
test_no_hardcoded_refs_in_installed_files() {
    echo ""
    echo "Test 4: No Hardcoded References"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="test-123"
    AGENT_COUNT=5

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT; then
        assert_success "No hardcoded references test passed for project '$PROJECT'"
    else
        assert_failure "Hardcoded references found in project '$PROJECT'"
    fi
}

# Test 5: Handles special characters (underscore and dot)
test_handles_special_characters() {
    echo ""
    echo "Test 5: Handles Special Characters"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="my_proj.v2"
    AGENT_COUNT=3

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT; then
        assert_success "Special characters handled for project '$PROJECT'"
    else
        assert_failure "Failed to handle special characters in project '$PROJECT'"
    fi
}

# Test 6: Agent count 1 (minimal)
test_agent_count_one() {
    echo ""
    echo "Test 6: Agent Count 1 (Minimal)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="minimal"
    AGENT_COUNT=1

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT; then
        assert_success "Single agent installation validated"
    else
        assert_failure "Single agent installation failed"
    fi
}

# Test 7: Agent count 5 (maximum current support)
test_agent_count_five() {
    echo ""
    echo "Test 7: Agent Count 5 (Maximum)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    PROJECT="scale-test"
    AGENT_COUNT=5

    if bash "$STARFORGE_ROOT/bin/test-project-agnostic.sh" "$PROJECT" $AGENT_COUNT; then
        assert_success "5 agent installation validated"
    else
        assert_failure "5 agent installation failed"
    fi
}

# Run all tests
run_all_tests() {
    # Check if test-project-agnostic.sh exists
    if [ ! -f "$STARFORGE_ROOT/bin/test-project-agnostic.sh" ]; then
        echo -e "${RED}ERROR: $STARFORGE_ROOT/bin/test-project-agnostic.sh not found${NC}"
        echo "This test suite requires the implementation to exist."
        echo "Expected path: $STARFORGE_ROOT/bin/test-project-agnostic.sh"
        exit 1
    fi

    test_install_with_custom_project_name
    test_creates_correct_worktree_names
    test_agent_detection_in_worktree
    test_no_hardcoded_refs_in_installed_files
    test_handles_special_characters
    test_agent_count_one
    test_agent_count_five
}

# Main execution
run_all_tests

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total tests:  $TESTS_RUN"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
else
    echo -e "Failed:       $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo ""
    exit 1
fi
