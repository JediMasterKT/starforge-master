#!/usr/bin/env bash
#
# test_ci_notification_flow.sh - Integration test for CI notification flow
#
# Tests the complete notification flow:
# 1. ci-notify-failure.sh
# 2. notify_tests_failed (router.sh)
# 3. Function composition and error handling
#

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
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
    echo "Setting up integration test environment..."

    # Source libraries
    source templates/lib/discord-notify.sh
    source templates/lib/router.sh

    # Set empty webhook for testing (notifications won't actually send)
    export DISCORD_WEBHOOK_STARFORGE_ALERTS=""

    echo "✅ Libraries loaded"
}

# Test 1: notify_tests_failed function exists
test_notify_tests_failed_exists() {
    type notify_tests_failed >/dev/null 2>&1
}

# Test 2: notify_tests_failed accepts required parameters
test_notify_tests_failed_accepts_params() {
    # Should succeed (exit 0) even with empty webhook
    notify_tests_failed "123" "test-router" "Error message" "https://logs.example.com" >/dev/null 2>&1
}

# Test 3: notify_tests_failed requires PR number
test_notify_tests_failed_requires_pr() {
    # Should fail without PR number
    ! notify_tests_failed "" "test-router" "Error" "https://logs.example.com" 2>/dev/null
}

# Test 4: notify_tests_failed handles missing test name
test_notify_tests_failed_handles_missing_test_name() {
    # Should succeed with missing test name (uses default)
    notify_tests_failed "123" "" "Error" "https://logs.example.com" >/dev/null 2>&1
}

# Test 5: notify_tests_failed handles missing error message
test_notify_tests_failed_handles_missing_error() {
    # Should succeed with missing error (uses default)
    notify_tests_failed "123" "test-router" "" "https://logs.example.com" >/dev/null 2>&1
}

# Test 6: ci-notify-failure.sh exists and is executable
test_ci_script_exists() {
    [ -f "templates/scripts/ci-notify-failure.sh" ] && \
    [ -x "templates/scripts/ci-notify-failure.sh" ]
}

# Test 7: ci-notify-failure.sh calls notify_tests_failed
test_ci_script_calls_notify() {
    # Call the script and verify it doesn't crash
    templates/scripts/ci-notify-failure.sh \
        "555" \
        "test-sandbox" \
        "Integration test error" \
        "https://ci.example.com/run/555" \
        >/dev/null 2>&1
}

# Test 8: ci-notify-failure.sh requires PR number
test_ci_script_requires_pr() {
    # Should fail without PR number
    ! templates/scripts/ci-notify-failure.sh 2>/dev/null
}

# Test 9: Integration with actual webhook URL
test_with_webhook_url() {
    # Set a test webhook URL
    export DISCORD_WEBHOOK_STARFORGE_ALERTS="https://discord.com/api/webhooks/test/fake"

    # Call notify_tests_failed (won't actually send - fake URL)
    # Just verify it doesn't crash
    notify_tests_failed "999" "test-integration" "Test error" "https://logs.example.com" >/dev/null 2>&1

    # Reset webhook
    export DISCORD_WEBHOOK_STARFORGE_ALERTS=""
}

# Test 10: Long error messages are handled
test_long_error_messages() {
    # Create 1000-character error message
    local long_error=$(printf '%0.s#' {1..1000})

    # Should handle long errors without crashing
    notify_tests_failed "777" "test-router" "$long_error" "https://logs.example.com" >/dev/null 2>&1
}

# Main test execution
main() {
    echo "========================================="
    echo "CI Notification Flow Integration Tests"
    echo "========================================="

    setup

    # Run tests
    run_test "notify_tests_failed function exists" "test_notify_tests_failed_exists"
    run_test "notify_tests_failed accepts parameters" "test_notify_tests_failed_accepts_params"
    run_test "notify_tests_failed requires PR number" "test_notify_tests_failed_requires_pr"
    run_test "notify_tests_failed handles missing test name" "test_notify_tests_failed_handles_missing_test_name"
    run_test "notify_tests_failed handles missing error" "test_notify_tests_failed_handles_missing_error"
    run_test "ci-notify-failure.sh exists" "test_ci_script_exists"
    run_test "ci-notify-failure.sh calls notify" "test_ci_script_calls_notify"
    run_test "ci-notify-failure.sh requires PR" "test_ci_script_requires_pr"
    run_test "Integration with webhook URL" "test_with_webhook_url"
    run_test "Long error messages handled" "test_long_error_messages"

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
        echo "All integration tests passed! ✅"
        exit 0
    fi
}

# Run main
main "$@"
