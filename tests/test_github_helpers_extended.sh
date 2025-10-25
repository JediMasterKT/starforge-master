#!/bin/bash
# Tests for new GitHub helper functions (Ticket #147)
# TDD: Write tests FIRST, then implement functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the helper script (will fail initially - TDD red phase)
source "$PROJECT_ROOT/templates/scripts/github-helpers.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper
assert_function_exists() {
    local func_name=$1
    TESTS_RUN=$((TESTS_RUN + 1))

    if declare -F "$func_name" > /dev/null; then
        echo "✅ Test $TESTS_RUN: Function $func_name exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "❌ Test $TESTS_RUN: Function $func_name does NOT exist"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_output_numeric() {
    local func_name=$1
    local result=$2
    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$result" =~ ^[0-9]+$ ]]; then
        echo "✅ Test $TESTS_RUN: $func_name returns numeric value: $result"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "❌ Test $TESTS_RUN: $func_name did NOT return numeric value: $result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_empty() {
    local func_name=$1
    local result=$2
    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -n "$result" ]; then
        echo "✅ Test $TESTS_RUN: $func_name returns non-empty result"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "❌ Test $TESTS_RUN: $func_name returned empty result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "======================================"
echo "GitHub Helpers Extended Tests (TDD)"
echo "======================================"
echo ""

# Test 1: get_in_progress_ticket_count exists
echo "Test Suite 1: get_in_progress_ticket_count"
assert_function_exists "get_in_progress_ticket_count"

if declare -F get_in_progress_ticket_count > /dev/null; then
    result=$(get_in_progress_ticket_count)
    assert_output_numeric "get_in_progress_ticket_count" "$result"
fi
echo ""

# Test 2: get_qa_approved_prs exists
echo "Test Suite 2: get_qa_approved_prs"
assert_function_exists "get_qa_approved_prs"

if declare -F get_qa_approved_prs > /dev/null; then
    result=$(get_qa_approved_prs)
    # Should return lines like "123|PR Title" or empty if no PRs
    echo "  Output: ${result:-<empty>}"
fi
echo ""

# Test 3: get_pr_line_changes exists
echo "Test Suite 3: get_pr_line_changes"
assert_function_exists "get_pr_line_changes"
echo ""

# Test 4: get_issue_priority exists
echo "Test Suite 4: get_issue_priority"
assert_function_exists "get_issue_priority"
echo ""

# Test 5: get_pr_author_agent exists
echo "Test Suite 5: get_pr_author_agent"
assert_function_exists "get_pr_author_agent"
echo ""

# Test 6: get_qa_declined_prs exists
echo "Test Suite 6: get_qa_declined_prs"
assert_function_exists "get_qa_declined_prs"

if declare -F get_qa_declined_prs > /dev/null; then
    result=$(get_qa_declined_prs)
    # Should return lines like "123|PR Title|author" or empty if no PRs
    echo "  Output: ${result:-<empty>}"
fi
echo ""

# Test 7: get_closed_today_count exists
echo "Test Suite 7: get_closed_today_count"
assert_function_exists "get_closed_today_count"

if declare -F get_closed_today_count > /dev/null; then
    result=$(get_closed_today_count)
    assert_output_numeric "get_closed_today_count" "$result"
fi
echo ""

# Test 8: get_qa_approved_pr_count exists (bonus helper for status reporting)
echo "Test Suite 8: get_qa_approved_pr_count"
assert_function_exists "get_qa_approved_pr_count"

if declare -F get_qa_approved_pr_count > /dev/null; then
    result=$(get_qa_approved_pr_count)
    assert_output_numeric "get_qa_approved_pr_count" "$result"
fi
echo ""

# Summary
echo "======================================"
echo "TEST SUMMARY"
echo "======================================"
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "✅ ALL TESTS PASSED"
    exit 0
else
    echo "❌ SOME TESTS FAILED"
    exit 1
fi
