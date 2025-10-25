#!/bin/bash
# Test suite for context-helpers.sh additional functions
# Tests for issue #150 - permission-free helper scripts

# Setup test environment
TEST_DIR=$(mktemp -d)
STARFORGE_CLAUDE_DIR="$TEST_DIR/.claude"
mkdir -p "$STARFORGE_CLAUDE_DIR/spikes/spike-20251024-1200-test-feature"
mkdir -p "$STARFORGE_CLAUDE_DIR/spikes/spike-20251024-1300-newer-feature"

# Create test breakdown file
cat > "$STARFORGE_CLAUDE_DIR/spikes/spike-20251024-1300-newer-feature/breakdown.md" << 'EOF'
# Task Breakdown: Test Feature Name

## Context
Testing breakdown extraction

### Subtask 1: First Task
Test content

### Subtask 2: Second Task
More test content

### Subtask 3: Third Task
Final test content
EOF

# Source the context-helpers.sh
source templates/scripts/context-helpers.sh

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
# TESTS FOR NEW FUNCTIONS (SHOULD FAIL - TDD Red Phase)
# ============================================================================

test_get_latest_spike_dir() {
  # Should return the most recent spike directory
  local result=$(get_latest_spike_dir)
  local expected="$STARFORGE_CLAUDE_DIR/spikes/spike-20251024-1300-newer-feature"

  if [ "$result" = "$expected" ]; then
    return 0
  else
    echo "(Expected: $expected, Got: $result)"
    return 1
  fi
}

test_get_feature_name_from_breakdown() {
  # Should extract feature name from breakdown
  local breakdown="$STARFORGE_CLAUDE_DIR/spikes/spike-20251024-1300-newer-feature/breakdown.md"
  local result=$(get_feature_name_from_breakdown "$breakdown")
  local expected="Test Feature Name"

  if [ "$result" = "$expected" ]; then
    return 0
  else
    echo "(Expected: '$expected', Got: '$result')"
    return 1
  fi
}

test_get_subtask_count_from_breakdown() {
  # Should count subtasks in breakdown
  local breakdown="$STARFORGE_CLAUDE_DIR/spikes/spike-20251024-1300-newer-feature/breakdown.md"
  local result=$(get_subtask_count_from_breakdown "$breakdown")
  local expected="3"

  if [ "$result" = "$expected" ]; then
    return 0
  else
    echo "(Expected: $expected, Got: $result)"
    return 1
  fi
}

test_get_latest_spike_dir_empty() {
  # Should handle empty spike directory
  local temp_dir=$(mktemp -d)
  local old_dir="$STARFORGE_CLAUDE_DIR"
  STARFORGE_CLAUDE_DIR="$temp_dir/.claude"
  mkdir -p "$STARFORGE_CLAUDE_DIR/spikes"

  local result=$(get_latest_spike_dir)
  STARFORGE_CLAUDE_DIR="$old_dir"
  rm -rf "$temp_dir"

  if [ -z "$result" ]; then
    return 0
  else
    echo "(Expected empty, Got: $result)"
    return 1
  fi
}

test_get_feature_name_missing_file() {
  # Should handle missing breakdown file
  local result=$(get_feature_name_from_breakdown "/nonexistent/file.md")

  if [ -z "$result" ]; then
    return 0
  else
    echo "(Expected empty, Got: $result)"
    return 1
  fi
}

test_get_subtask_count_no_subtasks() {
  # Should return 0 for breakdown with no subtasks
  local temp_file=$(mktemp)
  echo "# Task Breakdown: No Subtasks" > "$temp_file"
  echo "Some content" >> "$temp_file"

  local result=$(get_subtask_count_from_breakdown "$temp_file")
  rm "$temp_file"

  if [ "$result" = "0" ]; then
    return 0
  else
    echo "(Expected: 0, Got: $result)"
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

test_case "get_latest_spike_dir returns newest spike" test_get_latest_spike_dir
test_case "get_latest_spike_dir handles empty directory" test_get_latest_spike_dir_empty
test_case "get_feature_name_from_breakdown extracts name" test_get_feature_name_from_breakdown
test_case "get_feature_name_from_breakdown handles missing file" test_get_feature_name_missing_file
test_case "get_subtask_count_from_breakdown counts subtasks" test_get_subtask_count_from_breakdown
test_case "get_subtask_count_from_breakdown handles no subtasks" test_get_subtask_count_no_subtasks

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
