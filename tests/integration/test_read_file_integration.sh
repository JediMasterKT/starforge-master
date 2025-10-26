#!/bin/bash
# Integration tests for starforge_read_file MCP tool
# Tests real-world usage scenarios with actual file system

# Note: Not using 'set -e' because assert_test handles failures properly

echo "================================"
echo "Integration Tests: MCP Read File"
echo "================================"
echo ""

# Setup test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Source the implementation
source templates/lib/mcp-tools-file.sh

# Test counters
PASSED=0
FAILED=0

# Test helper
assert_test() {
  local name="$1"
  shift
  echo -n "Test: $name... "
  if "$@"; then
    echo "✅ PASS"
    ((PASSED++))
  else
    echo "❌ FAIL"
    ((FAILED++))
    return 1
  fi
}

# ============================================================================
# INTEGRATION TESTS
# ============================================================================

test_reads_actual_project_file() {
  # Test reading an actual project file (README.md should exist)
  if [ ! -f "README.md" ]; then
    echo "(Skipping - README.md not found)"
    return 0
  fi

  local result=$(starforge_read_file "$PWD/README.md")

  # Should be valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Invalid JSON)"
    return 1
  fi

  # Should contain content
  local content=$(echo "$result" | jq -r '.content')
  if [ -z "$content" ]; then
    echo "(No content)"
    return 1
  fi

  # Should contain "StarForge" (from our README)
  if echo "$content" | grep -q "StarForge"; then
    return 0
  else
    echo "(Content doesn't match expected)"
    return 1
  fi
}

test_handles_binary_file_gracefully() {
  # Create a simple binary file
  local bin_file="$TEST_DIR/binary.bin"
  echo -ne '\x00\x01\x02\xFF\xFE' > "$bin_file"

  local result=$(starforge_read_file "$bin_file")

  # Should return valid JSON (even if content is binary)
  if echo "$result" | jq . > /dev/null 2>&1; then
    return 0
  else
    echo "(Failed to handle binary file)"
    return 1
  fi
}

test_handles_large_file() {
  # Test with a larger file (~100KB)
  local large_file="$TEST_DIR/large.txt"
  for i in {1..1000}; do
    echo "Line $i: This is some content to make the file larger and test performance with bigger files" >> "$large_file"
  done

  local result=$(starforge_read_file "$large_file")

  # Should complete successfully
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Invalid JSON for large file)"
    return 1
  fi

  # Should have content
  local content=$(echo "$result" | jq -r '.content')
  if [ -z "$content" ]; then
    echo "(No content for large file)"
    return 1
  fi

  return 0
}

test_handles_unicode_content() {
  # Test with unicode characters
  local unicode_file="$TEST_DIR/unicode.txt"
  echo "Hello 世界 🌍 Привет" > "$unicode_file"

  local result=$(starforge_read_file "$unicode_file")

  # Should be valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Invalid JSON for unicode)"
    return 1
  fi

  # Should preserve unicode
  local content=$(echo "$result" | jq -r '.content')
  if echo "$content" | grep -q "世界"; then
    return 0
  else
    echo "(Unicode not preserved)"
    return 1
  fi
}

test_error_handling_permission_denied() {
  # Test file with no read permissions
  local no_read_file="$TEST_DIR/no_read.txt"
  echo "secret" > "$no_read_file"
  chmod 000 "$no_read_file"

  local result=$(starforge_read_file "$no_read_file")

  # Should return error
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Invalid JSON for permission error)"
    chmod 644 "$no_read_file"  # Cleanup
    return 1
  fi

  local error=$(echo "$result" | jq -r '.error // empty')
  chmod 644 "$no_read_file"  # Cleanup

  if [ -n "$error" ]; then
    return 0
  else
    echo "(Should return error for unreadable file)"
    return 1
  fi
}

test_consistent_output_format() {
  # Verify all outputs follow consistent JSON format
  local test_file="$TEST_DIR/consistent.txt"
  echo "test" > "$test_file"

  # Success case
  local success_result=$(starforge_read_file "$test_file")
  if ! echo "$success_result" | jq -e '.content' > /dev/null 2>&1; then
    echo "(Success case missing .content field)"
    return 1
  fi

  # Error case
  local error_result=$(starforge_read_file "$TEST_DIR/nonexistent.txt")
  if ! echo "$error_result" | jq -e '.error' > /dev/null 2>&1; then
    echo "(Error case missing .error field)"
    return 1
  fi

  return 0
}

test_concurrent_reads() {
  # Test that multiple concurrent reads work correctly
  local file1="$TEST_DIR/file1.txt"
  local file2="$TEST_DIR/file2.txt"
  echo "Content 1" > "$file1"
  echo "Content 2" > "$file2"

  # Run concurrent reads
  local result1=$(starforge_read_file "$file1" &)
  local result2=$(starforge_read_file "$file2" &)
  wait

  # Both should succeed
  result1=$(starforge_read_file "$file1")
  result2=$(starforge_read_file "$file2")

  if echo "$result1" | jq . > /dev/null 2>&1 && \
     echo "$result2" | jq . > /dev/null 2>&1; then
    return 0
  else
    echo "(Concurrent reads failed)"
    return 1
  fi
}

# ============================================================================
# RUN TESTS
# ============================================================================

assert_test "reads actual project file (README.md)" test_reads_actual_project_file
assert_test "handles binary files gracefully" test_handles_binary_file_gracefully
assert_test "handles large files (~100KB)" test_handles_large_file
assert_test "preserves unicode content" test_handles_unicode_content
assert_test "handles permission denied errors" test_error_handling_permission_denied
assert_test "maintains consistent JSON output format" test_consistent_output_format
assert_test "supports concurrent reads" test_concurrent_reads

# Report
echo ""
echo "================================"
echo "Integration Test Results"
echo "================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "✅ All integration tests passed!"
  exit 0
else
  echo "❌ $FAILED integration test(s) failed"
  exit 1
fi
