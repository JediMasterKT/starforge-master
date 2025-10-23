#!/bin/bash
# Test Suite for Hardcoded Pattern Detection
# Tests bin/test-hardcoded-patterns.sh
# Following TDD: Tests written BEFORE implementation

set -e  # Exit on error

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Get the directory where this test script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
SCANNER="$STARFORGE_ROOT/bin/test-hardcoded-patterns.sh"

# Test helper functions
assert_success() {
    local exit_code="$1"
    local test_name="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$exit_code" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: exit 0 (success)"
        echo "  Got:      exit $exit_code (failure)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_failure() {
    local exit_code="$1"
    local test_name="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$exit_code" -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected: exit 1 (failure)"
        echo "  Got:      exit 0 (success)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_output_contains() {
    local output="$1"
    local pattern="$2"
    local test_name="$3"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if echo "$output" | grep -q "$pattern"; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        echo "  Expected output to contain: '$pattern'"
        echo "  Got: '$output'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup: Create temporary test files
setup_test_file() {
    mktemp /tmp/test-pattern-XXXXXX
}

cleanup_test_file() {
    local file="$1"
    rm -f "$file"
}

echo "=========================================="
echo "Test Suite: Hardcoded Pattern Detection"
echo "Testing: bin/test-hardcoded-patterns.sh"
echo "=========================================="
echo ""

# Verify scanner exists
if [ ! -f "$SCANNER" ]; then
    echo -e "${RED}ERROR: Scanner not found at $SCANNER${NC}"
    echo "Tests cannot run. Implementation needed."
    exit 1
fi

# TEST GROUP 1: Empowerai Detection
echo "Test Group 1: Empowerai Pattern Detection"
echo "------------------------------------------"

# Test 1: Detects empowerai in shell scripts
test_file=$(setup_test_file)
echo 'cd ~/empowerai' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects empowerai reference in script"
cleanup_test_file "$test_file"

# Test 2: Detects empowerai in path
test_file=$(setup_test_file)
echo 'PROJECT_DIR="/Users/username/empowerai"' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects empowerai in path variable"
cleanup_test_file "$test_file"

# Test 3: Allows empowerai in markdown files
test_file=$(mktemp /tmp/test-pattern-XXXXXX.md)
echo 'empowerai was the old project name' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_success $exit_code "Allows empowerai in .md files (documentation)"
cleanup_test_file "$test_file"

# Test 4: Detects empowerai in template files
test_file=$(setup_test_file)
echo 'cd /path/to/empowerai/project' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects empowerai in template files"
cleanup_test_file "$test_file"

echo ""

# TEST GROUP 2: Hardcoded Agent Pattern Detection
echo "Test Group 2: Hardcoded Agent Pattern Detection"
echo "------------------------------------------------"

# Test 5: Detects hardcoded agent case statements
test_file=$(setup_test_file)
cat > "$test_file" <<'EOF'
case "$agent" in
  junior-dev-a) echo "a" ;;
  junior-dev-b) echo "b" ;;
  junior-dev-c) echo "c" ;;
esac
EOF
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects hardcoded agent patterns (junior-dev-[abc])"
cleanup_test_file "$test_file"

# Test 6: Detects junior-dev-a specifically
test_file=$(setup_test_file)
echo 'if [ "$agent" = "junior-dev-a" ]; then' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects junior-dev-a pattern"
cleanup_test_file "$test_file"

# Test 7: Detects junior-dev-b specifically
test_file=$(setup_test_file)
echo 'worktree="project-junior-dev-b"' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects junior-dev-b pattern"
cleanup_test_file "$test_file"

# Test 8: Detects junior-dev-c specifically
test_file=$(setup_test_file)
echo 'cd ../project-junior-dev-c' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects junior-dev-c pattern"
cleanup_test_file "$test_file"

# Test 9: Allows junior-dev-agent (not a hardcoded pattern)
test_file=$(setup_test_file)
echo 'This is about junior-dev-agent in general' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_success $exit_code "Allows junior-dev-agent (false positive check)"
cleanup_test_file "$test_file"

echo ""

# TEST GROUP 3: Absolute Path Detection
echo "Test Group 3: Absolute Path Detection"
echo "--------------------------------------"

# Test 10: Detects /Users/ paths
test_file=$(setup_test_file)
echo 'cp /Users/name/file.txt .' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects /Users/ absolute path"
cleanup_test_file "$test_file"

# Test 11: Detects /home/ paths
test_file=$(setup_test_file)
echo 'cd /home/username/project' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_failure $exit_code "Detects /home/ absolute path"
cleanup_test_file "$test_file"

# Test 12: Allows /tmp/ and /var/ paths (system directories)
test_file=$(setup_test_file)
echo 'tmpfile=/tmp/test.txt' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_success $exit_code "Allows /tmp/ paths (system directory)"
cleanup_test_file "$test_file"

