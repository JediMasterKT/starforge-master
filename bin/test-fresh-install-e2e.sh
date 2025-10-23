#!/bin/bash
# StarForge Fresh Installation E2E Test
# Simulates brand new user installation and validates end-to-end workflow
# This test would have caught Issue #36 (hardcoded empowerai references)

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

# Test configuration
TEST_PROJECT_NAME="user-project-test-$$"
TEST_BASE_DIR="/tmp/starforge-e2e-test"
TEST_PROJECT_DIR="$TEST_BASE_DIR/$TEST_PROJECT_NAME"

# Helper to resolve symlinks (macOS /tmp -> /private/tmp)
resolve_path() {
    local path="$1"
    # Try realpath first (Linux), then fall back to readlink (macOS)
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    else
        # macOS: resolve symlinks manually
        cd "$path" && pwd -P
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Fresh Installation E2E Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Testing installation in: $TEST_PROJECT_DIR"
echo "Performance target: <3 minutes"
echo ""

# Start timer
START_TIME=$(date +%s)

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

assert_failure() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="$1"
    local exit_code=${2:-$?}

    if [ $exit_code -ne 0 ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (should have failed)"
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
        echo -e "  ${RED}✗${NC} $desc"
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

assert_no_match() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local pattern="$1"
    local file="$2"
    local desc="${3:-Pattern should not match}"

    if ! grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Found '$pattern' in $file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup: Create fresh test repository
setup_fresh_repo() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 Setup: Creating fresh test repository"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Clean up any previous test
    rm -rf "$TEST_BASE_DIR"
    mkdir -p "$TEST_PROJECT_DIR"
    cd "$TEST_PROJECT_DIR"

    # Initialize git repo
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create simple project
    echo "print('Hello from $TEST_PROJECT_NAME')" > main.py
    echo "# $TEST_PROJECT_NAME" > README.md
    git add .
    git commit -m "Initial commit"

    echo -e "${GREEN}✓${NC} Created test repository at $TEST_PROJECT_DIR"
    echo ""
}

# Cleanup: Remove test directory
cleanup() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧹 Cleanup: Removing test files"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd /tmp
    rm -rf "$TEST_BASE_DIR"

    echo -e "${GREEN}✓${NC} Cleaned up test directory"
    echo ""
}

# ============================================
# TEST SUITE
# ============================================

# Test 1: Fresh repo install
test_fresh_repo_install() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 1: Fresh Repository Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$TEST_PROJECT_DIR"

    # Run installation (non-interactive mode)
    # Provide inputs: 3 (skip GitHub), 3 (agent count), y (proceed)
    echo -e "3\n3\ny" | bash "$STARFORGE_ROOT/bin/install.sh" > /tmp/install.log 2>&1
    local install_exit=$?

    assert_success "Installation completed successfully" $install_exit
    assert_dir_exists "$TEST_PROJECT_DIR/.claude" ".claude directory created"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/lib/project-env.sh" "project-env.sh created"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/CLAUDE.md" "CLAUDE.md created"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/settings.json" "settings.json created"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/LEARNINGS.md" "LEARNINGS.md created"

    echo ""
}

# Test 2: No empowerai references in installed files
test_no_empowerai_refs_in_fresh_install() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 2: No Hardcoded 'empowerai' References"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$TEST_PROJECT_DIR"

    # Check for hardcoded empowerai references
    local empowerai_count=$(grep -r "empowerai" .claude/ 2>/dev/null | grep -v "Binary file" | wc -l | tr -d ' ')

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$empowerai_count" -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} No 'empowerai' references in installed files"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Found $empowerai_count 'empowerai' references (should be 0)"
        echo ""
        echo "  Files with 'empowerai':"
        grep -r "empowerai" .claude/ 2>/dev/null | grep -v "Binary file" | head -5
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    echo ""
}

# Test 3: project-env.sh detects correct name
test_project_env_detects_correct_name() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 3: Project Environment Detection"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$TEST_PROJECT_DIR"

    # Source project-env.sh and check exports
    source .claude/lib/project-env.sh

    # Resolve paths for comparison (handle /tmp -> /private/tmp on macOS)
    local expected_main_repo=$(resolve_path "$TEST_PROJECT_DIR")
    local actual_main_repo=$(resolve_path "$STARFORGE_MAIN_REPO")
    local expected_claude_dir=$(resolve_path "$TEST_PROJECT_DIR/.claude")
    local actual_claude_dir=$(resolve_path "$STARFORGE_CLAUDE_DIR")

    assert_equals "$TEST_PROJECT_NAME" "$STARFORGE_PROJECT_NAME" "STARFORGE_PROJECT_NAME detected correctly"
    assert_equals "$expected_main_repo" "$actual_main_repo" "STARFORGE_MAIN_REPO set correctly"
    assert_equals "false" "$STARFORGE_IS_WORKTREE" "STARFORGE_IS_WORKTREE=false in main repo"
    assert_equals "$expected_claude_dir" "$actual_claude_dir" "STARFORGE_CLAUDE_DIR set correctly"

    echo ""
}

# Test 4: Worktrees created with project name
test_worktrees_created_with_project_name() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 4: Worktrees Created with Project Name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check for worktrees in parent directory
    local worktree_a="$TEST_BASE_DIR/${TEST_PROJECT_NAME}-junior-dev-a"
    local worktree_b="$TEST_BASE_DIR/${TEST_PROJECT_NAME}-junior-dev-b"
    local worktree_c="$TEST_BASE_DIR/${TEST_PROJECT_NAME}-junior-dev-c"

    # Worktrees are optional depending on user choice
    if [ -d "$worktree_a" ] || [ -d "$worktree_b" ] || [ -d "$worktree_c" ]; then
        assert_dir_exists "$worktree_a" "Worktree junior-dev-a created"
        assert_dir_exists "$worktree_b" "Worktree junior-dev-b created"
        assert_dir_exists "$worktree_c" "Worktree junior-dev-c created"
    else
        echo -e "  ${YELLOW}⚠${NC}  Worktrees not created (optional - skipping validation)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi

    echo ""
}

