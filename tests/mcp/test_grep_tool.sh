#!/bin/bash
# Test suite for starforge_grep_content MCP tool
# Tests for issue #178 - Grep Content Tool (B4)

# Note: NOT using 'set -e' because tests intentionally trigger errors
# to test error handling. The test_case() function handles failures properly.

# Setup test environment
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Create test files with various content
mkdir -p "$TEST_DIR/project/src"
mkdir -p "$TEST_DIR/project/tests"

cat > "$TEST_DIR/project/src/app.py" << 'EOF'
def calculate_sum(a, b):
    """Calculate sum of two numbers."""
    return a + b

def calculate_product(a, b):
    """Calculate product of two numbers."""
    return a * b

ERROR_CODE = 500
EOF

cat > "$TEST_DIR/project/src/utils.py" << 'EOF'
def validate_input(value):
    """Validate user input."""
    if not value:
        raise ValueError("Input required")
    return True

def process_data(data):
    """Process incoming data."""
    return data.strip()
EOF

cat > "$TEST_DIR/project/tests/test_app.py" << 'EOF'
import pytest
from app import calculate_sum

def test_calculate_sum():
    """Test sum calculation."""
    assert calculate_sum(2, 3) == 5
EOF

cat > "$TEST_DIR/project/README.md" << 'EOF'
# Project Documentation

This is a sample project for testing grep functionality.

ERROR: This is not a real error.
EOF

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
# TESTS FOR starforge_grep_content (TDD - Tests First)
# ============================================================================

