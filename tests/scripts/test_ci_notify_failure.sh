#!/usr/bin/env bash
#
# test_ci_notify_failure.sh - Unit tests for ci-notify-failure.sh
#
# Tests the CI notification helper script in isolation.
#

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name=$1
    local test_command=$2

    echo ""
    echo "Running: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$test_command"; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup() {
    echo "Setting up test environment..."

    # Create temp directory for test files
    TEST_DIR=$(mktemp -d)
    export TEST_DIR

    # Mock Discord webhook (don't send real notifications)
    export DISCORD_WEBHOOK_STARFORGE_ALERTS=""

    # Copy templates to test directory
    cp -r templates "$TEST_DIR/"

    echo "Test directory: $TEST_DIR"
}

# Cleanup test environment
cleanup() {
    echo ""
    echo "Cleaning up test environment..."
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Test 1: Script exists and is executable
test_script_exists() {
    [ -f "templates/scripts/ci-notify-failure.sh" ] && \
    [ -x "templates/scripts/ci-notify-failure.sh" ]
}

# Test 2: Script requires PR number
test_requires_pr_number() {
    # Should fail with exit code 1 when no PR number provided
    ! templates/scripts/ci-notify-failure.sh 2>/dev/null
}

# Test 3: Script accepts all arguments
test_accepts_arguments() {
    # Should succeed (exit 0) with valid arguments
    # Even with empty webhook, it should not fail (notifications optional)
    templates/scripts/ci-notify-failure.sh \
        "123" \
        "test-router" \
        "Error message here" \
        "https://github.com/user/repo/actions/runs/123" \
        >/dev/null 2>&1
}

# Test 4: Script handles missing router.sh gracefully
test_handles_missing_router() {
    # Create a copy of the script in isolation
    local isolated_script="$TEST_DIR/ci-notify-failure-isolated.sh"
    cp templates/scripts/ci-notify-failure.sh "$isolated_script"
    chmod +x "$isolated_script"

    # Run without router.sh available - should fail with clear error
    if "$isolated_script" "123" 2>&1 | grep -q "router.sh not found"; then
        return 0
    else
        return 1
    fi
}

# Test 5: Script outputs success message
test_outputs_success_message() {
    # With empty webhook, should output success message
    local output=$(templates/scripts/ci-notify-failure.sh \
        "123" \
        "test-router" \
        "Error message" \
        "https://logs.example.com" \
        2>&1)

    echo "$output" | grep -q "notification sent\|notification skipped"
}

# Main test execution
main() {
    echo "========================================="
    echo "CI Notify Failure Script Tests"
    echo "========================================="

    setup

    # Run tests
    run_test "Script exists and is executable" "test_script_exists"
    run_test "Script requires PR number" "test_requires_pr_number"
    run_test "Script accepts all arguments" "test_accepts_arguments"
    run_test "Script handles missing router.sh" "test_handles_missing_router"
    run_test "Script outputs success message" "test_outputs_success_message"

    # Print summary
    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo "All tests passed! ✅"
        exit 0
    fi
}

# Run main
main "$@"
