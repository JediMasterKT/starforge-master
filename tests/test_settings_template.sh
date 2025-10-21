#!/bin/bash
# Test suite for settings.json template placeholder functionality
# Following TDD - these tests should FAIL initially

set -e

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to assert
assert_exit_code() {
    local expected=$1
    local actual=$?
    local test_name=$2

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ $actual -eq $expected ]; then
        echo -e "${GREEN}✓${NC} PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} FAIL: $test_name (expected exit code $expected, got $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test: settings.json template should have {{PROJECT_DIR}} placeholder
test_settings_template_has_placeholders() {
    echo ""
    echo "Test 1: Template should contain {{PROJECT_DIR}} placeholder"

    local template_file="../templates/settings/settings.json"

    # Check if placeholder exists
    grep -q "{{PROJECT_DIR}}" "$template_file"
    assert_exit_code 0 "Template contains {{PROJECT_DIR}} placeholder"

    # Check that hard-coded absolute path does NOT exist (not including ~/ patterns)
    if grep -F "/Users/" "$template_file" | grep -F "empowerai" | grep -v "~/" | grep -v "{{PROJECT_DIR}}" > /dev/null 2>&1; then
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} FAIL: Template contains hard-coded absolute path"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} PASS: Template does NOT contain hard-coded absolute path"
    fi

    # Verify all 4 occurrences are replaced (count placeholder occurrences)
    local placeholder_count=$(grep -F "{{PROJECT_DIR}}" "$template_file" | wc -l | tr -d ' ')
    if [ "$placeholder_count" -eq 4 ]; then
        echo -e "${GREEN}✓${NC} PASS: Found all 4 placeholder occurrences"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} FAIL: Expected 4 placeholders, found $placeholder_count"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
}

# Test: installer should replace placeholders correctly
test_installer_replaces_placeholders() {
    echo ""
    echo "Test 2: Installer should replace placeholders with actual paths"

    # Create temporary test directory
    local test_dir="/tmp/starforge-test-$$"
    mkdir -p "$test_dir"

    # Copy templates to test location
    cp -r ../templates "$test_dir/"

    # Simulate what install.sh does
    local target_dir="$test_dir/test-project"
    local claude_dir="$target_dir/.claude"
    mkdir -p "$claude_dir"

    # Perform the replacement (this is what we'll add to install.sh)
    sed "s|{{PROJECT_DIR}}|$target_dir|g" "$test_dir/templates/settings/settings.json" > "$claude_dir/settings.json"

    # Verify placeholder is replaced
    if grep -q "{{PROJECT_DIR}}" "$claude_dir/settings.json"; then
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} FAIL: Installed settings.json still contains placeholder"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} PASS: Installed settings.json does NOT contain placeholder"
    fi

    # Verify actual path is present
    if grep -q "$target_dir" "$claude_dir/settings.json"; then
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} PASS: Installed settings.json contains actual project path"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} FAIL: Installed settings.json missing actual project path"
    fi

    # Verify all 4 occurrences were replaced
    local path_count=$(grep -F "$target_dir" "$claude_dir/settings.json" | wc -l | tr -d ' ')
    if [ "$path_count" -eq 4 ]; then
        echo -e "${GREEN}✓${NC} PASS: All 4 paths correctly replaced"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo -e "${RED}✗${NC} FAIL: Expected 4 path replacements, found $path_count"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
    fi

    # Cleanup
    rm -rf "$test_dir"
}

# Test: performance - replacement should be fast (<10ms)
test_performance() {
    echo ""
    echo "Test 3: Placeholder replacement performance (<10ms)"

    local start_time=$(date +%s%N)

    # Perform replacement
    local test_content=$(sed "s|{{PROJECT_DIR}}|/some/test/path|g" "../templates/settings/settings.json")

    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ $duration -lt 10 ]; then
        echo -e "${GREEN}✓${NC} PASS: Replacement completed in ${duration}ms (< 10ms target)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} FAIL: Replacement took ${duration}ms (> 10ms target)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: edge case - multiple placeholders in same line
test_multiple_placeholders_in_line() {
    echo ""
    echo "Test 4: Handle multiple placeholders in same line"

    # Create test content with multiple placeholders in one line
    local test_line='{"path": "{{PROJECT_DIR}}/foo", "other": "{{PROJECT_DIR}}/bar"}'
    local result=$(echo "$test_line" | sed "s|{{PROJECT_DIR}}|/test/path|g")

    TESTS_RUN=$((TESTS_RUN + 1))

    # Check both were replaced
    if echo "$result" | grep -q "/test/path/foo" && echo "$result" | grep -q "/test/path/bar"; then
        echo -e "${GREEN}✓${NC} PASS: Multiple placeholders in same line replaced correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} FAIL: Not all placeholders in line were replaced"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test: edge case - paths with special characters
test_paths_with_special_chars() {
    echo ""
    echo "Test 5: Handle paths with special characters"

    local special_path="/Users/test user/my-project (v2)"
    local test_content='{"path": "{{PROJECT_DIR}}"}'
    local result=$(echo "$test_content" | sed "s|{{PROJECT_DIR}}|$special_path|g")

    TESTS_RUN=$((TESTS_RUN + 1))

    if echo "$result" | grep -q "$special_path"; then
        echo -e "${GREEN}✓${NC} PASS: Special characters in path handled correctly"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} FAIL: Special characters not handled properly"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Run all tests
echo "=========================================="
echo "Running Settings Template Test Suite"
echo "=========================================="

# Change to tests directory for relative path resolution
cd "$(dirname "$0")"

test_settings_template_has_placeholders
test_installer_replaces_placeholders
test_performance
test_multiple_placeholders_in_line
test_paths_with_special_chars

# Summary
echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
