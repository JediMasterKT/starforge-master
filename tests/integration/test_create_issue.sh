#!/bin/bash
# tests/integration/test_create_issue.sh
#
# Integration test for starforge_create_issue MCP tool
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Integration Test: starforge_create_issue"
echo "=========================================="
echo ""

# Source the implementation
source templates/lib/mcp-tools-github.sh

# Track created issues for cleanup
CREATED_ISSUES=()

cleanup() {
    echo ""
    echo "Cleaning up test issues..."
    for issue in "${CREATED_ISSUES[@]}"; do
        gh issue close "$issue" --reason "completed" --comment "Integration test completed, closing." 2>/dev/null || true
        echo "   Closed issue #$issue"
    done
}

trap cleanup EXIT

# Test 1: Basic functionality - create issue with title and body
echo "Test 1: Create issue with title and body"
start=$(date +%s.%N)
result=$(starforge_create_issue --title "[TEST] Integration Test $(date +%s)" --body "This is a test issue created by integration tests.")
end=$(date +%s.%N)
duration=$(echo "$end - $start" | bc)

# Validate JSON
if echo "$result" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Returns valid JSON"
else
    echo -e "${RED}✗${NC} Invalid JSON"
    echo "   Got: $result"
    exit 1
fi

# Validate required fields
has_number=$(echo "$result" | jq 'has("number")')
has_url=$(echo "$result" | jq 'has("url")')

if [ "$has_number" = "true" ] && [ "$has_url" = "true" ]; then
    echo -e "${GREEN}✓${NC} Required fields present (number, url)"
else
    echo -e "${RED}✗${NC} Missing required fields"
    exit 1
fi

# Extract issue number and add to cleanup list
issue_number=$(echo "$result" | jq -r '.number')
CREATED_ISSUES+=("$issue_number")
echo -e "${GREEN}✓${NC} Created issue #$issue_number"

# Performance check (<3s per acceptance criteria)
if (( $(echo "$duration < 3.0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Performance OK (${duration}s < 3s)"
else
    echo -e "${RED}✗${NC} Too slow (${duration}s >= 3s)"
    exit 1
fi

echo ""

# Test 2: Create issue with labels
echo "Test 2: Create issue with labels"
result=$(starforge_create_issue --title "[TEST] With Labels $(date +%s)" --body "Test with labels" --label "bug,documentation")

# Validate JSON
if echo "$result" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Returns valid JSON"
else
    echo -e "${RED}✗${NC} Invalid JSON"
    exit 1
fi

# Extract issue number and verify labels
issue_number=$(echo "$result" | jq -r '.number')
CREATED_ISSUES+=("$issue_number")

# Verify labels were applied
issue_labels=$(gh issue view "$issue_number" --json labels --jq '.labels | map(.name) | join(",")')
if echo "$issue_labels" | grep -q "bug"; then
    echo -e "${GREEN}✓${NC} Labels applied correctly (found 'bug' in: $issue_labels)"
else
    echo -e "${RED}✗${NC} Labels not applied correctly"
    echo "   Expected: bug,documentation"
    echo "   Got: $issue_labels"
    exit 1
fi

echo ""

# Test 3: Create issue with assignee
echo "Test 3: Create issue with assignee"
current_user=$(gh api user --jq '.login')
result=$(starforge_create_issue --title "[TEST] With Assignee $(date +%s)" --body "Test with assignee" --assignee "$current_user")

# Validate JSON
if echo "$result" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Returns valid JSON"
else
    echo -e "${RED}✗${NC} Invalid JSON"
    exit 1
fi

issue_number=$(echo "$result" | jq -r '.number')
CREATED_ISSUES+=("$issue_number")
echo -e "${GREEN}✓${NC} Created issue #$issue_number with assignee"

echo ""

# Test 4: Error handling - missing title
echo "Test 4: Error handling - missing title"
result=$(starforge_create_issue --body "Body without title" 2>&1 || true)

if echo "$result" | grep -qi "error\|required"; then
    echo -e "${GREEN}✓${NC} Returns error for missing title"
else
    echo -e "${RED}✗${NC} Should error on missing title"
    echo "   Got: $result"
    exit 1
fi

echo ""

# Test 5: Error handling - missing body
echo "Test 5: Error handling - missing body"
result=$(starforge_create_issue --title "Title without body" 2>&1 || true)

if echo "$result" | grep -qi "error\|required"; then
    echo -e "${GREEN}✓${NC} Returns error for missing body"
else
    echo -e "${RED}✗${NC} Should error on missing body"
    echo "   Got: $result"
    exit 1
fi

echo ""

# Test 6: Verify issue is accessible
echo "Test 6: Verify created issue is accessible"
first_issue="${CREATED_ISSUES[0]}"
verify_result=$(gh issue view "$first_issue" --json number,title --jq '{number, title}')

if echo "$verify_result" | jq . >/dev/null 2>&1; then
    verified_number=$(echo "$verify_result" | jq -r '.number')
    if [ "$verified_number" = "$first_issue" ]; then
        echo -e "${GREEN}✓${NC} Issue #$first_issue is accessible and verified"
    else
        echo -e "${RED}✗${NC} Issue number mismatch"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Cannot verify created issue"
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ ALL INTEGRATION TESTS PASSED${NC}"
echo "=========================================="
echo ""
echo "Created and cleaned up ${#CREATED_ISSUES[@]} test issues"
