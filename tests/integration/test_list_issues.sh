#!/bin/bash
# tests/integration/test_list_issues.sh
#
# Integration test for starforge_list_issues MCP tool
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Integration Test: starforge_list_issues"
echo "=========================================="
echo ""

# Source the implementation
source templates/lib/mcp-tools-github.sh

# Test 1: Basic functionality - list open issues
echo "Test 1: List open issues (limit 5)"
start=$(date +%s.%N)
result=$(starforge_list_issues --state open --limit 5)
end=$(date +%s.%N)
duration=$(echo "$end - $start" | bc)

# Validate JSON
if echo "$result" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Returns valid JSON"
else
    echo -e "${RED}✗${NC} Invalid JSON"
    exit 1
fi

# Validate array
count=$(echo "$result" | jq 'length')
if [ "$count" -le 5 ]; then
    echo -e "${GREEN}✓${NC} Limit works (got $count issues, max 5)"
else
    echo -e "${RED}✗${NC} Limit failed (got $count issues, expected max 5)"
    exit 1
fi

# Performance check
if (( $(echo "$duration < 2.0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Performance OK (${duration}s < 2s)"
else
    echo -e "${RED}✗${NC} Too slow (${duration}s >= 2s)"
    exit 1
fi

echo ""

# Test 2: Filter by label
echo "Test 2: Filter by label (P1, limit 5)"
result=$(starforge_list_issues --label "P1" --limit 5)

if echo "$result" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Label filter returns valid JSON"
else
    echo -e "${RED}✗${NC} Label filter invalid JSON"
    exit 1
fi

count=$(echo "$result" | jq 'length')
echo "   Found $count P1 issues"

echo ""

# Test 3: Filter by state (closed)
echo "Test 3: Filter by state (closed, limit 3)"
result=$(starforge_list_issues --state closed --limit 3)

if echo "$result" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} State filter returns valid JSON"
else
    echo -e "${RED}✗${NC} State filter invalid JSON"
    exit 1
fi

# Verify all are closed (gh returns uppercase "CLOSED")
count=$(echo "$result" | jq 'length')
if [ "$count" -gt 0 ]; then
    all_closed=$(echo "$result" | jq -r 'all(.[]; .state == "CLOSED")')
    if [ "$all_closed" = "true" ]; then
        echo -e "${GREEN}✓${NC} All issues are closed"
    else
        echo -e "${RED}✗${NC} Some issues not closed"
        exit 1
    fi
fi

echo ""

# Test 4: Required fields present
echo "Test 4: Required fields present"
result=$(starforge_list_issues --limit 1)

first=$(echo "$result" | jq '.[0]')
if [ "$first" != "null" ]; then
    has_number=$(echo "$first" | jq 'has("number")')
    has_title=$(echo "$first" | jq 'has("title")')
    has_labels=$(echo "$first" | jq 'has("labels")')
    has_state=$(echo "$first" | jq 'has("state")')

    if [ "$has_number" = "true" ] && [ "$has_title" = "true" ] && [ "$has_labels" = "true" ] && [ "$has_state" = "true" ]; then
        echo -e "${GREEN}✓${NC} All required fields present"
    else
        echo -e "${RED}✗${NC} Missing required fields"
        echo "   number: $has_number"
        echo "   title: $has_title"
        echo "   labels: $has_labels"
        echo "   state: $has_state"
        exit 1
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ ALL INTEGRATION TESTS PASSED${NC}"
echo "=========================================="
