#!/usr/local/bin/bash
# Simple Integration Test: Doctor command
# Task 2.6: Permissions Validation for Phase 2

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Simple Integration Test: Doctor Command (Task 2.6)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create test environment
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Create minimal .claude structure
mkdir -p .claude/{hooks,scripts,lib,bin}
touch .claude/hooks/stop.py
touch .claude/scripts/test.sh
chmod +x .claude/hooks/stop.py
chmod +x .claude/scripts/test.sh

# Copy starforge
cp "$OLDPWD/bin/starforge" ./starforge
chmod +x ./starforge

# Test 1: Correct permissions
echo "Test 1: All permissions correct..."
if ./starforge doctor > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    cd "$OLDPWD"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Test 2: Incorrect permission
echo "Test 2: Detect non-executable file..."
chmod -x .claude/hooks/stop.py
if ! ./starforge doctor > /dev/null 2>&1; then
    # Should fail (exit code != 0)
    output=$(./starforge doctor 2>&1)
    if echo "$output" | grep -q "stop.py"; then
        echo -e "${GREEN}✓ PASS${NC}"
    else
        echo -e "${RED}✗ FAIL (didn't mention stop.py)${NC}"
        cd "$OLDPWD"
        rm -rf "$TEST_DIR"
        exit 1
    fi
else
    echo -e "${RED}✗ FAIL (should have detected error)${NC}"
    cd "$OLDPWD"
    rm -rf "$TEST_DIR"
    exit 1
fi

# Cleanup
cd "$OLDPWD"
rm -rf "$TEST_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}All tests passed!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
