#!/bin/bash
# Test suite for active agent detection in starforge update
#
# Tests cover:
# - Detection logic runs correctly
# - Worktree pattern matching
# - Force flag behavior
# - Error message clarity
# - Flag parsing

set -e

# Colors for output
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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test helper functions
test_start() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    echo -e "${YELLOW}TEST $TESTS_RUN: $test_name${NC}"
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✓ PASS${NC}"
}

test_fail() {
    local reason="$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}✗ FAIL: $reason${NC}"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        test_fail "$message"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Output should contain expected text}"

    if echo "$haystack" | grep -q "$needle"; then
        return 0
    else
        echo "  Expected to find: $needle"
        echo "  In output (first 200 chars): ${haystack:0:200}"
        test_fail "$message"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Output should NOT contain text}"

    if echo "$haystack" | grep -q "$needle"; then
        echo "  Should NOT find: $needle"
        echo "  But found in: ${haystack:0:200}"
        test_fail "$message"
        return 1
    else
        return 0
    fi
}

# Test 1: Detection function exists and is syntactically correct
test_function_exists() {
    test_start "detect_active_agents function exists and is valid"

    cd "$PROJECT_ROOT"

    # Check function exists in starforge script
    if grep -q "detect_active_agents()" bin/starforge; then
        # Try to extract and validate function syntax
        if bash -n bin/starforge 2>&1; then
            test_pass
            return 0
        else
            test_fail "starforge script has syntax errors"
            return 1
        fi
    else
        test_fail "detect_active_agents function not found in bin/starforge"
        return 1
    fi
}

# Test 2: Worktree pattern matches only agent directories
test_worktree_pattern() {
    test_start "Worktree pattern matches only agent directories"

    cd "$PROJECT_ROOT"

    # Get actual worktree list
    local worktrees=$(git worktree list)

    # Test pattern against known agent worktrees
    local agent_pattern="starforge-master-(junior-dev|senior|qa-engineer|orchestrator|tpm)-[a-z]"

    # Should match agent worktrees
    if echo "$worktrees" | grep -qE "$agent_pattern"; then
        # Should NOT match non-agent worktrees like discord, fix-permission, etc
        local non_agent_matches=$(echo "$worktrees" | grep -E "$agent_pattern" | grep -E "discord|fix-permission|permission-helper" || true)

        if [ -z "$non_agent_matches" ]; then
            test_pass
            return 0
        else
            test_fail "Pattern incorrectly matched non-agent worktrees: $non_agent_matches"
            return 1
        fi
    else
        echo "  Note: No agent worktrees found (OK for minimal test env)"
        test_pass
        return 0
    fi
}

# Test 3: Detection uses worktree paths, not just process names
test_uses_worktree_paths() {
    test_start "Detection uses worktree paths not just keywords"

    cd "$PROJECT_ROOT"

    # Check that function uses git worktree list
    if grep -q "git worktree list" bin/starforge; then
        # Check that it uses pgrep with worktree path
        if grep -q 'pgrep -f "claude.*\${worktree_path}"' bin/starforge || \
           grep -q 'pgrep -f "claude.*$worktree_path"' bin/starforge; then
            test_pass
            return 0
        else
            test_fail "Function does not use worktree paths in pgrep"
            return 1
        fi
    else
        test_fail "Function does not query git worktree list"
        return 1
    fi
}

# Test 4: Force flag is recognized
test_force_flag_recognized() {
    test_start "Force flag --force/-f is recognized"

    cd "$PROJECT_ROOT"

    # Check flag parsing in update command
    if grep -A 20 "update)" bin/starforge | grep -q "FORCE_FLAG"; then
        test_pass
        return 0
    else
        test_fail "FORCE_FLAG not found in update command"
        return 1
    fi
}

# Test 5: Unknown flags rejected
test_unknown_flag_rejected() {
    test_start "Unknown flags are rejected with error"

    cd "$PROJECT_ROOT"

    # Test that unknown flag causes error
    local output
    output=$(bash "$PROJECT_ROOT/bin/starforge" update --invalid-flag 2>&1 || true)

    if assert_contains "$output" "Unknown flag" "Should reject unknown flags"; then
        test_pass
        return 0
    else
        return 1
    fi
}

