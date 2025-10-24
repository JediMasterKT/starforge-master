#!/bin/bash
# Test suite for Stop hook - TDD approach

# Source project environment
source .claude/lib/project-env.sh

# Test configuration
TEST_DIR="$STARFORGE_CLAUDE_DIR/triggers/test-$(date +%s)"
TEST_LOG="$STARFORGE_CLAUDE_DIR/test-stop-hook.log"
HOOK_SCRIPT="$STARFORGE_CLAUDE_DIR/hooks/stop.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test() {
    echo "Setting up test environment..."
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_DIR/processed"
    > "$TEST_LOG"
    > "$STARFORGE_CLAUDE_DIR/agent-handoff.log"

    # Clean up any existing triggers
    rm -f "$STARFORGE_CLAUDE_DIR/triggers/"*.trigger
}

# Cleanup test environment
cleanup_test() {
    echo "Cleaning up test environment..."
    rm -rf "$TEST_DIR"
    rm -f "$TEST_LOG"
}

# Clean between tests
clean_triggers() {
    rm -f "$STARFORGE_CLAUDE_DIR/triggers/"*.trigger
}

# Test helper
run_test() {
    local test_name=$1
    local test_function=$2

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "\n${YELLOW}[TEST $TESTS_RUN]${NC} $test_name"

    # Clean triggers before each test
    clean_triggers

    if $test_function; then
        echo -e "${GREEN}✓ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# TEST 1: Hook script exists and is executable
test_hook_exists() {
    [ -f "$HOOK_SCRIPT" ] && [ -x "$HOOK_SCRIPT" ]
}

# TEST 2: Hook detects trigger file
test_detect_trigger() {
    # Create test trigger
    local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-detect-$(date +%s).trigger"
    cat > "$trigger_file" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "tpm",
  "action": "test_action",
  "message": "Test detection",
  "command": "Use tpm. This is a test.",
  "timestamp": "2025-10-24T00:00:00Z"
}
EOF

    # Verify trigger exists before hook runs
    if [ ! -f "$trigger_file" ]; then
        echo "ERROR: Trigger file not created"
        return 1
    fi

    # Simulate stop hook input
    echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1 > /dev/null

    # Verify trigger was processed (moved to processed/)
    if [ -f "$trigger_file" ]; then
        echo "ERROR: Trigger file still exists (not processed)"
        return 1
    fi

    if [ ! -f "$STARFORGE_CLAUDE_DIR/triggers/processed/$(basename $trigger_file)" ]; then
        echo "ERROR: Trigger not found in processed/"
        return 1
    fi

    return 0
}

# TEST 3: Hook logs handoff correctly
test_handoff_logging() {
    # Clear log
    > "$STARFORGE_CLAUDE_DIR/agent-handoff.log"

    # Create test trigger
    local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-log-$(date +%s).trigger"
    cat > "$trigger_file" << 'EOF'
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm",
  "action": "create_tickets",
  "message": "5 subtasks ready",
  "command": "Use tpm.",
  "timestamp": "2025-10-24T00:00:00Z"
}
EOF

    # Run hook
    echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1 > /dev/null

    # Verify log entry exists
    if ! grep -q "senior-engineer -> tpm" "$STARFORGE_CLAUDE_DIR/agent-handoff.log"; then
        echo "ERROR: Handoff not logged"
        cat "$STARFORGE_CLAUDE_DIR/agent-handoff.log"
        return 1
    fi

    return 0
}

# TEST 4: Hook handles missing trigger gracefully
test_no_trigger() {
    # Ensure no triggers exist
    rm -f "$STARFORGE_CLAUDE_DIR/triggers/"*.trigger

    # Run hook (should not error)
    echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1 > /dev/null
    local exit_code=$?

    # Should exit 0 even with no triggers
    [ $exit_code -eq 0 ]
}

