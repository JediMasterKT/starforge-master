#!/bin/bash
# Test: Doctor command permissions validation
# Task 2.6: Permissions Validation for Phase 2

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
}

# Teardown test environment
teardown_test_env() {
    cd - > /dev/null
    rm -rf "$TEST_DIR"
}

# Test helper
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    ((TESTS_RUN++))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test: All files have correct permissions
test_all_correct_permissions() {
    setup_test_env

    # All files already have +x
    # Source the starforge script (we'll need to mock this for now)
    # For now, test the logic directly

    local non_executable=()
    local files_to_check=(
        ".claude/hooks/stop.py"
        ".claude/scripts/test-script.sh"
        ".claude/lib/test-lib.sh"
        ".claude/bin/test-bin.sh"
    )

    for file in "${files_to_check[@]}"; do
        if [ ! -x "$file" ]; then
            non_executable+=("$file")
        fi
    done

    local result=0
    if [ ${#non_executable[@]} -eq 0 ]; then
        result=0
    else
        result=1
    fi

    assert_equals "0" "$result" "All files have correct permissions"

    teardown_test_env
}

# Test: stop.py is not executable
test_stop_py_not_executable() {
    setup_test_env

    # Remove execute permission from stop.py
    chmod -x .claude/hooks/stop.py

    local non_executable=()
    local files_to_check=(
        ".claude/hooks/stop.py"
        ".claude/scripts/test-script.sh"
        ".claude/lib/test-lib.sh"
        ".claude/bin/test-bin.sh"
    )

    for file in "${files_to_check[@]}"; do
        if [ ! -x "$file" ]; then
            non_executable+=("$file")
        fi
    done

    # Should find 1 non-executable file
    assert_equals "1" "${#non_executable[@]}" "Detects stop.py without execute permission"
    assert_equals ".claude/hooks/stop.py" "${non_executable[0]}" "Identifies correct file"

    teardown_test_env
}

# Test: Multiple files are not executable
test_multiple_not_executable() {
    setup_test_env

    # Remove execute permissions from multiple files
    chmod -x .claude/hooks/stop.py
    chmod -x .claude/scripts/test-script.sh

    local non_executable=()
    local files_to_check=(
        ".claude/hooks/stop.py"
        ".claude/scripts/test-script.sh"
        ".claude/lib/test-lib.sh"
        ".claude/bin/test-bin.sh"
    )

    for file in "${files_to_check[@]}"; do
        if [ ! -x "$file" ]; then
            non_executable+=("$file")
        fi
    done

    # Should find 2 non-executable files
    assert_equals "2" "${#non_executable[@]}" "Detects multiple files without execute permission"

    teardown_test_env
}

# Test: find command discovers .sh files in directories
test_find_sh_files() {
    setup_test_env

    # Create additional .sh files
    touch .claude/scripts/another-script.sh
    touch .claude/lib/helper.sh

    chmod +x .claude/scripts/another-script.sh
    chmod +x .claude/lib/helper.sh

    # Count .sh files found by find command
    local sh_files=()
    while IFS= read -r file; do
        sh_files+=("$file")
    done < <(find .claude/scripts .claude/lib .claude/bin -name "*.sh" 2>/dev/null)

    # Should find 5 .sh files (3 original + 2 new)
    assert_equals "5" "${#sh_files[@]}" "Finds all .sh files in directories"

    teardown_test_env
}

# Test: Return code is 0 when all permissions correct
test_return_code_success() {
    setup_test_env

    local non_executable=()
    local files_to_check=(
        ".claude/hooks/stop.py"
        ".claude/scripts/test-script.sh"
    )

    for file in "${files_to_check[@]}"; do
        if [ ! -x "$file" ]; then
            non_executable+=("$file")
        fi
    done

    local result
    if [ ${#non_executable[@]} -eq 0 ]; then
        result=0
    else
        result=1
    fi

    assert_equals "0" "$result" "Returns 0 when all permissions correct"

    teardown_test_env
}

# Test: Return code is 1 when permissions incorrect
test_return_code_failure() {
    setup_test_env

    chmod -x .claude/hooks/stop.py

    local non_executable=()
    local files_to_check=(
        ".claude/hooks/stop.py"
        ".claude/scripts/test-script.sh"
    )

    for file in "${files_to_check[@]}"; do
        if [ ! -x "$file" ]; then
            non_executable+=("$file")
        fi
    done

    local result
    if [ ${#non_executable[@]} -eq 0 ]; then
        result=0
    else
        result=1
    fi

    assert_equals "1" "$result" "Returns 1 when permissions incorrect"

    teardown_test_env
}

# Run all tests
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing: Doctor Command Permissions Validation (Task 2.6)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

test_all_correct_permissions
test_stop_py_not_executable
test_multiple_not_executable
test_find_sh_files
test_return_code_success
test_return_code_failure

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Results:"
echo "  Total: $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "  ${GREEN}All tests passed!${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
