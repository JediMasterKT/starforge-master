#!/bin/bash
# StarForge Foundation Library Test Suite
# Tests project-env.sh library (TDD approach)

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
TEST_DIR="$STARFORGE_ROOT/.test-tmp"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Foundation Library Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_equals() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local actual="$1"
    local expected="$2"
    local desc="${3:-Expected: $expected, Got: $actual}"

    if [ "$actual" = "$expected" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Expected: $expected"
        echo -e "    Got: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_not_empty() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local value="$1"
    local desc="${2:-Value should not be empty}"

    if [ -n "$value" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (value is empty)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_true() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local condition="$1"
    local desc="${2:-Condition should be true}"

    if [ "$condition" = "true" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (got: $condition)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_false() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local condition="$1"
    local desc="${2:-Condition should be false}"

    if [ "$condition" = "false" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (got: $condition)"
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
        echo -e "  ${RED}✗${NC} $desc"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Cleanup function
cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Setup test environment
setup() {
    cleanup
    mkdir -p "$TEST_DIR"
}

# ============================================================================
# TEST SUITE
# ============================================================================

test_detect_main_repo_from_main() {
    echo ""
    echo -e "${BLUE}TEST: Detect main repo from main repository${NC}"

    # Create test git repo
    local test_repo="$TEST_DIR/my-app"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Copy library to test repo
    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Create empty commit (required for worktree operations later)
    git commit --allow-empty -m "Initial commit" -q

    # Source the library
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    # Assertions
    assert_equals "$STARFORGE_MAIN_REPO" "$test_repo" "Main repo path detected correctly"
    assert_equals "$STARFORGE_PROJECT_NAME" "my-app" "Project name extracted correctly"
    assert_equals "$STARFORGE_IS_WORKTREE" "false" "Not detected as worktree"
    assert_equals "$STARFORGE_AGENT_ID" "main" "Agent ID is 'main' in main repo"
    assert_equals "$STARFORGE_CLAUDE_DIR" "$test_repo/.claude" "Claude dir path correct"
}

test_detect_main_repo_from_worktree() {
    echo ""
    echo -e "${BLUE}TEST: Detect main repo from worktree${NC}"

    # Create test git repo
    local test_repo="$TEST_DIR/my-app"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create empty commit
    git commit --allow-empty -m "Initial commit" -q

    # Copy library to main repo
    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Create worktree
    git worktree add ../my-app-junior-dev-a -b worktree-a 2>/dev/null

    # Navigate to worktree
    cd ../my-app-junior-dev-a

    # Copy library to worktree (simulating installation)
    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Source the library
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    # Assertions
    assert_equals "$STARFORGE_MAIN_REPO" "$test_repo" "Main repo detected from worktree"
    assert_equals "$STARFORGE_PROJECT_NAME" "my-app" "Project name correct from worktree"
    assert_equals "$STARFORGE_IS_WORKTREE" "true" "Correctly detected as worktree"
    assert_equals "$STARFORGE_AGENT_ID" "junior-dev-a" "Agent ID extracted from worktree name"
    assert_equals "$STARFORGE_CLAUDE_DIR" "$test_repo/.claude" "Claude dir points to main repo"
}

test_special_characters_in_name() {
    echo ""
    echo -e "${BLUE}TEST: Handle special characters in project name${NC}"

    # Test project names with dots, underscores, numbers
    local test_repo="$TEST_DIR/my-app_v2.0"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Create empty commit
    git commit --allow-empty -m "Initial commit" -q

    # Copy library
    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Source the library
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    # Assertions
    assert_equals "$STARFORGE_PROJECT_NAME" "my-app_v2.0" "Special chars preserved in project name"
}

test_is_worktree_function() {
    echo ""
    echo -e "${BLUE}TEST: is_worktree() function${NC}"

    # Test from main repo
    local test_repo="$TEST_DIR/test-worktree-func"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "Initial commit" -q

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Source and test from main
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    if is_worktree; then
        assert_true "false" "is_worktree should return false in main repo"
    else
        assert_true "true" "is_worktree returns false in main repo"
    fi

    # Create worktree and test
    git worktree add ../test-worktree-func-junior-dev-b -b worktree-b 2>/dev/null
    cd ../test-worktree-func-junior-dev-b

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    if is_worktree; then
        assert_true "true" "is_worktree returns true in worktree"
    else
        assert_true "false" "is_worktree should return true in worktree"
    fi
}

test_detect_agent_id_function() {
    echo ""
    echo -e "${BLUE}TEST: detect_agent_id() function${NC}"

    # Test main repo
    local test_repo="$TEST_DIR/agent-id-test"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "Initial commit" -q

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    local agent_id
    agent_id=$(detect_agent_id)
    assert_equals "$agent_id" "main" "detect_agent_id returns 'main' in main repo"

    # Test worktree junior-dev-a
    git worktree add ../agent-id-test-junior-dev-a -b branch-a 2>/dev/null
    cd ../agent-id-test-junior-dev-a
    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh
    agent_id=$(detect_agent_id)
    assert_equals "$agent_id" "junior-dev-a" "detect_agent_id extracts 'junior-dev-a'"

    # Test worktree junior-dev-c
    cd "$test_repo"
    git worktree add ../agent-id-test-junior-dev-c -b branch-c 2>/dev/null
    cd ../agent-id-test-junior-dev-c
    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh
    agent_id=$(detect_agent_id)
    assert_equals "$agent_id" "junior-dev-c" "detect_agent_id extracts 'junior-dev-c'"
}

test_empty_git_repo() {
    echo ""
    echo -e "${BLUE}TEST: Empty git repo edge case${NC}"

    # Empty git repo (no commits)
    local test_repo="$TEST_DIR/empty-repo"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Should still work and detect project name
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    assert_equals "$STARFORGE_PROJECT_NAME" "empty-repo" "Project name detected in empty repo"
    assert_not_empty "$STARFORGE_MAIN_REPO" "Main repo path set in empty repo"
}

test_non_git_directory() {
    echo ""
    echo -e "${BLUE}TEST: Non-git directory edge case${NC}"

    # Non-git directory
    local test_dir="$TEST_DIR/non-git-dir"
    mkdir -p "$test_dir"
    cd "$test_dir"

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Should fall back to pwd
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh

    assert_equals "$STARFORGE_PROJECT_NAME" "non-git-dir" "Project name from directory name"
    assert_equals "$STARFORGE_MAIN_REPO" "$test_dir" "Main repo falls back to pwd"
    assert_equals "$STARFORGE_IS_WORKTREE" "false" "Non-git dir not detected as worktree"
}

test_idempotent_sourcing() {
    echo ""
    echo -e "${BLUE}TEST: Idempotent (safe to source multiple times)${NC}"

    local test_repo="$TEST_DIR/idempotent-test"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "Initial commit" -q

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Source once
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh
    local first_value="$STARFORGE_MAIN_REPO"

    # Source again
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh
    local second_value="$STARFORGE_MAIN_REPO"

    # Source third time
    # shellcheck disable=SC1091
    . .claude/lib/project-env.sh
    local third_value="$STARFORGE_MAIN_REPO"

    assert_equals "$first_value" "$second_value" "Values consistent after 2nd source"
    assert_equals "$second_value" "$third_value" "Values consistent after 3rd source"
}

test_performance() {
    echo ""
    echo -e "${BLUE}TEST: Performance (<50ms)${NC}"

    local test_repo="$TEST_DIR/perf-test"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git commit --allow-empty -m "Initial commit" -q

    mkdir -p .claude/lib
    cp "$STARFORGE_ROOT/templates/lib/project-env.sh" .claude/lib/

    # Measure execution time (in milliseconds)
    local start_time
    local end_time
    local duration

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        start_time=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
        # shellcheck disable=SC1091
        . .claude/lib/project-env.sh
        end_time=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    else
        # Linux
        start_time=$(date +%s%3N)
        # shellcheck disable=SC1091
        . .claude/lib/project-env.sh
        end_time=$(date +%s%3N)
    fi

    duration=$((end_time - start_time))

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$duration" -lt 50 ]; then
        echo -e "  ${GREEN}✓${NC} Performance target met (${duration}ms < 50ms)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Performance target missed (${duration}ms >= 50ms)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================================================
# RUN TESTS
# ============================================================================

setup

# Run all tests
test_detect_main_repo_from_main
test_detect_main_repo_from_worktree
test_special_characters_in_name
test_is_worktree_function
test_detect_agent_id_function
test_empty_git_repo
test_non_git_directory
test_idempotent_sourcing
test_performance

# Cleanup
cleanup

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}TEST SUMMARY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    exit 1
fi
