#!/bin/bash
# Test suite for MCP context tools
# Tests for issue #183 - get_project_context MCP tool

# Setup test environment
TEST_DIR=$(mktemp -d)
PROJECT_ROOT="$TEST_DIR"
STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
mkdir -p "$STARFORGE_CLAUDE_DIR"

# Create test PROJECT_CONTEXT.md
cat > "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" << 'EOF'
# Test Project Context

## Project Name
**TestProject**

## Description
A test project for validating MCP tools.

## Primary Goal
Test the get_project_context MCP tool implementation.
EOF

# Source the mcp-tools-trigger.sh
source templates/lib/mcp-tools-trigger.sh 2>/dev/null || true

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
# TESTS FOR get_project_context (SHOULD FAIL - TDD Red Phase)
# ============================================================================

test_returns_project_context() {
  # Should return PROJECT_CONTEXT.md contents
  local result=$(get_project_context 2>&1)

  # Check if result contains expected content
  if echo "$result" | grep -q "TestProject" && echo "$result" | grep -q "Test the get_project_context MCP tool implementation"; then
    return 0
  else
    echo "(Expected content with 'TestProject', Got: $result)"
    return 1
  fi
}

test_returns_json_format() {
  # Should return valid JSON with MCP response format
  local result=$(get_project_context 2>&1)

  # Check for JSON structure (basic check)
  if echo "$result" | jq -e '.content' > /dev/null 2>&1; then
    # Check for text type
    if echo "$result" | jq -e '.content[0].type == "text"' > /dev/null 2>&1; then
      return 0
    else
      echo "(Expected .content[0].type == 'text')"
      return 1
    fi
  else
    echo "(Expected valid JSON with .content field, Got: $result)"
    return 1
  fi
}

test_errors_when_missing() {
  # Should error gracefully when PROJECT_CONTEXT.md is missing
  local temp_dir=$(mktemp -d)
  local old_root="$PROJECT_ROOT"
  PROJECT_ROOT="$temp_dir"
  STARFORGE_CLAUDE_DIR="$temp_dir/.claude"
  mkdir -p "$STARFORGE_CLAUDE_DIR"

  local result=$(get_project_context 2>&1)
  local exit_code=$?

  PROJECT_ROOT="$old_root"
  STARFORGE_CLAUDE_DIR="$old_root/.claude"
  rm -rf "$temp_dir"

  # Should return error (non-zero exit or error in JSON)
  if [ $exit_code -ne 0 ] || echo "$result" | grep -q "error\|not found\|missing"; then
    return 0
  else
    echo "(Expected error for missing file, Got: $result)"
    return 1
  fi
}

test_performance() {
  # Should complete in <100ms (fast enough for interactive use)
  # Note: JSON processing with jq adds ~20-30ms overhead, which is acceptable
  local start=$(date +%s%N)
  get_project_context > /dev/null 2>&1
  local end=$(date +%s%N)

  local duration_ms=$(( (end - start) / 1000000 ))

  if [ $duration_ms -lt 100 ]; then
    return 0
  else
    echo "(Expected <100ms, Got: ${duration_ms}ms)"
    return 1
  fi
}

test_content_complete() {
  # Should return complete file content (not truncated)
  local result=$(get_project_context 2>&1)

  # Extract text content from JSON
  local text_content=$(echo "$result" | jq -r '.content[0].text' 2>/dev/null || echo "")

  # Check all sections are present
  if echo "$text_content" | grep -q "Project Name" && \
     echo "$text_content" | grep -q "Description" && \
     echo "$text_content" | grep -q "Primary Goal"; then
    return 0
  else
    echo "(Expected all sections, Got: $text_content)"
    return 1
  fi
}

# Run tests
TEST_PHASE=${1:-"green"}

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

test_case "get_project_context returns project context" test_returns_project_context
test_case "get_project_context returns JSON format" test_returns_json_format
test_case "get_project_context errors when missing" test_errors_when_missing
test_case "get_project_context meets performance target" test_performance
test_case "get_project_context returns complete content" test_content_complete

# Cleanup
rm -rf "$TEST_DIR"

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
    echo "✅ TDD Red Phase: Tests failing as expected (functions not implemented yet)"
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
