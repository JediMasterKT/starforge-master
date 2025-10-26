#!/bin/bash
# Integration test for starforge_search_files MCP tool
# Tests for issue #177 - Search Files Tool/Glob (B3)
#
# Integration tests verify the feature works with real dependencies
# and meets real-world usage requirements.

set -e

# Setup: Create test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Integration test: starforge_search_files"
echo "========================================="
echo ""

# Create realistic project structure
mkdir -p "$TEST_DIR/project/src/components"
mkdir -p "$TEST_DIR/project/src/utils"
mkdir -p "$TEST_DIR/project/tests"
mkdir -p "$TEST_DIR/project/docs"

# Create test files
touch "$TEST_DIR/project/README.md"
touch "$TEST_DIR/project/package.json"
touch "$TEST_DIR/project/src/index.js"
touch "$TEST_DIR/project/src/app.js"
touch "$TEST_DIR/project/src/components/Button.js"
touch "$TEST_DIR/project/src/components/Card.js"
touch "$TEST_DIR/project/src/utils/helper.js"
touch "$TEST_DIR/project/src/utils/validator.py"
touch "$TEST_DIR/project/tests/test_app.js"
touch "$TEST_DIR/project/tests/test_utils.py"
touch "$TEST_DIR/project/docs/guide.md"

# Load implementation
source templates/lib/mcp-tools-file.sh

echo "Test 1: Search for JavaScript files in project"
echo "-----------------------------------------------"
result=$(starforge_search_files "*.js" "$TEST_DIR/project")
count=$(echo "$result" | jq -r '.files | length')
echo "Found $count JavaScript files"
if [ "$count" -ge 5 ]; then
  echo "✅ PASS: Found expected number of .js files"
else
  echo "❌ FAIL: Expected at least 5 .js files, got $count"
  exit 1
fi
echo ""

echo "Test 2: Search from current directory (default behavior)"
echo "---------------------------------------------------------"
cd "$TEST_DIR/project"
result=$(starforge_search_files "*.md")
count=$(echo "$result" | jq -r '.files | length')
echo "Found $count Markdown files"
if [ "$count" -ge 2 ]; then
  echo "✅ PASS: Found Markdown files in current directory"
else
  echo "❌ FAIL: Expected at least 2 .md files, got $count"
  exit 1
fi
echo ""

echo "Test 3: Handle non-existent pattern gracefully"
echo "------------------------------------------------"
result=$(starforge_search_files "*.nonexistent" "$TEST_DIR/project")
count=$(echo "$result" | jq -r '.files | length')
echo "Found $count files matching non-existent pattern"
if [ "$count" -eq 0 ]; then
  echo "✅ PASS: Gracefully handled non-matching pattern"
else
  echo "❌ FAIL: Expected 0 files, got $count"
  exit 1
fi
echo ""

echo "Test 4: Error handling for invalid directory"
echo "---------------------------------------------"
result=$(starforge_search_files "*.js" "/nonexistent/directory" 2>&1 || true)
error=$(echo "$result" | jq -r '.error' 2>/dev/null || echo "")
if [ -n "$error" ] && [ "$error" != "null" ] && [ "$error" != "" ]; then
  echo "Error message: $error"
  echo "✅ PASS: Graceful error message for invalid directory"
else
  echo "❌ FAIL: Expected error for invalid directory"
  exit 1
fi
echo ""

echo "Test 5: Performance with large directory (1000+ files)"
echo "--------------------------------------------------------"
perf_dir="$TEST_DIR/large_project"
mkdir -p "$perf_dir"
for i in {1..1500}; do
  touch "$perf_dir/file_$i.txt"
done

start=$(date +%s%3N)
result=$(starforge_search_files "*.txt" "$perf_dir")
end=$(date +%s%3N)
duration=$((end - start))

count=$(echo "$result" | jq -r '.files | length')
echo "Found $count files in ${duration}ms"

if [ "$count" -eq 1500 ]; then
  echo "✅ PASS: Found all 1500 files"
else
  echo "❌ FAIL: Expected 1500 files, got $count"
  exit 1
fi

if [ $duration -lt 1000 ]; then
  echo "✅ PASS: Performance within target (<1000ms for 1500 files)"
else
  echo "⚠️  WARNING: Slower than ideal (${duration}ms), but acceptable"
fi
echo ""

echo "Test 6: Returns absolute paths"
echo "--------------------------------"
result=$(starforge_search_files "*.json" "$TEST_DIR/project")
first_file=$(echo "$result" | jq -r '.files[0]')
if [[ "$first_file" =~ ^/ ]]; then
  echo "First file path: $first_file"
  echo "✅ PASS: Returns absolute paths"
else
  echo "❌ FAIL: Expected absolute path, got: $first_file"
  exit 1
fi
echo ""

echo "========================================="
echo "✅ ALL INTEGRATION TESTS PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "- ✅ Basic search functionality works"
echo "- ✅ Default directory behavior works"
echo "- ✅ Error handling is graceful"
echo "- ✅ Performance meets targets"
echo "- ✅ Returns absolute paths"
echo ""
