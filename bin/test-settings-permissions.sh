#!/bin/bash
# StarForge Settings Permissions Test Suite
# Tests settings.json template has comprehensive permissions (TDD for Ticket #34)
# Updated for Option B: Consolidated patterns (e.g., Bash(git *) instead of Bash(git status:*))

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
SETTINGS_FILE="$STARFORGE_ROOT/templates/settings/settings.json"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Settings Permissions Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Testing: $SETTINGS_FILE"
echo ""

# Test helper functions
assert_permission_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local permission_type="$1"
    local permission_rule="$2"
    local desc="${3:-Permission should exist: $permission_rule}"

    if jq -e ".permissions.${permission_type} | contains([\"${permission_rule}\"])" "$SETTINGS_FILE" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Missing: $permission_rule in permissions.$permission_type"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_min_permissions() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local permission_type="$1"
    local min_count="$2"
    local desc="${3:-At least $min_count $permission_type rules}"

    local actual_count
    actual_count=$(jq ".permissions.${permission_type} | length" "$SETTINGS_FILE")

    if [ "$actual_count" -ge "$min_count" ]; then
        echo -e "  ${GREEN}✓${NC} $desc (found $actual_count)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (found only $actual_count)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_uses_placeholder() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Should use {{PROJECT_DIR}} placeholder}"

    if grep -q "{{PROJECT_DIR}}" "$SETTINGS_FILE"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_no_hardcoded_paths() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Should not have hardcoded user paths}"

    if grep -q "/Users/[^{]" "$SETTINGS_FILE"; then
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Found hardcoded path: $(grep -o '/Users/[^"]*' "$SETTINGS_FILE" | head -1)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

assert_valid_json() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="${1:-Settings JSON is valid}"

    if jq empty "$SETTINGS_FILE" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# ============================================================================
# TEST SUITE - Updated for Option B (Consolidated Patterns)
# ============================================================================

test_valid_json_structure() {
    echo ""
    echo -e "${BLUE}TEST: Valid JSON structure${NC}"

    assert_valid_json "Settings file is valid JSON"
}

test_file_operation_permissions() {
    echo ""
    echo -e "${BLUE}TEST: File operation permissions${NC}"

    # Read permissions
    assert_permission_exists "allow" "Read(**/*)" "Allow reading all files"
    assert_permission_exists "allow" "Read({{PROJECT_DIR}}/**)" "Allow reading project files"

    # Write permissions
    assert_permission_exists "allow" "Write({{PROJECT_DIR}}/**)" "Allow writing project files"

    # Edit permissions
    assert_permission_exists "allow" "Edit({{PROJECT_DIR}}/**)" "Allow editing project files"

    # Grep/Glob permissions
    assert_permission_exists "allow" "Grep(**/*)" "Allow grep on all files"
    assert_permission_exists "allow" "Glob(**/*)" "Allow glob on all files"
}

test_git_command_permissions() {
    echo ""
    echo -e "${BLUE}TEST: Git command permissions (Option B: Consolidated)${NC}"

    # Option B: Consolidated git pattern
    assert_permission_exists "allow" "Bash(git *)" "Allow git commands (consolidated)"

    # Dangerous git commands should be denied
    assert_permission_exists "deny" "Bash(git push --force origin main:*)" "Deny force push to main"
    assert_permission_exists "deny" "Bash(git push -f origin main:*)" "Deny force push to main (short)"
    assert_permission_exists "deny" "Bash(git reset --hard origin/main:*)" "Deny hard reset to origin/main"
}

test_github_cli_permissions() {
    echo ""
    echo -e "${BLUE}TEST: GitHub CLI (gh) permissions (Option B: Consolidated)${NC}"

    # Option B: Consolidated gh pattern
    assert_permission_exists "allow" "Bash(gh *)" "Allow gh commands (consolidated)"
}

test_testing_command_permissions() {
    echo ""
    echo -e "${BLUE}TEST: Testing command permissions${NC}"

    assert_permission_exists "allow" "Bash(pytest *)" "Allow pytest"
    assert_permission_exists "allow" "Bash(npm *)" "Allow npm commands"
    assert_permission_exists "allow" "Bash(./bin/test-* *)" "Allow project test scripts"
}

