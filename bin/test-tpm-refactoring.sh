#!/bin/bash
# Integration test for tpm-agent.md refactoring
# Validates that all helper functions are properly integrated

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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 TPM Agent Refactoring Integration Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TPM_AGENT_FILE="$STARFORGE_ROOT/.claude/agents/tpm-agent.md"

# Test 1: Verify helper script sourcing
echo "Test 1: Verify helper scripts are sourced in tpm-agent.md"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "source.*context-helpers.sh" "$TPM_AGENT_FILE" && \
   grep -q "source.*github-helpers.sh" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} Helper scripts are sourced"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Helper scripts not properly sourced"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 2: Verify get_project_context usage
echo ""
echo "Test 2: Verify get_project_context replaces piped cat command"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_project_context" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_project_context is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_project_context not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 3: Verify get_building_summary usage
echo ""
echo "Test 3: Verify get_building_summary replaces grep pipe"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_building_summary" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_building_summary is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_building_summary not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 4: Verify get_primary_tech usage
echo ""
echo "Test 4: Verify get_primary_tech replaces grep pipe"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_primary_tech" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_primary_tech is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_primary_tech not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 5: Verify check_gh_auth usage
echo ""
echo "Test 5: Verify check_gh_auth replaces gh auth status"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "check_gh_auth" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} check_gh_auth is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} check_gh_auth not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 6: Verify get_ready_ticket_count usage
echo ""
echo "Test 6: Verify get_ready_ticket_count replaces gh issue list pipe"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_ready_ticket_count" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_ready_ticket_count is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_ready_ticket_count not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 7: Verify get_backlog_ticket_count usage
echo ""
echo "Test 7: Verify get_backlog_ticket_count replaces gh issue list pipe"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_backlog_ticket_count" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_backlog_ticket_count is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_backlog_ticket_count not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 8: Verify get_latest_issue_number usage
echo ""
echo "Test 8: Verify get_latest_issue_number replaces gh issue list --jq pipe"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_latest_issue_number" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_latest_issue_number is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_latest_issue_number not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 9: Verify get_latest_trigger usage
echo ""
echo "Test 9: Verify get_latest_trigger replaces ls pipe"
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q "get_latest_trigger" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} get_latest_trigger is used"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} get_latest_trigger not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 10: Verify old piped commands removed (context reading)
echo ""
echo "Test 10: Verify old 'cat ... | head -15' context reading removed"
TESTS_RUN=$((TESTS_RUN + 1))
if ! grep -q "cat.*PROJECT_CONTEXT.md.*|.*head" "$TPM_AGENT_FILE"; then
    echo -e "  ${GREEN}✓${NC} Old piped context reading removed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Old piped context reading still present"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Test 11: Verify old queue check commands removed
echo ""
echo "Test 11: Verify old 'gh issue list ... | jq length' removed from queue check"
TESTS_RUN=$((TESTS_RUN + 1))
# Check specifically in the queue check section (lines around check_queue function)
if grep -A 10 "check_queue()" "$TPM_AGENT_FILE" | grep -q "get_ready_ticket_count"; then
    echo -e "  ${GREEN}✓${NC} Queue check uses helper functions"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "  ${RED}✗${NC} Queue check doesn't use helper functions"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Total:  $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "Failed: 0"
fi
echo ""

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}✅ All refactoring checks passed!${NC}"
echo ""
exit 0
