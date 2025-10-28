#!/usr/local/bin/bash
# Integration Test: Doctor command permissions validation
# Task 2.6: Permissions Validation for Phase 2
#
# Tests the complete doctor command flow with actual bin/starforge

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup test environment
setup_test_env() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Create minimal .claude structure
    mkdir -p .claude/{hooks,scripts,lib,bin}

    # Create test files
    touch .claude/hooks/stop.py
    touch .claude/scripts/test-script.sh
    touch .claude/lib/test-lib.sh
    touch .claude/bin/test-bin.sh

    # Set correct permissions initially
    chmod +x .claude/hooks/stop.py
    chmod +x .claude/scripts/test-script.sh
    chmod +x .claude/lib/test-lib.sh
    chmod +x .claude/bin/test-bin.sh

    # Copy starforge CLI to test directory
    cp "$PROJECT_ROOT/bin/starforge" ./starforge
    chmod +x ./starforge
}

# Teardown test environment
teardown_test_env() {
    cd - > /dev/null
    rm -rf "$TEST_DIR"
}

# Test helper
run_test() {
    local test_name="$1"
    ((TESTS_RUN++))

    if "$test_name"; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test: doctor command succeeds with correct permissions
test_doctor_success_correct_permissions() {
    setup_test_env

    # Run doctor command
    output=$(./starforge doctor 2>&1)
    exit_code=$?

    # Check exit code
    if [ $exit_code -eq 0 ]; then
        # Check output contains success message
        if echo "$output" | grep -q "Permissions correct"; then
            teardown_test_env
            return 0
        fi
    fi

    echo "  Doctor command did not succeed with correct permissions"
    echo "  Exit code: $exit_code"
    echo "  Output: $output"
    teardown_test_env
    return 1
}

# Test: doctor command detects stop.py without execute permission
test_doctor_detects_stop_py() {
    setup_test_env

    # Remove execute permission from stop.py
    chmod -x .claude/hooks/stop.py

    # Run doctor command
    output=$(./starforge doctor 2>&1)
    exit_code=$?

    # Should fail (exit code 1)
    if [ $exit_code -ne 0 ]; then
        # Should mention stop.py
        if echo "$output" | grep -q "stop.py"; then
            teardown_test_env
            return 0
        fi
    fi

    echo "  Doctor command did not detect stop.py without execute permission"
    echo "  Exit code: $exit_code"
    echo "  Output: $output"
    teardown_test_env
    return 1
}

# Test: doctor command lists all non-executable files
test_doctor_lists_all_non_executable() {
    setup_test_env

    # Remove execute permissions from multiple files
    chmod -x .claude/hooks/stop.py
    chmod -x .claude/scripts/test-script.sh

    # Run doctor command
    output=$(./starforge doctor 2>&1)
    exit_code=$?

    # Should fail (exit code 1)
    if [ $exit_code -ne 0 ]; then
        # Should mention both files
        if echo "$output" | grep -q "stop.py" && echo "$output" | grep -q "test-script.sh"; then
            teardown_test_env
            return 0
        fi
    fi

    echo "  Doctor command did not list all non-executable files"
    echo "  Exit code: $exit_code"
    echo "  Output: $output"
    teardown_test_env
    return 1
}

# Test: doctor command provides fix instructions
test_doctor_provides_fix_instructions() {
    setup_test_env

    # Remove execute permission
    chmod -x .claude/hooks/stop.py

    # Run doctor command
    output=$(./starforge doctor 2>&1)

    # Should provide chmod +x fix
    if echo "$output" | grep -q "chmod +x"; then
        teardown_test_env
        return 0
    fi

    echo "  Doctor command did not provide fix instructions"
    echo "  Output: $output"
    teardown_test_env
    return 1
}

# Run all tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Integration Test: Doctor Command Permissions (Task 2.6)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

run_test test_doctor_success_correct_permissions
run_test test_doctor_detects_stop_py
run_test test_doctor_lists_all_non_executable
run_test test_doctor_provides_fix_instructions

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Results:"
echo "  Total: $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo "Note: Tests expected to fail until check_permissions() function is implemented"
    exit 1
else
    echo -e "  ${GREEN}All tests passed!${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
