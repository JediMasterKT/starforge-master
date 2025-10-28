#!/bin/bash
# tests/integration/test_teacher_agent.sh
#
# Integration tests for Teacher Agent (Ticket #227)
# Tests teaching modes, workflow, and skill integration
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Test 1: Verify teacher agent definition
test_teacher_agent_exists() {
    echo "Test 1: Verify teacher agent definition exists..."

    if [ ! -f "$PROJECT_ROOT/templates/agents/teacher-agent.md" ]; then
        echo "FAIL: teacher-agent.md does not exist"
        return 1
    fi

    if ! grep -q "name: teacher-agent" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing 'name: teacher-agent' in frontmatter"
        return 1
    fi

    if ! grep -q "skill-creator" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing skill-creator integration"
        return 1
    fi

    if ! grep -q "mcp-builder" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing mcp-builder integration"
        return 1
    fi

    if ! grep -q "starforge-agent-protocol" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing starforge-agent-protocol integration"
        return 1
    fi

    if ! grep -q "algorithmic-art" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing algorithmic-art integration"
        return 1
    fi

    if ! grep -q "webapp-testing" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing webapp-testing integration"
        return 1
    fi

    echo "PASS: Teacher agent definition complete with all required skills"
    return 0
}

# Test 2: Verify all teaching modes documented
test_teaching_modes_exist() {
    echo "Test 2: Verify all 4 teaching modes exist..."

    if ! grep -q "Concept Mode" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Concept Mode"
        return 1
    fi

    if ! grep -q "Problem Mode" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Problem Mode (Polya)"
        return 1
    fi

    if ! grep -q "Directness Mode" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Directness Mode"
        return 1
    fi

    if ! grep -q "Mastery Mode" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Mastery Mode (Ultralearning)"
        return 1
    fi

    echo "PASS: All 4 teaching modes documented"
    return 0
}

# Test 3: Verify 5-step workflow
test_workflow_steps_exist() {
    echo "Test 3: Verify 5-step teaching workflow..."

    # Check for workflow steps
    if ! grep -qi "assess" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Step 1: Assess"
        return 1
    fi

    if ! grep -qi "create.*module\|module.*create" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Step 2: Create Module"
        return 1
    fi

    if ! grep -qi "teach" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Step 3: Teach"
        return 1
    fi

    if ! grep -qi "evaluate" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Step 4: Evaluate"
        return 1
    fi

    if ! grep -qi "iterate\|next module" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing Step 5: Iterate"
        return 1
    fi

    echo "PASS: 5-step workflow documented"
    return 0
}

# Test 4: Verify YAML frontmatter structure
test_frontmatter_structure() {
    echo "Test 4: Verify YAML frontmatter structure..."

    if ! grep -q "^---$" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing YAML frontmatter delimiters"
        return 1
    fi

    if ! grep -q "^name:" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing 'name' field"
        return 1
    fi

    if ! grep -q "^description:" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing 'description' field"
        return 1
    fi

    if ! grep -q "^tools:" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing 'tools' field"
        return 1
    fi

    if ! grep -q "^skills:" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing 'skills' field"
        return 1
    fi

    if ! grep -q "^color:" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing 'color' field"
        return 1
    fi

    # Verify Skill tool is in tools list
    if ! grep -A5 "^tools:" "$PROJECT_ROOT/templates/agents/teacher-agent.md" | grep -q "Skill"; then
        echo "FAIL: 'Skill' not in tools list"
        return 1
    fi

    echo "PASS: YAML frontmatter structure correct"
    return 0
}

# Test 5: Verify use cases documented
test_use_cases_exist() {
    echo "Test 5: Verify use cases documented..."

    # Check for key use case concepts
    if ! grep -qi "onboard\|onboarding" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing onboarding use case"
        return 1
    fi

    if ! grep -qi "trigger\|worktree\|coordination" "$PROJECT_ROOT/templates/agents/teacher-agent.md"; then
        echo "FAIL: Missing StarForge-specific teaching content"
        return 1
    fi

    echo "PASS: Use cases documented"
    return 0
}

# Run all tests
main() {
    echo "================================"
    echo "Teacher Agent Integration Tests"
    echo "================================"
    echo ""

    TESTS_PASSED=0
    TESTS_FAILED=0

    for test_func in test_teacher_agent_exists test_teaching_modes_exist test_workflow_steps_exist test_frontmatter_structure test_use_cases_exist; do
        if $test_func; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
        echo ""
    done

    echo "================================"
    echo "Test Summary"
    echo "================================"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo "ALL TESTS PASSED"
        return 0
    else
        echo "SOME TESTS FAILED"
        return 1
    fi
}

main
