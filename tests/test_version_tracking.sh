#!/bin/bash
# Test suite for version tracking (Issue #69)
# Tests written FIRST following TDD methodology

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test utilities
pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    echo -e "${RED}  $2${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

# Setup test environment
setup_test_project() {
    local test_dir="/tmp/starforge-version-test-$$"
    rm -rf "$test_dir"
    mkdir -p "$test_dir"
    cd "$test_dir"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "# Test" > README.md
    git add .
    git commit -q -m "Initial commit"
    echo "$test_dir"
}

cleanup_test_project() {
    local test_dir="$1"
    cd /tmp
    rm -rf "$test_dir"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Version Tracking Tests (TDD)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: templates/VERSION exists
echo "Test 1: templates/VERSION file exists"
if [ -f "$PROJECT_ROOT/templates/VERSION" ]; then
    pass "templates/VERSION exists"
else
    fail "templates/VERSION exists" "File not found at $PROJECT_ROOT/templates/VERSION"
fi

# Test 2: templates/VERSION is valid JSON
echo "Test 2: templates/VERSION is valid JSON"
if [ -f "$PROJECT_ROOT/templates/VERSION" ]; then
    if jq empty "$PROJECT_ROOT/templates/VERSION" 2>/dev/null; then
        pass "templates/VERSION is valid JSON"
    else
        fail "templates/VERSION is valid JSON" "jq cannot parse file"
    fi
else
    fail "templates/VERSION is valid JSON" "File does not exist"
fi

# Test 3: templates/VERSION has required fields
echo "Test 3: templates/VERSION has required fields"
if [ -f "$PROJECT_ROOT/templates/VERSION" ]; then
    version=$(jq -r '.version' "$PROJECT_ROOT/templates/VERSION" 2>/dev/null)

    if [ "$version" = "1.0.0" ]; then
        pass "Version field is correct (1.0.0)"
    else
        fail "Version field is correct" "Expected 1.0.0, got: $version"
    fi
else
    fail "templates/VERSION has required fields" "File does not exist"
fi

# Test 4: install.sh has create_version_file function
echo "Test 4: install.sh has create_version_file function"
if grep -q "create_version_file" "$PROJECT_ROOT/bin/install.sh"; then
    pass "install.sh has create_version_file function"
else
    fail "install.sh has create_version_file function" "Function not found in install.sh"
fi

# Test 5: install.sh calls create_version_file
echo "Test 5: install.sh calls create_version_file"
if grep -q "create_version_file" "$PROJECT_ROOT/bin/install.sh"; then
    # Check if it's called in main function
    if grep -A 50 "^main()" "$PROJECT_ROOT/bin/install.sh" | grep -q "create_version_file"; then
        pass "install.sh calls create_version_file"
    else
        fail "install.sh calls create_version_file" "Function not called in main()"
    fi
else
    fail "install.sh calls create_version_file" "Function does not exist"
fi

# Test 6: starforge update backs up old version
echo "Test 6: starforge update has backup logic"
if grep -q "STARFORGE_VERSION.pre-update" "$PROJECT_ROOT/bin/starforge"; then
    pass "starforge update has backup logic"
else
    fail "starforge update has backup logic" "Backup code not found"
fi

# Test 7: starforge status displays version
echo "Test 7: starforge status displays version"
if grep -A 20 "status)" "$PROJECT_ROOT/bin/starforge" | grep -q "STARFORGE_VERSION"; then
    pass "starforge status has version display logic"
else
    fail "starforge status has version display logic" "Version display code not found"
fi

# Test 8: starforge status handles missing version
echo "Test 8: starforge status handles missing version gracefully"
if grep -A 20 "status)" "$PROJECT_ROOT/bin/starforge" | grep -q -i "unknown\|missing"; then
    pass "starforge status handles missing version"
else
    fail "starforge status handles missing version" "Graceful handling not found"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Results:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total:  $TESTS_RUN"
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
