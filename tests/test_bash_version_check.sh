#!/bin/bash
# Test suite for Bash version checking
# Tests the version_compare() function and version detection logic

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Import the version_compare function from bin/starforge
# Extract just the function for testing
version_compare() {
    local ver1=$1
    local ver2=$2

    # Split versions into array
    IFS='.' read -ra VER1 <<< "$ver1"
    IFS='.' read -ra VER2 <<< "$ver2"

    # Compare major version
    if [ "${VER1[0]}" -lt "${VER2[0]}" ]; then
        return 1  # ver1 < ver2
    elif [ "${VER1[0]}" -gt "${VER2[0]}" ]; then
        return 0  # ver1 > ver2
    fi

    # Major versions equal, compare minor
    if [ "${VER1[1]:-0}" -lt "${VER2[1]:-0}" ]; then
        return 1  # ver1 < ver2
    fi

    return 0  # ver1 >= ver2
}

# Test helper functions
assert_pass() {
    local test_name="$1"
    local ver1="$2"
    local ver2="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if version_compare "$ver1" "$ver2"; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name ($ver1 >= $ver2)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name ($ver1 >= $ver2) - Expected pass, got fail"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_fail() {
    local test_name="$1"
    local ver1="$2"
    local ver2="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if ! version_compare "$ver1" "$ver2"; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name ($ver1 < $ver2)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name ($ver1 < $ver2) - Expected fail, got pass"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test: Equal versions
test_version_compare_equal() {
    echo ""
    echo "=== Testing Equal Versions ==="
    assert_pass "Equal major.minor (4.0 == 4.0)" "4.0" "4.0"
    assert_pass "Equal major.minor.patch (5.2.1 == 5.2)" "5.2.1" "5.2"
    assert_pass "Equal major (3 == 3.0)" "3" "3.0"
}

# Test: Greater versions (should pass)
test_version_compare_greater() {
    echo ""
    echo "=== Testing Greater Versions ==="
    assert_pass "Greater major (5.0 >= 4.0)" "5.0" "4.0"
    assert_pass "Greater minor (4.1 >= 4.0)" "4.1" "4.0"
    assert_pass "Greater patch (4.0.1 >= 4.0)" "4.0.1" "4.0"
    assert_pass "Much greater (10.0 >= 4.0)" "10.0" "4.0"
    assert_pass "Greater minor with patch (5.2.15 >= 5.1)" "5.2.15" "5.1"
}

# Test: Lesser versions (should fail)
test_version_compare_less() {
    echo ""
    echo "=== Testing Lesser Versions ==="
    assert_fail "Lesser major (3.2 < 4.0)" "3.2" "4.0"
    assert_fail "Lesser minor (4.0 < 4.1)" "4.0" "4.1"
    # Note: version_compare only checks major.minor, not patch
    # So 4.0.0 and 4.0.1 are treated as equal (both 4.0)
    # This is intentional - StarForge only requires 4.0+
    assert_pass "Patch ignored (4.0.0 == 4.0.1 for comparison)" "4.0.0" "4.0.1"
    assert_fail "Much lesser (2.0 < 4.0)" "2.0" "4.0"
    assert_fail "Lesser minor with patch (3.2.57 < 4.0)" "3.2.57" "4.0"
}

# Test: Edge cases
test_edge_cases() {
    echo ""
    echo "=== Testing Edge Cases ==="
    assert_pass "Single digit major (5 >= 4.0)" "5" "4.0"
    assert_fail "Single digit lesser (3 < 4.0)" "3" "4.0"
    assert_pass "Missing minor treated as 0 (4.0 >= 4)" "4.0" "4"
    assert_pass "Both missing minor (4 >= 4)" "4" "4"
    assert_pass "Large version numbers (100.200 >= 4.0)" "100.200" "4.0"
}

# Test: Real-world scenarios
test_real_world_scenarios() {
    echo ""
    echo "=== Testing Real-World Scenarios ==="
    assert_fail "macOS default Bash (3.2 < 4.0)" "3.2" "4.0"
    assert_fail "macOS Bash 3.2.57 (3.2.57 < 4.0)" "3.2.57" "4.0"
    assert_pass "Homebrew Bash (5.0 >= 4.0)" "5.0" "4.0"
    assert_pass "Modern Bash (5.2.15 >= 4.0)" "5.2.15" "4.0"
    assert_pass "Ubuntu default (4.4 >= 4.0)" "4.4" "4.0"
    assert_pass "Minimum required (4.0 >= 4.0)" "4.0" "4.0"
}

# Test: Current Bash version detection
test_current_bash_version_detected() {
    echo ""
    echo "=== Testing Current Bash Version Detection ==="

    TESTS_RUN=$((TESTS_RUN + 1))

    # Extract version from BASH_VERSION (same logic as in bin/starforge)
    BASH_VERSION_CURRENT="${BASH_VERSION%%[^0-9.]*}"

    if [[ "$BASH_VERSION_CURRENT" =~ ^[0-9]+\.[0-9]+ ]]; then
        echo -e "${GREEN}✅ PASS${NC}: Current Bash version detected: $BASH_VERSION_CURRENT"
        TESTS_PASSED=$((TESTS_PASSED + 1))

        # Also test that current version passes or fails correctly
        if version_compare "$BASH_VERSION_CURRENT" "4.0"; then
            echo -e "${GREEN}✅ INFO${NC}: Current Bash ($BASH_VERSION_CURRENT) meets StarForge requirement (>=4.0)"
        else
            echo -e "${YELLOW}⚠️  INFO${NC}: Current Bash ($BASH_VERSION_CURRENT) does NOT meet StarForge requirement (>=4.0)"
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Could not detect valid Bash version from: $BASH_VERSION"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: Platform detection
test_platform_detection() {
    echo ""
    echo "=== Testing Platform Detection ==="

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}: Platform detected as macOS (OSTYPE=$OSTYPE)"
        echo -e "${GREEN}   INFO${NC}: Would show Homebrew installation instructions"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [[ "$OSTYPE" == "linux"* ]] || [[ "$OSTYPE" == "gnu"* ]]; then
        echo -e "${GREEN}✅ PASS${NC}: Platform detected as Linux (OSTYPE=$OSTYPE)"
        echo -e "${GREEN}   INFO${NC}: Would show apt-get/yum installation instructions"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠️  WARN${NC}: Unknown platform (OSTYPE=$OSTYPE)"
        echo -e "${YELLOW}   INFO${NC}: Would show generic Linux instructions"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
}

# Test: Bash version check integration
test_bash_version_check_integration() {
    echo ""
    echo "=== Testing Integration with bin/starforge ==="

    TESTS_RUN=$((TESTS_RUN + 1))

    # Check that bin/starforge contains the version check
    if grep -q "BASH_VERSION_REQUIRED=" "$(dirname "$0")/../bin/starforge"; then
        echo -e "${GREEN}✅ PASS${NC}: bin/starforge contains BASH_VERSION_REQUIRED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: bin/starforge missing BASH_VERSION_REQUIRED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    TESTS_RUN=$((TESTS_RUN + 1))

    # Check that version_compare function exists in bin/starforge
    if grep -q "version_compare()" "$(dirname "$0")/../bin/starforge"; then
        echo -e "${GREEN}✅ PASS${NC}: bin/starforge contains version_compare() function"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: bin/starforge missing version_compare() function"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    TESTS_RUN=$((TESTS_RUN + 1))

    # Check that version check happens before 'set -e'
    # Get line number of 'set -e' and 'version_compare'
    local set_e_line=$(grep -n "^set -e" "$(dirname "$0")/../bin/starforge" | head -1 | cut -d: -f1)
    local version_check_line=$(grep -n "version_compare()" "$(dirname "$0")/../bin/starforge" | head -1 | cut -d: -f1)

    if [ -n "$set_e_line" ] && [ -n "$version_check_line" ] && [ "$version_check_line" -lt "$set_e_line" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Version check (line $version_check_line) occurs before 'set -e' (line $set_e_line)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Version check should occur before 'set -e'"
        echo "   version_compare at line: $version_check_line"
        echo "   set -e at line: $set_e_line"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Running Bash Version Check Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

test_version_compare_equal
test_version_compare_greater
test_version_compare_less
test_edge_cases
test_real_world_scenarios
test_current_bash_version_detected
test_platform_detection
test_bash_version_check_integration

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total Tests:   $TESTS_RUN"
echo -e "${GREEN}Passed:        $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed:        $TESTS_FAILED${NC}"
else
    echo "Failed:        $TESTS_FAILED"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit with proper code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
