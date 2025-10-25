#!/bin/bash
# Test for new github-helpers.sh function: get_backlog_ticket_count
# TDD approach: Write test FIRST, then implement

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 GitHub Helpers New Function Test (get_backlog_ticket_count)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Source the helper library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
HELPERS_FILE="$STARFORGE_ROOT/templates/scripts/github-helpers.sh"

if [ ! -f "$HELPERS_FILE" ]; then
    echo -e "${RED}✗${NC} github-helpers.sh not found at $HELPERS_FILE"
    exit 1
fi

source "$HELPERS_FILE"

# Test: get_backlog_ticket_count function exists
echo "Test 1: get_backlog_ticket_count function exists"
TESTS_RUN=$((TESTS_RUN + 1))
if type get_backlog_ticket_count &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Function exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Function does not exist"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test: Function returns numeric value or 0
echo ""
echo "Test 2: get_backlog_ticket_count returns numeric value"
TESTS_RUN=$((TESTS_RUN + 1))
result=$(get_backlog_ticket_count 2>/dev/null || echo "0")
if [[ "$result" =~ ^[0-9]+$ ]]; then
    echo -e "  ${GREEN}✓${NC} Returns numeric value: $result"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Does not return numeric value: $result"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test: get_latest_issue_number function exists
echo ""
echo "Test 3: get_latest_issue_number function exists"
TESTS_RUN=$((TESTS_RUN + 1))
if type get_latest_issue_number &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Function exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Function does not exist"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "Failed: 0"
fi
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

exit 0
