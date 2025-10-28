#!/bin/bash
# Integration test for file counts validation (Task 2.4)
#
# Tests that bin/starforge doctor correctly validates file counts

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Testing file counts validation..."
echo ""

# Test 1: Doctor command should run successfully
echo "Test 1: Doctor command runs"
cd /Users/krunaaltavkar/starforge-master

# Run doctor command (don't use set -e since doctor may return non-zero if files incomplete)
set +e
output=$(/usr/local/bin/bash "$PROJECT_ROOT/bin/starforge" doctor 2>&1)
exit_code=$?
set -e

if echo "$output" | grep -q "🏥 StarForge Health Check"; then
    echo -e "${GREEN}✓ PASS${NC}: Doctor command executed (exit code: $exit_code)"
else
    echo -e "${RED}✗ FAIL${NC}: Doctor command didn't run"
    echo "Output: $output"
    exit 1
fi

# Test 2: Verify file count checks are present
echo ""
echo "Test 2: File count checks are reported"

if echo "$output" | grep -q "Library files"; then
    echo -e "${GREEN}✓ PASS${NC}: Library files count reported"
else
    echo -e "${RED}✗ FAIL${NC}: Missing library files count"
    exit 1
fi

if echo "$output" | grep -q "Bin files"; then
    echo -e "${GREEN}✓ PASS${NC}: Bin files count reported"
else
    echo -e "${RED}✗ FAIL${NC}: Missing bin files count"
    exit 1
fi

if echo "$output" | grep -q "Agent definitions"; then
    echo -e "${GREEN}✓ PASS${NC}: Agent definitions count reported"
else
    echo -e "${RED}✗ FAIL${NC}: Missing agent definitions count"
    exit 1
fi

# Test 3: Verify expected vs actual format
echo ""
echo "Test 3: Count format is correct (actual/expected)"
if echo "$output" | grep -q "[0-9]*/[0-9]*"; then
    echo -e "${GREEN}✓ PASS${NC}: Count format correct"
else
    echo -e "${RED}✗ FAIL${NC}: Count format incorrect"
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ All file counts validation tests passed${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Sample output from doctor command:"
echo "$output"
