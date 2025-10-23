#!/bin/bash
# Test: QA learnings file contains comprehensive E2E failure prevention guidance
# Related to Issue #37

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_NAME="QA Learnings E2E Failure Prevention"
PASSED=0
FAILED=0

# Find the main repo root (worktree parent)
REPO_ROOT=$(git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2)
QA_LEARNINGS="${REPO_ROOT}/.claude/agents/agent-learnings/qa-engineer/learnings.md"

echo "========================================="
echo "TEST: ${TEST_NAME}"
echo "========================================="
echo "Testing file: ${QA_LEARNINGS}"
echo ""

# Helper function to test if content exists in file
test_content_exists() {
    local description="$1"
    local pattern="$2"

    if /usr/bin/grep -q "$pattern" "$QA_LEARNINGS"; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  ${YELLOW}Missing pattern:${NC} $pattern"
        ((FAILED++))
        return 1
    fi
}

# Helper function to test if section exists
test_section_exists() {
    local description="$1"
    local section_pattern="$2"

    if /usr/bin/grep -E "$section_pattern" "$QA_LEARNINGS" > /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}: $description"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}: $description"
        echo -e "  ${YELLOW}Missing section matching:${NC} $section_pattern"
        ((FAILED++))
        return 1
    fi
}

# Test 1: File exists
echo "Test 1: QA learnings file exists"
if [ -f "$QA_LEARNINGS" ]; then
    echo -e "${GREEN}✓ PASS${NC}: QA learnings file exists"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}: QA learnings file not found"
    ((FAILED++))
    exit 1
fi

echo ""

# Test 2: Configuration Variation Testing section
echo "Test 2: Configuration Variation Testing Requirements"
test_section_exists \
    "Section: Configuration Variation Testing" \
    "##.*Configuration.*Variation|Configuration.*Variation.*Testing"

test_content_exists \
    "Mentions testing with 1 agent" \
    "1 agent"

test_content_exists \
    "Mentions testing with 3 agents" \
    "3 agents"

test_content_exists \
    "Mentions testing with 10 agents" \
    "10 agents"

echo ""

# Test 3: Enhanced Testing Checklist
echo "Test 3: Enhanced Testing Checklist"
test_section_exists \
    "Section: Enhanced Testing Checklist" \
    "##.*Enhanced.*Testing|Testing.*Checklist|Checklist"

test_content_exists \
    "Checklist for minimum configuration" \
    "minimum\|min"

test_content_exists \
    "Checklist for maximum configuration" \
    "maximum\|max"

test_content_exists \
    "Checklist for edge cases" \
    "edge case\|Edge Case"

echo ""

# Test 4: Claim Validation Process
echo "Test 4: Claim Validation Process"
test_section_exists \
    "Section: Claim Validation" \
    "##.*Claim.*Validation|Validat.*Claim"

test_content_exists \
    "Validation for 'project-agnostic' claims" \
    "project-agnostic"

test_content_exists \
    "Grep for hardcoded values" \
    "grep.*hardcoded\|hardcoded.*grep"

test_content_exists \
    "Grep for hardcoded paths" \
    "path"

test_content_exists \
    "Grep for hardcoded agent names" \
    "agent.*name\|name.*agent"

echo ""

# Test 5: E2E Testing Scenarios
echo "Test 5: E2E Testing Scenarios"
test_section_exists \
    "Section: E2E Testing Scenarios" \
    "##.*E2E|##.*End.*to.*End|##.*Integration.*Test"

test_content_exists \
    "Fresh installation testing" \
    "fresh install\|Fresh Install\|new project"

test_content_exists \
    "Different configurations testing" \
    "different.*configuration\|configuration.*variation"

test_content_exists \
    "Different project names testing" \
    "project name"

echo ""

# Test 6: Common Failure Patterns
echo "Test 6: Common Failure Patterns to Watch For"
test_section_exists \
    "Section: Common Failure Patterns" \
    "##.*Failure.*Pattern|##.*Common.*Failure|##.*Red Flag"

test_content_exists \
    "Watch for hardcoded names" \
    "hardcoded.*name\|name.*hardcoded"

test_content_exists \
    "Watch for hardcoded paths" \
    "hardcoded.*path\|path.*hardcoded"

test_content_exists \
    "Watch for hardcoded agent counts" \
    "agent.*count\|count.*agent\|number.*agent"

echo ""

# Test 7: Regression Prevention
echo "Test 7: Regression Prevention Strategy"
test_section_exists \
    "Section: Regression Prevention" \
    "##.*Regression|##.*Prevention"

test_content_exists \
    "Cross-reference past failures" \
    "past.*failure\|previous.*failure\|similar.*failure"

test_content_exists \
    "Document known patterns" \
    "known.*pattern\|pattern.*known"

echo ""

# Test 8: Multi-Configuration Testing
echo "Test 8: Multi-Configuration Testing Requirements"
test_content_exists \
    "Test with custom naming patterns" \
    "custom.*nam"

test_content_exists \
    "Test with different directory structures" \
    "directory.*structure\|directory.*different"

echo ""

# Test 9: Reference to Issue #36
echo "Test 9: References to Related Issues"
test_content_exists \
    "References Issue #36" \
    "#36\|Issue 36"

echo ""

# Summary
echo "========================================="
echo "TEST SUMMARY"
echo "========================================="
echo -e "Total Passed: ${GREEN}${PASSED}${NC}"
echo -e "Total Failed: ${RED}${FAILED}${NC}"
echo "========================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
