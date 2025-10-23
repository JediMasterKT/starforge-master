#!/bin/bash
# StarForge Trigger Router Test Suite
# Tests for .claude/lib/router.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$STARFORGE_ROOT/.tmp/router-test"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Trigger Router Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_file_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-File exists: $file}"

    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (file not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_not_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-File should not exist: $file}"

    if [ ! -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (file exists: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_dir_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local dir="$1"
    local desc="${2:-Directory exists: $dir}"

    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (directory not found: $dir)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_equals() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local expected="$1"
    local actual="$2"
    local desc="${3:-Values should be equal}"

    if [ "$expected" = "$actual" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Expected: $expected"
        echo -e "    Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    # Clean up old test directory
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"

    # Create minimal .claude directory structure
    mkdir -p "$TEST_DIR/.claude/triggers/processed"
    mkdir -p "$TEST_DIR/.claude/triggers/invalid"
    mkdir -p "$TEST_DIR/.claude/queues/tpm/pending"
    mkdir -p "$TEST_DIR/.claude/queues/orchestrator/pending"
    mkdir -p "$TEST_DIR/.claude/queues/senior-engineer/pending"

    # Create empty log file
    touch "$TEST_DIR/.claude/router.log"

    cd "$TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    cd "$STARFORGE_ROOT"
    rm -rf "$TEST_DIR"
}

# Mock logger functions for testing
log_info() { echo "[INFO] $1: $2" >> "$TEST_DIR/.claude/router.log"; }
log_error() { echo "[ERROR] $1: $2" >> "$TEST_DIR/.claude/router.log"; }
log_warn() { echo "[WARN] $1: $2" >> "$TEST_DIR/.claude/router.log"; }

# Source the router library (will fail initially - that's expected in TDD)
if [ -f "$STARFORGE_ROOT/.claude/lib/router.sh" ]; then
    source "$STARFORGE_ROOT/.claude/lib/router.sh"
else
    echo -e "${YELLOW}⚠${NC} router.sh not found yet (expected in RED phase)"
    # Define stub function so tests can run
    route_trigger_to_queue() {
        echo "route_trigger_to_queue not implemented yet"
        return 1
    }
fi

# ============================================
# TEST SUITE
# ============================================

echo "📋 Test Suite: Trigger Router"
echo ""

# Test 1: Valid trigger converted to queue task
test_route_valid_trigger() {
    setup_test_env

    local trigger_file="$TEST_DIR/.claude/triggers/test-trigger.trigger"

    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "tpm",
  "action": "create_tickets",
  "context": {
    "feature": "test-feature"
  }
}
JSON

    echo "Test 1: Route valid trigger to queue"
    route_trigger_to_queue "$trigger_file"

    # Assert: Task created in pending queue
    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$task_count" "One task created in tpm/pending"

    # Assert: Trigger moved to processed
    assert_file_not_exists "$trigger_file" "Original trigger removed"
    assert_equals "1" "$(ls "$TEST_DIR/.claude/triggers/processed"/*.trigger 2>/dev/null | wc -l | tr -d ' ')" "Trigger archived in processed/"

    cleanup_test_env
}

# Test 2: Invalid JSON trigger moved to invalid/
test_route_invalid_json() {
    setup_test_env

    local trigger_file="$TEST_DIR/.claude/triggers/bad-trigger.trigger"

    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "tpm",
  "action": "create_tickets"
  INVALID JSON
}
JSON

    echo "Test 2: Route invalid JSON trigger"
    route_trigger_to_queue "$trigger_file" || true

    # Assert: No task created
    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "0" "$task_count" "No task created for invalid JSON"

    # Assert: Trigger moved to invalid/
    assert_file_not_exists "$trigger_file" "Original trigger removed"
    assert_equals "1" "$(ls "$TEST_DIR/.claude/triggers/invalid"/*.trigger 2>/dev/null | wc -l | tr -d ' ')" "Trigger moved to invalid/"

    cleanup_test_env
}

# Test 3: All fields correctly mapped
test_route_field_mapping() {
    setup_test_env

    local trigger_file="$TEST_DIR/.claude/triggers/mapping-test.trigger"

    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "orchestrator",
  "action": "assign_tickets",
  "context": {
    "tickets": [1, 2, 3]
  }
}
JSON

    echo "Test 3: Verify field mapping"
    route_trigger_to_queue "$trigger_file"

    # Get the created task file
    local task_file=$(ls "$TEST_DIR/.claude/queues/orchestrator/pending"/*.json 2>/dev/null | head -1)

    if [ -f "$task_file" ]; then
        # Assert: Agent field correct
        local agent=$(jq -r '.agent' "$task_file")
        assert_equals "orchestrator" "$agent" "Agent field mapped correctly"

        # Assert: Action field correct
        local action=$(jq -r '.action' "$task_file")
        assert_equals "assign_tickets" "$action" "Action field mapped correctly"

        # Assert: Context preserved
        local context=$(jq -r '.context.tickets | length' "$task_file")
        assert_equals "3" "$context" "Context field mapped correctly"

        # Assert: Required fields present
        local has_id=$(jq 'has("id")' "$task_file")
        assert_equals "true" "$has_id" "Task has id field"

        local has_created_at=$(jq 'has("created_at")' "$task_file")
        assert_equals "true" "$has_created_at" "Task has created_at field"

        local has_priority=$(jq 'has("priority")' "$task_file")
        assert_equals "true" "$has_priority" "Task has priority field"

        local has_retry_count=$(jq 'has("retry_count")' "$task_file")
        assert_equals "true" "$has_retry_count" "Task has retry_count field"
    else
        echo -e "  ${RED}✗${NC} Task file not created"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# Test 4: Logging events
test_route_logging() {
    setup_test_env

    local trigger_file="$TEST_DIR/.claude/triggers/log-test.trigger"

    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "senior-engineer",
  "action": "create_breakdown",
  "context": {}
}
JSON

    echo "Test 4: Verify logging"
    route_trigger_to_queue "$trigger_file"

    # Assert: Log entry created
    if [ -f "$TEST_DIR/.claude/router.log" ]; then
        local log_count=$(grep -c "create_breakdown" "$TEST_DIR/.claude/router.log" 2>/dev/null || echo "0")
        assert_equals "1" "$log_count" "Routing event logged"
    else
        echo -e "  ${RED}✗${NC} Log file not created"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# Test 5: Multiple triggers in sequence
test_route_multiple_triggers() {
    setup_test_env

    echo "Test 5: Route multiple triggers"

    # Create 3 triggers
    for i in 1 2 3; do
        cat > "$TEST_DIR/.claude/triggers/multi-$i.trigger" <<JSON
{
  "to_agent": "tpm",
  "action": "task_$i",
  "context": {"num": $i}
}
JSON
        route_trigger_to_queue "$TEST_DIR/.claude/triggers/multi-$i.trigger"
    done

    # Assert: All 3 tasks created
    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "3" "$task_count" "All 3 tasks created"

    # Assert: All triggers archived
    local archived_count=$(ls "$TEST_DIR/.claude/triggers/processed"/*.trigger 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "3" "$archived_count" "All 3 triggers archived"

    cleanup_test_env
}

# Run all tests
test_route_valid_trigger
test_route_invalid_json
test_route_field_mapping
test_route_logging
test_route_multiple_triggers

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Tests run:    $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
