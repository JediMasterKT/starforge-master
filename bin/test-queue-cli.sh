#!/bin/bash
# Test suite for starforge queue CLI command
# Tests for Queue Phase 1 - List Command

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$STARFORGE_ROOT/.tmp/queue-cli-test"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Queue CLI Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_success() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="$1"
    local exit_code=${2:-$?}

    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (exit code: $exit_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local haystack="$1"
    local needle="$2"
    local desc="$3"

    if echo "$haystack" | grep -qi "$needle"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Expected to find: $needle"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local haystack="$1"
    local needle="$2"
    local desc="$3"

    if ! echo "$haystack" | grep -q "$needle"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Should not contain: $needle"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_json_valid() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local json="$1"
    local desc="$2"

    if echo "$json" | jq empty 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Invalid JSON"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/.claude/queues/tpm/pending"
    mkdir -p "$TEST_DIR/.claude/queues/orchestrator/pending"
    mkdir -p "$TEST_DIR/.claude/queues/senior-engineer/pending"
    mkdir -p "$TEST_DIR/.claude/queues/qa-engineer/pending"
    mkdir -p "$TEST_DIR/.claude/queues/junior-dev-a/pending"
    cd "$TEST_DIR"
}

cleanup_test_env() {
    cd "$STARFORGE_ROOT"
    rm -rf "$TEST_DIR"
}

# ============================================
# TEST SUITE
# ============================================

# Test 1: Queue list with empty queue
test_queue_list_empty() {
    setup_test_env
    echo "Test 1: List empty queue"

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list tpm 2>&1)
    local exit_code=$?

    assert_success "Command exits successfully" $exit_code
    assert_contains "$output" "No pending tasks" "Shows 'No pending tasks' for empty queue"

    cleanup_test_env
}

# Test 2: Queue list with tasks
test_queue_list_with_tasks() {
    setup_test_env
    echo "Test 2: List queue with tasks"

    # Create test tasks
    echo '{"id":"test-1","action":"create_tickets","agent":"tpm"}' > .claude/queues/tpm/pending/test-1.json
    echo '{"id":"test-2","action":"create_tickets","agent":"tpm"}' > .claude/queues/tpm/pending/test-2.json

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list tpm 2>&1)
    local exit_code=$?

    assert_success "Command exits successfully" $exit_code
    assert_contains "$output" "test-1" "Shows first task ID"
    assert_contains "$output" "test-2" "Shows second task ID"
    assert_contains "$output" "2" "Shows task count"

    cleanup_test_env
}

# Test 3: Queue list all queues
test_queue_list_all() {
    setup_test_env
    echo "Test 3: List all queues"

    # Create tasks in different queues
    echo '{"id":"tpm-1"}' > .claude/queues/tpm/pending/tpm-1.json
    echo '{"id":"orch-1"}' > .claude/queues/orchestrator/pending/orch-1.json

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list 2>&1)
    local exit_code=$?

    assert_success "Command exits successfully" $exit_code
    assert_contains "$output" "tpm" "Shows tpm queue"
    assert_contains "$output" "orchestrator" "Shows orchestrator queue"

    cleanup_test_env
}

# Test 4: Queue list with JSON output
test_queue_list_json() {
    setup_test_env
    echo "Test 4: JSON output format"

    echo '{"id":"test-1","action":"test"}' > .claude/queues/tpm/pending/test-1.json

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list tpm --json 2>&1)
    local exit_code=$?

    assert_success "Command exits successfully" $exit_code
    assert_json_valid "$output" "Output is valid JSON"

    cleanup_test_env
}

# Test 5: Queue list non-existent queue
test_queue_list_nonexistent() {
    setup_test_env
    echo "Test 5: Non-existent queue handling"

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list nonexistent 2>&1)
    # Should either show empty or error gracefully

    assert_contains "$output" "No pending tasks\|not found\|does not exist" "Handles non-existent queue gracefully"

    cleanup_test_env
}

# Test 6: Queue list shows task count
test_queue_list_task_count() {
    setup_test_env
    echo "Test 6: Task count display"

    # Create 5 tasks
    for i in {1..5}; do
        echo "{\"id\":\"task-$i\"}" > ".claude/queues/tpm/pending/task-$i.json"
    done

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list tpm 2>&1)

    assert_contains "$output" "5\|five" "Shows correct task count"

    cleanup_test_env
}

# Test 7: Queue list shows oldest task
test_queue_list_oldest_task() {
    setup_test_env
    echo "Test 7: Oldest task display"

    # Create tasks with different timestamps
    touch -t 202310010000 .claude/queues/tpm/pending/old-task.json
    echo '{"id":"old-task"}' > .claude/queues/tpm/pending/old-task.json

    sleep 1

    echo '{"id":"new-task"}' > .claude/queues/tpm/pending/new-task.json

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list tpm 2>&1)

    # Should show age or timestamp of oldest task
    assert_contains "$output" "oldest\|age\|created" "Shows information about oldest task"

    cleanup_test_env
}

# Test 8: Queue list shows newest task
test_queue_list_newest_task() {
    setup_test_env
    echo "Test 8: Newest task display"

    # Create tasks
    echo '{"id":"task-1"}' > .claude/queues/tpm/pending/task-1.json
    sleep 1
    echo '{"id":"task-2"}' > .claude/queues/tpm/pending/task-2.json

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list tpm 2>&1)

    # Should show newest task info
    assert_contains "$output" "newest\|latest\|recent" "Shows information about newest task"

    cleanup_test_env
}

# Test 9: Queue list with multiple agent queues
test_queue_list_multiple_agents() {
    setup_test_env
    echo "Test 9: Multiple agent queues"

    # Create tasks in multiple agent queues
    echo '{"id":"a1"}' > .claude/queues/junior-dev-a/pending/a1.json
    echo '{"id":"orch1"}' > .claude/queues/orchestrator/pending/orch1.json
    echo '{"id":"qa1"}' > .claude/queues/qa-engineer/pending/qa1.json

    local output=$("$STARFORGE_ROOT/bin/starforge" queue list 2>&1)

    assert_contains "$output" "junior-dev-a" "Shows junior-dev-a queue"
    assert_contains "$output" "orchestrator" "Shows orchestrator queue"
    assert_contains "$output" "qa-engineer" "Shows qa-engineer queue"

    cleanup_test_env
}

# Test 10: Queue list help text
test_queue_list_help() {
    setup_test_env
    echo "Test 10: Help text"

    local output=$("$STARFORGE_ROOT/bin/starforge" queue --help 2>&1 || true)

    assert_contains "$output" "list\|usage\|help" "Shows help information"

    cleanup_test_env
}

# ============================================
# RUN ALL TESTS
# ============================================

test_queue_list_empty
test_queue_list_with_tasks
test_queue_list_all
test_queue_list_json
test_queue_list_nonexistent
test_queue_list_task_count
test_queue_list_oldest_task
test_queue_list_newest_task
test_queue_list_multiple_agents
test_queue_list_help

# ============================================
# PRINT SUMMARY
# ============================================

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
    echo ""
    echo "Queue CLI functionality working:"
    echo "  ✓ List empty queues"
    echo "  ✓ List queues with tasks"
    echo "  ✓ List all queues"
    echo "  ✓ JSON output"
    echo "  ✓ Task count, oldest, newest"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Implement the queue list command to make tests pass."
    echo ""
    exit 1
fi