# Test 6: Error message has required elements
test_error_message_completeness() {
    test_start "Error message contains all required guidance"

    cd "$PROJECT_ROOT"

    # Check that detect_active_agents function has proper error output
    local function_text=$(sed -n '/^detect_active_agents()/,/^}/p' bin/starforge)

    local has_error=0
    local has_wait=0
    local has_kill=0
    local has_force=0

    if echo "$function_text" | grep -q "Cannot update.*Active agents detected"; then
        has_error=1
    fi

    if echo "$function_text" | grep -q "Wait for agents to complete"; then
        has_wait=1
    fi

    if echo "$function_text" | grep -q "Stop agents manually"; then
        has_kill=1
    fi

    if echo "$function_text" | grep -q "Force update anyway"; then
        has_force=1
    fi

    local missing=""
    [ $has_error -eq 0 ] && missing="${missing}error message, "
    [ $has_wait -eq 0 ] && missing="${missing}wait option, "
    [ $has_kill -eq 0 ] && missing="${missing}kill option, "
    [ $has_force -eq 0 ] && missing="${missing}force option, "

    if [ -z "$missing" ]; then
        test_pass
        return 0
    else
        test_fail "Missing: $missing"
        return 1
    fi
}

# Test 7: Function returns correct exit codes
test_exit_codes() {
    test_start "Function returns correct exit codes (0=found, 1=not found)"

    cd "$PROJECT_ROOT"

    # Check that function returns 0 when agents found, 1 when not
    local function_text=$(sed -n '/^detect_active_agents()/,/^}/p' bin/starforge)

    if echo "$function_text" | grep -q "return 0.*# Active agents found" && \
       echo "$function_text" | grep -q "return 1"; then
        test_pass
        return 0
    else
        test_fail "Exit codes not properly documented or used"
        return 1
    fi
}

# Test 8: Inline documentation exists
test_has_documentation() {
    test_start "Function has inline comments explaining logic"

    cd "$PROJECT_ROOT"

    # Check for comments in detect_active_agents function
    local function_text=$(sed -n '/^detect_active_agents()/,/^}/p' bin/starforge)

    # Should have comments about strategy, pattern, etc
    if echo "$function_text" | grep -q "#.*worktree"; then
        test_pass
        return 0
    else
        test_fail "Missing inline documentation about worktree strategy"
        return 1
    fi
}

# Test 9: No overly broad patterns
test_no_broad_patterns() {
    test_start "Does not use overly broad pgrep patterns"

    cd "$PROJECT_ROOT"

    # Check that we don't use the old broad pattern
    local function_text=$(sed -n '/^detect_active_agents()/,/^}/p' bin/starforge)

    # Should NOT have: pgrep -f "claude.*(junior|senior|qa|orchestrator|tpm)"
    if echo "$function_text" | grep -q 'pgrep -f "claude.*(\(junior\|senior\|qa\|orchestrator\|tpm\)"'; then
        test_fail "Still using overly broad pgrep pattern"
        return 1
    else
        test_pass
        return 0
    fi
}

# Test 10: Integration - Full update command with unknown flag
test_integration_unknown_flag() {
    test_start "Integration: starforge update rejects unknown flags"

    cd "$PROJECT_ROOT"

    local output
    local exit_code
    set +e  # Temporarily allow failures
    output=$(bash bin/starforge update --unknown 2>&1)
    exit_code=$?
    set -e  # Re-enable exit on error

    if [ $exit_code -ne 0 ]; then
        if assert_contains "$output" "Unknown flag"; then
            test_pass
            return 0
        else
            return 1
        fi
    else
        test_fail "Command should exit non-zero for unknown flag"
        return 1
    fi
}

# Test 11: Integration - Force flag accepted
test_integration_force_flag() {
    test_start "Integration: starforge update accepts --force flag"

    cd "$PROJECT_ROOT"

    # Just check that --force doesn't cause "unknown flag" error
    local output
    output=$(bash bin/starforge update --force 2>&1 || true)

    if assert_not_contains "$output" "Unknown flag.*--force"; then
        test_pass
        return 0
    else
        return 1
    fi
}

# Test 12: Worktree extraction uses correct command
test_worktree_command() {
    test_start "Uses 'git worktree list' to find agent directories"

    cd "$PROJECT_ROOT"

    local function_text=$(sed -n '/^detect_active_agents()/,/^}/p' bin/starforge)

    # Should use git worktree list
    if echo "$function_text" | grep -q "git worktree list"; then
        # And should use grep to filter
        if echo "$function_text" | grep -q "grep.*starforge-master"; then
            test_pass
            return 0
        else
            test_fail "Uses git worktree list but doesn't filter with grep"
            return 1
        fi
    else
        test_fail "Does not use 'git worktree list'"
        return 1
    fi
}

# Run all tests
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Active Agent Detection Test Suite${NC}"
    echo -e "${GREEN}========================================${NC}"

    test_function_exists
    test_worktree_pattern
    test_uses_worktree_paths
    test_force_flag_recognized
    test_unknown_flag_rejected
    test_error_message_completeness
    test_exit_codes
    test_has_documentation
    test_no_broad_patterns
    test_integration_unknown_flag
    test_integration_force_flag
    test_worktree_command

    # Summary
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Test Results${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
        echo ""
        exit 1
    else
        echo -e "Tests failed: ${GREEN}0${NC}"
        echo ""
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    fi
}

# Run tests
main