test_greps_content_by_pattern() {
  # Should find content matching pattern
  local result=$(starforge_grep_content "calculate_sum" "$TEST_DIR/project" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check if matches field exists
  local matches=$(echo "$result" | jq -r '.matches' 2>/dev/null)
  if [ -z "$matches" ] || [ "$matches" = "null" ]; then
    echo "(No matches field in JSON)"
    return 1
  fi

  # Should find matches in both app.py and test_app.py
  local count=$(echo "$result" | jq '.matches | length')
  if [ "$count" -ge 2 ]; then
    return 0
  else
    echo "(Expected at least 2 matches, got $count)"
    return 1
  fi
}

test_case_insensitive_search() {
  # Should support case-insensitive search
  local result=$(starforge_grep_content "ERROR" "$TEST_DIR/project" "" true 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should find both ERROR_CODE and "ERROR:" matches
  local count=$(echo "$result" | jq '.matches | length')
  if [ "$count" -ge 2 ]; then
    return 0
  else
    echo "(Expected at least 2 case-insensitive matches, got $count)"
    return 1
  fi
}

test_file_type_filter() {
  # Should filter by file type
  local result=$(starforge_grep_content "calculate" "$TEST_DIR/project" "py" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # All matches should be from .py files
  local all_py=true
  local files=$(echo "$result" | jq -r '.matches[].file' 2>/dev/null)
  while IFS= read -r file; do
    if [[ ! "$file" =~ \.py$ ]]; then
      all_py=false
      break
    fi
  done <<< "$files"

  if [ "$all_py" = true ]; then
    return 0
  else
    echo "(Found non-.py files with file_type filter)"
    return 1
  fi
}

test_returns_file_paths_and_line_numbers() {
  # Should return file paths and line numbers for matches
  local result=$(starforge_grep_content "def calculate_sum" "$TEST_DIR/project" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Check first match has file, line_number, and content fields
  local first_match=$(echo "$result" | jq -r '.matches[0]' 2>/dev/null)
  if [ -z "$first_match" ] || [ "$first_match" = "null" ]; then
    echo "(No matches found)"
    return 1
  fi

  local has_file=$(echo "$first_match" | jq 'has("file")')
  local has_line=$(echo "$first_match" | jq 'has("line_number")')
  local has_content=$(echo "$first_match" | jq 'has("content")')

  if [ "$has_file" = "true" ] && [ "$has_line" = "true" ] && [ "$has_content" = "true" ]; then
    return 0
  else
    echo "(Match missing required fields: file=$has_file, line_number=$has_line, content=$has_content)"
    return 1
  fi
}

test_handles_no_matches() {
  # Should return empty matches array when pattern not found
  local result=$(starforge_grep_content "NONEXISTENT_PATTERN_XYZ" "$TEST_DIR/project" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should have matches field with empty array
  local matches=$(echo "$result" | jq -r '.matches')
  local count=$(echo "$result" | jq '.matches | length')

  if [ "$count" -eq 0 ]; then
    return 0
  else
    echo "(Expected 0 matches for non-existent pattern, got $count)"
    return 1
  fi
}

test_requires_pattern() {
  # Should return error when pattern is missing
  local result=$(starforge_grep_content "" "$TEST_DIR/project" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should have error field
  local error=$(echo "$result" | jq -r '.error' 2>/dev/null)
  if [ -z "$error" ] || [ "$error" = "null" ]; then
    echo "(No error field for missing pattern)"
    return 1
  fi

  if echo "$error" | grep -iq "pattern.*required"; then
    return 0
  else
    echo "(Error doesn't mention pattern requirement. Got: $error)"
    return 1
  fi
}

test_handles_invalid_directory() {
  # Should return error for non-existent directory
  local result=$(starforge_grep_content "test" "$TEST_DIR/nonexistent" 2>&1)

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

  if echo "$error" | grep -iq "not found\|does not exist\|no such"; then
    return 0
  else
    echo "(Error doesn't indicate missing directory. Got: $error)"
    return 1
  fi
}

test_regex_pattern_support() {
  # Should support regex patterns
  local result=$(starforge_grep_content "calculate_[a-z]+" "$TEST_DIR/project" 2>&1)

  # Check if result is valid JSON
  if ! echo "$result" | jq . > /dev/null 2>&1; then
    echo "(Result is not valid JSON: $result)"
    return 1
  fi

  # Should find both calculate_sum and calculate_product
  local content=$(echo "$result" | jq -r '.matches[].content' 2>/dev/null | tr '\n' ' ')

  if echo "$content" | grep -q "calculate_sum" && echo "$content" | grep -q "calculate_product"; then
    return 0
  else
    echo "(Regex pattern didn't match expected functions)"
    return 1
  fi
}

test_performance_large_codebase() {
  # Should search 1000 files in <1s
  # Create large test directory
  local perf_dir="$TEST_DIR/large_project"
  mkdir -p "$perf_dir"

  # Create 1000 small files (faster than fewer large files)
  for i in {1..1000}; do
    echo "function test_$i() { return $i; }" > "$perf_dir/file_$i.js"
  done

  # Add target pattern to a few files
  echo "const TARGET_PATTERN = 'find_me';" >> "$perf_dir/file_500.js"
  echo "// TARGET_PATTERN in comment" >> "$perf_dir/file_750.js"

  # Measure time (in milliseconds)
  local start=$(date +%s%3N)
  starforge_grep_content "TARGET_PATTERN" "$perf_dir" > /dev/null 2>&1
  local end=$(date +%s%3N)
  local duration=$((end - start))

  # Should be under 1000ms (1 second)
  if [ $duration -lt 1000 ]; then
    return 0
  else
    echo "(Too slow: ${duration}ms, target: <1000ms)"
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
test_case "greps content by pattern" test_greps_content_by_pattern
test_case "case-insensitive search" test_case_insensitive_search
test_case "file type filter" test_file_type_filter
test_case "returns file paths and line numbers" test_returns_file_paths_and_line_numbers
test_case "handles no matches" test_handles_no_matches
test_case "requires pattern" test_requires_pattern
test_case "handles invalid directory" test_handles_invalid_directory
test_case "regex pattern support" test_regex_pattern_support
test_case "meets performance target (<1s for 1000 files)" test_performance_large_codebase

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
