#!/bin/bash
# Test Suite for Junior Engineer Template
# Validates no hardcoded references remain

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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Junior Engineer Template Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper
assert_grep_fails() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local pattern="$1"
    local file="$2"
    local desc="$3"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Found hardcoded reference: $pattern"
        grep -n "$pattern" "$file" | head -3
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

assert_grep_succeeds() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local pattern="$1"
    local file="$2"
    local desc="$3"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Pattern not found: $pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run tests
TEMPLATE_FILE="$STARFORGE_ROOT/templates/agents/junior-engineer.md"

echo -e "${BLUE}Test 1: No hardcoded '~/empowerai' paths${NC}"
assert_grep_fails "~/empowerai" "$TEMPLATE_FILE" "Should not contain '~/empowerai' hardcoded paths"

echo ""
echo -e "${BLUE}Test 2: No hardcoded 'empowerai-' patterns${NC}"
assert_grep_fails "empowerai-junior-dev" "$TEMPLATE_FILE" "Should not contain 'empowerai-junior-dev' pattern"
assert_grep_fails "empowerai-/'" "$TEMPLATE_FILE" "Should not contain sed pattern 'empowerai-/'"

echo ""
echo -e "${BLUE}Test 3: Uses project-env.sh sourcing${NC}"
assert_grep_succeeds "source.*project-env.sh" "$TEMPLATE_FILE" "Should source project-env.sh"

echo ""
echo -e "${BLUE}Test 4: Uses STARFORGE_AGENT_ID variable${NC}"
assert_grep_succeeds '\$STARFORGE_AGENT_ID' "$TEMPLATE_FILE" "Should use \$STARFORGE_AGENT_ID variable"

echo ""
echo -e "${BLUE}Test 5: Uses STARFORGE_CLAUDE_DIR variable${NC}"
assert_grep_succeeds '\$STARFORGE_CLAUDE_DIR' "$TEMPLATE_FILE" "Should use \$STARFORGE_CLAUDE_DIR variable"

echo ""
echo -e "${BLUE}Test 6: Uses is_worktree function${NC}"
assert_grep_succeeds "is_worktree" "$TEMPLATE_FILE" "Should use is_worktree function"

echo ""
echo -e "${BLUE}Test 7: No noreply@empowerai.local email${NC}"
assert_grep_fails "noreply@empowerai.local" "$TEMPLATE_FILE" "Should not hardcode empowerai email domain"

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}Test Results${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Tests run:    $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
else
    echo -e "Tests failed: $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
