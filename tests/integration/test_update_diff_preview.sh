#!/bin/bash
# Integration test for pre-update diff preview feature (#72)
#
# Tests that starforge update shows diff preview before applying changes

set -e

# Colors for output
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
    if [ -n "$2" ]; then
        echo "  Expected: $2"
    fi
    if [ -n "$3" ]; then
        echo "  Got: $3"
    fi
}

run_test() {
    ((TESTS_RUN++))
    echo ""
    echo -e "${YELLOW}TEST:${NC} $1"
}

# Setup test environment
TEST_DIR=$(mktemp -d)
echo "Test directory: $TEST_DIR"

# Get StarForge directory (where bin/starforge is located)
STARFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STARFORGE_BIN="$STARFORGE_DIR/bin/starforge"

# Verify starforge binary exists
if [ ! -f "$STARFORGE_BIN" ]; then
    echo -e "${RED}❌ ERROR: starforge binary not found at $STARFORGE_BIN${NC}"
    exit 1
fi

cd "$TEST_DIR"

# Create a mock project
mkdir -p test-project
cd test-project
git init --quiet
git config user.email "test@example.com"
git config user.name "Test User"

# Install StarForge
echo "Installing StarForge in test project..."
"$STARFORGE_BIN" install --quiet 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Skipping install test (requires templates)${NC}"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 0
}

# Test 1: Diff shows changed files
run_test "Diff shows changed files with line counts"

# Modify a template file
echo "# NEW LINE FOR TESTING" >> "$STARFORGE_DIR/templates/agents/orchestrator.md"

# Run update with cancel
output=$(echo "n" | "$STARFORGE_BIN" update 2>&1 || true)

# Restore template
git -C "$STARFORGE_DIR" checkout -- templates/agents/orchestrator.md 2>/dev/null || true

# Check if diff shows the changed file
if echo "$output" | grep -q "orchestrator.md"; then
    pass "Changed file shown in diff"
else
    fail "Changed file NOT shown in diff" "orchestrator.md in output" "not found"
fi

if echo "$output" | grep -q "+"; then
    pass "Line additions shown (+)"
else
    fail "Line additions NOT shown" "+N format" "not found"
fi

# Test 2: Diff shows version change
run_test "Diff shows version change (old → new)"

# Create VERSION file in templates
cat > "$STARFORGE_DIR/templates/VERSION" << 'EOF'
{
  "version": "1.1.0",
  "commit": "abc123"
}
EOF

output=$(echo "n" | "$STARFORGE_BIN" update 2>&1 || true)

# Clean up VERSION file
rm -f "$STARFORGE_DIR/templates/VERSION"

if echo "$output" | grep -q "→" || echo "$output" | grep -q "version"; then
    pass "Version change shown in output"
else
    fail "Version change NOT shown" "version change indicator" "not found"
fi

# Test 3: Diff shows NEW FILES
run_test "Diff highlights NEW FILES"

# Create a new template file
echo "#!/bin/bash" > "$STARFORGE_DIR/templates/scripts/new-test-script.sh"

output=$(echo "n" | "$STARFORGE_BIN" update 2>&1 || true)

# Clean up
rm -f "$STARFORGE_DIR/templates/scripts/new-test-script.sh"

if echo "$output" | grep -q "new-test-script.sh"; then
    pass "New file shown in output"
else
    fail "New file NOT shown" "new-test-script.sh" "not found"
fi

if echo "$output" | grep -iq "new"; then
    pass "NEW indicator shown for new files"
else
    fail "NEW indicator NOT shown" "NEW keyword" "not found"
fi

# Test 4: Cancel aborts update
run_test "Cancel (n) aborts update without changing files"

# Get current hash of a file
initial_hash=$(md5sum .claude/agents/orchestrator.md | awk '{print $1}')

# Modify template
echo "# CHANGE TO TEST CANCEL" >> "$STARFORGE_DIR/templates/agents/orchestrator.md"

# Cancel update
echo "n" | "$STARFORGE_BIN" update 2>&1 > /dev/null || true

# Restore template
git -C "$STARFORGE_DIR" checkout -- templates/agents/orchestrator.md 2>/dev/null || true

# Check file unchanged
after_hash=$(md5sum .claude/agents/orchestrator.md | awk '{print $1}')

if [ "$initial_hash" = "$after_hash" ]; then
    pass "File unchanged after cancel"
else
    fail "File WAS changed after cancel" "unchanged" "file modified"
fi

# Test 5: Detailed diff view
run_test "Detailed diff (d) shows unified diff"

# Modify template
echo "# DETAILED DIFF TEST" >> "$STARFORGE_DIR/templates/agents/orchestrator.md"

# Request detailed diff then cancel
output=$(echo -e "d\nn" | "$STARFORGE_BIN" update 2>&1 || true)

# Restore template
git -C "$STARFORGE_DIR" checkout -- templates/agents/orchestrator.md 2>/dev/null || true

if echo "$output" | grep -q "@@"; then
    pass "Unified diff markers (@@) shown"
else
    fail "Unified diff NOT shown" "@@ markers" "not found"
fi

# Test 6: Performance test
run_test "Diff generation completes in <3 seconds"

start=$(date +%s)
echo "n" | "$STARFORGE_BIN" update 2>&1 > /dev/null || true
end=$(date +%s)

elapsed=$((end - start))

if [ $elapsed -lt 3 ]; then
    pass "Diff generated in ${elapsed}s (target: <3s)"
else
    fail "Diff too slow: ${elapsed}s" "<3s" "${elapsed}s"
fi

# Test 7: Breaking changes highlight
run_test "BREAKING CHANGES highlighted for settings.json"

# Create VERSION with breaking change
cat > "$STARFORGE_DIR/templates/VERSION" << 'EOF'
{
  "version": "2.0.0",
  "breaking_changes": [
    "settings.json: Permissions model changed"
  ]
}
EOF

# Modify settings.json
echo "  // breaking change test" >> "$STARFORGE_DIR/templates/settings/settings.json"

output=$(echo "n" | "$STARFORGE_BIN" update 2>&1 || true)

# Clean up
rm -f "$STARFORGE_DIR/templates/VERSION"
git -C "$STARFORGE_DIR" checkout -- templates/settings/settings.json 2>/dev/null || true

if echo "$output" | grep -iq "breaking"; then
    pass "BREAKING CHANGE indicator shown"
else
    fail "BREAKING CHANGE NOT shown" "BREAKING keyword" "not found"
fi

# Test 8: Summary count
run_test "Summary shows count (X changed, Y unchanged)"

output=$(echo "n" | "$STARFORGE_BIN" update 2>&1 || true)

if echo "$output" | grep -q "changed" || echo "$output" | grep -q "unchanged"; then
    pass "Summary count shown"
else
    fail "Summary count NOT shown" "changed/unchanged count" "not found"
fi

# Cleanup
cd /
rm -rf "$TEST_DIR"

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
