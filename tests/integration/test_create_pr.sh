#!/bin/bash
# Integration test for starforge_create_pr tool
# Tests the PR creation functionality with mocked gh CLI

set -e

TEST_NAME="MCP create_pr Integration Test"
echo "========================================="
echo "$TEST_NAME"
echo "========================================="
echo ""

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the MCP GitHub tools
source "$PROJECT_ROOT/templates/lib/mcp-tools-github.sh"

# Mock gh CLI for integration testing
gh() {
    if [[ "$1" == "pr" && "$2" == "create" ]]; then
        # Simulate successful PR creation
        # Extract title for dynamic response
        local title=""
        for ((i=1; i<=$#; i++)); do
            if [[ "${!i}" == "--title" ]]; then
                local next=$((i+1))
                title="${!next}"
                break
            fi
        done

        # Return PR URL
        echo "https://github.com/test-owner/test-repo/pull/42"
        return 0
    fi

    echo "Error: Unexpected gh command: $@" >&2
    return 1
}
export -f gh

# Test 1: Create PR with all parameters
echo "Test 1: Create PR with all parameters"
result=$(starforge_create_pr \
    --title "Add new feature" \
    --body "This PR adds a new feature to improve functionality" \
    --head "feature/new-feature" \
    --base "main")

if [ $? -ne 0 ]; then
    echo "❌ FAIL: starforge_create_pr returned error"
    exit 1
fi

# Verify JSON structure
if ! echo "$result" | jq -e '.number' > /dev/null 2>&1; then
    echo "❌ FAIL: Invalid JSON structure - missing 'number'"
    echo "   Output: $result"
    exit 1
fi

if ! echo "$result" | jq -e '.url' > /dev/null 2>&1; then
    echo "❌ FAIL: Invalid JSON structure - missing 'url'"
    echo "   Output: $result"
    exit 1
fi

pr_number=$(echo "$result" | jq -r '.number')
pr_url=$(echo "$result" | jq -r '.url')

if [ "$pr_number" != "42" ]; then
    echo "❌ FAIL: Expected PR number 42, got $pr_number"
    exit 1
fi

if ! echo "$pr_url" | grep -q "github.com"; then
    echo "❌ FAIL: PR URL doesn't contain github.com"
    exit 1
fi

echo "✅ PASS: PR created successfully"
echo "   PR Number: $pr_number"
echo "   PR URL: $pr_url"
echo ""

# Test 2: Create draft PR
echo "Test 2: Create draft PR"
result=$(starforge_create_pr \
    --title "WIP: Draft feature" \
    --body "Work in progress" \
    --head "feature/draft" \
    --base "main" \
    --draft)

if [ $? -ne 0 ]; then
    echo "❌ FAIL: Draft PR creation failed"
    exit 1
fi

pr_number=$(echo "$result" | jq -r '.number')
if [ "$pr_number" != "42" ]; then
    echo "❌ FAIL: Draft PR number mismatch"
    exit 1
fi

echo "✅ PASS: Draft PR created successfully"
echo ""

# Test 3: Multiline body
echo "Test 3: Create PR with multiline body"
multiline_body="## Summary
This PR implements feature X

## Changes
- Added new function
- Updated tests
- Fixed bug Y

## Testing
All tests pass"

result=$(starforge_create_pr \
    --title "Implement feature X" \
    --body "$multiline_body" \
    --head "feature/x" \
    --base "main")

if [ $? -ne 0 ]; then
    echo "❌ FAIL: Multiline body PR creation failed"
    exit 1
fi

echo "✅ PASS: PR with multiline body created successfully"
echo ""

# Test 4: Error handling - missing title
echo "Test 4: Error handling - missing title"
if starforge_create_pr --body "Body" --head "test" --base "main" 2>&1 | grep -q "title"; then
    echo "✅ PASS: Correctly validates missing title"
else
    echo "❌ FAIL: Should error on missing title"
    exit 1
fi
echo ""

# Test 5: Error handling - missing head branch
echo "Test 5: Error handling - missing head branch"
if starforge_create_pr --title "Test" --body "Body" --base "main" 2>&1 | grep -q "head"; then
    echo "✅ PASS: Correctly validates missing head branch"
else
    echo "❌ FAIL: Should error on missing head branch"
    exit 1
fi
echo ""

# Test 6: Performance test
echo "Test 6: Performance - should complete in <5s"
start=$(date +%s.%N)
result=$(starforge_create_pr \
    --title "Performance test" \
    --body "Testing performance" \
    --head "feature/perf" \
    --base "main")
end=$(date +%s.%N)

duration=$(echo "$end - $start" | bc)
if (( $(echo "$duration < 5.0" | bc -l) )); then
    echo "✅ PASS: Completed in ${duration}s (< 5s target)"
else
    echo "❌ FAIL: Too slow - ${duration}s (>= 5s)"
    exit 1
fi
echo ""

# Summary
echo "========================================="
echo "All integration tests passed!"
echo "========================================="
echo "✅ Basic PR creation"
echo "✅ Draft PR creation"
echo "✅ Multiline body handling"
echo "✅ Error validation (missing title)"
echo "✅ Error validation (missing head)"
echo "✅ Performance target met (<5s)"
echo ""
echo "Integration test suite complete."
