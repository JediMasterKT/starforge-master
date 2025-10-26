#!/bin/bash
# Integration test for MCP get_project_context tool
# Tests the tool with real PROJECT_CONTEXT.md from the repository

set -e

TEST_NAME="MCP get_project_context Integration Test"
echo "========================================="
echo "$TEST_NAME"
echo "========================================="
echo ""

# Setup: Use real repository structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT
export STARFORGE_CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Verify PROJECT_CONTEXT.md exists (should be in main repo)
MAIN_REPO_CONTEXT="/Users/krunaaltavkar/starforge-master-discord/.claude/PROJECT_CONTEXT.md"
if [ ! -f "$MAIN_REPO_CONTEXT" ]; then
  echo "❌ FAIL: PROJECT_CONTEXT.md not found in main repo"
  echo "   Expected: $MAIN_REPO_CONTEXT"
  exit 1
fi

# Create test .claude directory with PROJECT_CONTEXT.md
mkdir -p "$STARFORGE_CLAUDE_DIR"
cp "$MAIN_REPO_CONTEXT" "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md"

# Source the MCP tools
source "$PROJECT_ROOT/templates/lib/mcp-tools-trigger.sh"

# Test 1: Happy path - Get project context from real file
echo "Test 1: Get project context with real PROJECT_CONTEXT.md"
result=$(get_project_context)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ FAIL: get_project_context returned error"
  echo "   Exit code: $exit_code"
  echo "   Output: $result"
  exit 1
fi

# Verify JSON structure
if ! echo "$result" | jq -e '.content' > /dev/null 2>&1; then
  echo "❌ FAIL: Invalid JSON structure"
  echo "   Output: $result"
  exit 1
fi

# Verify content contains expected project info
content_text=$(echo "$result" | jq -r '.content[0].text')
if ! echo "$content_text" | grep -q "StarForge"; then
  echo "❌ FAIL: Content doesn't contain 'StarForge'"
  echo "   Content: $content_text"
  exit 1
fi

echo "✅ PASS: Retrieved project context successfully"
echo ""

# Test 2: Error handling - Missing file
echo "Test 2: Error handling for missing PROJECT_CONTEXT.md"
rm "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md"

# Capture both stdout and stderr, and exit code separately
set +e
result=$(get_project_context 2>&1)
exit_code=$?
set -e

if [ $exit_code -eq 0 ]; then
  echo "❌ FAIL: Should return error for missing file"
  exit 1
fi

if ! echo "$result" | grep -iq "not found"; then
  echo "❌ FAIL: Error message should mention 'not found'"
  echo "   Output: $result"
  exit 1
fi

echo "✅ PASS: Handles missing file gracefully"
echo ""

# Test 3: Performance with real file
echo "Test 3: Performance with real PROJECT_CONTEXT.md"
cp "$MAIN_REPO_CONTEXT" "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md"

# Run 10 times and measure average
total_time=0
iterations=10

for i in $(seq 1 $iterations); do
  start=$(date +%s%N)
  get_project_context > /dev/null 2>&1
  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 ))
  total_time=$((total_time + duration))
done

avg_time=$((total_time / iterations))

if [ $avg_time -gt 100 ]; then
  echo "❌ FAIL: Average time too slow"
  echo "   Average: ${avg_time}ms (target: <100ms)"
  exit 1
fi

echo "✅ PASS: Performance acceptable (avg: ${avg_time}ms over $iterations runs)"
echo ""

# Test 4: Content completeness
echo "Test 4: Verify complete content returned"
result=$(get_project_context)
content_text=$(echo "$result" | jq -r '.content[0].text')

# Check for key sections
missing_sections=""
if ! echo "$content_text" | grep -q "Project Name"; then
  missing_sections="$missing_sections 'Project Name'"
fi
if ! echo "$content_text" | grep -q "Description"; then
  missing_sections="$missing_sections 'Description'"
fi
if ! echo "$content_text" | grep -q "Primary Goal"; then
  missing_sections="$missing_sections 'Primary Goal'"
fi

if [ -n "$missing_sections" ]; then
  echo "❌ FAIL: Missing sections:$missing_sections"
  exit 1
fi

echo "✅ PASS: All expected sections present"
echo ""

# Cleanup
rm -rf "$STARFORGE_CLAUDE_DIR"

# Summary
echo "========================================="
echo "✅ ALL INTEGRATION TESTS PASSED"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Real file integration: ✅"
echo "  - Error handling: ✅"
echo "  - Performance (<100ms): ✅"
echo "  - Content completeness: ✅"
