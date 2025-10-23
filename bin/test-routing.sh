#!/bin/bash
# StarForge Queue Phase 2 Testing Suite
# Comprehensive tests for routing functionality
# Tests router, watcher, manual submission, and integration

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
TEST_DIR="$STARFORGE_ROOT/.tmp/routing-test"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Queue Phase 2 Testing Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
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

assert_file_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-File exists: $file}"

    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (file not found)"
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
        echo -e "  ${RED}✗${NC} $desc (file exists)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_true() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local condition="$1"
    local desc="$2"

    if eval "$condition"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_DIR/.claude/triggers/processed"
    mkdir -p "$TEST_DIR/.claude/triggers/invalid"
    mkdir -p "$TEST_DIR/.claude/queues/tpm/pending"
    mkdir -p "$TEST_DIR/.claude/queues/orchestrator/pending"
    mkdir -p "$TEST_DIR/.claude/queues/senior-engineer/pending"
    mkdir -p "$TEST_DIR/.claude/queues/qa-engineer/pending"
    mkdir -p "$TEST_DIR/.claude/queues/junior-dev-a/pending"
    touch "$TEST_DIR/.claude/router.log"
    cd "$TEST_DIR"
}

cleanup_test_env() {
    cd "$STARFORGE_ROOT"
    rm -rf "$TEST_DIR"
}

# Mock logger functions
log_info() { echo "[INFO] $1: $2" >> "$TEST_DIR/.claude/router.log"; }
log_error() { echo "[ERROR] $1: $2" >> "$TEST_DIR/.claude/router.log"; }
log_warn() { echo "[WARN] $1: $2" >> "$TEST_DIR/.claude/router.log"; }

# Source router library
if [ -f "$STARFORGE_ROOT/.claude/lib/router.sh" ]; then
    source "$STARFORGE_ROOT/.claude/lib/router.sh"
elif [ -f "$STARFORGE_ROOT/templates/lib/router.sh" ]; then
    source "$STARFORGE_ROOT/templates/lib/router.sh"
else
    echo -e "${YELLOW}⚠${NC} router.sh not found - some tests will be skipped"
    route_trigger_to_queue() { return 1; }
fi

# ============================================
# ROUTER VALIDATION TESTS
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Router Validation Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Valid trigger routed to correct queue
test_route_valid_trigger() {
    setup_test_env
    echo "Test 1: Route valid trigger to queue"

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

    route_trigger_to_queue "$trigger_file"

    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$task_count" "Task created in tpm queue"
    assert_file_not_exists "$trigger_file" "Trigger removed from triggers/"

    cleanup_test_env
}

# Test 2: Invalid JSON trigger moved to invalid/
test_route_invalid_trigger() {
    setup_test_env
    echo "Test 2: Invalid JSON trigger handled"

    local trigger_file="$TEST_DIR/.claude/triggers/bad-trigger.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "tpm",
  INVALID JSON
}
JSON

    route_trigger_to_queue "$trigger_file" || true

    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "0" "$task_count" "No task created for invalid JSON"
    assert_true "[ \$(ls \"$TEST_DIR/.claude/triggers/invalid\"/*.trigger 2>/dev/null | wc -l) -eq 1 ]" "Trigger moved to invalid/"

    cleanup_test_env
}

