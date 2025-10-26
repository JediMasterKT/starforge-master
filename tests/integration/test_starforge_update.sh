#!/usr/bin/env bash
# Integration test for starforge update directory creation
#
# Tests that 'starforge update' creates missing directories
# and validates the structure properly.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo ""
    echo -e "${YELLOW}Running: $test_name${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))

    if $test_function; then
        echo -e "${GREEN}✅ PASS: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Update with missing directories (simulate corruption)
test_update_with_missing_directories() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"

    # Setup: Create minimal StarForge installation
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create basic .claude structure (simulating initial install)
    mkdir -p .claude/agents
    mkdir -p .claude/scripts

    # Simulate corruption: delete critical subdirectories
    # (These should be recreated by update)
    rm -rf .claude/agents/agent-learnings 2>/dev/null || true
    rm -rf .claude/spikes 2>/dev/null || true
    rm -rf .claude/triggers/processed 2>/dev/null || true

    # Execute: Run starforge update (non-interactive mode)
    # Note: We need to mock/skip the interactive parts
    export STARFORGE_DIR="/Users/krunaaltavkar/starforge-master"

    # We'll test the core functions directly since full update requires git remote
    source "$STARFORGE_DIR/templates/lib/starforge-common.sh"

    ensure_directory_structure "$test_dir/.claude"
    initialize_agent_learnings "$test_dir/.claude" "$STARFORGE_DIR"

    # Assert: Verify directories were created
    local missing_dirs=()

    if [ ! -d "$test_dir/.claude/agents/agent-learnings" ]; then
        missing_dirs+=("agents/agent-learnings")
    fi

    if [ ! -d "$test_dir/.claude/spikes" ]; then
        missing_dirs+=("spikes")
    fi

    if [ ! -d "$test_dir/.claude/triggers/processed" ]; then
        missing_dirs+=("triggers/processed")
    fi

    # Check per-agent directories
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        if [ ! -d "$test_dir/.claude/agents/agent-learnings/$agent" ]; then
            missing_dirs+=("agents/agent-learnings/$agent")
        fi
    done

    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"

    # Return result
    if [ ${#missing_dirs[@]} -eq 0 ]; then
        return 0
    else
        echo "  Missing directories: ${missing_dirs[*]}"
        return 1
    fi
}

# Test 2: Update recreates agent-learnings subdirectories
test_update_recreates_agent_subdirectories() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"

    # Setup: Create .claude with missing agent subdirectories
    mkdir -p .claude/agents/agent-learnings

    # Execute: Initialize agent learnings
    export STARFORGE_DIR="/Users/krunaaltavkar/starforge-master"
    source "$STARFORGE_DIR/templates/lib/starforge-common.sh"

    initialize_agent_learnings "$test_dir/.claude" "$STARFORGE_DIR"

    # Assert: All agent subdirectories exist
    local agents=("orchestrator" "senior-engineer" "junior-engineer" "qa-engineer" "tpm")
    local missing=0

    for agent in "${agents[@]}"; do
        if [ ! -d "$test_dir/.claude/agents/agent-learnings/$agent" ]; then
            echo "  ❌ Missing: agents/agent-learnings/$agent"
            missing=$((missing + 1))
        fi

        if [ ! -d "$test_dir/.claude/agents/scratchpads/$agent" ]; then
            echo "  ❌ Missing: agents/scratchpads/$agent"
            missing=$((missing + 1))
        fi
    done

    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"

    # Return result
    [ $missing -eq 0 ]
}

# Test 3: Validation catches missing directories
test_validation_catches_missing_directories() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"

    # Setup: Create incomplete .claude structure
    mkdir -p .claude/agents
    mkdir -p .claude/scripts
    # Deliberately omit some required directories

    # Execute: Run validation
    export STARFORGE_DIR="/Users/krunaaltavkar/starforge-master"
    source "$STARFORGE_DIR/templates/lib/starforge-common.sh"

    # Assert: Validation should fail
    if validate_directory_structure "$test_dir/.claude" 2>&1 | grep -q "Missing:"; then
        validation_failed=true
    else
        validation_failed=false
    fi

    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"

    # Return result (we expect validation to fail)
    if [ "$validation_failed" = true ]; then
        return 0
    else
        echo "  ❌ Validation should have detected missing directories"
        return 1
    fi
}

# Test 4: Full directory structure validation passes after ensure
test_full_structure_validation() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"

    # Setup: Empty .claude
    mkdir -p .claude

    # Execute: Ensure structure then validate
    export STARFORGE_DIR="/Users/krunaaltavkar/starforge-master"
    source "$STARFORGE_DIR/templates/lib/starforge-common.sh"

    ensure_directory_structure "$test_dir/.claude"
    initialize_agent_learnings "$test_dir/.claude" "$STARFORGE_DIR"

    # Assert: Validation should pass
    if validate_directory_structure "$test_dir/.claude" > /dev/null 2>&1; then
        validation_passed=true
    else
        validation_passed=false
    fi

    # Cleanup
    cd - > /dev/null
    rm -rf "$test_dir"

    # Return result
    [ "$validation_passed" = true ]
}

# Run all tests
echo "================================"
echo "StarForge Update Integration Tests"
echo "================================"

run_test "Test 1: Update with missing directories" test_update_with_missing_directories
run_test "Test 2: Update recreates agent subdirectories" test_update_recreates_agent_subdirectories
run_test "Test 3: Validation catches missing directories" test_validation_catches_missing_directories
run_test "Test 4: Full structure validation passes" test_full_structure_validation

# Summary
echo ""
echo "================================"
echo "Test Summary"
echo "================================"
echo "Total: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
