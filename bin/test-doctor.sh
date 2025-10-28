#!/bin/bash
# Test suite for starforge doctor command

# Note: Do NOT use set -e - we need to capture failures for testing

# Colors for test output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_BIN="$SCRIPT_DIR/starforge"

# Test helper functions
pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}✗${NC} $1"
    if [ -n "$2" ]; then
        echo "  Expected: $2"
    fi
    if [ -n "$3" ]; then
        echo "  Got: $3"
    fi
}

run_test() {
    ((TESTS_RUN++))
}

echo "========================================"
echo "Testing starforge doctor command"
echo "========================================"
echo ""

# Create a temporary test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Initialize git repo
git init -q
git config user.email "test@test.com"
git config user.name "Test User"

# Create minimal .claude structure for tests
mkdir -p .claude/{agents,scripts,hooks,bin,triggers,coordination}

echo "Test directory: $TEST_DIR"
echo ""

# Test 1: Doctor command exists
run_test
echo "Test 1: Doctor command case handler exists"
if grep -q "doctor)" "$STARFORGE_BIN"; then
    pass "Doctor command case handler found"
else
    fail "Doctor command case handler not found"
fi
echo ""

# Test 2: run_doctor_checks function exists
run_test
echo "Test 2: run_doctor_checks function exists"
if grep -q "run_doctor_checks()" "$STARFORGE_BIN"; then
    pass "run_doctor_checks function found"
else
    fail "run_doctor_checks function not found"
fi
echo ""

# Test 3: Doctor command runs without error
run_test
echo "Test 3: Doctor command runs without error (basic structure)"
output=$(timeout 5 bash "$STARFORGE_BIN" doctor 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "Doctor command executed successfully"
else
    fail "Doctor command failed to execute" "exit code 0" "exit code $exit_code"
fi
echo ""

# Test 4: Doctor command shows header
run_test
echo "Test 4: Doctor command shows diagnostic header"
output=$(timeout 5 bash "$STARFORGE_BIN" doctor 2>&1)
if echo "$output" | grep -q "Running StarForge Doctor"; then
    pass "Doctor command shows header"
else
    fail "Doctor command missing header"
fi
echo ""

# Test 5: Doctor command shows completion message
run_test
echo "Test 5: Doctor command shows completion message"
output=$(timeout 5 bash "$STARFORGE_BIN" doctor 2>&1)
if echo "$output" | grep -q "All systems go\|Installation incomplete"; then
    pass "Doctor command shows completion message"
else
    fail "Doctor command missing completion message"
fi
echo ""

# Test 6: Doctor command returns exit code 0 when checks pass
run_test
echo "Test 6: Doctor command returns exit code 0 when checks pass"
output=$(timeout 5 bash "$STARFORGE_BIN" doctor 2>&1)
exit_code=$?
if [ $exit_code -eq 0 ]; then
    pass "Doctor command returns exit code 0"
else
    fail "Doctor command returns wrong exit code" "0" "$exit_code"
fi
echo ""

# Test 7: TODO comment exists for future automation
run_test
echo "Test 7: TODO comment for future automation exists"
if grep -q "TODO.*automation\|TODO.*Future enhancement" "$STARFORGE_BIN"; then
    pass "TODO comment for automation found"
else
    fail "TODO comment for automation not found"
fi
echo ""

# Test 8: Help text includes doctor command
run_test
echo "Test 8: Help text includes doctor command"
help_output=$(bash "$STARFORGE_BIN" help 2>&1)
if echo "$help_output" | grep -q "doctor"; then
    pass "Help text includes doctor command"
else
    fail "Help text missing doctor command"
fi
echo ""

# Cleanup
cd - > /dev/null
rm -rf "$TEST_DIR"

# Summary
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