# Test 3: Router archives triggers
test_router_archives_triggers() {
    setup_test_env
    echo "Test 3: Router archives processed triggers"

    local trigger_file="$TEST_DIR/.claude/triggers/archive-test.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "orchestrator",
  "action": "assign_tickets",
  "context": {}
}
JSON

    route_trigger_to_queue "$trigger_file"

    local archived=$(ls "$TEST_DIR/.claude/triggers/processed"/*.trigger 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$archived" "Trigger archived in processed/"

    cleanup_test_env
}

# Test 4: Router logs events
test_router_logs_events() {
    setup_test_env
    echo "Test 4: Router logs routing events"

    local trigger_file="$TEST_DIR/.claude/triggers/log-test.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "senior-engineer",
  "action": "create_breakdown",
  "context": {}
}
JSON

    route_trigger_to_queue "$trigger_file"

    assert_file_exists "$TEST_DIR/.claude/router.log" "Log file created"
    assert_true "grep -q 'create_breakdown' '$TEST_DIR/.claude/router.log' 2>/dev/null" "Event logged"

    cleanup_test_env
}

# ============================================
# TASK JSON STRUCTURE TESTS
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 Task JSON Structure Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 5: Task has required fields
test_task_json_structure() {
    setup_test_env
    echo "Test 5: Task JSON has all required fields"

    local trigger_file="$TEST_DIR/.claude/triggers/structure-test.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "qa-engineer",
  "action": "review_pr",
  "context": {"pr": 123}
}
JSON

    route_trigger_to_queue "$trigger_file"

    local task_file=$(ls "$TEST_DIR/.claude/queues/qa-engineer/pending"/*.json 2>/dev/null | head -1)

    if [ -f "$task_file" ]; then
        assert_true "jq -e '.id' '$task_file' >/dev/null 2>&1" "Task has 'id' field"
        assert_true "jq -e '.agent' '$task_file' >/dev/null 2>&1" "Task has 'agent' field"
        assert_true "jq -e '.action' '$task_file' >/dev/null 2>&1" "Task has 'action' field"
        assert_true "jq -e '.context' '$task_file' >/dev/null 2>&1" "Task has 'context' field"
        assert_true "jq -e '.created_at' '$task_file' >/dev/null 2>&1" "Task has 'created_at' field"
        assert_true "jq -e '.priority' '$task_file' >/dev/null 2>&1" "Task has 'priority' field"
        assert_true "jq -e '.retry_count' '$task_file' >/dev/null 2>&1" "Task has 'retry_count' field"
    fi

    cleanup_test_env
}

# Test 6: Context preserved correctly
test_task_context_preserved() {
    setup_test_env
    echo "Test 6: Task context preserved from trigger"

    local trigger_file="$TEST_DIR/.claude/triggers/context-test.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "tpm",
  "action": "create_tickets",
  "context": {
    "tickets": [1, 2, 3],
    "milestone": "v1.0"
  }
}
JSON

    route_trigger_to_queue "$trigger_file"

    local task_file=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | head -1)

    if [ -f "$task_file" ]; then
        local ticket_count=$(jq '.context.tickets | length' "$task_file")
        assert_equals "3" "$ticket_count" "Context tickets array preserved"

        local milestone=$(jq -r '.context.milestone' "$task_file")
        assert_equals "v1.0" "$milestone" "Context milestone preserved"
    fi

    cleanup_test_env
}

# ============================================
# MANUAL SUBMISSION TESTS
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✍️  Manual Submission Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 7: Manual trigger creation
test_manual_submission() {
    setup_test_env
    echo "Test 7: Manual trigger submission works"

    # Create trigger manually (simulating trigger-helpers.sh)
    local trigger_file="$TEST_DIR/.claude/triggers/manual-test-$(date +%s).trigger"
    cat > "$trigger_file" <<EOF
{
  "from_agent": "orchestrator",
  "to_agent": "junior-dev-a",
  "action": "implement_ticket",
  "context": {"ticket": 42},
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "message": "Test manual submission"
}
EOF

    assert_file_exists "$trigger_file" "Manual trigger created"

    # Route it
    route_trigger_to_queue "$trigger_file"

    local task_count=$(ls "$TEST_DIR/.claude/queues/junior-dev-a/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$task_count" "Manual trigger routed to queue"

    cleanup_test_env
}

# Test 8: Invalid agent rejected
test_invalid_agent() {
    setup_test_env
    echo "Test 8: Invalid agent name rejected"

    local trigger_file="$TEST_DIR/.claude/triggers/invalid-agent.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "",
  "action": "test",
  "context": {}
}
JSON

    route_trigger_to_queue "$trigger_file" || true

    local task_count=$(find "$TEST_DIR/.claude/queues" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "0" "$task_count" "No task created for empty agent"

    cleanup_test_env
}

# Test 9: Invalid action still creates task
test_invalid_action() {
    setup_test_env
    echo "Test 9: Missing action field rejected"

    local trigger_file="$TEST_DIR/.claude/triggers/invalid-action.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "tpm",
  "action": "",
  "context": {}
}
JSON

    route_trigger_to_queue "$trigger_file" || true

    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "0" "$task_count" "No task created for empty action"

    cleanup_test_env
}

# ============================================
# INTEGRATION & COMPATIBILITY TESTS
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔗 Integration & Backwards Compatibility Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 10: Backwards compatibility - old trigger format
test_backwards_compatibility() {
    setup_test_env
    echo "Test 10: Backwards compatibility with Phase 1"

    # Phase 1 triggers might not have all fields
    local trigger_file="$TEST_DIR/.claude/triggers/legacy-trigger.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "qa-engineer",
  "action": "review_pr",
  "context": {"pr": 99}
}
JSON

    route_trigger_to_queue "$trigger_file"

    local task_count=$(ls "$TEST_DIR/.claude/queues/qa-engineer/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$task_count" "Legacy trigger format supported"

    cleanup_test_env
}

# Test 11: New workflow with full trigger
test_new_workflow() {
    setup_test_env
    echo "Test 11: New workflow with complete trigger"

    local trigger_file="$TEST_DIR/.claude/triggers/new-workflow.trigger"
    cat > "$trigger_file" <<EOF
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm",
  "action": "create_tickets",
  "context": {"feature": "new-feature", "subtasks": 5},
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "message": "5 subtasks ready",
  "command": "Use tpm. Create tickets from breakdown."
}
EOF

    route_trigger_to_queue "$trigger_file"

    local task_file=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | head -1)

    if [ -f "$task_file" ]; then
        local subtasks=$(jq '.context.subtasks' "$task_file")
        assert_equals "5" "$subtasks" "Complete workflow context preserved"
    fi

    cleanup_test_env
}

# Test 12: Mixed workflow - multiple agents
test_mixed_workflow() {
    setup_test_env
    echo "Test 12: Mixed workflow across multiple agents"

    # Create triggers for different agents
    for agent in "tpm" "orchestrator" "senior-engineer" "qa-engineer"; do
        local trigger_file="$TEST_DIR/.claude/triggers/${agent}-test.trigger"
        cat > "$trigger_file" <<EOF
{
  "to_agent": "$agent",
  "action": "test_action",
  "context": {"test": true}
}
EOF
        route_trigger_to_queue "$trigger_file"
    done

    # Check all queues have tasks
    for agent in "tpm" "orchestrator" "senior-engineer" "qa-engineer"; do
        local task_count=$(ls "$TEST_DIR/.claude/queues/$agent/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
        assert_equals "1" "$task_count" "Task routed to $agent queue"
    done

    cleanup_test_env
}

# Test 13: Rapid trigger processing
test_rapid_trigger_processing() {
    setup_test_env
    echo "Test 13: Handles rapid trigger creation"

    # Create 10 triggers rapidly
    for i in {1..10}; do
        local trigger_file="$TEST_DIR/.claude/triggers/rapid-$i.trigger"
        cat > "$trigger_file" <<EOF
{
  "to_agent": "tpm",
  "action": "task_$i",
  "context": {"num": $i}
}
EOF
        route_trigger_to_queue "$trigger_file"
    done

    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "10" "$task_count" "All 10 rapid triggers processed"

    local archived=$(ls "$TEST_DIR/.claude/triggers/processed"/*.trigger 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "10" "$archived" "All 10 triggers archived"

    cleanup_test_env
}

# Test 14: Queue isolation
test_queue_isolation() {
    setup_test_env
    echo "Test 14: Queues remain isolated"

    # Create triggers for two different agents
    local trigger1="$TEST_DIR/.claude/triggers/agent1-task.trigger"
    cat > "$trigger1" <<'JSON'
{
  "to_agent": "tpm",
  "action": "action1",
  "context": {}
}
JSON

    local trigger2="$TEST_DIR/.claude/triggers/agent2-task.trigger"
    cat > "$trigger2" <<'JSON'
{
  "to_agent": "orchestrator",
  "action": "action2",
  "context": {}
}
JSON

    route_trigger_to_queue "$trigger1"
    route_trigger_to_queue "$trigger2"

    local tpm_tasks=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    local orch_tasks=$(ls "$TEST_DIR/.claude/queues/orchestrator/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')

    assert_equals "1" "$tpm_tasks" "TPM queue has 1 task only"
    assert_equals "1" "$orch_tasks" "Orchestrator queue has 1 task only"

    cleanup_test_env
}

# Test 15: Error recovery
test_error_recovery() {
    setup_test_env
    echo "Test 15: Error recovery and logging"

    # Try to route non-existent file
    route_trigger_to_queue "$TEST_DIR/.claude/triggers/nonexistent.trigger" 2>/dev/null || true

    # Router should log error and continue
    assert_true "grep -q 'ERROR' '$TEST_DIR/.claude/router.log' 2>/dev/null" "Error logged for missing file"

    # System should still work for valid trigger
    local trigger_file="$TEST_DIR/.claude/triggers/recovery-test.trigger"
    cat > "$trigger_file" <<'JSON'
{
  "to_agent": "tpm",
  "action": "test",
  "context": {}
}
JSON

    route_trigger_to_queue "$trigger_file"

    local task_count=$(ls "$TEST_DIR/.claude/queues/tpm/pending"/*.json 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "1" "$task_count" "System recovered and processed valid trigger"

    cleanup_test_env
}

# ============================================
# RUN ALL TESTS
# ============================================

test_route_valid_trigger
test_route_invalid_trigger
test_router_archives_triggers
test_router_logs_events
test_task_json_structure
test_task_context_preserved
test_manual_submission
test_invalid_agent
test_invalid_action
test_backwards_compatibility
test_new_workflow
test_mixed_workflow
test_rapid_trigger_processing
test_queue_isolation
test_error_recovery

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
    echo "Phase 2 routing functionality is working correctly:"
    echo "  ✓ Router validation (4 tests)"
    echo "  ✓ Task JSON structure (2 tests)"
    echo "  ✓ Manual submission (3 tests)"
    echo "  ✓ Integration & compatibility (6 tests)"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
