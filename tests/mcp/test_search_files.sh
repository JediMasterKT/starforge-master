#!/bin/bash
# Test suite for starforge_search_files MCP tool
# Tests for issue #177 - Search Files Tool/Glob (B3)

# Note: NOT using 'set -e' because tests intentionally trigger errors
# to test error handling. The test_case() function handles failures properly.

# Setup test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Create test directory structure with various file types
mkdir -p "$TEST_DIR/src/components"
mkdir -p "$TEST_DIR/src/utils"
mkdir -p "$TEST_DIR/tests"
mkdir -p "$TEST_DIR/docs"

# Create test files
touch "$TEST_DIR/README.md"
touch "$TEST_DIR/package.json"
touch "$TEST_DIR/src/index.js"
touch "$TEST_DIR/src/app.js"
touch "$TEST_DIR/src/components/Button.js"
touch "$TEST_DIR/src/components/Card.js"
touch "$TEST_DIR/src/utils/helper.js"
touch "$TEST_DIR/src/utils/validator.py"
touch "$TEST_DIR/tests/test_app.js"
touch "$TEST_DIR/tests/test_utils.py"
touch "$TEST_DIR/docs/guide.md"
touch "$TEST_DIR/docs/api.md"

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
# TESTS FOR starforge_search_files (TDD - Tests First)
# ============================================================================

test_searches_files_by_pattern() {
  # Should search for files matching glob pattern *.js
  local result=$(starforge_search_files "*.js" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if files field exists and is an array
  local files=$(echo "$result" | jq -r '.files' 2>/dev/null)
  if [ -z "$files" ] || [ "$files" = "null" ]; then
    echo "(No files field in JSON)"
    return 1
  fi

  # Should find multiple .js files
  local count=$(echo "$result" | jq -r '.files | length' 2>/dev/null)
  if [ "$count" -lt 4 ]; then
    echo "(Expected at least 4 .js files, got: $count)"
    return 1
  fi

  # Verify files contain expected paths
  if echo "$result" | jq -r '.files[]' | grep -q "index.js" && \
     echo "$result" | jq -r '.files[]' | grep -q "app.js"; then
    return 0
  else
    echo "(Missing expected files in results)"
    return 1
  fi
}

test_defaults_to_current_directory() {
  # Should default to current directory when path not provided
  # Change to test directory
  cd "$TEST_DIR"
  local result=$(starforge_search_files "*.md" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should find .md files in current directory
  local count=$(echo "$result" | jq -r '.files | length' 2>/dev/null)
  if [ "$count" -lt 1 ]; then
    echo "(Expected at least 1 .md file, got: $count)"
    return 1
  fi

  return 0
}

test_handles_no_matches() {
  # Should return empty array when no files match pattern
  local result=$(starforge_search_files "*.nonexistent" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should have files field with empty array
  local count=$(echo "$result" | jq -r '.files | length' 2>/dev/null)
  if [ "$count" -eq 0 ]; then
    return 0
  else
    echo "(Expected 0 files, got: $count)"
    return 1
  fi
}

test_recursive_search() {
  # Should recursively search subdirectories
  local result=$(starforge_search_files "*.py" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should find .py files in subdirectories
  local count=$(echo "$result" | jq -r '.files | length' 2>/dev/null)
  if [ "$count" -lt 2 ]; then
    echo "(Expected at least 2 .py files, got: $count)"
    return 1
  fi

  # Verify recursive search found files in nested directories
  if echo "$result" | jq -r '.files[]' | grep -q "utils/validator.py" && \
     echo "$result" | jq -r '.files[]' | grep -q "tests/test_utils.py"; then
    return 0
  else
    echo "(Recursive search didn't find nested files)"
    return 1
  fi
}

test_handles_invalid_directory() {
  # Should return error for non-existent directory
  local result=$(starforge_search_files "*.js" "/nonexistent/directory" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should have error field
  local error=$(echo "$result" | jq -r '.error' 2>/dev/null)
  if [ -z "$error" ] || [ "$error" = "null" ]; then
    echo "(No error field for invalid directory)"
    return 1
  fi

  # Error should mention directory not found or doesn't exist
  if echo "$error" | grep -iq "not found\|does not exist\|no such"; then
    return 0
  else
    echo "(Error doesn't indicate missing directory. Got: $error)"
    return 1
  fi
}

test_returns_absolute_paths() {
  # Should return absolute paths (not relative)
  local result=$(starforge_search_files "*.json" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Get first file path
  local first_file=$(echo "$result" | jq -r '.files[0]' 2>/dev/null)
  if [ -z "$first_file" ] || [ "$first_file" = "null" ]; then
    echo "(No files found in result)"
    return 1
  fi

  # Path should be absolute (start with /)
  if [[ "$first_file" =~ ^/ ]]; then
    return 0
  else
    echo "(Path is not absolute: $first_file)"
    return 1
  fi
}

test_performance_large_directory() {
  # Should search <500ms for directory with many files
  # Create a directory with 1000 files
  local perf_dir="$TEST_DIR/perf_test"
  mkdir -p "$perf_dir"
  for i in {1..1000}; do
    touch "$perf_dir/file_$i.txt"
  done

  # Measure time (in milliseconds)
  local start=$(date +%s%3N)
  starforge_search_files "*.txt" "$perf_dir" > /dev/null 2>&1
  local end=$(date +%s%3N)
  local duration=$((end - start))

  # Should be under 500ms
  if [ $duration -lt 500 ]; then
    return 0
  else
    echo "(Too slow: ${duration}ms, target: <500ms)"
    return 1
  fi
}

test_handles_wildcard_patterns() {
  # Should support various wildcard patterns
  local result=$(starforge_search_files "*.md" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should find .md files
  local count=$(echo "$result" | jq -r '.files | length' 2>/dev/null)
  if [ "$count" -ge 3 ]; then
    return 0
  else
    echo "(Expected at least 3 .md files, got: $count)"
    return 1
  fi
}

test_returns_json_structure() {
  # Should return JSON with correct structure
  local result=$(starforge_search_files "*.js" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON)"
    return 1
  fi

  # Should have either files field (success) or error field (failure)
  local has_files=$(echo "$result" | jq 'has("files")' 2>/dev/null)
  local has_error=$(echo "$result" | jq 'has("error")' 2>/dev/null)

  if [ "$has_files" = "true" ] || [ "$has_error" = "true" ]; then
    return 0
  else
    echo "(JSON missing both files and error fields)"
    return 1
  fi
}

test_handles_empty_pattern() {
  # Should return error for empty pattern
  local result=$(starforge_search_files "" "$TEST_DIR" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should have error field
  local error=$(echo "$result" | jq -r '.error' 2>/dev/null)
  if [ -z "$error" ] || [ "$error" = "null" ]; then
    echo "(No error field for empty pattern)"
    return 1
  fi

  # Error should mention pattern is required
  if echo "$error" | grep -iq "pattern.*required\|pattern.*empty"; then
    return 0
  else
    echo "(Error doesn't indicate missing pattern. Got: $error)"
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
test_case "searches files by pattern" test_searches_files_by_pattern
test_case "defaults to current directory" test_defaults_to_current_directory
test_case "handles no matches" test_handles_no_matches
test_case "recursive search" test_recursive_search
test_case "handles invalid directory" test_handles_invalid_directory
test_case "returns absolute paths" test_returns_absolute_paths
test_case "handles wildcard patterns" test_handles_wildcard_patterns
test_case "returns valid JSON structure" test_returns_json_structure
test_case "handles empty pattern" test_handles_empty_pattern
test_case "meets performance target (<500ms for 1000 files)" test_performance_large_directory

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