# TEST 5: Hook parses trigger JSON correctly
test_json_parsing() {
    local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-parse-$(date +%s).trigger"
    cat > "$trigger_file" << 'EOF'
{
  "from_agent": "orchestrator",
  "to_agent": "junior-dev-a",
  "action": "implement_ticket",
  "message": "Ticket #42 assigned",
  "command": "Use junior-engineer.",
  "context": {"ticket": 42},
  "timestamp": "2025-10-24T00:00:00Z"
}
EOF

    # Run hook and capture output
    local output=$(echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1)

    # Verify output contains expected agent
    echo "$output" | grep -q "junior-dev-a"
}

# TEST 6: Hook handles malformed JSON
test_malformed_json() {
    local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-malformed-$(date +%s).trigger"
    echo "INVALID JSON {{{" > "$trigger_file"

    # Run hook (should not crash)
    echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1 > /dev/null
    local exit_code=$?

    # Should fail gracefully (exit 0, not crash)
    if [ $exit_code -ne 0 ]; then
        echo "ERROR: Hook crashed on malformed JSON"
        return 1
    fi

    # Verify malformed trigger was moved to processed/
    if [ -f "$trigger_file" ]; then
        echo "ERROR: Malformed trigger not processed"
        return 1
    fi

    return 0
}

# TEST 7: Hook processes oldest trigger first
test_trigger_priority() {
    # Create two triggers with different timestamps
    local trigger1="$STARFORGE_CLAUDE_DIR/triggers/test-a-$(date +%s).trigger"
    sleep 1
    local trigger2="$STARFORGE_CLAUDE_DIR/triggers/test-b-$(date +%s).trigger"

    cat > "$trigger1" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "agent-a",
  "action": "test1",
  "message": "First trigger",
  "command": "Use agent-a.",
  "timestamp": "2025-10-24T00:00:00Z"
}
EOF

    cat > "$trigger2" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "agent-b",
  "action": "test2",
  "message": "Second trigger",
  "command": "Use agent-b.",
  "timestamp": "2025-10-24T00:01:00Z"
}
EOF

    # Run hook
    local output=$(echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1)

    # Should process first trigger (trigger1) which has earlier filename
    echo "$output" | grep -q "agent-a"
}

# TEST 8: Hook creates processed directory
test_processed_directory() {
    # Remove processed directory
    rm -rf "$STARFORGE_CLAUDE_DIR/triggers/processed"

    # Create trigger
    local trigger_file="$STARFORGE_CLAUDE_DIR/triggers/test-dir-$(date +%s).trigger"
    cat > "$trigger_file" << 'EOF'
{
  "from_agent": "test",
  "to_agent": "tpm",
  "action": "test",
  "message": "Test",
  "command": "Use tpm.",
  "timestamp": "2025-10-24T00:00:00Z"
}
EOF

    # Run hook
    echo '{"event": "stop"}' | "$HOOK_SCRIPT" 2>&1 > /dev/null

    # Verify processed directory was created
    [ -d "$STARFORGE_CLAUDE_DIR/triggers/processed" ]
}

# Run all tests
main() {
    echo "========================================"
    echo "Stop Hook Test Suite (TDD)"
    echo "========================================"

    setup_test

    run_test "Hook script exists and is executable" test_hook_exists
    run_test "Hook detects trigger file" test_detect_trigger
    run_test "Hook logs handoff correctly" test_handoff_logging
    run_test "Hook handles missing trigger gracefully" test_no_trigger
    run_test "Hook parses trigger JSON correctly" test_json_parsing
    run_test "Hook handles malformed JSON" test_malformed_json
    run_test "Hook processes oldest trigger first" test_trigger_priority
    run_test "Hook creates processed directory" test_processed_directory

    # Print summary
    echo ""
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
    echo "========================================"

    # Cleanup
    cleanup_test

    # Exit with error if any tests failed
    [ $TESTS_FAILED -eq 0 ]
}

main "$@"
