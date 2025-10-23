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

# Test 1: Version file created on install
echo "Test 1: Version file created on install"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

if [ -f "$test_dir/.claude/STARFORGE_VERSION" ]; then
    pass "Version file exists after install"
else
    fail "Version file exists after install" "File not found at .claude/STARFORGE_VERSION"
fi
cleanup_test_project "$test_dir"

# Test 2: Version file is valid JSON
echo "Test 2: Version file is valid JSON"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

if jq empty "$test_dir/.claude/STARFORGE_VERSION" 2>/dev/null; then
    pass "Version file is valid JSON"
else
    fail "Version file is valid JSON" "jq cannot parse file"
fi
cleanup_test_project "$test_dir"

# Test 3: Version file has required fields
echo "Test 3: Version file has required fields"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

version=$(jq -r '.version' "$test_dir/.claude/STARFORGE_VERSION" 2>/dev/null)
installed_at=$(jq -r '.installed_at' "$test_dir/.claude/STARFORGE_VERSION" 2>/dev/null)
template_commit=$(jq -r '.template_commit' "$test_dir/.claude/STARFORGE_VERSION" 2>/dev/null)
components=$(jq -r '.components' "$test_dir/.claude/STARFORGE_VERSION" 2>/dev/null)

if [ "$version" = "1.0.0" ]; then
    pass "Version field is correct (1.0.0)"
else
    fail "Version field is correct" "Expected 1.0.0, got: $version"
fi

if [ -n "$installed_at" ] && [ "$installed_at" != "null" ]; then
    pass "installed_at field exists"
else
    fail "installed_at field exists" "Field is empty or null"
fi

if [ -n "$template_commit" ] && [ "$template_commit" != "null" ]; then
    pass "template_commit field exists"
else
    fail "template_commit field exists" "Field is empty or null"
fi

if [ -n "$components" ] && [ "$components" != "null" ]; then
    pass "components field exists"
else
    fail "components field exists" "Field is empty or null"
fi

cleanup_test_project "$test_dir"

# Test 4: Version updated on update
echo "Test 4: Version updated on update"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

initial_version=$(jq -r '.version' "$test_dir/.claude/STARFORGE_VERSION")

# Create new version in templates
mkdir -p "$PROJECT_ROOT/templates"
echo '{"version": "1.1.0"}' > "$PROJECT_ROOT/templates/VERSION"

cd "$test_dir"
"$PROJECT_ROOT/bin/starforge" update

new_version=$(jq -r '.version' "$test_dir/.claude/STARFORGE_VERSION" 2>/dev/null || echo "error")

if [ "$new_version" = "1.1.0" ]; then
    pass "Version updated from $initial_version to 1.1.0"
else
    fail "Version updated on update" "Expected 1.1.0, got: $new_version"
fi

# Cleanup temp VERSION file
rm -f "$PROJECT_ROOT/templates/VERSION"
cleanup_test_project "$test_dir"

# Test 5: Old version backed up before update
echo "Test 5: Old version backed up before update"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

initial_version=$(jq -r '.version' "$test_dir/.claude/STARFORGE_VERSION")

# Create new version in templates
mkdir -p "$PROJECT_ROOT/templates"
echo '{"version": "1.1.0"}' > "$PROJECT_ROOT/templates/VERSION"

cd "$test_dir"
"$PROJECT_ROOT/bin/starforge" update

if [ -f "$test_dir/.claude/STARFORGE_VERSION.pre-update" ]; then
    pre_update_version=$(jq -r '.version' "$test_dir/.claude/STARFORGE_VERSION.pre-update")
    if [ "$pre_update_version" = "$initial_version" ]; then
        pass "Old version backed up to .pre-update"
    else
        fail "Old version backed up correctly" "Backup has wrong version: $pre_update_version"
    fi
else
    fail "Old version backed up to .pre-update" "Backup file not found"
fi

rm -f "$PROJECT_ROOT/templates/VERSION"
cleanup_test_project "$test_dir"

# Test 6: Version displayed in status command
echo "Test 6: Version displayed in status command"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

cd "$test_dir"
output=$("$PROJECT_ROOT/bin/starforge" status 2>&1)

if echo "$output" | grep -q "StarForge v"; then
    pass "Version displayed in status command"
else
    fail "Version displayed in status command" "Version not found in output"
fi

cleanup_test_project "$test_dir"

# Test 7: Missing version file handled gracefully
echo "Test 7: Missing version file handled gracefully"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

rm "$test_dir/.claude/STARFORGE_VERSION"
cd "$test_dir"
output=$("$PROJECT_ROOT/bin/starforge" status 2>&1)

if echo "$output" | grep -q -i "unknown" || echo "$output" | grep -q -i "missing"; then
    pass "Missing version file handled gracefully"
else
    fail "Missing version file handled gracefully" "Expected graceful message, got error or crash"
fi

cleanup_test_project "$test_dir"

# Test 8: Version read performance (<100ms)
echo "Test 8: Version read performance (<100ms)"
test_dir=$(setup_test_project)
"$PROJECT_ROOT/bin/starforge" install <<EOF
y
3
n
3
y
EOF

cd "$test_dir"
start=$(date +%s%N)
jq -r '.version' "$test_dir/.claude/STARFORGE_VERSION" > /dev/null 2>&1
end=$(date +%s%N)

elapsed=$(( (end - start) / 1000000 ))  # Convert to ms

if [ $elapsed -lt 100 ]; then
    pass "Version read in ${elapsed}ms (target: <100ms)"
else
    fail "Version read performance" "Took ${elapsed}ms (target: <100ms)"
fi

cleanup_test_project "$test_dir"

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
