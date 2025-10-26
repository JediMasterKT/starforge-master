#!/usr/bin/env bash
# Integration tests for starforge-common.sh library
#
# Tests directory creation, agent initialization, and validation functions

set -e

TEST_DIR=$(mktemp -d)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$STARFORGE_ROOT/templates"

# Test colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

# Helper to run a test
run_test() {
    local test_name="$1"
    local test_func="$2"

    ((test_count++))
    echo -n "Test $test_count: $test_name... "

    if $test_func; then
        echo -e "${GREEN}PASS${NC}"
        ((pass_count++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((fail_count++))
        return 1
    fi
}

# Test 1: ensure_directory_structure creates all required directories
test_ensure_directory_structure() {
    local test_claude_dir="$TEST_DIR/test1/.claude"

    # Source the library
    source "$TEMPLATE_DIR/lib/starforge-common.sh"

    # Run function
    ensure_directory_structure "$test_claude_dir" >/dev/null 2>&1

    # Verify core directories exist
    [ -d "$test_claude_dir/agents" ] || return 1
    [ -d "$test_claude_dir/agents/agent-learnings" ] || return 1
    [ -d "$test_claude_dir/agents/scratchpads" ] || return 1
    [ -d "$test_claude_dir/scripts" ] || return 1
    [ -d "$test_claude_dir/lib" ] || return 1
    [ -d "$test_claude_dir/bin" ] || return 1
    [ -d "$test_claude_dir/hooks" ] || return 1
    [ -d "$test_claude_dir/coordination" ] || return 1
    [ -d "$test_claude_dir/triggers" ] || return 1
    [ -d "$test_claude_dir/triggers/processed" ] || return 1
    [ -d "$test_claude_dir/spikes" ] || return 1
    [ -d "$test_claude_dir/scratchpads" ] || return 1
    [ -d "$test_claude_dir/breakdowns" ] || return 1
    [ -d "$test_claude_dir/research" ] || return 1
    [ -d "$test_claude_dir/qa" ] || return 1
    [ -d "$test_claude_dir/backups" ] || return 1

    return 0
}

# Test 2: initialize_agent_learnings creates per-agent subdirectories
test_initialize_agent_learnings() {
    local test_claude_dir="$TEST_DIR/test2/.claude"

    # Setup: Create directory structure first
    source "$TEMPLATE_DIR/lib/starforge-common.sh"
    ensure_directory_structure "$test_claude_dir" >/dev/null 2>&1

    # Create mock template learnings
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        mkdir -p "$TEMPLATE_DIR/agents/agent-learnings/$agent"
        echo "# $agent learnings" > "$TEMPLATE_DIR/agents/agent-learnings/$agent/learnings.md"
    done

    # Run function
    initialize_agent_learnings "$test_claude_dir" "$STARFORGE_ROOT" >/dev/null 2>&1

    # Verify per-agent directories exist
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        [ -d "$test_claude_dir/agents/agent-learnings/$agent" ] || return 1
        [ -d "$test_claude_dir/agents/scratchpads/$agent" ] || return 1
        [ -f "$test_claude_dir/agents/agent-learnings/$agent/learnings.md" ] || return 1
    done

    # Cleanup mock templates
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        rm -f "$TEMPLATE_DIR/agents/agent-learnings/$agent/learnings.md"
    done

    return 0
}

# Test 3: initialize_agent_learnings preserves existing learnings
test_preserve_existing_learnings() {
    local test_claude_dir="$TEST_DIR/test3/.claude"

    source "$TEMPLATE_DIR/lib/starforge-common.sh"
    ensure_directory_structure "$test_claude_dir" >/dev/null 2>&1

    # Create existing learnings
    mkdir -p "$test_claude_dir/agents/agent-learnings/orchestrator"
    echo "# Existing learning" > "$test_claude_dir/agents/agent-learnings/orchestrator/learnings.md"

    # Create mock template
    mkdir -p "$TEMPLATE_DIR/agents/agent-learnings/orchestrator"
    echo "# Template learning" > "$TEMPLATE_DIR/agents/agent-learnings/orchestrator/learnings.md"

    # Run function
    initialize_agent_learnings "$test_claude_dir" "$STARFORGE_ROOT" >/dev/null 2>&1

    # Verify existing file was NOT overwritten
    content=$(cat "$test_claude_dir/agents/agent-learnings/orchestrator/learnings.md")
    [ "$content" = "# Existing learning" ] || return 1

    # Cleanup
    rm -f "$TEMPLATE_DIR/agents/agent-learnings/orchestrator/learnings.md"

    return 0
}

# Test 4: validate_directory_structure passes for valid structure
test_validate_success() {
    local test_claude_dir="$TEST_DIR/test4/.claude"

    source "$TEMPLATE_DIR/lib/starforge-common.sh"
    ensure_directory_structure "$test_claude_dir" >/dev/null 2>&1
    initialize_agent_learnings "$test_claude_dir" "$STARFORGE_ROOT" >/dev/null 2>&1

    # Should pass validation
    validate_directory_structure "$test_claude_dir" >/dev/null 2>&1
    return $?
}

# Test 5: validate_directory_structure fails for incomplete structure
test_validate_failure() {
    local test_claude_dir="$TEST_DIR/test5/.claude"

    # Create incomplete structure (missing critical directories)
    mkdir -p "$test_claude_dir/agents"

    source "$TEMPLATE_DIR/lib/starforge-common.sh"

    # Should fail validation
    if validate_directory_structure "$test_claude_dir" >/dev/null 2>&1; then
        return 1  # Test fails if validation passes
    else
        return 0  # Test passes if validation fails
    fi
}

# Test 6: Full workflow (ensure -> initialize -> validate)
test_full_workflow() {
    local test_claude_dir="$TEST_DIR/test6/.claude"

    source "$TEMPLATE_DIR/lib/starforge-common.sh"

    # Create mock templates
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        mkdir -p "$TEMPLATE_DIR/agents/agent-learnings/$agent"
        echo "# Template" > "$TEMPLATE_DIR/agents/agent-learnings/$agent/learnings.md"
    done

    # Run full workflow
    ensure_directory_structure "$test_claude_dir" >/dev/null 2>&1 || return 1
    initialize_agent_learnings "$test_claude_dir" "$STARFORGE_ROOT" >/dev/null 2>&1 || return 1
    validate_directory_structure "$test_claude_dir" >/dev/null 2>&1 || return 1

    # Cleanup
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        rm -f "$TEMPLATE_DIR/agents/agent-learnings/$agent/learnings.md"
    done

    return 0
}

# Run all tests
echo "Running integration tests for starforge-common.sh..."
echo ""

run_test "ensure_directory_structure creates all directories" test_ensure_directory_structure
run_test "initialize_agent_learnings creates per-agent dirs" test_initialize_agent_learnings
run_test "initialize_agent_learnings preserves existing files" test_preserve_existing_learnings
run_test "validate_directory_structure passes for valid structure" test_validate_success
run_test "validate_directory_structure fails for incomplete structure" test_validate_failure
run_test "Full workflow (ensure -> initialize -> validate)" test_full_workflow

# Cleanup
rm -rf "$TEST_DIR"

# Summary
echo ""
echo "========================================="
echo "Test Summary:"
echo "  Total:  $test_count"
echo "  Passed: $pass_count"
echo "  Failed: $fail_count"
echo "========================================="
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
