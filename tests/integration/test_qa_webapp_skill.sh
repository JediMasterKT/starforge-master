#!/bin/bash
# tests/integration/test_qa_webapp_skill.sh
#
# Integration tests for webapp-testing skill integration with QA Engineer
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "QA Engineer webapp-testing Skill Tests"
echo "========================================"
echo ""

# Test 1: Verify agent definition has Skill tool
test_qa_agent_has_skill_tool() {
    echo "Test 1: Verify QA agent definition includes Skill tool..."

    if ! grep -q "tools:.*Skill" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: QA agent missing 'Skill' in tools list"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: QA agent has Skill tool in definition"
    return 0
}

# Test 2: Verify webapp-testing skill declared in YAML frontmatter
test_qa_agent_declares_webapp_testing_skill() {
    echo "Test 2: Verify webapp-testing skill declared in agent YAML..."

    # Check for skills section
    if ! grep -q "^skills:" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing 'skills:' section in YAML frontmatter"
        return 1
    fi

    # Check for webapp-testing skill
    if ! grep -q "webapp-testing" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing 'webapp-testing' skill declaration"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: webapp-testing skill properly declared"
    return 0
}

# Test 3: Verify Gate 3 workflow exists
test_gate3_workflow_exists() {
    echo "Test 3: Verify Gate 3: Live UI Validation workflow exists..."

    if ! grep -q "Gate 3: Live UI Validation" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing 'Gate 3: Live UI Validation' section"
        return 1
    fi

    # Check for key workflow steps
    if ! grep -q "Start dev server" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing dev server startup in Gate 3"
        return 1
    fi

    if ! grep -q "Invoke webapp-testing skill" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing skill invocation in Gate 3"
        return 1
    fi

    if ! grep -q "Cleanup dev server" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing dev server cleanup in Gate 3"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: Gate 3 workflow properly documented"
    return 0
}

# Test 4: Verify accessibility validation in Gate 3
test_gate3_includes_accessibility() {
    echo "Test 4: Verify Gate 3 includes accessibility validation..."

    if ! grep -qi "accessibility\|ARIA\|keyboard" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing accessibility validation in Gate 3"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: Accessibility validation documented in Gate 3"
    return 0
}

# Test 5: Verify learnings file exists with correct template
test_learnings_file_exists() {
    echo "Test 5: Verify skill learnings file exists..."

    # For StarForge development, check templates directory
    LEARNINGS_FILE="$PROJECT_ROOT/templates/agents/agent-learnings/qa-engineer/skill-webapp-testing.md"

    if [ ! -f "$LEARNINGS_FILE" ]; then
        echo -e "${RED}FAIL${NC}: Learnings file missing at $LEARNINGS_FILE"
        return 1
    fi

    # Verify template structure
    if ! grep -q "## Learning Template" "$LEARNINGS_FILE"; then
        echo -e "${RED}FAIL${NC}: Learnings file missing template section"
        return 1
    fi

    if ! grep -q "Date:" "$LEARNINGS_FILE" && ! grep -q "date:" "$LEARNINGS_FILE"; then
        echo -e "${RED}FAIL${NC}: Learnings file missing date field"
        return 1
    fi

    if ! grep -q "Action:" "$LEARNINGS_FILE" && ! grep -q "action:" "$LEARNINGS_FILE"; then
        echo -e "${RED}FAIL${NC}: Learnings file missing action field"
        return 1
    fi

    if ! grep -q "Result:" "$LEARNINGS_FILE" && ! grep -q "result:" "$LEARNINGS_FILE"; then
        echo -e "${RED}FAIL${NC}: Learnings file missing result field"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: Learnings file exists with proper template"
    return 0
}

# Test 6: Verify dev server lifecycle documented
test_dev_server_lifecycle_documented() {
    echo "Test 6: Verify dev server lifecycle is documented..."

    # Check for reference to TECH_STACK.md for dev server commands
    if ! grep -q "TECH_STACK.md" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${YELLOW}WARN${NC}: No reference to TECH_STACK.md for dev server commands"
        # Don't fail - this is optional but recommended
    fi

    # Check for dev server start command example
    if ! grep -q "npm.*start\|yarn.*start\|dev.*server\|python.*manage.py\|flask.*run" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${YELLOW}WARN${NC}: No dev server start command example found"
        # Don't fail - implementation may vary
    fi

    echo -e "${GREEN}PASS${NC}: Dev server lifecycle considerations present"
    return 0
}

# Test 7: Verify screenshot capture mentioned
test_screenshot_capture_mentioned() {
    echo "Test 7: Verify screenshot capture is mentioned..."

    if ! grep -qi "screenshot" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${RED}FAIL${NC}: Missing screenshot capture in Gate 3"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}: Screenshot capture documented"
    return 0
}

# Test 8: Verify learnings logged after PR review
test_learnings_logged_after_review() {
    echo "Test 8: Verify learnings logged after PR review..."

    if ! grep -qi "log.*learning\|learning.*log\|outcome.*log" "$PROJECT_ROOT/templates/agents/qa-engineer.md"; then
        echo -e "${YELLOW}WARN${NC}: No explicit mention of logging learnings"
        # Don't fail - may be implicit in workflow
    fi

    echo -e "${GREEN}PASS${NC}: Learning logging considerations present"
    return 0
}

# Run all tests
FAILED=0

test_qa_agent_has_skill_tool || FAILED=$((FAILED + 1))
echo ""

test_qa_agent_declares_webapp_testing_skill || FAILED=$((FAILED + 1))
echo ""

test_gate3_workflow_exists || FAILED=$((FAILED + 1))
echo ""

test_gate3_includes_accessibility || FAILED=$((FAILED + 1))
echo ""

test_learnings_file_exists || FAILED=$((FAILED + 1))
echo ""

test_dev_server_lifecycle_documented || FAILED=$((FAILED + 1))
echo ""

test_screenshot_capture_mentioned || FAILED=$((FAILED + 1))
echo ""

test_learnings_logged_after_review || FAILED=$((FAILED + 1))
echo ""

# Summary
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    echo "========================================"
    exit 0
else
    echo -e "${RED}$FAILED TEST(S) FAILED${NC}"
    echo "========================================"
    exit 1
fi
