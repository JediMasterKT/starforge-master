#!/bin/bash
# Simple fast test

set -e

echo "Testing settings.json template..."

# Test 1: Check for placeholders
if grep -F "{{PROJECT_DIR}}" ../templates/settings/settings.json > /dev/null; then
    echo "✓ PASS: Template has placeholders"
else
    echo "✗ FAIL: Template missing placeholders"
    exit 1
fi

# Test 2: Check no hard-coded paths
if grep -F "/Users/krunaaltavkar/empowerai" ../templates/settings/settings.json | grep -v "~/" > /dev/null; then
    echo "✗ FAIL: Template has hard-coded paths"
    exit 1
else
    echo "✓ PASS: No hard-coded absolute paths"
fi

# Test 3: Test replacement
result=$(sed "s|{{PROJECT_DIR}}|/test/path|g" ../templates/settings/settings.json | grep -F "/test/path" | wc -l | tr -d ' ')
if [ "$result" -eq 4 ]; then
    echo "✓ PASS: All 4 placeholders replaced"
else
    echo "✗ FAIL: Expected 4 replacements, got $result"
    exit 1
fi

echo ""
echo "All tests passed!"
