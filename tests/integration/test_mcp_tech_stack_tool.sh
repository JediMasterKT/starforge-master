#!/bin/bash
# Integration test for MCP get_tech_stack tool
# Tests the tool with real TECH_STACK.md from the repository

set -e

TEST_NAME="MCP get_tech_stack Integration Test"
echo "========================================="
echo "$TEST_NAME"
echo "========================================="
echo ""

# Setup: Use real repository structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT
export STARFORGE_CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Find TECH_STACK.md (check worktree first, then main repo)
TECH_STACK_SOURCE=""
if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
  TECH_STACK_SOURCE="$STARFORGE_CLAUDE_DIR/TECH_STACK.md"
else
  # Try main repo
  MAIN_REPO=$(git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2)
  if [ -f "$MAIN_REPO/.claude/TECH_STACK.md" ]; then
    TECH_STACK_SOURCE="$MAIN_REPO/.claude/TECH_STACK.md"
  fi
fi

if [ -z "$TECH_STACK_SOURCE" ]; then
  echo "❌ FAIL: TECH_STACK.md not found"
  echo "   Checked: $STARFORGE_CLAUDE_DIR/TECH_STACK.md"
  exit 1
fi

# Create temporary test .claude directory with TECH_STACK.md
TEST_CLAUDE_DIR="/tmp/starforge-test-$$/.claude"
mkdir -p "$TEST_CLAUDE_DIR"
cp "$TECH_STACK_SOURCE" "$TEST_CLAUDE_DIR/TECH_STACK.md"

# Override STARFORGE_CLAUDE_DIR for tests
export STARFORGE_CLAUDE_DIR="$TEST_CLAUDE_DIR"

# Source the MCP tools
source "$PROJECT_ROOT/templates/lib/mcp-tools-trigger.sh"

# Test 1: Happy path - Get tech stack from real file
echo "Test 1: Get tech stack with real TECH_STACK.md"
result=$(get_tech_stack)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ FAIL: get_tech_stack returned error"
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

# Verify content contains expected tech stack info
content_text=$(echo "$result" | jq -r '.content[0].text')
if ! echo "$content_text" | grep -qi "bash\|shell\|language"; then
  echo "❌ FAIL: Content doesn't contain tech stack info"
  echo "   Content: $content_text"
  exit 1
fi

echo "✅ PASS: Retrieved tech stack successfully"
echo ""

# Test 2: Error handling - Missing file
echo "Test 2: Error handling for missing TECH_STACK.md"
rm "$STARFORGE_CLAUDE_DIR/TECH_STACK.md"

# Capture both stdout and stderr, and exit code separately
set +e
result=$(get_tech_stack 2>&1)
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

# Test 3: Performance with real file (target: <100ms, matches D1)
echo "Test 3: Performance with real TECH_STACK.md"
cp "$TECH_STACK_SOURCE" "$STARFORGE_CLAUDE_DIR/TECH_STACK.md"

# Run 10 times and measure average
total_time=0
iterations=10

for i in $(seq 1 $iterations); do
  start=$(date +%s%N)
  get_tech_stack > /dev/null 2>&1
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
result=$(get_tech_stack)
content_text=$(echo "$result" | jq -r '.content[0].text')

# Check that content is not empty
if [ -z "$content_text" ] || [ "$content_text" = "null" ]; then
  echo "❌ FAIL: Content is empty"
  exit 1
fi

# Check that content length matches expectations (should be substantial)
content_length=${#content_text}
if [ $content_length -lt 100 ]; then
  echo "❌ FAIL: Content too short (${content_length} chars)"
  exit 1
fi

echo "✅ PASS: Complete content returned (${content_length} chars)"
echo ""

# Cleanup
rm -rf "/tmp/starforge-test-$$"

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
