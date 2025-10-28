#!/bin/bash
# Test: Directory Structure Validation
#
# Tests the check_directory_structure() function for Task 2.2

set -e -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✓ PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "  Expected: $2"
    echo "  Got: $3"
}

run_test() {
    ((TESTS_RUN++))
    echo ""
    echo -e "${YELLOW}Test $TESTS_RUN:${NC} $1"
}

# Create a test environment
TEST_DIR=$(mktemp -d)
echo "Test directory: $TEST_DIR"
echo ""

# Source the starforge script to get check_directory_structure function
# We'll need to extract just the function since the script has exit points
source_check_directory_structure() {
    # Extract the check_directory_structure function from bin/starforge
    # This allows us to test it in isolation

    # Read the function definition
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # Check if function exists in bin/starforge
    if ! grep -q "check_directory_structure()" "$SCRIPT_DIR/bin/starforge" 2>/dev/null; then
        echo -e "${RED}❌ ERROR: check_directory_structure() function not found in bin/starforge${NC}"
        echo "This test requires the function to be implemented first (TDD will fail correctly)"
        return 1
    fi

    # Extract and source the function
    # Note: This is a safe way to test bash functions
    eval "$(sed -n '/^check_directory_structure()/,/^}/p' "$SCRIPT_DIR/bin/starforge")"
}

# TEST 1: Function exists (will fail initially - TDD red phase)
run_test "Function exists in bin/starforge"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if grep -q "check_directory_structure()" "$SCRIPT_DIR/bin/starforge" 2>/dev/null; then
    pass "check_directory_structure() function found"

    # Try to source it
    set +e  # Temporarily disable exit on error
    source_check_directory_structure 2>/dev/null
    if [ $? -eq 0 ]; then
        pass "Function can be sourced"
    else
        fail "Function cannot be sourced" "Sourceable function" "Source failed"
    fi
    set -e  # Re-enable exit on error
else
    fail "check_directory_structure() function not found" "Function exists in bin/starforge" "Not found"
fi

# TEST 2: Complete directory structure passes
run_test "Complete directory structure"
cd "$TEST_DIR"
mkdir -p .claude/{lib,bin,agents,hooks,scripts,triggers,logs}

set +e
source_check_directory_structure 2>/dev/null
if [ $? -eq 0 ]; then
    check_directory_structure 2>/dev/null
    if [ $? -eq 0 ]; then
        pass "Complete structure validated successfully"
    else
        fail "Complete structure validation failed" "Return 0" "Return 1"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Function not available yet"
fi
set -e

# TEST 3: Missing single directory detected
run_test "Missing single directory (.claude/triggers)"
cd "$TEST_DIR"
rm -rf .claude/triggers

set +e
source_check_directory_structure 2>/dev/null
if [ $? -eq 0 ]; then
    check_directory_structure 2>/dev/null
    if [ $? -eq 0 ]; then
        fail "Should detect missing directory" "Return 1" "Return 0"
    else
        pass "Missing directory detected correctly"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Function not available yet"
fi
set -e

# TEST 4: Missing multiple directories detected
run_test "Missing multiple directories"
cd "$TEST_DIR"
rm -rf .claude/{agents,scripts,hooks}

set +e
source_check_directory_structure 2>/dev/null
if [ $? -eq 0 ]; then
    check_directory_structure 2>/dev/null
    if [ $? -eq 0 ]; then
        fail "Should detect missing directories" "Return 1" "Return 0"
    else
        pass "Missing directories detected correctly"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Function not available yet"
fi
set -e

# TEST 5: Output format (complete structure)
run_test "Output format for complete structure"
cd "$TEST_DIR"
mkdir -p .claude/{lib,bin,agents,hooks,scripts,triggers,logs}

set +e
source_check_directory_structure 2>/dev/null
if [ $? -eq 0 ]; then
    output=$(check_directory_structure 2>&1)
    if echo "$output" | grep -q "✅.*Directory structure complete"; then
        pass "Correct success message displayed"
    else
        fail "Success message format incorrect" "✅ Directory structure complete" "$output"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Function not available yet"
fi
set -e

# TEST 6: Output format (missing directories)
run_test "Output format for missing directories"
cd "$TEST_DIR"
rm -rf .claude/triggers

set +e
source_check_directory_structure 2>/dev/null
if [ $? -eq 0 ]; then
    output=$(check_directory_structure 2>&1)
    if echo "$output" | grep -q "❌.*Directory structure incomplete"; then
        pass "Error message displayed"
    else
        fail "Error message not found" "❌ Directory structure incomplete" "$output"
    fi

    if echo "$output" | grep -q "Missing directories"; then
        pass "Missing directories section shown"
    else
        fail "Missing directories section not shown" "Missing directories:" "$output"
    fi

    if echo "$output" | grep -q ".claude/triggers"; then
        pass "Specific missing directory listed"
    else
        fail "Specific directory not listed" ".claude/triggers in output" "$output"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Function not available yet"
fi
set -e

# TEST 7: No .claude directory at all
run_test "No .claude directory"
cd "$TEST_DIR"
rm -rf .claude

set +e
source_check_directory_structure 2>/dev/null
if [ $? -eq 0 ]; then
    check_directory_structure 2>/dev/null
    if [ $? -eq 0 ]; then
        fail "Should detect missing .claude directory" "Return 1" "Return 0"
    else
        pass "Missing .claude directory detected"
    fi
else
    echo -e "${YELLOW}⊘ SKIP${NC}: Function not available yet"
fi
set -e

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
