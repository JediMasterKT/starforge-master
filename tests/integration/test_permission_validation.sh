#!/bin/bash
# tests/integration/test_permission_validation.sh
#
# Integration test for permission validation feature
#

set -e

# Export color variables for check_permissions function
export BLUE='\033[0;34m'
export GREEN='\033[0;32m'
export RED='\033[0;31m'
export YELLOW='\033[1;33m'
export NC='\033[0m'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
assert_success() {
    local test_name="$1"
    local command="$2"

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name"
        ((TESTS_FAILED++))
    fi
}

assert_failure() {
    local test_name="$1"
    local command="$2"

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${RED}✗ FAIL:${NC} $test_name (expected failure but succeeded)"
        ((TESTS_FAILED++))
    else
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        ((TESTS_PASSED++))
    fi
}

assert_contains() {
    local test_name="$1"
    local command="$2"
    local expected_text="$3"

    local output=$(eval "$command" 2>&1)
    if echo "$output" | grep -q "$expected_text"; then
        echo -e "${GREEN}✓ PASS:${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ FAIL:${NC} $test_name"
        echo "  Expected to find: $expected_text"
        echo "  Got output: $output" | head -5
        ((TESTS_FAILED++))
    fi
}

# Setup
echo "================================"
echo "Permission Validation Tests"
echo "================================"
echo ""

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_ROOT"

# Source the permission check function
source <(grep -A 60 "^check_permissions()" bin/install.sh)

echo "Test Suite: Permission Validation"
echo ""

# Test 1: Writable directory (happy path)
echo "Test 1: Writable directory"
TEST_DIR=$(mktemp -d)
assert_success "Writable directory should pass" "check_permissions '$TEST_DIR' 'test'"
rm -rf "$TEST_DIR"
echo ""

# Test 2: Read-only directory (error path)
echo "Test 2: Read-only directory"
TEST_DIR=$(mktemp -d)
chmod 444 "$TEST_DIR"
assert_failure "Read-only directory should fail" "check_permissions '$TEST_DIR' 'test'"
chmod 755 "$TEST_DIR"
rm -rf "$TEST_DIR"
echo ""

# Test 3: Non-existent directory with writable parent
echo "Test 3: Non-existent directory with writable parent"
TEST_DIR=$(mktemp -d)
NON_EXISTENT="$TEST_DIR/does-not-exist"
assert_success "Non-existent directory with writable parent should pass" "check_permissions '$NON_EXISTENT' 'test'"
rm -rf "$TEST_DIR"
echo ""

# Test 4: Non-existent directory with read-only parent
echo "Test 4: Non-existent directory with read-only parent"
TEST_DIR=$(mktemp -d)
chmod 444 "$TEST_DIR"
NON_EXISTENT="$TEST_DIR/does-not-exist"
assert_failure "Non-existent directory with read-only parent should fail" "check_permissions '$NON_EXISTENT' 'test'"
chmod 755 "$TEST_DIR"
rm -rf "$TEST_DIR"
echo ""

# Test 5: Error message includes current permissions
echo "Test 5: Error message shows current permissions"
TEST_DIR=$(mktemp -d)
chmod 444 "$TEST_DIR"
assert_contains "Error should show current permissions" \
    "check_permissions '$TEST_DIR' 'test'" \
    "Current permissions:"
chmod 755 "$TEST_DIR"
rm -rf "$TEST_DIR"
echo ""

# Test 6: Error message includes fix commands
echo "Test 6: Error message shows fix commands"
TEST_DIR=$(mktemp -d)
chmod 444 "$TEST_DIR"
assert_contains "Error should show fix command (chown)" \
    "check_permissions '$TEST_DIR' 'test'" \
    "sudo chown"
assert_contains "Error should show fix command (chmod)" \
    "check_permissions '$TEST_DIR' 'test'" \
    "chmod u+w"
chmod 755 "$TEST_DIR"
rm -rf "$TEST_DIR"
echo ""

# Test 7: Git worktree permission check
echo "Test 7: Git worktree permissions (if in git repo)"
if [ -d ".git" ] || [ -f ".git" ]; then
    # We're in a git repo, test should pass if we have write access
    assert_success "Git repo with write access should pass" "check_permissions '$(pwd)' 'test'"
else
    echo "  (Skipped - not in git repo)"
fi
echo ""

# Test 8: Integration with bin/starforge update
echo "Test 8: Integration with bin/starforge update"
# Create mock .claude directory
mkdir -p .claude/test
assert_contains "bin/starforge update should check permissions" \
    "bin/starforge update --force" \
    "Checking permissions"
rm -rf .claude
echo ""

# Test 9: Integration with bin/install.sh
echo "Test 9: Integration with bin/install.sh"
# This would require a full install test environment
# For now, verify the function is called in main()
if grep -q "check_permissions.*TARGET_DIR.*install" bin/install.sh; then
    echo -e "${GREEN}✓ PASS:${NC} bin/install.sh calls check_permissions"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL:${NC} bin/install.sh does not call check_permissions"
    ((TESTS_FAILED++))
fi
echo ""

# Test 10: Performance - permission check should be fast
echo "Test 10: Performance test"
TEST_DIR=$(mktemp -d)
START=$(date +%s%N)
check_permissions "$TEST_DIR" "test" > /dev/null 2>&1
END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))  # Convert to milliseconds

if [ "$DURATION" -lt 100 ]; then  # Should complete in <100ms
    echo -e "${GREEN}✓ PASS:${NC} Permission check completed in ${DURATION}ms (<100ms target)"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL:${NC} Permission check took ${DURATION}ms (>100ms)"
    ((TESTS_FAILED++))
fi
rm -rf "$TEST_DIR"
echo ""

# Summary
echo "================================"
echo "Test Results"
echo "================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
