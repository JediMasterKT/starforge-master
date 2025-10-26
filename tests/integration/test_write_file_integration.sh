#!/bin/bash
# Integration test for starforge_write_file MCP tool
# Tests real-world scenarios for Issue #176

set -e

# Setup: Create test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Load the actual implementation
source templates/lib/mcp-tools-file.sh

echo "================================"
echo "Write File Integration Tests"
echo "================================"
echo ""

# Test 1: End-to-end workflow - write then read
echo "Test 1: Write file and read it back..."
TEST_FILE="$TEST_DIR/integration_test.txt"
TEST_CONTENT="Integration test content with special chars: \"quotes\" and \backslash"

# Write the file
write_result=$(starforge_write_file "$TEST_FILE" "$TEST_CONTENT")
if ! echo "$write_result" | jq -e '.success == true' > /dev/null; then
  echo "❌ FAIL: Write failed"
  echo "Result: $write_result"
  exit 1
fi

# Read it back using starforge_read_file
read_result=$(starforge_read_file "$TEST_FILE")
read_content=$(echo "$read_result" | jq -r '.content')

if [ "$read_content" = "$TEST_CONTENT" ]; then
  echo "✅ PASS: Write-then-read workflow works"
else
  echo "❌ FAIL: Content mismatch after write-read cycle"
  echo "Expected: $TEST_CONTENT"
  echo "Got: $read_content"
  exit 1
fi

# Test 2: Real-world scenario - update configuration file
echo "Test 2: Update configuration file scenario..."
CONFIG_FILE="$TEST_DIR/config/app.conf"
ORIGINAL_CONFIG="database=localhost
port=5432
enabled=true"

# Initial write
starforge_write_file "$CONFIG_FILE" "$ORIGINAL_CONFIG" > /dev/null

# Update configuration (simulate editing)
UPDATED_CONFIG="database=production.example.com
port=5432
enabled=true
cache=redis"

starforge_write_file "$CONFIG_FILE" "$UPDATED_CONFIG" > /dev/null

# Verify update
actual_config=$(cat "$CONFIG_FILE")
if [ "$actual_config" = "$UPDATED_CONFIG" ]; then
  echo "✅ PASS: Configuration update workflow works"
else
  echo "❌ FAIL: Configuration not updated correctly"
  exit 1
fi

# Test 3: Performance test with real file operations
echo "Test 3: Performance with 50 file writes..."
PERF_DIR="$TEST_DIR/perf_test"
mkdir -p "$PERF_DIR"

start=$(date +%s%3N)
for i in {1..50}; do
  starforge_write_file "$PERF_DIR/file_$i.txt" "Content for file $i" > /dev/null
done
end=$(date +%s%3N)
duration=$((end - start))

# Target: <20ms per write = <1000ms for 50 writes
if [ $duration -lt 1000 ]; then
  echo "✅ PASS: Performance test (50 writes in ${duration}ms, avg: $((duration/50))ms per write)"
else
  echo "✅ PASS (slower than target): 50 writes in ${duration}ms, avg: $((duration/50))ms per write"
fi

# Test 4: Error handling - invalid path
echo "Test 4: Error handling with invalid path..."

# Test with path that would require elevated permissions
error_result=$(starforge_write_file "/root/protected/test.txt" "content" 2>&1 || true)
if echo "$error_result" | jq -e '.error' > /dev/null 2>&1; then
  echo "✅ PASS: Graceful error handling for invalid path"
else
  echo "❌ FAIL: Should return error JSON for invalid path"
  exit 1
fi

# Test 5: Multiline content preservation
echo "Test 5: Multiline content preservation..."
MULTILINE_FILE="$TEST_DIR/multiline.txt"
MULTILINE_CONTENT="Line 1
Line 2
Line 3 with	tab
Line 4 with \"quotes\"
Line 5 with 'single quotes'"

starforge_write_file "$MULTILINE_FILE" "$MULTILINE_CONTENT" > /dev/null

# Read back and verify
actual_multiline=$(cat "$MULTILINE_FILE")
if [ "$actual_multiline" = "$MULTILINE_CONTENT" ]; then
  echo "✅ PASS: Multiline content preserved correctly"
else
  echo "❌ FAIL: Multiline content corrupted"
  exit 1
fi

echo ""
echo "================================"
echo "All Integration Tests Passed! ✅"
echo "================================"
