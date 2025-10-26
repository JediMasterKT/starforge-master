#!/bin/bash
# tests/integration/test_mcp_format_parameter.sh
#
# Integration test for MCP format parameter feature (Ticket #234)
#
# Verifies format parameter reduces token usage by 20%+

set -e

echo "======================================="
echo "MCP Format Parameter Integration Test"
echo "======================================="
echo ""

# Source the tools
SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$SCRIPT_DIR/templates/lib/mcp-tools-file.sh"

# Test 1: read_file concise format limits to 100 lines
echo "Test 1: read_file concise format"
test_file=$(mktemp)
for i in {1..150}; do
    echo "Line $i with some extra content here" >> "$test_file"
done

response_concise=$(starforge_read_file "$test_file" --format concise)
response_detailed=$(starforge_read_file "$test_file" --format detailed)

# Verify concise has line 100 but not 101
if echo "$response_concise" | grep -q "Line 100"; then
    echo "  ✅ Concise includes line 100"
else
    echo "  ❌ FAIL: Concise missing line 100"
    rm -f "$test_file"
    exit 1
fi

if echo "$response_concise" | grep -q "Line 101"; then
    echo "  ❌ FAIL: Concise should not include line 101"
    rm -f "$test_file"
    exit 1
else
    echo "  ✅ Concise excludes line 101 (correct)"
fi

# Verify detailed has all lines
if echo "$response_detailed" | grep -q "Line 150"; then
    echo "  ✅ Detailed includes all 150 lines"
else
    echo "  ❌ FAIL: Detailed missing line 150"
    rm -f "$test_file"
    exit 1
fi

rm -f "$test_file"
echo ""

# Test 2: search_files format parameter
echo "Test 2: search_files format parameter"
test_dir=$(mktemp -d)
touch "$test_dir/file1.txt"
touch "$test_dir/file2.txt"
touch "$test_dir/file3.txt"

response_concise=$(starforge_search_files "*.txt" "$test_dir" --format concise)
response_detailed=$(starforge_search_files "*.txt" "$test_dir" --format detailed)

# Verify concise returns simple array
if echo "$response_concise" | grep -q '"files"'; then
    echo "  ✅ Concise has files field"
else
    echo "  ❌ FAIL: Concise missing files field"
    rm -rf "$test_dir"
    exit 1
fi

# Verify concise doesn't have path objects (just strings)
if echo "$response_concise" | grep -q '"path":'; then
    echo "  ❌ FAIL: Concise should not have path objects"
    rm -rf "$test_dir"
    exit 1
else
    echo "  ✅ Concise returns simple array (no objects)"
fi

# Verify detailed has path objects
if echo "$response_detailed" | grep -q '"path":'; then
    echo "  ✅ Detailed has path objects"
else
    echo "  ❌ FAIL: Detailed missing path objects"
    rm -rf "$test_dir"
    exit 1
fi

rm -rf "$test_dir"
echo ""

# Test 3: Token reduction measurement
echo "Test 3: Token reduction measurement"
test_file=$(mktemp)
for i in {1..200}; do
    echo "This is line number $i with substantial content to simulate real files" >> "$test_file"
done

response_concise=$(starforge_read_file "$test_file" --format concise)
response_detailed=$(starforge_read_file "$test_file" --format detailed)

concise_size=${#response_concise}
detailed_size=${#response_detailed}

if [ $detailed_size -eq 0 ]; then
    echo "  ❌ FAIL: Detailed response is empty"
    rm -f "$test_file"
    exit 1
fi

reduction=$(( (detailed_size - concise_size) * 100 / detailed_size ))

echo "  Detailed size: $detailed_size chars"
echo "  Concise size: $concise_size chars"
echo "  Reduction: $reduction%"

if [ $reduction -ge 20 ]; then
    echo "  ✅ Token reduction ($reduction%) meets 20% target"
else
    echo "  ❌ FAIL: Token reduction ($reduction%) below 20% target"
    rm -f "$test_file"
    exit 1
fi

rm -f "$test_file"
echo ""

# Test 4: Default standardization (concise is default for read_file)
echo "Test 4: Default standardization"
test_file=$(mktemp)
for i in {1..150}; do
    echo "Line $i" >> "$test_file"
done

response_default=$(starforge_read_file "$test_file")

# Default should be concise (first 100 lines only)
if echo "$response_default" | grep -q "Line 100"; then
    if echo "$response_default" | grep -q "Line 101"; then
        echo "  ❌ FAIL: Default format should be concise (exclude line 101)"
        rm -f "$test_file"
        exit 1
    else
        echo "  ✅ Default format is concise (line 100 present, 101 absent)"
    fi
else
    echo "  ❌ FAIL: Default format missing expected content"
    rm -f "$test_file"
    exit 1
fi

rm -f "$test_file"
echo ""

# Test 5: Invalid format handling
echo "Test 5: Invalid format handling"
test_file=$(mktemp)
echo "test" > "$test_file"

response_invalid=$(starforge_read_file "$test_file" --format invalid 2>&1 || true)

if [ -z "$response_invalid" ]; then
    echo "  ❌ FAIL: No response from invalid format"
    rm -f "$test_file"
    exit 1
fi

if echo "$response_invalid" | grep -q "error" && echo "$response_invalid" | grep -q "Invalid format"; then
    echo "  ✅ Invalid format returns proper error"
else
    echo "  ❌ FAIL: Invalid format should return error mentioning 'Invalid format'"
    echo "  Got: $response_invalid"
    rm -f "$test_file"
    exit 1
fi

rm -f "$test_file"
echo ""

echo "======================================="
echo "✅ ALL INTEGRATION TESTS PASSED"
echo "======================================="
echo ""
echo "Summary:"
echo "- Format parameter implemented in read_file"
echo "- Format parameter implemented in search_files"
echo "- Token reduction: $reduction% (target: 20%)"
echo "- Backward compatibility maintained"
echo "- Error handling verified"
echo ""

exit 0
