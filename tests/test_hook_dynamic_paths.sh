#!/bin/bash
# Test Suite for Hook Dynamic Path Updates (Ticket #26)
# TDD approach: Tests written FIRST, implementation follows

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$STARFORGE_ROOT/.test-tmp-hooks"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Hook Dynamic Paths Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_no_hardcoded_paths() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local pattern="$2"
    local desc="$3"

    if grep -q "$pattern" "$file"; then
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Found hardcoded pattern in $file:"
        grep "$pattern" "$file" | head -3
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

assert_sources_project_env() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="$2"

    if grep -q "source.*project-env.sh" "$file" || grep -q "\. .*project-env.sh" "$file"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    File does not source project-env.sh: $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_uses_dynamic_var() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local var_name="$2"
    local desc="$3"

    if grep -q "\$$var_name" "$file" || grep -q "\${$var_name}" "$file"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Variable $var_name not found in $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_hook_executable() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local hook_file="$1"
    local test_repo="$2"
    local desc="$3"

    cd "$test_repo"

    # Verify hook was installed
    if [ ! -x ".git/hooks/pre-commit" ]; then
        echo -e "  ${RED}✗${NC} $desc - Hook not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        cd - > /dev/null
        return 1
    fi

    # Try a dry run with sample JSON input
    # Hook logs to file, so check exit code instead
    local test_json='{"tool_input":{"file_path":"test.txt"},"cwd":"'"$test_repo"'"}'
    if echo "$test_json" | bash .git/hooks/pre-commit > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        cd - > /dev/null
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc - Hook returned non-zero exit code"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        cd - > /dev/null
        return 1
    fi
}

# Cleanup function
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

trap cleanup EXIT

# Setup test environment
mkdir -p "$TEST_DIR"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 1: block-main-edits.sh has no hardcoded "empowerai" references
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BLUE}Test 1: Verify no hardcoded 'empowerai' in block-main-edits.sh${NC}"
assert_no_hardcoded_paths \
    "$STARFORGE_ROOT/templates/hooks/block-main-edits.sh" \
    "empowerai" \
    "block-main-edits.sh should not contain hardcoded 'empowerai'"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 2: block-main-edits.sh sources project-env.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BLUE}Test 2: Verify block-main-edits.sh sources project-env.sh${NC}"
assert_sources_project_env \
    "$STARFORGE_ROOT/templates/hooks/block-main-edits.sh" \
    "block-main-edits.sh should source project-env.sh"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 3: block-main-edits.sh uses $STARFORGE_PROJECT_NAME
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BLUE}Test 3: Verify block-main-edits.sh uses STARFORGE_PROJECT_NAME${NC}"
assert_uses_dynamic_var \
    "$STARFORGE_ROOT/templates/hooks/block-main-edits.sh" \
    "STARFORGE_PROJECT_NAME" \
    "block-main-edits.sh should use \$STARFORGE_PROJECT_NAME variable"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 4: block-main-bash.sh has no hardcoded project names
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BLUE}Test 4: Verify no hardcoded paths in block-main-bash.sh${NC}"
assert_no_hardcoded_paths \
    "$STARFORGE_ROOT/templates/hooks/block-main-bash.sh" \
    "empowerai" \
    "block-main-bash.sh should not contain hardcoded 'empowerai'"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 5: Hook works in different project contexts
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BLUE}Test 5: Hook works in different project contexts${NC}"

# Create test project with different name
TEST_PROJECT="$TEST_DIR/my-test-project"
mkdir -p "$TEST_PROJECT"
cd "$TEST_PROJECT"
git init > /dev/null 2>&1

# Create .claude/lib directory and copy project-env.sh
mkdir -p .claude/lib
cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

# Install hooks
mkdir -p .git/hooks
cp "$STARFORGE_ROOT/templates/hooks/block-main-edits.sh" .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Test hook execution
assert_hook_executable \
    "$TEST_PROJECT/.git/hooks/pre-commit" \
    "$TEST_PROJECT" \
    "Hook should execute in project with different name"

cd "$STARFORGE_ROOT"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TEST 6: Hook uses dynamic project name variable
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo -e "${BLUE}Test 6: Hook uses dynamic project name in worktree detection${NC}"

# Verify that the hook checks for $STARFORGE_PROJECT_NAME-junior-dev pattern
# rather than hardcoded "empowerai-junior-dev"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q '\$STARFORGE_PROJECT_NAME-junior-dev-\[abc\]' "$STARFORGE_ROOT/templates/hooks/block-main-edits.sh"; then
    echo -e "  ${GREEN}✓${NC} Hook uses \$STARFORGE_PROJECT_NAME for worktree pattern matching"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Hook does not use \$STARFORGE_PROJECT_NAME for worktree detection"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Print Summary
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Total Tests: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
