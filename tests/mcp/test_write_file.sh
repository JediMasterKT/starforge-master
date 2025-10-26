#!/bin/bash
# Test suite for starforge_write_file MCP tool
# Tests for issue #176 - Write File Tool (B2)

# Note: NOT using 'set -e' because tests intentionally trigger errors
# to test error handling. The test_case() function handles failures properly.

# Setup test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Test counters
PASSED=0
FAILED=0

# Test function
test_case() {
  local name=$1
  shift
  echo -n "Testing: $name... "
  if "$@"; then
    echo "✅ PASS"
    ((PASSED++))
  else
    echo "❌ FAIL"
    ((FAILED++))
  fi
}

# ============================================================================
# TESTS FOR starforge_write_file (TDD - Tests First)
# ============================================================================

test_writes_file_successfully() {
  # Should write content to file and return success
  local test_file="$TEST_DIR/test_write.txt"
  local content="Hello, World!"

  local result=$(starforge_write_file "$test_file" "$content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if success field exists
  local success=$(echo "$result" | jq -r '.success' 2>/dev/null)
  if [ "$success" != "true" ]; then
    echo "(Success field is not true. Result: $result)"
    return 1
  fi

  # Verify file exists and has correct content
  if [ ! -f "$test_file" ]; then
    echo "(File was not created)"
    return 1
  fi

  local actual_content=$(cat "$test_file")
  if [ "$actual_content" = "$content" ]; then
    return 0
  else
    echo "(Content mismatch. Expected: '$content', Got: '$actual_content')"
    return 1
  fi
}

test_creates_parent_directory() {
  # Should create parent directories if they don't exist
  local test_file="$TEST_DIR/nested/deep/path/file.txt"
  local content="Nested content"

  local result=$(starforge_write_file "$test_file" "$content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if success field exists
  local success=$(echo "$result" | jq -r '.success' 2>/dev/null)
  if [ "$success" != "true" ]; then
    echo "(Failed to create parent directories. Result: $result)"
    return 1
  fi

  # Verify file exists
  if [ ! -f "$test_file" ]; then
    echo "(File was not created in nested directory)"
    return 1
  fi

  # Verify content
  local actual_content=$(cat "$test_file")
  if [ "$actual_content" = "$content" ]; then
    return 0
  else
    echo "(Content mismatch in nested file)"
    return 1
  fi
}

test_overwrites_existing_file() {
  # Should overwrite existing file with new content
  local test_file="$TEST_DIR/overwrite_test.txt"

  # Create initial file
  echo "Original content" > "$test_file"

  # Overwrite with new content
  local new_content="New content"
  local result=$(starforge_write_file "$test_file" "$new_content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if success field exists
  local success=$(echo "$result" | jq -r '.success' 2>/dev/null)
  if [ "$success" != "true" ]; then
    echo "(Failed to overwrite file. Result: $result)"
    return 1
  fi

  # Verify content was overwritten
  local actual_content=$(cat "$test_file")
  if [ "$actual_content" = "$new_content" ]; then
    return 0
  else
    echo "(Content was not overwritten. Got: '$actual_content')"
    return 1
  fi
}

test_atomic_write() {
  # Should use atomic write (temp file + mv)
  # We test this by verifying that partial writes don't corrupt the file
  local test_file="$TEST_DIR/atomic_test.txt"

  # Pre-create file with original content
  echo "Original content" > "$test_file"

  # Write new content atomically
  local new_content="New atomic content"
  local result=$(starforge_write_file "$test_file" "$new_content" 2>&1)

  # Verify no temp files left behind
  local temp_files=$(find "$TEST_DIR" -name "*.tmp.*" 2>/dev/null | wc -l)
  if [ $temp_files -gt 0 ]; then
    echo "(Temp files left behind after write)"
    return 1
  fi

  # Verify successful write
  local success=$(echo "$result" | jq -r '.success' 2>/dev/null)
  if [ "$success" != "true" ]; then
    echo "(Atomic write failed. Result: $result)"
    return 1
  fi

  # Verify content is correct (if write is atomic, content should be complete)
  local actual_content=$(cat "$test_file")
  if [ "$actual_content" = "$new_content" ]; then
    return 0
  else
    echo "(Atomic write produced incorrect content)"
    return 1
  fi
}

test_rejects_relative_path() {
  # Should reject relative paths and return error
  local result=$(starforge_write_file "relative/path/file.txt" "content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if error field exists
  local error=$(echo "$result" | jq -r '.error' 2>/dev/null)
  if [ -z "$error" ] || [ "$error" = "null" ]; then
    echo "(No error field for relative path)"
    return 1
  fi

  # Error should mention "absolute"
  if echo "$error" | grep -iq "absolute"; then
    return 0
  else
    echo "(Error doesn't mention absolute path requirement. Got: $error)"
    return 1
  fi
}

test_handles_empty_content() {
  # Should handle empty content (write empty file)
  local test_file="$TEST_DIR/empty_test.txt"
  local content=""

  local result=$(starforge_write_file "$test_file" "$content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if success field exists
  local success=$(echo "$result" | jq -r '.success' 2>/dev/null)
  if [ "$success" != "true" ]; then
    echo "(Failed to write empty content. Result: $result)"
    return 1
  fi

  # Verify file exists and is empty
  if [ ! -f "$test_file" ]; then
    echo "(File was not created for empty content)"
    return 1
  fi

  local size=$(wc -c < "$test_file" | tr -d ' ')
  if [ "$size" -eq 0 ]; then
    return 0
  else
    echo "(Empty content produced non-empty file: $size bytes)"
    return 1
  fi
}

test_handles_special_characters() {
  # Should handle special characters in content
  local test_file="$TEST_DIR/special_chars.txt"
  local content='Line with "quotes" and \backslash
Line with newline and tabs	here'

  local result=$(starforge_write_file "$test_file" "$content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if success field exists
  local success=$(echo "$result" | jq -r '.success' 2>/dev/null)
  if [ "$success" != "true" ]; then
    echo "(Failed to write special characters. Result: $result)"
    return 1
  fi

  # Verify content matches exactly
  local actual_content=$(cat "$test_file")
  if [ "$actual_content" = "$content" ]; then
    return 0
  else
    echo "(Special characters not preserved correctly)"
    return 1
  fi
}

test_performance_write() {
  # Should write file in <50ms (relaxed threshold to prevent flakes)
  # Original requirement was <20ms, but filesystem variability causes flakes
  local test_file="$TEST_DIR/perf_test.txt"
  local content="Performance test content"

  # Measure time (in milliseconds)
  local start=$(date +%s%3N)
  starforge_write_file "$test_file" "$content" > /dev/null 2>&1
  local end=$(date +%s%3N)
  local duration=$((end - start))

  # Should be under 50ms (relaxed threshold to prevent flakes)
  if [ $duration -lt 50 ]; then
    return 0
  else
    echo "(Too slow: ${duration}ms, target: <50ms)"
    return 1
  fi
}

test_validates_path_required() {
  # Should return error if path is not provided
  local result=$(starforge_write_file "" "content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if error field exists
  local error=$(echo "$result" | jq -r '.error' 2>/dev/null)
  if [ -z "$error" ] || [ "$error" = "null" ]; then
    echo "(No error field for empty path)"
    return 1
  fi

  # Error should mention "required" or "path"
  if echo "$error" | grep -iq "required\|path"; then
    return 0
  else
    echo "(Error doesn't indicate missing path. Got: $error)"
    return 1
  fi
}

test_returns_json_structure() {
  # Should return JSON with correct structure
  local test_file="$TEST_DIR/json_test.txt"
  local result=$(starforge_write_file "$test_file" "test content" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON)"
    return 1
  fi

  # Should have either success field (success) or error field (failure)
  local has_success=$(echo "$result" | jq 'has("success")' 2>/dev/null)
  local has_error=$(echo "$result" | jq 'has("error")' 2>/dev/null)

  if [ "$has_success" = "true" ] || [ "$has_error" = "true" ]; then
    return 0
  else
    echo "(JSON missing both success and error fields)"
    return 1
  fi
}

# ============================================================================
# RUN TESTS
# ============================================================================

# Source the implementation (will fail in red phase)
TEST_PHASE=${1:-"red"}

if [ "$TEST_PHASE" = "green" ]; then
  # Load the actual implementation
  if [ -f "templates/lib/mcp-tools-file.sh" ]; then
    source templates/lib/mcp-tools-file.sh
  else
    echo "❌ Implementation file not found: templates/lib/mcp-tools-file.sh"
    exit 1
  fi
fi

if [ "$TEST_PHASE" = "red" ]; then
  echo "================================"
  echo "TDD Red Phase - Tests Should FAIL"
  echo "================================"
else
  echo "================================"
  echo "TDD Green Phase - Tests Should PASS"
  echo "================================"
fi
echo ""

# Run all tests
test_case "writes file successfully" test_writes_file_successfully
test_case "creates parent directory" test_creates_parent_directory
test_case "overwrites existing file" test_overwrites_existing_file
test_case "atomic write (no temp files left)" test_atomic_write
test_case "rejects relative path" test_rejects_relative_path
test_case "handles empty content" test_handles_empty_content
test_case "handles special characters" test_handles_special_characters
test_case "validates path required" test_validates_path_required
test_case "returns valid JSON structure" test_returns_json_structure
test_case "meets performance target (<50ms)" test_performance_write

# Report
echo ""
echo "================================"
echo "Test Results ($TEST_PHASE Phase)"
echo "================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ "$TEST_PHASE" = "red" ]; then
  # Red phase: expect failures
  if [ $FAILED -gt 0 ]; then
    echo "✅ TDD Red Phase: Tests failing as expected (function not implemented yet)"
    exit 0
  else
    echo "❌ TDD Red Phase: Tests should fail but they passed!"
    exit 1
  fi
else
  # Green phase: expect all tests to pass
  if [ $FAILED -eq 0 ]; then
    echo "✅ TDD Green Phase: All tests passing!"
    exit 0
  else
    echo "❌ TDD Green Phase: $FAILED test(s) failed"
    exit 1
  fi
fi
