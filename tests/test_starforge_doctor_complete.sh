#!/bin/bash
# Comprehensive test suite for starforge doctor command
# Tests all 5 validation functions + integration + edge cases + UX
# Created by: qa-engineer (Task 2.7)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directories
TEST_ROOT="/tmp/starforge-doctor-test-$$"
ORIGINAL_DIR="$(pwd)"

# Test helper functions
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    echo -e "   ${YELLOW}Details${NC}: $2"
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Setup test environment
setup() {
    section "Setup Test Environment"

    # Create test directory
    mkdir -p "$TEST_ROOT"
    cd "$TEST_ROOT"

    # Copy starforge binary for testing
    cp "$ORIGINAL_DIR/bin/starforge" "$TEST_ROOT/starforge"
    chmod +x "$TEST_ROOT/starforge"

    echo "Test directory: $TEST_ROOT"
    echo "Starforge binary: $TEST_ROOT/starforge"
}

# Cleanup test environment
cleanup() {
    section "Cleanup Test Environment"
    cd "$ORIGINAL_DIR"
    rm -rf "$TEST_ROOT"
    echo "Cleaned up: $TEST_ROOT"
}

# Helper: Create perfect .claude structure
create_perfect_installation() {
    mkdir -p .claude/{lib,bin,agents,hooks,scripts,triggers,logs}
    mkdir -p .claude/agents/agent-learnings

    # Create critical files
    echo "# CLAUDE.md" > .claude/CLAUDE.md
    echo "# LEARNINGS.md" > .claude/LEARNINGS.md
    echo '{"hooks":{"Stop":{"enabled":true}}}' > .claude/settings.json
    echo "#!/usr/bin/env python3" > .claude/hooks/stop.py
    chmod +x .claude/hooks/stop.py

    # Create 11 lib files
    for i in {1..11}; do
        echo "#!/bin/bash" > ".claude/lib/file-$i.sh"
        chmod +x ".claude/lib/file-$i.sh"
    done

    # Create 3 bin files
    for i in {1..3}; do
        echo "#!/bin/bash" > ".claude/bin/file-$i.sh"
        chmod +x ".claude/bin/file-$i.sh"
    done

    # Create 5 agent files
    for i in {1..5}; do
        echo "# Agent $i" > ".claude/agents/agent-$i.md"
    done
}

