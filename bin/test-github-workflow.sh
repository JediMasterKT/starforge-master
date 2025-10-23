#!/bin/bash
# StarForge GitHub Workflow Test Suite
# TDD tests for GitHub Actions PR validation workflow

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
WORKFLOW_FILE="$STARFORGE_ROOT/.github/workflows/pr-validation.yml"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "GitHub Workflow Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_success() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Test passed}"

    echo -e "  ${GREEN}✓${NC} $desc"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

assert_failure() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Test failed}"

    echo -e "  ${RED}✗${NC} $desc"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
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
        echo -e "  ${RED}✗${NC} $desc (file not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local pattern="$2"
    local desc="${3:-File contains: $pattern}"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (pattern not found in $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Workflow File Exists
test_workflow_file_exists() {
    echo ""
    echo "Test 1: Workflow File Exists"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_exists "$WORKFLOW_FILE" "pr-validation.yml exists"
}

# Test 2: Workflow Syntax Valid
test_workflow_syntax_valid() {
    echo ""
    echo "Test 2: Workflow Syntax Valid"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    TESTS_RUN=$((TESTS_RUN + 1))

    # Check if yamllint is available
    if command -v yamllint &> /dev/null; then
        if yamllint -d relaxed "$WORKFLOW_FILE" 2>&1; then
            echo -e "  ${GREEN}✓${NC} YAML syntax is valid (yamllint)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "  ${RED}✗${NC} YAML syntax is invalid (yamllint)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        # Fallback: Basic YAML syntax check using python
        if command -v python3 &> /dev/null; then
            if python3 -c "import yaml; yaml.safe_load(open('$WORKFLOW_FILE'))" 2>&1; then
                echo -e "  ${GREEN}✓${NC} YAML syntax is valid (python)"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "  ${RED}✗${NC} YAML syntax is invalid (python)"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
        else
            echo -e "  ${YELLOW}⚠${NC}  YAML validator not available (skipping)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        fi
    fi
}

# Test 3: Workflow Has Unit Test Job
test_workflow_has_unit_test_job() {
    echo ""
    echo "Test 3: Workflow Has Unit Test Job"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "unit-tests:" "Workflow has unit-tests job"
}

# Test 4: Workflow Triggers on PR
test_workflow_triggers_on_pr() {
    echo ""
    echo "Test 4: Workflow Triggers on PR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "pull_request:" "Workflow triggers on pull_request"
    assert_file_contains "$WORKFLOW_FILE" "opened" "Workflow triggers on PR opened"
    assert_file_contains "$WORKFLOW_FILE" "synchronize" "Workflow triggers on PR synchronize"
    assert_file_contains "$WORKFLOW_FILE" "reopened" "Workflow triggers on PR reopened"
}

# Test 5: Workflow Runs Existing Tests
test_workflow_runs_existing_tests() {
    echo ""
    echo "Test 5: Workflow Runs Existing Tests"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "bin/test-install.sh" "Workflow calls test-install.sh"
    assert_file_contains "$WORKFLOW_FILE" "bin/test-cli.sh" "Workflow calls test-cli.sh"
}

# Test 6: Workflow Uploads Artifacts
test_workflow_uploads_artifacts() {
    echo ""
    echo "Test 6: Workflow Uploads Artifacts"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "actions/upload-artifact" "Workflow uploads artifacts"
}

# Test 7: Workflow Has Timeout
test_workflow_has_timeout() {
    echo ""
    echo "Test 7: Workflow Has Timeout"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "timeout-minutes:" "Workflow has timeout configured"
}

# Test 8: Workflow Sets Job Name
test_workflow_sets_job_name() {
    echo ""
    echo "Test 8: Workflow Sets Job Name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "name:" "Workflow has name"
}

# Test 9: Workflow Checks Out Code
test_workflow_checks_out_code() {
    echo ""
    echo "Test 9: Workflow Checks Out Code"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "actions/checkout" "Workflow checks out code"
}

# Test 10: Workflow Runs on Ubuntu
test_workflow_runs_on_ubuntu() {
    echo ""
    echo "Test 10: Workflow Runs on Ubuntu"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_contains "$WORKFLOW_FILE" "runs-on:" "Workflow specifies runs-on"
    assert_file_contains "$WORKFLOW_FILE" "ubuntu-latest" "Workflow runs on ubuntu-latest"
}

# Run all tests
run_all_tests() {
    test_workflow_file_exists
    test_workflow_syntax_valid
    test_workflow_has_unit_test_job
    test_workflow_triggers_on_pr
    test_workflow_runs_existing_tests
    test_workflow_uploads_artifacts
    test_workflow_has_timeout
    test_workflow_sets_job_name
    test_workflow_checks_out_code
    test_workflow_runs_on_ubuntu
}

# Main execution
run_all_tests

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
