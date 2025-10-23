#!/bin/bash
# Test Suite for Dynamic Agent Detection
# Tests detect_agent_id() with various agent configurations
# Following TDD: Tests written BEFORE implementation

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: '$expected'"
        echo "  Got:      '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup: Create temporary test directory structure
setup_test_env() {
    TEST_DIR=$(mktemp -d)
    echo "$TEST_DIR"
}

# Cleanup: Remove test directory
cleanup_test_env() {
    local test_dir="$1"
    rm -rf "$test_dir"
}

# Test the actual detect_agent_id function from project-env.sh
test_detect_agent_id() {
    local test_dir="$1"

    # Source the actual project-env.sh to get the detect_agent_id function
    # We need to extract just the function, not run the whole script
    (
        cd "$test_dir"
        # Extract and source just the detect_agent_id function
        eval "$(sed -n '/^detect_agent_id()/,/^}/p' "$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | cut -d' ' -f2)/templates/lib/project-env.sh" 2>/dev/null || sed -n '/^detect_agent_id()/,/^}/p' "$SCRIPT_DIR/../templates/lib/project-env.sh")"
        detect_agent_id
    )
}

# Get the directory where this test script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Test Suite: Dynamic Agent Detection"
echo "Testing CURRENT implementation in:"
echo "  templates/lib/project-env.sh"
echo "=========================================="
echo ""

# First, let's test the CURRENT (broken) implementation
echo "Phase 1: Testing CURRENT hardcoded implementation"
echo "Expected: Tests 4-8 should FAIL (proves bug exists)"
echo "=========================================="
echo ""

# TEST 1-3: Current implementation handles a, b, c (should PASS)
echo "Test Group 1: Standard 3-agent configuration"
echo "------------------------------------------"
TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/starforge-master-junior-dev-a"
result=$(test_detect_agent_id "$TEST_DIR/starforge-master-junior-dev-a")
assert_equals "junior-dev-a" "$result" "Detect junior-dev-a"
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/starforge-master-junior-dev-b"
result=$(test_detect_agent_id "$TEST_DIR/starforge-master-junior-dev-b")
assert_equals "junior-dev-b" "$result" "Detect junior-dev-b"
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/starforge-master-junior-dev-c"
result=$(test_detect_agent_id "$TEST_DIR/starforge-master-junior-dev-c")
assert_equals "junior-dev-c" "$result" "Detect junior-dev-c"
cleanup_test_env "$TEST_DIR"

echo ""
echo "Test Group 2: Extended configuration (5 agents)"
echo "Expected: FAIL (hardcoded implementation limitation)"
echo "------------------------------------------"

# TEST 4-5: Current implementation does NOT handle d, e (should FAIL - this is the bug!)
TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/starforge-master-junior-dev-d"
result=$(test_detect_agent_id "$TEST_DIR/starforge-master-junior-dev-d")
assert_equals "junior-dev-d" "$result" "Detect junior-dev-d (should FAIL with current code)" || true
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/starforge-master-junior-dev-e"
result=$(test_detect_agent_id "$TEST_DIR/starforge-master-junior-dev-e")
assert_equals "junior-dev-e" "$result" "Detect junior-dev-e (should FAIL with current code)" || true
cleanup_test_env "$TEST_DIR"

echo ""
echo "Test Group 3: Custom naming pattern"
echo "Expected: FAIL (hardcoded implementation limitation)"
echo "------------------------------------------"

# TEST 6-8: Custom naming should FAIL with current implementation
TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/myproject-dev-1"
result=$(test_detect_agent_id "$TEST_DIR/myproject-dev-1")
assert_equals "dev-1" "$result" "Detect dev-1 (should FAIL with current code)" || true
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/myproject-dev-2"
result=$(test_detect_agent_id "$TEST_DIR/myproject-dev-2")
assert_equals "dev-2" "$result" "Detect dev-2 (should FAIL with current code)" || true
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/myproject-dev-10"
result=$(test_detect_agent_id "$TEST_DIR/myproject-dev-10")
assert_equals "dev-10" "$result" "Detect dev-10 (should FAIL with current code)" || true
cleanup_test_env "$TEST_DIR"

echo ""
echo "Test Group 4: Main repo detection"
echo "------------------------------------------"

# TEST 9-10: Main repo detection (should PASS)
TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/starforge-master"
result=$(test_detect_agent_id "$TEST_DIR/starforge-master")
assert_equals "main" "$result" "Detect main repo"
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/random-project"
result=$(test_detect_agent_id "$TEST_DIR/random-project")
assert_equals "main" "$result" "Detect unknown directory as main"
cleanup_test_env "$TEST_DIR"

echo ""
echo "Test Group 5: Reduced configuration (2 agents only)"
echo "------------------------------------------"

# TEST 11-12: 2-agent setup (should PASS with current code)
TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/project-junior-dev-a"
result=$(test_detect_agent_id "$TEST_DIR/project-junior-dev-a")
assert_equals "junior-dev-a" "$result" "Detect junior-dev-a (2-agent setup)"
cleanup_test_env "$TEST_DIR"

TEST_DIR=$(setup_test_env)
mkdir -p "$TEST_DIR/project-junior-dev-b"
result=$(test_detect_agent_id "$TEST_DIR/project-junior-dev-b")
assert_equals "junior-dev-b" "$result" "Detect junior-dev-b (2-agent setup)"
cleanup_test_env "$TEST_DIR"

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Total:  $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo -e "${YELLOW}This is EXPECTED. These failures demonstrate the bug.${NC}"
    echo "The hardcoded implementation fails for:"
    echo "  - Agents beyond a, b, c (e.g., d, e)"
    echo "  - Custom naming patterns (e.g., dev-1, dev-2)"
    echo ""
    echo "Next: Implement dynamic detection to fix these failures."
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