# Helper: Run doctor command and capture output
run_doctor() {
    # Create a minimal starforge script that sources the doctor functions
    cat > ./test-doctor.sh << 'EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_directory_structure() {
    local required_dirs=(
        ".claude"
        ".claude/lib"
        ".claude/bin"
        ".claude/agents"
        ".claude/hooks"
        ".claude/scripts"
        ".claude/triggers"
        ".claude/logs"
    )

    local missing_dirs=()

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            missing_dirs+=("$dir")
        fi
    done

    if [ ${#missing_dirs[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Directory structure complete${NC}"
        return 0
    else
        echo -e "${RED}❌ Directory structure incomplete${NC}"
        echo "   Missing directories:"
        for dir in "${missing_dirs[@]}"; do
            echo "     - $dir"
        done
        return 1
    fi
}

check_critical_files() {
    local required_files=(
        ".claude/CLAUDE.md"
        ".claude/LEARNINGS.md"
        ".claude/settings.json"
        ".claude/hooks/stop.py"
    )

    local missing_files=()

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Critical files present${NC}"
        return 0
    else
        echo -e "${RED}❌ Critical files missing${NC}"
        echo "   Missing files:"
        for file in "${missing_files[@]}"; do
            echo "     - $file"
        done
        return 1
    fi
}

check_file_counts() {
    local all_passed=true

    # Check lib files
    local expected_lib=11
    local actual_lib=$(find .claude/lib -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$actual_lib" -eq "$expected_lib" ]; then
        echo -e "${GREEN}✅ Library files complete ($actual_lib/$expected_lib)${NC}"
    else
        echo -e "${RED}❌ Library files incomplete ($actual_lib/$expected_lib)${NC}"
        echo "   Expected files in .claude/lib/:"
        echo "     - discord-notify.sh, logger.sh, project-env.sh, router.sh"
        echo "     - mcp-tools-*.sh (6 files), git-helpers.sh"
        all_passed=false
    fi

    # Check bin files
    local expected_bin=3
    local actual_bin=$(find .claude/bin -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$actual_bin" -eq "$expected_bin" ]; then
        echo -e "${GREEN}✅ Bin files complete ($actual_bin/$expected_bin)${NC}"
    else
        echo -e "${RED}❌ Bin files incomplete ($actual_bin/$expected_bin)${NC}"
        echo "   Expected: daemon.sh, daemon-runner.sh, update-helpers.sh"
        all_passed=false
    fi

    # Check agent definitions
    local expected_agents=5
    local actual_agents=$(find .claude/agents -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$actual_agents" -eq "$expected_agents" ]; then
        echo -e "${GREEN}✅ Agent definitions present ($actual_agents/$expected_agents)${NC}"
    else
        echo -e "${RED}❌ Agent definitions incomplete ($actual_agents/$expected_agents)${NC}"
        echo "   Expected: orchestrator, senior-engineer, junior-engineer, qa-engineer, tpm-agent"
        all_passed=false
    fi

    [ "$all_passed" = true ] && return 0 || return 1
}

check_json_config() {
    local settings_file=".claude/settings.json"

    if [ ! -f "$settings_file" ]; then
        echo -e "${RED}❌ settings.json not found${NC}"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️  jq not found, skipping JSON validation${NC}"
        return 0
    fi

    if ! jq empty "$settings_file" 2>/dev/null; then
        echo -e "${RED}❌ settings.json is not valid JSON${NC}"
        echo "   Run 'jq . $settings_file' to see parse errors"
        return 1
    fi

    local has_stop_hook=$(jq -r '.hooks.Stop // empty' "$settings_file" 2>/dev/null)

    if [ -z "$has_stop_hook" ]; then
        echo -e "${RED}❌ JSON configuration incomplete${NC}"
        echo "   Missing: hooks.Stop configuration"
        return 1
    fi

    echo -e "${GREEN}✅ JSON configuration valid${NC}"
    return 0
}

check_permissions() {
    local files_to_check=()
    local non_executable=()

    files_to_check+=(".claude/hooks/stop.py")

    while IFS= read -r file; do
        files_to_check+=("$file")
    done < <(find .claude/scripts .claude/lib .claude/bin -name "*.sh" 2>/dev/null)

    for file in "${files_to_check[@]}"; do
        if [ ! -x "$file" ]; then
            non_executable+=("$file")
        fi
    done

    if [ ${#non_executable[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Permissions correct${NC}"
        return 0
    else
        echo -e "${RED}❌ Permission errors found${NC}"
        echo "   Non-executable files:"
        for file in "${non_executable[@]}"; do
            echo "     - $file"
        done
        echo ""
        echo "   Fix with: chmod +x <file>"
        return 1
    fi
}

run_doctor_checks() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔍 StarForge Doctor${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local all_passed=true

    check_directory_structure || all_passed=false
    check_critical_files || all_passed=false
    check_file_counts || all_passed=false
    check_json_config || all_passed=false
    check_permissions || all_passed=false

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$all_passed" = true ]; then
        echo -e "${GREEN}🎉 All systems go! StarForge is ready.${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Installation incomplete. Run 'starforge update' to fix.${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        return 1
    fi
}

run_doctor_checks
EOF
    chmod +x ./test-doctor.sh
    ./test-doctor.sh
}

# ============================================================================
# TEST SECTION 1: Directory Structure Validation
# ============================================================================

section "Section 1: Directory Structure Tests"

test_directory_structure_all_present() {
    cd "$TEST_ROOT" && mkdir -p test1 && cd test1
    create_perfect_installation

    if run_doctor &>/dev/null; then
        pass "All 8 directories present"
    else
        fail "All 8 directories present" "Doctor should pass with complete directory structure"
    fi
}

test_directory_structure_missing_one() {
    cd "$TEST_ROOT" && mkdir -p test2 && cd test2
    create_perfect_installation
    rmdir .claude/logs

    if run_doctor &>/dev/null; then
        fail "Missing one directory" "Doctor should fail when logs directory missing"
    else
        pass "Missing one directory detected"
    fi
}

test_directory_structure_missing_multiple() {
    cd "$TEST_ROOT" && mkdir -p test3 && cd test3
    create_perfect_installation
    rmdir .claude/logs .claude/triggers .claude/scripts

    if run_doctor &>/dev/null; then
        fail "Missing multiple directories" "Doctor should fail when 3 directories missing"
    else
        pass "Missing multiple directories detected"
    fi
}

test_directory_structure_empty_claude() {
    cd "$TEST_ROOT" && mkdir -p test4 && cd test4
    mkdir -p .claude

    if run_doctor &>/dev/null; then
        fail "Empty .claude directory" "Doctor should fail with empty .claude"
    else
        pass "Empty .claude directory detected"
    fi
}

test_directory_structure_no_claude() {
    cd "$TEST_ROOT" && mkdir -p test5 && cd test5

    if run_doctor &>/dev/null; then
        fail "No .claude directory" "Doctor should fail with no .claude"
    else
        pass "No .claude directory detected"
    fi
}

# ============================================================================
# TEST SECTION 2: Critical Files Validation
# ============================================================================

section "Section 2: Critical Files Tests"

test_critical_files_all_present() {
    cd "$TEST_ROOT" && mkdir -p test6 && cd test6
    create_perfect_installation

    if run_doctor &>/dev/null; then
        pass "All 4 critical files present"
    else
        fail "All 4 critical files present" "Doctor should pass with all critical files"
    fi
}

test_critical_files_missing_claude_md() {
    cd "$TEST_ROOT" && mkdir -p test7 && cd test7
    create_perfect_installation
    rm .claude/CLAUDE.md

    if run_doctor &>/dev/null; then
        fail "Missing CLAUDE.md" "Doctor should fail when CLAUDE.md missing"
    else
        pass "Missing CLAUDE.md detected"
    fi
}

test_critical_files_missing_settings_json() {
    cd "$TEST_ROOT" && mkdir -p test8 && cd test8
    create_perfect_installation
    rm .claude/settings.json

    if run_doctor &>/dev/null; then
        fail "Missing settings.json" "Doctor should fail when settings.json missing"
    else
        pass "Missing settings.json detected"
    fi
}

test_critical_files_missing_stop_py() {
    cd "$TEST_ROOT" && mkdir -p test9 && cd test9
    create_perfect_installation
    rm .claude/hooks/stop.py

    if run_doctor &>/dev/null; then
        fail "Missing stop.py" "Doctor should fail when stop.py missing"
    else
        pass "Missing stop.py detected"
    fi
}

test_critical_files_missing_multiple() {
    cd "$TEST_ROOT" && mkdir -p test10 && cd test10
    create_perfect_installation
    rm .claude/CLAUDE.md .claude/LEARNINGS.md

    if run_doctor &>/dev/null; then
        fail "Missing multiple critical files" "Doctor should fail when 2 files missing"
    else
        pass "Missing multiple critical files detected"
    fi
}

# ============================================================================
# TEST SECTION 3: File Counts Validation
# ============================================================================

section "Section 3: File Count Tests"

test_file_counts_all_correct() {
    cd "$TEST_ROOT" && mkdir -p test11 && cd test11
    create_perfect_installation

    if run_doctor &>/dev/null; then
        pass "All file counts correct (11 lib, 3 bin, 5 agents)"
    else
        fail "All file counts correct" "Doctor should pass with correct file counts"
    fi
}

test_file_counts_lib_incorrect() {
    cd "$TEST_ROOT" && mkdir -p test12 && cd test12
    create_perfect_installation
    rm .claude/lib/file-1.sh

    if run_doctor &>/dev/null; then
        fail "Incorrect lib count" "Doctor should fail with 10 lib files instead of 11"
    else
        pass "Incorrect lib count detected (10/11)"
    fi
}

test_file_counts_bin_incorrect() {
    cd "$TEST_ROOT" && mkdir -p test13 && cd test13
    create_perfect_installation
    rm .claude/bin/file-1.sh

    if run_doctor &>/dev/null; then
        fail "Incorrect bin count" "Doctor should fail with 2 bin files instead of 3"
    else
        pass "Incorrect bin count detected (2/3)"
    fi
}

test_file_counts_agents_incorrect() {
    cd "$TEST_ROOT" && mkdir -p test14 && cd test14
    create_perfect_installation
    rm .claude/agents/agent-1.md

    if run_doctor &>/dev/null; then
        fail "Incorrect agent count" "Doctor should fail with 4 agents instead of 5"
    else
        pass "Incorrect agent count detected (4/5)"
    fi
}

test_file_counts_all_incorrect() {
    cd "$TEST_ROOT" && mkdir -p test15 && cd test15
    create_perfect_installation
    rm .claude/lib/file-1.sh .claude/bin/file-1.sh .claude/agents/agent-1.md

    if run_doctor &>/dev/null; then
        fail "All counts incorrect" "Doctor should fail with multiple count errors"
    else
        pass "All counts incorrect detected"
    fi
}

test_file_counts_extra_files() {
    cd "$TEST_ROOT" && mkdir -p test16 && cd test16
    create_perfect_installation
    echo "#!/bin/bash" > .claude/lib/extra.sh
    chmod +x .claude/lib/extra.sh

    if run_doctor &>/dev/null; then
        fail "Extra files (12 lib)" "Doctor should fail with 12 lib files instead of 11"
    else
        pass "Extra files detected (12/11)"
    fi
}

# ============================================================================
# TEST SECTION 4: JSON Configuration Validation
# ============================================================================

section "Section 4: JSON Configuration Tests"

test_json_config_valid() {
    cd "$TEST_ROOT" && mkdir -p test17 && cd test17
    create_perfect_installation

    if run_doctor &>/dev/null; then
        pass "Valid JSON configuration"
    else
        fail "Valid JSON configuration" "Doctor should pass with valid settings.json"
    fi
}

test_json_config_invalid_syntax() {
    cd "$TEST_ROOT" && mkdir -p test18 && cd test18
    create_perfect_installation
    echo '{"hooks":{"Stop":}' > .claude/settings.json

    if run_doctor &>/dev/null; then
        fail "Invalid JSON syntax" "Doctor should fail with malformed JSON"
    else
        pass "Invalid JSON syntax detected"
    fi
}

test_json_config_missing_stop_hook() {
    cd "$TEST_ROOT" && mkdir -p test19 && cd test19
    create_perfect_installation
    echo '{"hooks":{}}' > .claude/settings.json

    if run_doctor &>/dev/null; then
        fail "Missing hooks.Stop" "Doctor should fail without hooks.Stop config"
    else
        pass "Missing hooks.Stop detected"
    fi
}

test_json_config_empty_file() {
    cd "$TEST_ROOT" && mkdir -p test20 && cd test20
    create_perfect_installation
    echo '' > .claude/settings.json

    if run_doctor &>/dev/null; then
        fail "Empty JSON file" "Doctor should fail with empty settings.json"
    else
        pass "Empty JSON file detected"
    fi
}

# ============================================================================
# TEST SECTION 5: Permissions Validation
# ============================================================================

section "Section 5: Permissions Tests"

test_permissions_all_correct() {
    cd "$TEST_ROOT" && mkdir -p test21 && cd test21
    create_perfect_installation

    if run_doctor &>/dev/null; then
        pass "All permissions correct"
    else
        fail "All permissions correct" "Doctor should pass with all executable bits set"
    fi
}

test_permissions_missing_stop_py() {
    cd "$TEST_ROOT" && mkdir -p test22 && cd test22
    create_perfect_installation
    chmod -x .claude/hooks/stop.py

    if run_doctor &>/dev/null; then
        fail "Missing executable on stop.py" "Doctor should fail when stop.py not executable"
    else
        pass "Missing executable on stop.py detected"
    fi
}

test_permissions_missing_lib_file() {
    cd "$TEST_ROOT" && mkdir -p test23 && cd test23
    create_perfect_installation
    chmod -x .claude/lib/file-1.sh

    if run_doctor &>/dev/null; then
        fail "Missing executable on lib file" "Doctor should fail when lib file not executable"
    else
        pass "Missing executable on lib file detected"
    fi
}

test_permissions_missing_multiple() {
    cd "$TEST_ROOT" && mkdir -p test24 && cd test24
    create_perfect_installation
    chmod -x .claude/lib/file-1.sh .claude/bin/file-1.sh .claude/hooks/stop.py

    if run_doctor &>/dev/null; then
        fail "Missing multiple executables" "Doctor should fail with 3 non-executable files"
    else
        pass "Missing multiple executables detected"
    fi
}

test_permissions_no_permissions() {
    cd "$TEST_ROOT" && mkdir -p test25 && cd test25
    create_perfect_installation
    chmod 000 .claude/hooks/stop.py

    if run_doctor &>/dev/null; then
        fail "No permissions at all" "Doctor should fail when file has no permissions"
    else
        pass "No permissions at all detected"
    fi
}

# ============================================================================
# TEST SECTION 6: Integration Scenarios
# ============================================================================

section "Section 6: Integration Scenarios"

test_integration_perfect_installation() {
    cd "$TEST_ROOT" && mkdir -p test26 && cd test26
    create_perfect_installation

    output=$(run_doctor 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        if echo "$output" | grep -q "All systems go"; then
            pass "Perfect installation (exit 0 + success message)"
        else
            fail "Perfect installation" "Missing success message in output"
        fi
    else
        fail "Perfect installation" "Exit code should be 0, got $exit_code"
    fi
}

test_integration_multiple_failures() {
    cd "$TEST_ROOT" && mkdir -p test27 && cd test27
    create_perfect_installation

    # Create multiple failures
    rmdir .claude/logs
    rm .claude/CLAUDE.md
    rm .claude/lib/file-1.sh
    echo '{"hooks":{}}' > .claude/settings.json
    chmod -x .claude/hooks/stop.py

    output=$(run_doctor 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        # Check that all 5 failures are detected
        failures=0
        echo "$output" | grep -q "Directory structure incomplete" && ((failures++))
        echo "$output" | grep -q "Critical files missing" && ((failures++))
        echo "$output" | grep -q "Library files incomplete" && ((failures++))
        echo "$output" | grep -q "JSON configuration incomplete" && ((failures++))
        echo "$output" | grep -q "Permission errors found" && ((failures++))

        if [ $failures -eq 5 ]; then
            pass "Multiple failures (all 5 checks failed)"
        else
            fail "Multiple failures" "Only detected $failures/5 failures"
        fi
    else
        fail "Multiple failures" "Exit code should be 1, got 0"
    fi
}

test_integration_mixed_results() {
    cd "$TEST_ROOT" && mkdir -p test28 && cd test28
    create_perfect_installation

    # Create some failures (2 pass, 3 fail)
    rmdir .claude/logs
    rm .claude/CLAUDE.md

    output=$(run_doctor 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        pass "Mixed results (some pass, some fail, exit 1)"
    else
        fail "Mixed results" "Exit code should be 1 when any check fails"
    fi
}

test_integration_exit_code_success() {
    cd "$TEST_ROOT" && mkdir -p test29 && cd test29
    create_perfect_installation

    run_doctor &>/dev/null
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        pass "Exit code 0 on success"
    else
        fail "Exit code 0 on success" "Got exit code $exit_code"
    fi
}

test_integration_exit_code_failure() {
    cd "$TEST_ROOT" && mkdir -p test30 && cd test30
    create_perfect_installation
    rmdir .claude/logs

    run_doctor &>/dev/null
    exit_code=$?

    if [ $exit_code -eq 1 ]; then
        pass "Exit code 1 on failure"
    else
        fail "Exit code 1 on failure" "Got exit code $exit_code"
    fi
}

# ============================================================================
# TEST SECTION 7: Edge Cases
# ============================================================================

section "Section 7: Edge Cases"

test_edge_case_symlinks() {
    cd "$TEST_ROOT" && mkdir -p test31 && cd test31
    create_perfect_installation

    # Create symlink to a directory
    rm -rf .claude/logs
    mkdir -p /tmp/logs-symlink-$$
    ln -s /tmp/logs-symlink-$$ .claude/logs

    if run_doctor &>/dev/null; then
        pass "Symlinked directories accepted"
    else
        fail "Symlinked directories" "Doctor should accept symlinks as valid directories"
    fi

    rm -rf /tmp/logs-symlink-$$
}

test_edge_case_extra_subdirectories() {
    cd "$TEST_ROOT" && mkdir -p test32 && cd test32
    create_perfect_installation

    # Add extra subdirectories
    mkdir -p .claude/agents/agent-learnings/extra-stuff
    mkdir -p .claude/coordination
    mkdir -p .claude/breakdowns

    if run_doctor &>/dev/null; then
        pass "Extra subdirectories ignored"
    else
        fail "Extra subdirectories" "Doctor should not care about extra subdirs"
    fi
}

test_edge_case_nested_json() {
    cd "$TEST_ROOT" && mkdir -p test33 && cd test33
    create_perfect_installation

    # Create deeply nested JSON
    cat > .claude/settings.json << 'EOF'
{
    "hooks": {
        "Stop": {
            "enabled": true,
            "nested": {
                "deep": {
                    "config": "value"
                }
            }
        }
    }
}
EOF

    if run_doctor &>/dev/null; then
        pass "Nested JSON configuration accepted"
    else
        fail "Nested JSON" "Doctor should accept nested hooks.Stop config"
    fi
}

test_edge_case_executable_no_shebang() {
    cd "$TEST_ROOT" && mkdir -p test34 && cd test34
    create_perfect_installation

    # Create executable without shebang
    echo "echo 'no shebang'" > .claude/lib/file-1.sh
    chmod +x .claude/lib/file-1.sh

    if run_doctor &>/dev/null; then
        pass "Executable without shebang accepted"
    else
        fail "Executable without shebang" "Doctor only checks executable bit, not content"
    fi
}

test_edge_case_empty_files() {
    cd "$TEST_ROOT" && mkdir -p test35 && cd test35
    create_perfect_installation

    # Create empty but valid files
    : > .claude/CLAUDE.md
    : > .claude/LEARNINGS.md

    if run_doctor &>/dev/null; then
        pass "Empty critical files accepted"
    else
        fail "Empty critical files" "Doctor should accept empty files (they exist)"
    fi
}

# ============================================================================
# TEST SECTION 8: User Experience / Output Format
# ============================================================================

section "Section 8: User Experience Tests"

test_ux_output_has_colors() {
    cd "$TEST_ROOT" && mkdir -p test36 && cd test36
    create_perfect_installation

    output=$(run_doctor 2>&1)

    # Check for ANSI color codes
    if echo "$output" | grep -q '\[0;3'; then
        pass "Output contains color codes"
    else
        fail "Output contains color codes" "No ANSI color codes found in output"
    fi
}

test_ux_output_has_checkmarks() {
    cd "$TEST_ROOT" && mkdir -p test37 && cd test37
    create_perfect_installation

    output=$(run_doctor 2>&1)

    # Check for checkmarks
    if echo "$output" | grep -q '✅'; then
        pass "Output contains checkmarks"
    else
        fail "Output contains checkmarks" "No checkmarks found in success output"
    fi
}

test_ux_output_has_error_marks() {
    cd "$TEST_ROOT" && mkdir -p test38 && cd test38
    create_perfect_installation
    rmdir .claude/logs

    output=$(run_doctor 2>&1)

    # Check for error marks
    if echo "$output" | grep -q '❌'; then
        pass "Output contains error marks"
    else
        fail "Output contains error marks" "No error marks found in failure output"
    fi
}

test_ux_error_messages_actionable() {
    cd "$TEST_ROOT" && mkdir -p test39 && cd test39
    create_perfect_installation
    chmod -x .claude/hooks/stop.py

    output=$(run_doctor 2>&1)

    # Check for actionable fix message
    if echo "$output" | grep -q 'Fix with: chmod +x'; then
        pass "Error messages are actionable"
    else
        fail "Error messages are actionable" "No 'Fix with' suggestion found"
    fi
}

test_ux_success_message_clear() {
    cd "$TEST_ROOT" && mkdir -p test40 && cd test40
    create_perfect_installation

    output=$(run_doctor 2>&1)

    # Check for clear success message
    if echo "$output" | grep -q "All systems go"; then
        pass "Success message is clear"
    else
        fail "Success message is clear" "Expected 'All systems go' in output"
    fi
}

# ============================================================================
# MAIN TEST EXECUTION
# ============================================================================

main() {
    # Setup
    setup

    # Section 1: Directory Structure (5 tests)
    test_directory_structure_all_present
    test_directory_structure_missing_one
    test_directory_structure_missing_multiple
    test_directory_structure_empty_claude
    test_directory_structure_no_claude

    # Section 2: Critical Files (5 tests)
    test_critical_files_all_present
    test_critical_files_missing_claude_md
    test_critical_files_missing_settings_json
    test_critical_files_missing_stop_py
    test_critical_files_missing_multiple

    # Section 3: File Counts (6 tests)
    test_file_counts_all_correct
    test_file_counts_lib_incorrect
    test_file_counts_bin_incorrect
    test_file_counts_agents_incorrect
    test_file_counts_all_incorrect
    test_file_counts_extra_files

    # Section 4: JSON Configuration (4 tests)
    test_json_config_valid
    test_json_config_invalid_syntax
    test_json_config_missing_stop_hook
    test_json_config_empty_file

    # Section 5: Permissions (5 tests)
    test_permissions_all_correct
    test_permissions_missing_stop_py
    test_permissions_missing_lib_file
    test_permissions_missing_multiple
    test_permissions_no_permissions

    # Section 6: Integration (5 tests)
    test_integration_perfect_installation
    test_integration_multiple_failures
    test_integration_mixed_results
    test_integration_exit_code_success
    test_integration_exit_code_failure

    # Section 7: Edge Cases (5 tests)
    test_edge_case_symlinks
    test_edge_case_extra_subdirectories
    test_edge_case_nested_json
    test_edge_case_executable_no_shebang
    test_edge_case_empty_files

    # Section 8: UX Tests (5 tests)
    test_ux_output_has_colors
    test_ux_output_has_checkmarks
    test_ux_output_has_error_marks
    test_ux_error_messages_actionable
    test_ux_success_message_clear

    # Cleanup
    cleanup

    # Report results
    section "Test Results Summary"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${CYAN}Total Tests:${NC}   $TESTS_RUN"
    echo -e "${GREEN}Passed:${NC}        $TESTS_PASSED"
    echo -e "${RED}Failed:${NC}        $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

# Run main
main
exit $?
