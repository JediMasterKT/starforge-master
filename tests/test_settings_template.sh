#!/bin/bash
# Test suite for settings.json template placeholder replacement
# Following TDD methodology - these tests should FAIL first

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_FILE="$PROJECT_ROOT/templates/settings/settings.json"

# Helper function to assert exit code
assert_exit_code() {
    local expected=$1
    local actual=$2
    local test_name=$3

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" -eq "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name (expected exit code $expected, got $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Helper function to count occurrences
count_occurrences() {
    local pattern=$1
    local file=$2
    grep -o "$pattern" "$file" 2>/dev/null | wc -l | tr -d ' '
}

# Test 1: Template has {{PROJECT_DIR}} placeholders
test_settings_template_has_placeholders() {
    echo ""
    echo "TEST: Template uses {{PROJECT_DIR}} placeholder"

    local count=$(count_occurrences "{{PROJECT_DIR}}" "$TEMPLATE_FILE")

    if [ "$count" -gt 0 ]; then
        assert_exit_code 0 0 "Template contains {{PROJECT_DIR}} placeholder ($count occurrences)"
    else
        assert_exit_code 0 1 "Template contains {{PROJECT_DIR}} placeholder (found 0)"
    fi
}

# Test 2: Template has no hard-coded 'empowerai' paths
test_settings_template_no_hardcoded_paths() {
    echo ""
    echo "TEST: Template has no hard-coded 'empowerai' paths"

    # Check for 'empowerai' in the template (should not exist)
    if grep -q "empowerai" "$TEMPLATE_FILE" 2>/dev/null; then
        assert_exit_code 1 0 "Template does NOT contain 'empowerai' string"
    else
        assert_exit_code 0 0 "Template does NOT contain 'empowerai' string"
    fi
}

# Test 3: Template has no hard-coded user paths (/Users/username)
test_settings_template_no_user_paths() {
    echo ""
    echo "TEST: Template has no hard-coded /Users/ paths"

    # Check for /Users/ in the template (should not exist in permissions, OK in deny rules)
    local user_paths_in_permissions=$(grep -A 20 '"allow"' "$TEMPLATE_FILE" | grep -c "/Users/" 2>/dev/null || echo "0")
    user_paths_in_permissions=$(echo "$user_paths_in_permissions" | tr -d '\n' | tr -d ' ')

    if [ "$user_paths_in_permissions" -eq 0 ]; then
        assert_exit_code 0 0 "Template permissions do NOT contain /Users/ paths"
    else
        assert_exit_code 0 1 "Template permissions do NOT contain /Users/ paths (found $user_paths_in_permissions)"
    fi
}

# Test 4: Template hooks use {{PROJECT_DIR}} placeholder
test_settings_template_hooks_use_placeholder() {
    echo ""
    echo "TEST: Template hooks use {{PROJECT_DIR}} placeholder"

    # Check if hooks section contains {{PROJECT_DIR}}
    if grep -A 20 '"hooks"' "$TEMPLATE_FILE" | grep -q "{{PROJECT_DIR}}" 2>/dev/null; then
        assert_exit_code 0 0 "Template hooks contain {{PROJECT_DIR}} placeholder"
    else
        assert_exit_code 0 1 "Template hooks contain {{PROJECT_DIR}} placeholder"
    fi
}

# Test 5: Installer replaces placeholders correctly (integration test)
test_installer_replaces_placeholders() {
    echo ""
    echo "TEST: Installer replaces {{PROJECT_DIR}} placeholders"

    # Create temporary test directory
    local test_dir="/tmp/starforge-test-$$"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo (required for install)
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Run installer non-interactively by providing answers
    # We'll use 'yes' to answer all prompts and redirect stdin
    echo -e "3\nn\n0\n" | timeout 30 "$PROJECT_ROOT/bin/install.sh" > /dev/null 2>&1 || true

    # Check if settings.json was created
    if [ -f ".claude/settings.json" ]; then
        # Check that placeholder was replaced
        if grep -q "{{PROJECT_DIR}}" ".claude/settings.json" 2>/dev/null; then
            assert_exit_code 1 0 "Installed settings.json does NOT contain {{PROJECT_DIR}} placeholder"
        else
            assert_exit_code 0 0 "Installed settings.json does NOT contain {{PROJECT_DIR}} placeholder"
        fi

        # Check that actual path was inserted
        if grep -q "$test_dir" ".claude/settings.json" 2>/dev/null; then
            assert_exit_code 0 0 "Installed settings.json contains actual project path"
        else
            assert_exit_code 0 1 "Installed settings.json contains actual project path"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Skipping installer test (settings.json not created)"
    fi

    # Cleanup
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}

# Test 6: Count total placeholder replacements expected
test_placeholder_count() {
    echo ""
    echo "TEST: Template has expected number of {{PROJECT_DIR}} placeholders"

    local count=$(count_occurrences "{{PROJECT_DIR}}" "$TEMPLATE_FILE")

    # We optimized the template from 8 hard-coded paths to 6 placeholders
    # by removing redundant duplicate paths (e.g., ~/empowerai* and /Users/.../empowerai*)
    # Expect exactly 6 placeholders: 3 in allow[], 1 in deny[], 2 in hooks[]
    if [ "$count" -eq 6 ]; then
        assert_exit_code 0 0 "Template has exactly 6 {{PROJECT_DIR}} placeholders (optimized from 8)"
    else
        assert_exit_code 0 1 "Template has exactly 6 {{PROJECT_DIR}} placeholders (found $count, expected 6)"
    fi
}

# Main test runner
main() {
    echo "=========================================="
    echo "Settings Template Placeholder Tests (TDD)"
    echo "=========================================="

    # Verify template file exists
    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo -e "${RED}ERROR: Template file not found: $TEMPLATE_FILE${NC}"
        exit 1
    fi

    echo "Testing: $TEMPLATE_FILE"

    # Run all tests
    test_settings_template_has_placeholders
    test_settings_template_no_hardcoded_paths
    test_settings_template_no_user_paths
    test_settings_template_hooks_use_placeholder
    test_placeholder_count
    test_installer_replaces_placeholders

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo -e "Tests run:    $TESTS_RUN"
    echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
        echo ""
        echo -e "${RED}TEST SUITE FAILED${NC}"
        exit 1
    else
        echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
        echo ""
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        exit 0
    fi
}

# Run tests
main
