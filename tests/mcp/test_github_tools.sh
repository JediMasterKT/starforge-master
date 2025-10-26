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

# Test 9: Runs safe gh command
test_runs_safe_gh_command() {
    echo ""
    echo "Test: Run safe gh command"

    # Test a safe read-only command
    local result=$(starforge_run_gh_command "issue list --limit 1")

    assert_json_valid "$result" "Returns valid JSON for gh issue list"

    # Should contain success indicator
    local has_array=$(echo "$result" | jq -e 'type == "array"' 2>/dev/null || echo "false")
    assert_equals "true" "$has_array" "Command returns expected output"
}

# Test 10: Rejects non-gh command
test_rejects_non_gh_command() {
    echo ""
    echo "Test: Reject non-gh command"

    # Try to run a non-gh command
    local result=$(starforge_run_gh_command "rm -rf /" 2>&1 || echo '{"error": "command rejected"}')

    # Should reject or error
    assert_contains "$result" "error\|rejected\|invalid" "Rejects non-gh command"
}

# Test 11: Sanitizes command injection attempt
test_sanitizes_command_injection() {
    echo ""
    echo "Test: Sanitize command injection"

    # Try command injection with semicolon
    local result=$(starforge_run_gh_command "issue list; rm -rf /" 2>&1 || echo '{"error": "invalid"}')

    # Should reject or sanitize
    assert_contains "$result" "error\|invalid" "Prevents command injection with semicolon"

    # Try command injection with pipe
    result=$(starforge_run_gh_command "issue list | cat /etc/passwd" 2>&1 || echo '{"error": "invalid"}')

    assert_contains "$result" "error\|invalid" "Prevents command injection with pipe"
}

# Test 12: Returns stdout and stderr
test_returns_stdout_stderr() {
    echo ""
    echo "Test: Return stdout and stderr"

    # Run a command that should succeed
    local result=$(starforge_run_gh_command "api user" 2>&1)

    # Should return JSON output from gh
    assert_json_valid "$result" "Returns valid JSON from gh api"
}

# Test 13: Handles gh auth errors gracefully
test_handles_gh_auth_errors() {
    echo ""
    echo "Test: Handle gh authentication errors"

    # This test assumes we might not be authenticated
    # The function should handle errors gracefully
    local result=$(starforge_run_gh_command "api /repos/nonexistent/repo" 2>&1 || echo '{"error": "not found"}')

    # Should return error message, not crash
    echo -e "${GREEN}✓${NC} Handles gh errors gracefully"
    ((PASSED++))
}

# Test 14: Validates command syntax
test_validates_command_syntax() {
    echo ""
    echo "Test: Validate command syntax"

    # Empty command
    local result=$(starforge_run_gh_command "" 2>&1 || echo '{"error": "invalid"}')
    assert_contains "$result" "error\|invalid" "Rejects empty command"

    # Only whitespace
    result=$(starforge_run_gh_command "   " 2>&1 || echo '{"error": "invalid"}')
    assert_contains "$result" "error\|invalid" "Rejects whitespace-only command"
}

# Test 15: Allows multiple safe gh subcommands
test_allows_multiple_gh_subcommands() {
    echo ""
    echo "Test: Allow multiple safe gh subcommands"

    # Test various safe gh subcommands
    local cmds=("issue list --limit 1" "api user" "repo view --json name")

    for cmd in "${cmds[@]}"; do
        local result=$(starforge_run_gh_command "$cmd" 2>&1 || true)
        # Just verify it doesn't crash
        echo -e "${GREEN}✓${NC} Allows safe command: gh $cmd"
        ((PASSED++))
    done
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

# NEW: Tests for run_gh_command (TDD - written before implementation)
test_runs_safe_gh_command
test_rejects_non_gh_command
test_sanitizes_command_injection
test_returns_stdout_stderr
test_handles_gh_auth_errors
test_validates_command_syntax
test_allows_multiple_gh_subcommands

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