test_safe_utility_permissions() {
    echo ""
    echo -e "${BLUE}TEST: Safe utility command permissions (Option B: Consolidated)${NC}"

    # Individual utilities
    assert_permission_exists "allow" "Bash(ls *)" "Allow ls"
    assert_permission_exists "allow" "Bash(pwd *)" "Allow pwd"
    assert_permission_exists "allow" "Bash(cd *)" "Allow cd"
    assert_permission_exists "allow" "Bash(mkdir *)" "Allow mkdir"
    assert_permission_exists "allow" "Bash(cat *)" "Allow cat"
    assert_permission_exists "allow" "Bash(echo *)" "Allow echo"
    assert_permission_exists "allow" "Bash(jq *)" "Allow jq"
    assert_permission_exists "allow" "Bash(grep *)" "Allow bash grep"
    assert_permission_exists "allow" "Bash(find *)" "Allow find"
    assert_permission_exists "allow" "Bash(sed *)" "Allow sed"
    assert_permission_exists "allow" "Bash(awk *)" "Allow awk"
    assert_permission_exists "allow" "Bash(date *)" "Allow date"
    assert_permission_exists "allow" "Bash(basename *)" "Allow basename"
    assert_permission_exists "allow" "Bash(dirname *)" "Allow dirname"
    assert_permission_exists "allow" "Bash(source *)" "Allow source"
    assert_permission_exists "allow" "Bash(chmod *)" "Allow chmod"
    assert_permission_exists "allow" "Bash(cp *)" "Allow cp"
    assert_permission_exists "allow" "Bash(mv *)" "Allow mv"
    assert_permission_exists "allow" "Bash(rm *)" "Allow rm (with deny rules for dangerous usage)"
}

test_dangerous_command_denials() {
    echo ""
    echo -e "${BLUE}TEST: Dangerous commands are denied${NC}"

    assert_permission_exists "deny" "Bash(rm -rf /:*)" "Deny rm -rf /"
    assert_permission_exists "deny" "Bash(rm -rf ~:*)" "Deny rm -rf ~"
    assert_permission_exists "deny" "Bash(rm -rf {{PROJECT_DIR}}/.git:*)" "Deny deleting .git"
    assert_permission_exists "deny" "Bash(rm -rf .git:*)" "Deny deleting .git (relative)"
}

test_system_command_asks() {
    echo ""
    echo -e "${BLUE}TEST: System commands require approval${NC}"

    assert_permission_exists "ask" "Bash(sudo *)" "Ask for sudo"
    assert_permission_exists "ask" "Bash(su *)" "Ask for su"
    assert_permission_exists "ask" "Bash(chown *)" "Ask for chown"
    assert_permission_exists "ask" "Bash(chmod +x /usr/* *)" "Ask for chmod on system dirs"
    assert_permission_exists "ask" "Bash(kill *)" "Ask for kill"
    assert_permission_exists "ask" "Bash(killall *)" "Ask for killall"
    assert_permission_exists "ask" "Bash(shutdown *)" "Ask for shutdown"
    assert_permission_exists "ask" "Bash(reboot *)" "Ask for reboot"
    assert_permission_exists "ask" "Bash(dd *)" "Ask for dd"
    assert_permission_exists "ask" "Bash(mkfs *)" "Ask for mkfs"
    assert_permission_exists "ask" "Bash(fdisk *)" "Ask for fdisk"
    assert_permission_exists "ask" "Bash(diskutil *)" "Ask for diskutil"
}

test_hooks_configured() {
    echo ""
    echo -e "${BLUE}TEST: Hooks are configured${NC}"

    TESTS_RUN=$((TESTS_RUN + 1))
    local hook_count
    hook_count=$(jq '.hooks.PreToolUse | length' "$SETTINGS_FILE")

    if [ "$hook_count" -ge 2 ]; then
        echo -e "  ${GREEN}✓${NC} PreToolUse hooks configured (found $hook_count)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} PreToolUse hooks not configured properly (found $hook_count)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

test_minimum_permission_count() {
    echo ""
    echo -e "${BLUE}TEST: Comprehensive permissions (Option B: ~50+ consolidated rules)${NC}"

    # Option B has fewer rules than Option A (77) but still comprehensive
    assert_min_permissions "allow" 40 "At least 40 allow rules"
    assert_min_permissions "deny" 5 "At least 5 deny rules"
    assert_min_permissions "ask" 8 "At least 8 ask rules"
}

test_placeholder_usage() {
    echo ""
    echo -e "${BLUE}TEST: Template uses placeholders${NC}"

    assert_uses_placeholder "Uses {{PROJECT_DIR}} placeholder"
    assert_no_hardcoded_paths "No hardcoded user paths"
}

test_performance() {
    echo ""
    echo -e "${BLUE}TEST: Performance (<10ms load time)${NC}"

    TESTS_RUN=$((TESTS_RUN + 1))

    local start_time
    local end_time
    local duration

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        start_time=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
        jq empty "$SETTINGS_FILE" > /dev/null 2>&1
        end_time=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    else
        # Linux
        start_time=$(date +%s%3N)
        jq empty "$SETTINGS_FILE" > /dev/null 2>&1
        end_time=$(date +%s%3N)
    fi

    duration=$((end_time - start_time))

    if [ "$duration" -lt 10 ]; then
        echo -e "  ${GREEN}✓${NC} Performance target met (${duration}ms < 10ms)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Performance target missed (${duration}ms >= 10ms)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ============================================================================
# RUN TESTS
# ============================================================================

# Run all tests
test_valid_json_structure
test_file_operation_permissions
test_git_command_permissions
test_github_cli_permissions
test_testing_command_permissions
test_safe_utility_permissions
test_dangerous_command_denials
test_system_command_asks
test_hooks_configured
test_minimum_permission_count
test_placeholder_usage
test_performance

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}TEST SUMMARY${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    exit 1
fi
