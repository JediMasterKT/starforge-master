#!/bin/bash
# Test installer for project-agnostic installation
# Tests for ticket #15

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
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$PROJECT_ROOT/bin/install.sh"

# Temp directory for test projects
TEST_ROOT="/tmp/starforge-installer-tests-$$"

# Helper functions
assert_exit_code() {
    local expected=$1
    local actual=$2
    local msg=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$actual" -eq "$expected" ]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $msg (expected exit code $expected, got $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local file=$1
    local msg=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $msg (file not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_dir_exists() {
    local dir=$1
    local msg=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $msg (directory not found: $dir)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_executable() {
    local file=$1
    local msg=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ -x "$file" ]; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $msg (file not executable: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_string_in_file() {
    local string=$1
    local file=$2
    local msg=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if grep -q "$string" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $msg (string '$string' not found in $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_string_not_in_file() {
    local string=$1
    local file=$2
    local msg=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if ! grep -q "$string" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $msg (string '$string' found in $file, should not be present)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_project() {
    local project_name=$1
    local test_dir="$TEST_ROOT/$project_name"

    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init -q
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create a dummy file
    echo "# $project_name" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    echo "$test_dir"
}

# Cleanup
cleanup() {
    if [ -d "$TEST_ROOT" ]; then
        rm -rf "$TEST_ROOT"
    fi
}

# Run installer in non-interactive mode
run_installer_noninteractive() {
    # Provide input to installer using printf via expect or yes
    # Use yes to answer all prompts with default
    (sleep 1; echo 3; sleep 1; echo; sleep 1; echo n) | "$INSTALL_SCRIPT" > /tmp/installer_output_$$.log 2>&1 &
    local install_pid=$!

    # Wait up to 30 seconds
    local count=0
    while kill -0 $install_pid 2>/dev/null && [ $count -lt 30 ]; do
        sleep 1
        count=$((count + 1))
    done

    # If still running, kill it
    if kill -0 $install_pid 2>/dev/null; then
        kill -9 $install_pid 2>/dev/null
    fi

    wait $install_pid 2>/dev/null
}

# Test 1: Installer creates .claude/lib/ directory
test_installer_creates_lib_directory() {
    echo ""
    echo "Test 1: Installer creates .claude/lib/ directory"

    local test_dir=$(setup_test_project "installer-test")
    cd "$test_dir"
    run_installer_noninteractive

    assert_dir_exists "$test_dir/.claude/lib" "Creates .claude/lib/ directory"

    cd "$PROJECT_ROOT"
}

# Test 2: Installer copies project-env.sh
test_installer_copies_project_env() {
    echo ""
    echo "Test 2: Installer copies project-env.sh"

    local test_dir=$(setup_test_project "installer-test-2")
    cd "$test_dir"
    run_installer_noninteractive

    assert_file_exists "$test_dir/.claude/lib/project-env.sh" "Copies project-env.sh to .claude/lib/"
    assert_executable "$test_dir/.claude/lib/project-env.sh" "project-env.sh has execute permissions"

    cd "$PROJECT_ROOT"
}

# Test 3: Installer creates worktrees with project name
test_installer_creates_worktrees_with_project_name() {
    echo ""
    echo "Test 3: Installer creates worktrees with actual project name"

    local test_dir=$(setup_test_project "my-awesome-app")
    cd "$test_dir"

    # Run installer with agents
    (sleep 1; echo 3; sleep 1; echo 2; sleep 1; echo y) | "$INSTALL_SCRIPT" > /tmp/installer_output_$$.log 2>&1 &
    local install_pid=$!
    local count=0
    while kill -0 $install_pid 2>/dev/null && [ $count -lt 30 ]; do
        sleep 1
        count=$((count + 1))
    done
    if kill -0 $install_pid 2>/dev/null; then
        kill -9 $install_pid 2>/dev/null
    fi
    wait $install_pid 2>/dev/null

    # Check worktree list
    git worktree list | grep -q "my-awesome-app-junior-dev-a"
    assert_exit_code 0 $? "Worktree created with project name (my-awesome-app-junior-dev-a)"

    git worktree list | grep -q "my-awesome-app-junior-dev-b"
    assert_exit_code 0 $? "Worktree created with project name (my-awesome-app-junior-dev-b)"

    # Verify no hard-coded "empowerai" in worktree names
    git worktree list | grep -q "empowerai" && exit_code=0 || exit_code=1
    assert_exit_code 1 $exit_code "No hard-coded 'empowerai' in worktree names"

    cd "$PROJECT_ROOT"
}

# Test 4: settings.json has correct paths
test_installer_settings_json_correct() {
    echo ""
    echo "Test 4: settings.json has correct project path"

    local test_dir=$(setup_test_project "backend-api")
    cd "$test_dir"
    run_installer_noninteractive

    assert_string_in_file "$test_dir" "$test_dir/.claude/settings.json" "settings.json contains correct project path"

    cd "$PROJECT_ROOT"
}

# Test 5: lib/ directory exists - don't fail, just overwrite
test_installer_lib_already_exists() {
    echo ""
    echo "Test 5: Installer handles existing .claude/lib/ directory"

    local test_dir=$(setup_test_project "existing-lib-test")
    cd "$test_dir"

    # Create .claude/lib/ manually
    mkdir -p "$test_dir/.claude/lib"
    echo "old content" > "$test_dir/.claude/lib/project-env.sh"

    # Run installer
    run_installer_noninteractive

    assert_file_exists "$test_dir/.claude/lib/project-env.sh" "project-env.sh exists after reinstall"

    # Verify content was overwritten (not "old content")
    if grep -q "old content" "$test_dir/.claude/lib/project-env.sh"; then
        echo -e "${RED}✗${NC} File should have been overwritten"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${GREEN}✓${NC} File was properly overwritten"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi

    cd "$PROJECT_ROOT"
}

# Test 6: No hard-coded project assumptions
test_installer_no_hardcoded_assumptions() {
    echo ""
    echo "Test 6: Installer has no hard-coded 'empowerai' assumptions"

    local test_dir=$(setup_test_project "unique-project-xyz")
    cd "$test_dir"
    run_installer_noninteractive

    # Check that settings.json doesn't contain hard-coded empowerai
    assert_string_not_in_file "empowerai" "$test_dir/.claude/settings.json" "settings.json has no hard-coded 'empowerai'"

    cd "$PROJECT_ROOT"
}

# Test 7: Installer is idempotent (safe to rerun)
test_installer_idempotent() {
    echo ""
    echo "Test 7: Installer is idempotent (safe to rerun)"

    local test_dir=$(setup_test_project "idempotent-test")
    cd "$test_dir"

    # Run installer twice
    run_installer_noninteractive
    local first_checksum=$(md5sum "$test_dir/.claude/lib/project-env.sh" 2>/dev/null | cut -d' ' -f1)

    run_installer_noninteractive
    local second_checksum=$(md5sum "$test_dir/.claude/lib/project-env.sh" 2>/dev/null | cut -d' ' -f1)

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$first_checksum" = "$second_checksum" ]; then
        echo -e "${GREEN}✓${NC} Installer produces consistent results when rerun"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Installer produces different results when rerun"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cd "$PROJECT_ROOT"
}

# Main test execution
main() {
    echo "=================================="
    echo "Testing Installer (Ticket #15)"
    echo "=================================="

    # Verify install script exists
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo -e "${RED}ERROR: Install script not found at $INSTALL_SCRIPT${NC}"
        exit 1
    fi

    # Create test root
    mkdir -p "$TEST_ROOT"

    # Run tests
    test_installer_creates_lib_directory
    test_installer_copies_project_env
    test_installer_creates_worktrees_with_project_name
    test_installer_settings_json_correct
    test_installer_lib_already_exists
    test_installer_no_hardcoded_assumptions
    test_installer_idempotent

    # Cleanup
    cleanup

    # Summary
    echo ""
    echo "=================================="
    echo "Test Results"
    echo "=================================="
    echo "Total:  $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Run tests
main
