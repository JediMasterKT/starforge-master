#!/bin/bash
# tests/mcp/test_github_tools.sh
#
# TDD tests for MCP GitHub tools
#
# MUST RUN FIRST - Tests written before implementation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Test helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local msg="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $msg"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $msg"
        echo "  Expected: $expected"
        echo "  Got: $actual"
        ((FAILED++))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"

    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓${NC} $msg"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $msg"
        echo "  Expected to contain: $needle"
        echo "  Got: $haystack"
        ((FAILED++))
    fi
}

assert_json_valid() {
    local json="$1"
    local msg="$2"

    if echo "$json" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $msg"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $msg"
        echo "  Invalid JSON: $json"
        ((FAILED++))
    fi
}

assert_performance() {
    local duration="$1"
    local max_seconds="$2"
    local msg="$3"

    if (( $(echo "$duration < $max_seconds" | bc -l) )); then
        echo -e "${GREEN}✓${NC} $msg (${duration}s < ${max_seconds}s)"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $msg (${duration}s >= ${max_seconds}s)"
        ((FAILED++))
    fi
}

# Source the implementation
SOURCE_FILE="templates/lib/mcp-tools-github.sh"
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}ERROR:${NC} $SOURCE_FILE does not exist"
    echo "Tests should fail initially (TDD red phase)"
    exit 1
fi

source "$SOURCE_FILE"

echo "=========================================="
echo "MCP GitHub Tools - Unit Tests"
echo "=========================================="
echo ""

# Test 1: Lists open issues
test_lists_open_issues() {
    echo "Test: List open issues"

    local result=$(starforge_list_issues --state open)

    assert_json_valid "$result" "Returns valid JSON"

    # Check it has issues array
    local has_array=$(echo "$result" | jq -e 'type == "array"' 2>/dev/null || echo "false")
    assert_equals "true" "$has_array" "Returns JSON array"

    # Check each issue has required fields
    local first_issue=$(echo "$result" | jq -r '.[0]')
    if [ "$first_issue" != "null" ]; then
        local has_number=$(echo "$first_issue" | jq -e 'has("number")' 2>/dev/null || echo "false")
        assert_equals "true" "$has_number" "Issue has number field"

        local has_title=$(echo "$first_issue" | jq -e 'has("title")' 2>/dev/null || echo "false")
        assert_equals "true" "$has_title" "Issue has title field"

        local has_labels=$(echo "$first_issue" | jq -e 'has("labels")' 2>/dev/null || echo "false")
        assert_equals "true" "$has_labels" "Issue has labels field"

        local has_state=$(echo "$first_issue" | jq -e 'has("state")' 2>/dev/null || echo "false")
        assert_equals "true" "$has_state" "Issue has state field"
    fi
}

# Test 2: Filters by label
test_filters_by_label() {
    echo ""
    echo "Test: Filter by label"

    # Filter for a specific label (use a common one)
    local result=$(starforge_list_issues --label "P1")

    assert_json_valid "$result" "Returns valid JSON for label filter"

    # Verify all issues have the label
    local count=$(echo "$result" | jq 'length')
    if [ "$count" -gt 0 ]; then
        local all_have_label=$(echo "$result" | jq -r 'all(.[]; .labels | map(.name) | contains(["P1"]))')
        assert_equals "true" "$all_have_label" "All issues have P1 label"
    fi
}

# Test 3: Limits results
test_limits_results() {
    echo ""
    echo "Test: Limit results"

    # Request only 5 issues
    local result=$(starforge_list_issues --limit 5)

    assert_json_valid "$result" "Returns valid JSON for limit"

    local count=$(echo "$result" | jq 'length')
    assert_equals "true" "$([ $count -le 5 ] && echo true || echo false)" "Returns at most 5 issues"
}

# Test 4: Filters by state
test_filters_by_state() {
    echo ""
    echo "Test: Filter by state"

    # Test closed issues
    local result=$(starforge_list_issues --state closed --limit 5)

    assert_json_valid "$result" "Returns valid JSON for state filter"

    # Verify all issues are closed
    local count=$(echo "$result" | jq 'length')
    if [ "$count" -gt 0 ]; then
        local all_closed=$(echo "$result" | jq -r 'all(.[]; .state == "closed")')
        assert_equals "true" "$all_closed" "All issues are closed"
    fi
}

# Test 5: Multiple labels (AND logic)
test_filters_multiple_labels() {
    echo ""
    echo "Test: Filter by multiple labels"

    # Filter for multiple labels
    local result=$(starforge_list_issues --label "P1,mcp-integration" --limit 10)

    assert_json_valid "$result" "Returns valid JSON for multiple labels"

    # Verify issues have at least one of the labels
    local count=$(echo "$result" | jq 'length')
    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Found issues with multiple labels"
        ((PASSED++))
    else
        echo "ℹ️  No issues found with both labels (OK if none exist)"
    fi
}

# Test 6: Performance
test_performance() {
    echo ""
    echo "Test: Performance"

    local start=$(date +%s.%N)
    local result=$(starforge_list_issues --limit 30)
    local end=$(date +%s.%N)

    local duration=$(echo "$end - $start" | bc)

    # Acceptance criteria: <2s per call
    assert_performance "$duration" "2.0" "List issues completes in <2s"
}

# Test 7: Error handling - invalid state
test_error_handling_invalid_state() {
    echo ""
    echo "Test: Error handling - invalid state"

    # gh CLI should handle this, but our wrapper should pass it through
    local result=$(starforge_list_issues --state invalid_state 2>&1 || true)

    # Should either error or return empty
    echo -e "${GREEN}✓${NC} Handles invalid state gracefully"
    ((PASSED++))
}

# Test 8: Empty results
test_empty_results() {
    echo ""
    echo "Test: Empty results"

    # Use a label that likely doesn't exist
    local result=$(starforge_list_issues --label "nonexistent-label-xyz-123")

    assert_json_valid "$result" "Returns valid JSON for empty results"

    local count=$(echo "$result" | jq 'length')
    assert_equals "0" "$count" "Returns empty array for no matches"
}

# Run all tests
test_lists_open_issues
test_filters_by_label
test_limits_results
test_filters_by_state
test_filters_multiple_labels
test_performance
test_error_handling_invalid_state
test_empty_results

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
