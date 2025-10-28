#!/bin/bash
# Integration Test: Directory Structure Validation (Task 2.2)
#
# Tests check_directory_structure() function in real scenarios

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Integration Test: Directory Structure Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
TEST_DIR=$(mktemp -d)
echo "Test directory: $TEST_DIR"

# Copy starforge script to test directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cp "$SCRIPT_DIR/bin/starforge" "$TEST_DIR/starforge"

# TEST 1: Complete structure
echo ""
echo -e "${YELLOW}Test 1:${NC} Complete directory structure"
cd "$TEST_DIR"
mkdir -p .claude/{lib,bin,agents,hooks,scripts,triggers,logs}

# Extract and run just the check_directory_structure function
eval "$(sed -n '/^check_directory_structure()/,/^}/p' "$TEST_DIR/starforge")"
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if check_directory_structure > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}: Complete structure validated"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Should pass for complete structure"
    ((TESTS_FAILED++))
fi

# TEST 2: Missing single directory
echo ""
echo -e "${YELLOW}Test 2:${NC} Missing single directory (.claude/triggers)"
rm -rf .claude/triggers

if ! check_directory_structure > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}: Missing directory detected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Should fail for missing directory"
    ((TESTS_FAILED++))
fi

# TEST 3: Missing multiple directories
echo ""
echo -e "${YELLOW}Test 3:${NC} Missing multiple directories"
rm -rf .claude/{agents,scripts,hooks}

if ! check_directory_structure > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}: Missing directories detected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Should fail for missing directories"
    ((TESTS_FAILED++))
fi

# TEST 4: Output format (complete)
echo ""
echo -e "${YELLOW}Test 4:${NC} Output format for complete structure"
mkdir -p .claude/{lib,bin,agents,hooks,scripts,triggers,logs}

output=$(check_directory_structure 2>&1)
if echo "$output" | grep -q "✅.*Directory structure complete"; then
    echo -e "${GREEN}✓ PASS${NC}: Correct success message"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Wrong success message format"
    echo "Got: $output"
    ((TESTS_FAILED++))
fi

# TEST 5: Output format (missing)
echo ""
echo -e "${YELLOW}Test 5:${NC} Output format for missing directories"
rm -rf .claude/triggers

output=$(check_directory_structure 2>&1)
if echo "$output" | grep -q "❌.*Directory structure incomplete"; then
    echo -e "${GREEN}✓ PASS${NC}: Error message displayed"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Wrong error message"
    ((TESTS_FAILED++))
fi

if echo "$output" | grep -q ".claude/triggers"; then
    echo -e "${GREEN}✓ PASS${NC}: Missing directory listed"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Missing directory not listed"
    ((TESTS_FAILED++))
fi

# TEST 6: No .claude directory
echo ""
echo -e "${YELLOW}Test 6:${NC} No .claude directory at all"
rm -rf .claude

if ! check_directory_structure > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}: Missing .claude detected"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: Should fail for missing .claude"
    ((TESTS_FAILED++))
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some integration tests failed${NC}"
    exit 1
fi
