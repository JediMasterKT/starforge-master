#!/bin/bash
#
# Integration tests for Discord CI notification feature (Issue #242)
#
# Tests verify:
# 1. CI workflow has Discord notification step
# 2. Step only runs on failure
# 3. Notification uses correct webhook secret
# 4. router.sh has notify_tests_failed() function
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_pass() {
    local test_name="$1"
    echo -e "${GREEN}✓${NC} PASS: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local test_name="$1"
    local reason="$2"
    echo -e "${RED}✗${NC} FAIL: $test_name"
    echo "  Reason: $reason"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

run_test() {
    local test_name="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    echo "Running: $test_name"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: CI workflow file has Discord notification step
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_workflow_has_discord_step() {
    run_test "CI workflow has Discord notification step"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    if [ ! -f "$workflow_file" ]; then
        test_fail "Workflow file existence" "File not found: $workflow_file"
        return 1
    fi

    # Check for Discord notification step name
    if grep -q "Notify Discord on Test Failure" "$workflow_file"; then
        test_pass "Workflow has Discord notification step"
        return 0
    else
        test_fail "Workflow has Discord notification step" "Step 'Notify Discord on Test Failure' not found"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Workflow step only runs on failure
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_workflow_conditional() {
    run_test "Notification step only runs on test failure"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    # Extract the Discord notification step and check for "if: failure()"
    # We need to find the step and then check if it has the conditional
    local step_section=$(sed -n '/- name: Notify Discord on Test Failure/,/^[[:space:]]*-[[:space:]]*name:/p' "$workflow_file" | head -n -1)

    if [ -z "$step_section" ]; then
        # Try alternative: check until end of file if it's the last step
        step_section=$(sed -n '/- name: Notify Discord on Test Failure/,$p' "$workflow_file")
    fi

    if echo "$step_section" | grep -q "if:.*failure()"; then
        test_pass "Step has 'if: failure()' conditional"
        return 0
    else
        test_fail "Step conditional" "Step should have 'if: failure()' to run only on test failures"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Workflow uses GitHub secret for webhook URL
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_workflow_uses_secret() {
    run_test "Workflow uses DISCORD_WEBHOOK_STARFORGE_ALERTS secret"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    # Check if Discord step references the secret (check 50 lines for longer steps)
    if grep -A 50 "Notify Discord on Test Failure" "$workflow_file" | grep -q "secrets.DISCORD_WEBHOOK_STARFORGE_ALERTS"; then
        test_pass "Step uses DISCORD_WEBHOOK_STARFORGE_ALERTS secret"
        return 0
    else
        test_fail "Webhook secret" "Step should use \${{ secrets.DISCORD_WEBHOOK_STARFORGE_ALERTS }}"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Notification includes PR number
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notification_includes_pr_number() {
    run_test "Notification includes PR number"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    # Check if Discord step includes PR number in payload
    # Should reference github.event.pull_request.number
    if grep -A 30 "Notify Discord on Test Failure" "$workflow_file" | grep -q "github.event.pull_request.number"; then
        test_pass "Notification includes PR number"
        return 0
    else
        test_fail "PR number in notification" "Should include github.event.pull_request.number in Discord payload"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Notification uses red color (ERROR)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notification_red_color() {
    run_test "Notification uses red color for error"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    # Check for red color code (15158332 in decimal)
    if grep -A 30 "Notify Discord on Test Failure" "$workflow_file" | grep -q "15158332"; then
        test_pass "Notification uses red color (15158332)"
        return 0
    else
        test_fail "Red color" "Notification should use color code 15158332 (red) for errors"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: router.sh has notify_tests_failed() function
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_router_has_notify_tests_failed() {
    run_test "router.sh has notify_tests_failed() function"

    local router_file="$PROJECT_ROOT/templates/lib/router.sh"

    if [ ! -f "$router_file" ]; then
        test_fail "router.sh file existence" "File not found: $router_file"
        return 1
    fi

    # Check for function definition
    if grep -q "^notify_tests_failed()" "$router_file" || grep -q "^notify_tests_failed ()" "$router_file"; then
        test_pass "router.sh has notify_tests_failed() function"
        return 0
    else
        test_fail "notify_tests_failed() function" "Function not found in router.sh"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: Function accepts required parameters
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notify_tests_failed_parameters() {
    run_test "notify_tests_failed() accepts required parameters"

    local router_file="$PROJECT_ROOT/templates/lib/router.sh"

    # Source the router to check function signature
    # We'll check for parameter assignments in the function
    if grep -A 10 "^notify_tests_failed()" "$router_file" | grep -q "pr_number"; then
        test_pass "Function handles pr_number parameter"
    else
        test_fail "Function parameters" "Function should accept pr_number parameter"
        return 1
    fi

    if grep -A 10 "^notify_tests_failed()" "$router_file" | grep -q "test_name\|failed_test"; then
        test_pass "Function handles test name parameter"
    else
        test_fail "Function parameters" "Function should accept test_name parameter"
        return 1
    fi

    return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 8: Notification includes clickable CI logs link
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_notification_includes_logs_link() {
    run_test "Notification includes clickable link to CI logs"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    # Check for GitHub Actions run URL
    # Should reference github.server_url, github.repository, github.run_id
    local step_content=$(grep -A 40 "Notify Discord on Test Failure" "$workflow_file")

    if echo "$step_content" | grep -q "github.server_url" && \
       echo "$step_content" | grep -q "github.repository" && \
       echo "$step_content" | grep -q "github.run_id"; then
        test_pass "Notification includes clickable CI logs link"
        return 0
    else
        test_fail "CI logs link" "Should include github.server_url, github.repository, github.run_id for clickable link"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 9: Error message shown in code block
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_error_in_code_block() {
    run_test "Error message displayed in Discord code block"

    local workflow_file="$PROJECT_ROOT/.github/workflows/pr-validation.yml"

    # Check for triple backticks in Discord message (escaped with backslashes in YAML strings)
    # Looking for \`\`\` pattern
    if grep -A 40 "Notify Discord on Test Failure" "$workflow_file" | grep '\\`\\`\\`'; then
        test_pass "Error message uses code block formatting"
        return 0
    else
        test_fail "Code block formatting" "Error message should be wrapped in code blocks"
        return 1
    fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 10: Existing tests still pass
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_no_breaking_changes() {
    run_test "No breaking changes to existing functionality"

    local router_file="$PROJECT_ROOT/templates/lib/router.sh"

    # Verify existing functions still present
    if ! grep -q "route_trigger_to_queue()" "$router_file"; then
        test_fail "Breaking changes" "route_trigger_to_queue() function removed or renamed"
        return 1
    fi

    # Verify file is valid bash
    if ! bash -n "$router_file" 2>/dev/null; then
        test_fail "Syntax validation" "router.sh has bash syntax errors"
        return 1
    fi

    test_pass "No breaking changes detected"
    return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run all tests
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "=========================================="
echo "Discord CI Notifications Integration Tests"
echo "Issue #242"
echo "=========================================="

# Run tests
test_workflow_has_discord_step
test_workflow_conditional
test_workflow_uses_secret
test_notification_includes_pr_number
test_notification_red_color
test_notification_includes_logs_link
test_error_in_code_block
test_router_has_notify_tests_failed
test_notify_tests_failed_parameters
test_no_breaking_changes

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
else
    echo "Tests failed: $TESTS_FAILED"
fi
echo "=========================================="

# Exit with failure if any tests failed
if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