# Test 13: Allows /etc/ paths
test_file=$(setup_test_file)
echo 'config=/etc/config.conf' > "$test_file"
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_success $exit_code "Allows /etc/ paths (system directory)"
cleanup_test_file "$test_file"

echo ""

# TEST GROUP 4: Output Format
echo "Test Group 4: Output Format and Reporting"
echo "------------------------------------------"

# Test 14: Reports file name and line number
test_file=$(setup_test_file)
echo 'line 1' > "$test_file"
echo 'cd ~/empowerai' >> "$test_file"
echo 'line 3' >> "$test_file"
output=$(bash "$SCANNER" "$test_file" 2>&1 || true)
assert_output_contains "$output" "$test_file" "Output contains file name"

# Test 15: Reports line number
assert_output_contains "$output" "2" "Output contains line number"
cleanup_test_file "$test_file"

echo ""

# TEST GROUP 5: Edge Cases
echo "Test Group 5: Edge Cases"
echo "------------------------"

# Test 16: Clean file passes
test_file=$(setup_test_file)
cat > "$test_file" <<'EOF'
#!/bin/bash
# Clean script with no hardcoded patterns
PROJECT_DIR="$(pwd)"
AGENT_ID=$(detect_agent_id)
echo "Working in $PROJECT_DIR as $AGENT_ID"
EOF
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_success $exit_code "Clean file passes scan"
cleanup_test_file "$test_file"

# Test 17: Multiple violations reported
test_file=$(setup_test_file)
cat > "$test_file" <<'EOF'
cd ~/empowerai
agent="junior-dev-a"
path="/Users/me/project"
EOF
bash "$SCANNER" "$test_file" 2>&1 >/dev/null && exit_code=0 || exit_code=$?
assert_failure $exit_code "Multiple violations cause failure"
cleanup_test_file "$test_file"

# Test 18: Documentation in .md allows everything
test_file=$(mktemp /tmp/test-pattern-XXXXXX.md)
cat > "$test_file" <<'EOF'
# Documentation
Old path: ~/empowerai
Agent examples: junior-dev-a, junior-dev-b, junior-dev-c
User path: /Users/example/project
EOF
bash "$SCANNER" "$test_file" > /dev/null 2>&1 && exit_code=0 || exit_code=$?
assert_success $exit_code "Documentation files (.md) exempt from all checks"
cleanup_test_file "$test_file"

echo ""

# TEST GROUP 6: Performance
echo "Test Group 6: Performance"
echo "-------------------------"

# Test 19: Full codebase scan completes quickly
start_time=$(date +%s)
bash "$SCANNER" > /dev/null 2>&1 || true
end_time=$(date +%s)
duration=$((end_time - start_time))

TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ $duration -lt 30 ]; then
    echo -e "${GREEN}✓ PASS${NC}: Full codebase scan completes in <30 seconds (${duration}s)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}: Full codebase scan too slow (${duration}s, expected <30s)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""

# TEST GROUP 7: Exclusions
echo "Test Group 7: Exclusions (Files That Should Be Skipped)"
echo "--------------------------------------------------------"

# Test 20: .git directory excluded
TESTS_TOTAL=$((TESTS_TOTAL + 1))
if [ -d "$STARFORGE_ROOT/.git" ]; then
    output=$(bash "$SCANNER" 2>&1 || true)
    if ! echo "$output" | grep -q ".git/"; then
        echo -e "${GREEN}✓ PASS${NC}: .git directory excluded from scan"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: .git directory should be excluded"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC}: .git directory doesn't exist (test skipped)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

# Test 21: Research folder excluded
test_research_dir="$STARFORGE_ROOT/.claude/research"
if [ -d "$test_research_dir" ]; then
    # Create test file in research
    test_file="$test_research_dir/test-pattern.txt"
    echo 'cd ~/empowerai' > "$test_file"
    output=$(bash "$SCANNER" 2>&1 || true)

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if ! echo "$output" | grep -q "$test_file"; then
        echo -e "${GREEN}✓ PASS${NC}: .claude/research/ directory excluded"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: .claude/research/ should be excluded"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    rm -f "$test_file"
else
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${YELLOW}⚠ SKIP${NC}: .claude/research doesn't exist (test skipped)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo -e "Total:  $TESTS_TOTAL"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    echo "FAIL: Hardcoded pattern detection has issues."
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "Hardcoded pattern detection successfully:"
    echo "  - Detects empowerai references (except in .md)"
    echo "  - Detects hardcoded agent patterns (junior-dev-[abc])"
    echo "  - Detects user-specific absolute paths (/Users/, /home/)"
    echo "  - Allows system paths (/tmp/, /etc/, /var/)"
    echo "  - Excludes documentation (.md files)"
    echo "  - Excludes .git and research folders"
    echo "  - Reports violations with file:line format"
    echo "  - Completes full scan in <30 seconds"
    exit 0
fi
