#!/bin/bash
# Test Helpers
# Purpose: Eliminate permission prompts from piped test commands
# Workaround for: https://github.com/anthropics/claude-code/issues/5465

# Run tests with coverage and save output
# Replaces: pytest --cov=src --cov-report=term-missing | tee coverage.txt
run_tests_with_coverage() {
    local test_path=${1:-"tests/"}
    local coverage_path=${2:-"src"}
    local output_file=${3:-"coverage.txt"}

    # Get test command from TECH_STACK.md if available
    local test_cmd="pytest"
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        test_cmd=$(grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2)
    fi

    # Run tests with coverage
    $test_cmd --cov="$coverage_path" --cov-report=term-missing "$test_path" | tee "$output_file"

    return ${PIPESTATUS[0]}  # Return pytest exit code, not tee
}

# Extract coverage percentage from coverage report
# Replaces: grep 'TOTAL' coverage.txt | awk '{print $4}' | tr -d '%'
get_coverage_percentage() {
    local coverage_file=${1:-"coverage.txt"}

    if [ ! -f "$coverage_file" ]; then
        echo "❌ Coverage file not found: $coverage_file"
        return 1
    fi

    local coverage=$(grep 'TOTAL' "$coverage_file" | awk '{print $4}' | tr -d '%')

    if [ -z "$coverage" ]; then
        echo "0"
        return 1
    fi

    echo "$coverage"
}

# Count functions missing docstrings
# Replaces: grep -r "def " --include="*.py" src/ | grep -v '"""' | wc -l
check_missing_docstrings() {
    local source_path=${1:-"src/"}

    if [ ! -d "$source_path" ]; then
        echo "0"
        return 1
    fi

    local missing=$(grep -r "def " --include="*.py" "$source_path" | grep -v '"""' | wc -l | tr -d ' ')

    echo "$missing"
}

# Run specific test suite
# Replaces: pytest tests/integration/test_pr_*.py -v
run_test_suite() {
    local test_pattern=$1

    if [ -z "$test_pattern" ]; then
        echo "❌ Test pattern required"
        return 1
    fi

    # Get test command from TECH_STACK.md if available
    local test_cmd="pytest"
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        test_cmd=$(grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2)
    fi

    $test_cmd "$test_pattern" -v

    return $?
}

# Run regression tests (all tests except integration)
# Replaces: pytest tests/ -v --ignore=tests/integration/test_pr_${PR_NUMBER}_integration.py
run_regression_tests() {
    local ignore_pattern=$1

    # Get test command from TECH_STACK.md if available
    local test_cmd="pytest"
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        test_cmd=$(grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2)
    fi

    if [ -n "$ignore_pattern" ]; then
        $test_cmd tests/ -v --ignore="$ignore_pattern"
    else
        $test_cmd tests/ -v
    fi

    return $?
}

# Check test results summary
# Replaces: pytest --tb=no -q | tail -1
get_test_summary() {
    local test_path=${1:-"tests/"}

    # Get test command from TECH_STACK.md if available
    local test_cmd="pytest"
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        test_cmd=$(grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2)
    fi

    $test_cmd "$test_path" --tb=no -q 2>&1 | tail -1
}

# Verify all tests pass (returns 0 if all pass, 1 otherwise)
verify_tests_passing() {
    local test_path=${1:-"tests/"}

    # Get test command from TECH_STACK.md if available
    local test_cmd="pytest"
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        test_cmd=$(grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2)
    fi

    $test_cmd "$test_path" -q > /dev/null 2>&1

    return $?
}

# Count test cases in a test file or directory
# Replaces: pytest tests/test_feature.py --co -q | wc -l | tr -d ' '
count_test_cases() {
    local test_path=$1

    if [ -z "$test_path" ]; then
        echo "❌ Test path required"
        return 1
    fi

    # Get test command from TECH_STACK.md if available
    local test_cmd="pytest"
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        test_cmd=$(grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2)
    fi

    # Count tests using --collect-only
    local count=$($test_cmd "$test_path" --co -q 2>/dev/null | wc -l | tr -d ' ')

    if [ -z "$count" ]; then
        echo "0"
        return 1
    fi

    echo "$count"
}
