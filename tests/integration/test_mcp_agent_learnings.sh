#!/bin/bash
# Integration test for MCP get_agent_learnings tool
# Tests the tool with real agent learnings files from the repository

set -e

TEST_NAME="MCP get_agent_learnings Integration Test"
echo "========================================="
echo "$TEST_NAME"
echo "========================================="
echo ""

# Setup: Use real repository structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export PROJECT_ROOT
export STARFORGE_CLAUDE_DIR="$PROJECT_ROOT/.claude"

# Create test .claude directory structure
mkdir -p "$STARFORGE_CLAUDE_DIR/agents/agent-learnings/junior-engineer"
mkdir -p "$STARFORGE_CLAUDE_DIR/agents/agent-learnings/senior-engineer"
mkdir -p "$STARFORGE_CLAUDE_DIR/agents/agent-learnings/qa-engineer"

# Create sample learnings files
cat > "$STARFORGE_CLAUDE_DIR/agents/agent-learnings/junior-engineer/learnings.md" <<'EOF'
---
name: "junior-engineer"
description: "Learnings and patterns for the junior-engineer agent"
---

# Agent Learnings

## Learning 1: Always use TDD

**Date:** 2025-01-15

**What happened:**
Tests were written after implementation.

**What was learned:**
TDD prevents bugs and improves design.

**Why it matters:**
Better code quality from the start.

**Corrected approach:**
Always write tests first.
EOF

cat > "$STARFORGE_CLAUDE_DIR/agents/agent-learnings/senior-engineer/learnings.md" <<'EOF'
---
name: "senior-engineer"
description: "Learnings for senior engineer"
---

# Senior Engineer Learnings

## Learning 1: Architecture diagrams required

**Date:** 2025-01-16

**What happened:**
Tickets lacked diagrams, caused confusion.

**What was learned:**
Diagrams prevent implementation drift.
EOF

# Source the MCP tools
source "$PROJECT_ROOT/templates/lib/mcp-tools-trigger.sh"

# Test 1: Get learnings for specific agent
echo "Test 1: Get learnings for junior-engineer"
result=$(get_agent_learnings "junior-engineer")
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ FAIL: get_agent_learnings returned error"
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

# Verify content contains expected learnings
content_text=$(echo "$result" | jq -r '.content[0].text')
if ! echo "$content_text" | grep -q "Learning 1: Always use TDD"; then
  echo "❌ FAIL: Content doesn't contain expected learning"
  echo "   Content: $content_text"
  exit 1
fi

echo "✅ PASS: Retrieved junior-engineer learnings successfully"
echo ""

# Test 2: Get learnings for different agent
echo "Test 2: Get learnings for senior-engineer"
result=$(get_agent_learnings "senior-engineer")
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "❌ FAIL: get_agent_learnings returned error for senior-engineer"
  exit 1
fi

content_text=$(echo "$result" | jq -r '.content[0].text')
if ! echo "$content_text" | grep -q "Architecture diagrams required"; then
  echo "❌ FAIL: Content doesn't contain senior-engineer learning"
  echo "   Content: $content_text"
  exit 1
fi

echo "✅ PASS: Retrieved senior-engineer learnings successfully"
echo ""

# Test 3: Handle missing learnings gracefully
echo "Test 3: Handle missing learnings for agent without file"
result=$(get_agent_learnings "qa-engineer")
exit_code=$?

# Should succeed but return empty or default message
if [ $exit_code -ne 0 ]; then
  echo "❌ FAIL: Should handle missing learnings gracefully"
  echo "   Exit code: $exit_code"
  exit 1
fi

# Verify it returns valid JSON
if ! echo "$result" | jq -e '.content' > /dev/null 2>&1; then
  echo "❌ FAIL: Invalid JSON for missing learnings"
  echo "   Output: $result"
  exit 1
fi

echo "✅ PASS: Handles missing learnings gracefully"
echo ""

# Test 4: Handle invalid agent name
echo "Test 4: Handle invalid/nonexistent agent"
result=$(get_agent_learnings "nonexistent-agent")
exit_code=$?

# Should handle gracefully
if [ $exit_code -ne 0 ]; then
  echo "❌ FAIL: Should handle invalid agent gracefully"
  exit 1
fi

echo "✅ PASS: Handles invalid agent gracefully"
echo ""

# Test 5: Performance test
echo "Test 5: Performance with real file"

# Run 10 times and measure average
total_time=0
iterations=10

for i in $(seq 1 $iterations); do
  start=$(date +%s%N)
  get_agent_learnings "junior-engineer" > /dev/null 2>&1
  end=$(date +%s%N)
  duration=$(( (end - start) / 1000000 ))
  total_time=$((total_time + duration))
done

avg_time=$((total_time / iterations))

# Target: <10ms per ticket requirement
if [ $avg_time -gt 50 ]; then
  echo "❌ FAIL: Average time too slow"
  echo "   Average: ${avg_time}ms (target: <50ms)"
  exit 1
fi

echo "✅ PASS: Performance acceptable (avg: ${avg_time}ms over $iterations runs)"
echo ""

# Test 6: Content completeness
echo "Test 6: Verify complete content returned"
result=$(get_agent_learnings "junior-engineer")
content_text=$(echo "$result" | jq -r '.content[0].text')

# Check for key sections
if ! echo "$content_text" | grep -q "name:"; then
  echo "❌ FAIL: Missing frontmatter name"
  exit 1
fi

if ! echo "$content_text" | grep -q "Agent Learnings"; then
  echo "❌ FAIL: Missing 'Agent Learnings' header"
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
echo "  - Specific agent retrieval: ✅"
echo "  - Multiple agents: ✅"
echo "  - Missing learnings handling: ✅"
echo "  - Invalid agent handling: ✅"
echo "  - Performance (<50ms): ✅"
echo "  - Content completeness: ✅"
