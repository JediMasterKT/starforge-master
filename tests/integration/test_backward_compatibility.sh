#!/bin/bash
# tests/integration/test_backward_compatibility.sh
#
# Integration test for backward compatibility (Ticket #234 - QA Review Fix)
#
# Verifies both old (positional) and new (flag-based) APIs work

set -e

echo "======================================="
echo "Backward Compatibility Integration Test"
echo "======================================="
echo ""

# Source the tools
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$SCRIPT_DIR/templates/lib/mcp-tools-file.sh"

# Create test environment
test_file=$(mktemp)
test_dir=$(mktemp -d)
for i in {1..150}; do
    echo "Line $i with content" >> "$test_file"
done
touch "$test_dir/test1.txt"
touch "$test_dir/test2.txt"

# Test 1: read_file with old API (positional)
echo "Test 1: read_file old API (positional argument)"
response=$(starforge_read_file "$test_file")
if echo "$response" | jq -e '.content' > /dev/null 2>&1; then
    echo "  ✅ Old API works (positional)"
else
    echo "  ❌ FAIL: Old API broken"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi
echo ""

# Test 2: read_file with new API (flags)
echo "Test 2: read_file new API (flag-based)"
response=$(starforge_read_file --format concise "$test_file")
if echo "$response" | jq -e '.content' > /dev/null 2>&1; then
    echo "  ✅ New API works (flags)"
else
    echo "  ❌ FAIL: New API broken"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi
echo ""

# Test 3: read_file with mixed API (positional + flags)
echo "Test 3: read_file mixed API (positional + flags)"
response=$(starforge_read_file "$test_file" --format detailed)
if echo "$response" | jq -e '.content' > /dev/null 2>&1; then
    echo "  ✅ Mixed API works (positional + flags)"
else
    echo "  ❌ FAIL: Mixed API broken"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi
echo ""

# Test 4: search_files with old API (positional)
echo "Test 4: search_files old API (positional)"
response=$(starforge_search_files "*.txt" "$test_dir")
if echo "$response" | jq -e '.files' > /dev/null 2>&1; then
    echo "  ✅ Old API works (positional)"
else
    echo "  ❌ FAIL: Old API broken"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi
echo ""

# Test 5: search_files with new API (flags)
echo "Test 5: search_files new API (flag-based)"
response=$(starforge_search_files --format detailed "*.txt" "$test_dir")
if echo "$response" | jq -e '.files' > /dev/null 2>&1; then
    echo "  ✅ New API works (flags)"
else
    echo "  ❌ FAIL: New API broken"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi
echo ""

# Test 6: Default standardization (both should default to "concise")
echo "Test 6: Default standardization"
response_read=$(starforge_read_file "$test_file")
response_search=$(starforge_search_files "*.txt" "$test_dir")

# read_file default should be "concise" (first 100 lines)
if echo "$response_read" | grep -q "Line 100"; then
    if echo "$response_read" | grep -q "Line 101"; then
        echo "  ❌ FAIL: read_file default should be concise (exclude line 101)"
        rm -f "$test_file"
        rm -rf "$test_dir"
        exit 1
    else
        echo "  ✅ read_file defaults to concise (line 100 present, 101 absent)"
    fi
else
    echo "  ❌ FAIL: read_file default missing expected content"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi

# search_files default should be "concise" (paths only, no objects)
if echo "$response_search" | grep -q '"path":'; then
    echo "  ❌ FAIL: search_files default should be concise (no path objects)"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
else
    echo "  ✅ search_files defaults to concise (no path objects)"
fi
echo ""

# Test 7: All existing test files still work
echo "Test 7: Verify existing tests still pass"
cd "$SCRIPT_DIR"
if bash tests/mcp/test_read_file.sh green 2>&1 | grep -q "All tests passing"; then
    echo "  ✅ test_read_file.sh still passes"
else
    echo "  ❌ FAIL: test_read_file.sh broken by changes"
    rm -f "$test_file"
    rm -rf "$test_dir"
    exit 1
fi
echo ""

# Cleanup
rm -f "$test_file"
rm -rf "$test_dir"

echo "======================================="
echo "✅ ALL BACKWARD COMPATIBILITY TESTS PASSED"
echo "======================================="
echo ""
echo "Summary:"
echo "- Old API (positional) works ✅"
echo "- New API (flag-based) works ✅"
echo "- Mixed API works ✅"
echo "- Defaults standardized to 'concise' ✅"
echo "- Existing tests still pass ✅"
echo ""

exit 0