# Test 5: Agent detection works in fresh worktree
test_agent_detection_works_in_fresh_worktree() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 5: Agent Detection in Worktree"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local worktree_a="$TEST_BASE_DIR/${TEST_PROJECT_NAME}-junior-dev-a"

    if [ -d "$worktree_a" ]; then
        cd "$worktree_a"

        # Source project-env.sh from worktree
        source .claude/lib/project-env.sh

        # Resolve paths for comparison
        local expected_main_repo=$(resolve_path "$TEST_PROJECT_DIR")
        local actual_main_repo=$(resolve_path "$STARFORGE_MAIN_REPO")

        assert_equals "junior-dev-a" "$STARFORGE_AGENT_ID" "STARFORGE_AGENT_ID detected as junior-dev-a"
        assert_equals "$expected_main_repo" "$actual_main_repo" "STARFORGE_MAIN_REPO points to main repo"
        assert_equals "true" "$STARFORGE_IS_WORKTREE" "STARFORGE_IS_WORKTREE=true in worktree"
        assert_equals "$TEST_PROJECT_NAME" "$STARFORGE_PROJECT_NAME" "STARFORGE_PROJECT_NAME correct in worktree"
    else
        TESTS_RUN=$((TESTS_RUN + 4))
        TESTS_FAILED=$((TESTS_FAILED + 4))
        echo -e "  ${RED}✗${NC} Worktree not found, skipping agent detection tests"
    fi

    echo ""
}

# Test 6: Edge case - Non-git directory should fail gracefully
test_non_git_directory_fails_gracefully() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 6: Non-Git Directory Error Handling"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local non_git_dir="/tmp/non-git-test-$$"
    mkdir -p "$non_git_dir"
    cd "$non_git_dir"

    # Try to install in non-git directory (should fail)
    echo -e "3\n3\ny" | bash "$STARFORGE_ROOT/bin/install.sh" > /tmp/non-git-install.log 2>&1
    local exit_code=$?

    assert_failure "Installation fails gracefully in non-git directory" $exit_code

    rm -rf "$non_git_dir"

    echo ""
}

# Test 7: Directory structure validation
test_directory_structure_validation() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 7: Directory Structure Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$TEST_PROJECT_DIR"

    # Check expected directory structure
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/agents" "agents/ directory exists"
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/agents/agent-learnings" "agent-learnings/ directory exists"
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/lib" "lib/ directory exists"
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/scripts" "scripts/ directory exists"
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/triggers" "triggers/ directory exists"
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/triggers/processed" "triggers/processed/ directory exists"
    assert_dir_exists "$TEST_PROJECT_DIR/.claude/coordination" "coordination/ directory exists"

    echo ""
}

# Test 8: Critical files validation
test_critical_files_validation() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Test 8: Critical Files Validation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    cd "$TEST_PROJECT_DIR"

    assert_file_exists "$TEST_PROJECT_DIR/.claude/CLAUDE.md" "CLAUDE.md exists"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/agents/orchestrator.md" "orchestrator agent exists"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/agents/junior-engineer.md" "junior-engineer agent exists"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/agents/qa-engineer.md" "qa-engineer agent exists"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/agents/senior-engineer.md" "senior-engineer agent exists"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/agents/tpm.md" "tpm agent exists"
    assert_file_exists "$TEST_PROJECT_DIR/.claude/scripts/trigger-helpers.sh" "trigger-helpers.sh exists"

    echo ""
}

# ============================================
# RUN ALL TESTS
# ============================================

# Setup
setup_fresh_repo

# Run tests
test_fresh_repo_install
test_no_empowerai_refs_in_fresh_install
test_project_env_detects_correct_name
test_worktrees_created_with_project_name
test_agent_detection_works_in_fresh_worktree
test_non_git_directory_fails_gracefully
test_directory_structure_validation
test_critical_files_validation

# Cleanup
cleanup

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# ============================================
# PRINT SUMMARY
# ============================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Tests run:    $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
echo -e "  Duration:     ${MINUTES}m ${SECONDS}s"
echo ""

# Check performance target
if [ $DURATION -lt 180 ]; then
    echo -e "  ${GREEN}✓${NC} Performance target met (<3 minutes)"
else
    echo -e "  ${YELLOW}⚠${NC}  Performance target missed (took ${MINUTES}m ${SECONDS}s, target: <3 min)"
fi

echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All E2E tests passed!${NC}"
    echo ""
    echo "Fresh installation validation complete:"
    echo "  ✓ Installation works in brand new project"
    echo "  ✓ No hardcoded 'empowerai' references"
    echo "  ✓ Project name detected correctly"
    echo "  ✓ Worktrees created with correct naming"
    echo "  ✓ Agent detection works in worktrees"
    echo "  ✓ Error handling for edge cases"
    echo "  ✓ Directory structure validated"
    echo "  ✓ Critical files present"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some E2E tests failed${NC}"
    echo ""
    echo "This test simulates the complete user journey from"
    echo "fresh repository to working StarForge installation."
    echo "Failures indicate issues that real users would encounter."
    echo ""
    exit 1
fi
