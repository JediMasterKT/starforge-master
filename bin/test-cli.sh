#!/bin/bash
# StarForge CLI Test Suite
# TDD tests for starforge command-line interface

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
STARFORGE_CLI="$STARFORGE_ROOT/bin/starforge"
TEST_DIR="$STARFORGE_ROOT/.tmp/cli-tests"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge CLI Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_command_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local cmd="$1"
    local desc="${2:-Command exists: $cmd}"

    if [ -x "$cmd" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (not executable)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_output_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output="$1"
    local pattern="$2"
    local desc="${3:-Output contains: $pattern}"

    if echo "$output" | grep -q "$pattern"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_exit_code() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local exit_code="$1"
    local expected="$2"
    local desc="${3:-Exit code is $expected}"

    if [ "$exit_code" -eq "$expected" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (got $exit_code, expected $expected)"
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

# Test 1: CLI Executable
test_cli_executable() {
    echo ""
    echo "Test 1: CLI Executable"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_command_exists "$STARFORGE_CLI" "starforge CLI is executable"
}

# Test 2: Help Command
test_help_command() {
    echo ""
    echo "Test 2: Help Command"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local output=$("$STARFORGE_CLI" help 2>&1)
    local exit_code=$?

    assert_exit_code "$exit_code" 0 "help command exits successfully"
    assert_output_contains "$output" "StarForge - AI Development Team" "help shows title"
    assert_output_contains "$output" "starforge install" "help shows install command"
    assert_output_contains "$output" "starforge analyze" "help shows analyze command"
    assert_output_contains "$output" "starforge use" "help shows use command"
    assert_output_contains "$output" "starforge status" "help shows status command"
    assert_output_contains "$output" "starforge monitor" "help shows monitor command"
}

# Test 3: Help Aliases
test_help_aliases() {
    echo ""
    echo "Test 3: Help Aliases"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Test --help
    local output=$("$STARFORGE_CLI" --help 2>&1)
    local exit_code=$?
    assert_exit_code "$exit_code" 0 "--help works"
    assert_output_contains "$output" "StarForge" "--help shows help"

    # Test -h
    output=$("$STARFORGE_CLI" -h 2>&1)
    exit_code=$?
    assert_exit_code "$exit_code" 0 "-h works"
    assert_output_contains "$output" "StarForge" "-h shows help"

    # Test no arguments (defaults to help)
    output=$("$STARFORGE_CLI" 2>&1)
    exit_code=$?
    assert_exit_code "$exit_code" 0 "no arguments defaults to help"
    assert_output_contains "$output" "StarForge" "no args shows help"
}

# Test 4: Unknown Command
test_unknown_command() {
    echo ""
    echo "Test 4: Unknown Command"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local tmpfile=$(mktemp)
    set +e
    "$STARFORGE_CLI" foobar > "$tmpfile" 2>&1
    local exit_code=$?
    set -e
    local output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    assert_exit_code "$exit_code" 1 "unknown command exits with error"
    assert_output_contains "$output" "Unknown command" "unknown command shows error"
    assert_output_contains "$output" "starforge help" "unknown command suggests help"
}

# Test 5: Status Without Installation
test_status_without_install() {
    echo ""
    echo "Test 5: Status Without Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cleanup
    mkdir -p "$TEST_DIR/no-starforge"
    cd "$TEST_DIR/no-starforge"

    local tmpfile=$(mktemp)
    set +e
    "$STARFORGE_CLI" status > "$tmpfile" 2>&1
    local exit_code=$?
    set -e
    local output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    assert_exit_code "$exit_code" 1 "status fails without .claude/"
    assert_output_contains "$output" "StarForge not installed" "status shows error message"
    assert_output_contains "$output" "starforge install" "status suggests installation"

    cd - > /dev/null
}

# Test 6: Use Command Without Agent
test_use_without_agent() {
    echo ""
    echo "Test 6: Use Command Without Agent"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local tmpfile=$(mktemp)
    set +e
    "$STARFORGE_CLI" use > "$tmpfile" 2>&1
    local exit_code=$?
    set -e
    local output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    assert_exit_code "$exit_code" 1 "use without agent exits with error"
    assert_output_contains "$output" "Please specify an agent" "use shows error"
    assert_output_contains "$output" "orchestrator" "use lists available agents"
    assert_output_contains "$output" "senior-engineer" "use lists senior-engineer"
}

# Test 7: Use Command With Unknown Agent
test_use_unknown_agent() {
    echo ""
    echo "Test 7: Use Command With Unknown Agent"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Create a test project with StarForge installed
    cleanup
    mkdir -p "$TEST_DIR/test-project"
    cd "$TEST_DIR/test-project"
    git init -q
    git config user.name "Test"
    git config user.email "test@test.com"
    echo "test" > README.md
    git add .
    git commit -q -m "init"

    # Install StarForge
    echo -e "3\n1\nn" | "$STARFORGE_ROOT/bin/install.sh" > /dev/null 2>&1

    local tmpfile=$(mktemp)
    set +e
    "$STARFORGE_CLI" use unknown-agent > "$tmpfile" 2>&1
    local exit_code=$?
    set -e
    local output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    assert_exit_code "$exit_code" 1 "use with unknown agent exits with error"
    assert_output_contains "$output" "Unknown agent" "use shows unknown agent error"

    cd - > /dev/null
}

# Test 8: Status With Installation
test_status_with_install() {
    echo ""
    echo "Test 8: Status With Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Reuse project from test 7
    cd "$TEST_DIR/test-project"

    local output=$("$STARFORGE_CLI" status 2>&1)
    local exit_code=$?

    assert_exit_code "$exit_code" 0 "status succeeds with .claude/"
    assert_output_contains "$output" "StarForge Agent Status" "status shows title"
    assert_output_contains "$output" "WORKTREES" "status shows worktrees section"

    cd - > /dev/null
}

# Test 9: Agent Name Normalization
test_agent_name_normalization() {
    echo ""
    echo "Test 9: Agent Name Normalization"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "$TEST_DIR/test-project"

    # Test various name formats (without actually invoking Claude)
    # We'll just check that the command recognizes the agent
    local agents=("orchestrator" "senior-engineer" "junior-engineer" "qa-engineer" "tpm-agent")

    for agent in "${agents[@]}"; do
        # The command will fail because Claude CLI isn't mocked, but it should recognize the agent
        set +e
        local output=$("$STARFORGE_CLI" use "$agent" 2>&1)
        set -e

        TESTS_RUN=$((TESTS_RUN + 1))
        if echo "$output" | grep -q "Invoking" || echo "$output" | grep -q "Opening Claude"; then
            echo -e "  ${GREEN}✓${NC} Agent recognized: $agent"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "  ${RED}✗${NC} Agent not recognized: $agent"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done

    cd - > /dev/null
}

# Test 10: Monitor Without Installation
test_monitor_without_install() {
    echo ""
    echo "Test 10: Monitor Without Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cleanup
    mkdir -p "$TEST_DIR/no-starforge-2"
    cd "$TEST_DIR/no-starforge-2"

    local tmpfile=$(mktemp)
    set +e
    "$STARFORGE_CLI" monitor > "$tmpfile" 2>&1
    local exit_code=$?
    set -e
    local output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    assert_exit_code "$exit_code" 1 "monitor fails without .claude/"
    assert_output_contains "$output" "StarForge not installed" "monitor shows error"

    cd - > /dev/null
}

# Test 11: Analyze Without Installation
test_analyze_without_install() {
    echo ""
    echo "Test 11: Analyze Without Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "$TEST_DIR/no-starforge-2"

    local tmpfile=$(mktemp)
    set +e
    "$STARFORGE_CLI" analyze > "$tmpfile" 2>&1
    local exit_code=$?
    set -e
    local output=$(cat "$tmpfile")
    rm -f "$tmpfile"

    assert_exit_code "$exit_code" 1 "analyze fails without .claude/"
    assert_output_contains "$output" "StarForge not installed" "analyze shows error"

    cd - > /dev/null
}

# Run all tests
run_all_tests() {
    test_cli_executable
    test_help_command
    test_help_aliases
    test_unknown_command
    test_status_without_install
    test_use_without_agent
    test_use_unknown_agent
    test_status_with_install
    test_agent_name_normalization
    test_monitor_without_install
    test_analyze_without_install
}

# Main execution
run_all_tests

# Cleanup
cleanup

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total tests:  $TESTS_RUN"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
else
    echo -e "Failed:       $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo ""
    exit 1
fi
