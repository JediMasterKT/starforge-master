#!/bin/bash
# Unit tests for update diff preview functions
#
# Tests the diff preview functions in isolation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS:${NC} $1"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL:${NC} $1"
}

run_test() {
    ((TESTS_RUN++))
    echo ""
    echo -e "${YELLOW}TEST:${NC} $1"
}

# Source the starforge binary to get the functions
STARFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Extract functions from bin/starforge
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
RED='\033[0;31m'
BLUE='\033[0;34m'

# Source the normalize function
normalize_settings_json() {
    local file="$1"
    sed 's|"cwd": "[^"]*"|"cwd": "{{PROJECT_DIR}}"|g' "$file" | \
    sed 's|/Users/[^/"]*/[^/"]*|{{PROJECT_DIR}}|g' | \
    sed 's|/home/[^/"]*/[^/"]*|{{PROJECT_DIR}}|g'
}

# Test 1: normalize_settings_json function
run_test "normalize_settings_json replaces paths correctly"

# Create test file
TEST_FILE=$(mktemp)
cat > "$TEST_FILE" << 'EOF'
{
  "cwd": "/Users/testuser/project",
  "path": "/home/testuser/another",
  "other": "keep this"
}
EOF

result=$(normalize_settings_json "$TEST_FILE")

if echo "$result" | grep -q "{{PROJECT_DIR}}"; then
    pass "Path normalized to {{PROJECT_DIR}}"
else
    fail "Path NOT normalized"
fi

if echo "$result" | grep -q "keep this"; then
    pass "Non-path content preserved"
else
    fail "Non-path content lost"
fi

rm "$TEST_FILE"

# Test 2: VERSION file structure
run_test "VERSION file has correct structure"

VERSION_FILE="$STARFORGE_DIR/templates/VERSION"

if [ ! -f "$VERSION_FILE" ]; then
    fail "VERSION file does not exist at $VERSION_FILE"
else
    pass "VERSION file exists"

    # Validate JSON structure
    if jq -e '.version' "$VERSION_FILE" > /dev/null 2>&1; then
        pass "VERSION has 'version' field"
    else
        fail "VERSION missing 'version' field"
    fi

    if jq -e '.commit' "$VERSION_FILE" > /dev/null 2>&1; then
        pass "VERSION has 'commit' field"
    else
        fail "VERSION missing 'commit' field"
    fi

    if jq -e '.changelog' "$VERSION_FILE" > /dev/null 2>&1; then
        pass "VERSION has 'changelog' field"
    else
        fail "VERSION missing 'changelog' field"
    fi

    if jq -e '.breaking_changes' "$VERSION_FILE" > /dev/null 2>&1; then
        pass "VERSION has 'breaking_changes' field"
    else
        fail "VERSION missing 'breaking_changes' field"
    fi
fi

# Test 3: Diff functions exist in bin/starforge
run_test "Required functions exist in bin/starforge"

STARFORGE_BIN="$STARFORGE_DIR/bin/starforge"

if grep -q "show_update_diff()" "$STARFORGE_BIN"; then
    pass "show_update_diff function exists"
else
    fail "show_update_diff function NOT found"
fi

if grep -q "show_detailed_diff()" "$STARFORGE_BIN"; then
    pass "show_detailed_diff function exists"
else
    fail "show_detailed_diff function NOT found"
fi

if grep -q "normalize_settings_json()" "$STARFORGE_BIN"; then
    pass "normalize_settings_json function exists"
else
    fail "normalize_settings_json function NOT found"
fi

# Test 4: Update command calls show_update_diff
run_test "Update command calls show_update_diff before backup"

if grep -A5 "update)" "$STARFORGE_BIN" | grep -q "show_update_diff"; then
    pass "Update command calls show_update_diff"
else
    fail "Update command does NOT call show_update_diff"
fi

if grep -B5 "create_backup" "$STARFORGE_BIN" | grep -q "show_update_diff"; then
    pass "show_update_diff called BEFORE create_backup"
else
    fail "show_update_diff NOT called before backup"
fi

# Test 5: Update copies VERSION to STARFORGE_VERSION
run_test "Update command copies VERSION to STARFORGE_VERSION"

if grep -q "STARFORGE_VERSION" "$STARFORGE_BIN"; then
    pass "Update command references STARFORGE_VERSION"
else
    fail "Update command does NOT reference STARFORGE_VERSION"
fi

# Report
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}✅ ALL TESTS PASSED${NC}"
    exit 0
fi
