#!/bin/bash
# tests/mcp/test_create_pr_only.sh
#
# Focused tests for starforge_create_pr function
#

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

# Source the implementation
SOURCE_FILE="templates/lib/mcp-tools-github.sh"
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}ERROR:${NC} $SOURCE_FILE does not exist"
    exit 1
fi

source "$SOURCE_FILE"

echo "=========================================="
echo "Create PR Tests"
echo "=========================================="
echo ""

# Test 1: Create PR successfully (mocked)
test_creates_pr_successfully() {
    echo "Test: Create PR successfully"

    # Mock gh pr create for testing
    gh() {
        if [[ "$1" == "pr" && "$2" == "create" ]]; then
            # Simulate successful PR creation
            echo "https://github.com/owner/repo/pull/123"
            return 0
        fi
        command gh "$@"
    }
    export -f gh

    local result=$(starforge_create_pr --title "Test PR" --body "Test body" --head "feature/test" --base "main")

    assert_json_valid "$result" "Returns valid JSON"

    local pr_number=$(echo "$result" | jq -r '.number')
    assert_equals "123" "$pr_number" "Returns PR number"

    local pr_url=$(echo "$result" | jq -r '.url')
    assert_contains "$pr_url" "github.com" "Returns PR URL"

    # Cleanup mock
    unset -f gh
}

# Test 2: Create PR with custom base branch
test_creates_pr_with_custom_base() {
    echo ""
    echo "Test: Create PR with custom base branch"

    # Mock gh pr create
    gh() {
        if [[ "$1" == "pr" && "$2" == "create" ]]; then
            echo "https://github.com/owner/repo/pull/456"
            return 0
        fi
        command gh "$@"
    }
    export -f gh

    local result=$(starforge_create_pr --title "Test PR" --body "Body" --head "feature/test" --base "develop")

    assert_json_valid "$result" "Returns valid JSON for custom base"

    local pr_number=$(echo "$result" | jq -r '.number')
    assert_equals "456" "$pr_number" "Returns correct PR number"

    # Cleanup mock
    unset -f gh
}

# Test 3: Create draft PR
test_creates_draft_pr() {
    echo ""
    echo "Test: Create draft PR"

    # Mock gh pr create
    gh() {
        if [[ "$1" == "pr" && "$2" == "create" ]]; then
            echo "https://github.com/owner/repo/pull/789"
            return 0
        fi
        command gh "$@"
    }
    export -f gh

    local result=$(starforge_create_pr --title "Draft PR" --body "Body" --head "feature/test" --base "main" --draft)

    assert_json_valid "$result" "Returns valid JSON for draft PR"

    local pr_number=$(echo "$result" | jq -r '.number')
    assert_equals "789" "$pr_number" "Creates draft PR successfully"

    # Cleanup mock
    unset -f gh
}

# Test 4: Handle multiline body correctly
test_handles_multiline_body() {
    echo ""
    echo "Test: Handle multiline body"

    # Mock gh pr create
    gh() {
        if [[ "$1" == "pr" && "$2" == "create" ]]; then
            echo "https://github.com/owner/repo/pull/111"
            return 0
        fi
        command gh "$@"
    }
    export -f gh

    local multiline_body="Line 1
Line 2
Line 3"

    local result=$(starforge_create_pr --title "Test" --body "$multiline_body" --head "feature/test" --base "main")

    assert_json_valid "$result" "Handles multiline body correctly"

    # Cleanup mock
    unset -f gh
}

# Test 5: Error handling - missing required params
test_error_missing_required_params() {
    echo ""
    echo "Test: Error handling - missing required params"

    # Missing title should fail
    local result=$(starforge_create_pr --body "Body" --head "feature/test" --base "main" 2>&1 || true)

    assert_contains "$result" "title" "Error mentions missing title"
}

# Test 6: Error handling - missing head branch
test_error_missing_head_branch() {
    echo ""
    echo "Test: Error handling - missing head branch"

    # Missing head should fail
    local result=$(starforge_create_pr --title "Test" --body "Body" --base "main" 2>&1 || true)

    assert_contains "$result" "head" "Error mentions missing head branch"
}

# Run all tests
test_creates_pr_successfully
test_creates_pr_with_custom_base
test_creates_draft_pr
test_handles_multiline_body
test_error_missing_required_params
test_error_missing_head_branch

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
