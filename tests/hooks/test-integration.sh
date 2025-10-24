#!/bin/bash
# Integration test for Stop hook with trigger-helpers

# Source project environment
source .claude/lib/project-env.sh

# Source trigger helpers
source "$STARFORGE_CLAUDE_DIR/scripts/trigger-helpers.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "Stop Hook Integration Test"
echo "========================================"
echo ""

# Clean up
echo "Cleaning up old triggers..."
rm -f "$STARFORGE_CLAUDE_DIR/triggers/"*.trigger
> "$STARFORGE_CLAUDE_DIR/agent-handoff.log"

# Test 1: Senior Engineer → TPM workflow
echo -e "${YELLOW}[TEST 1]${NC} Senior Engineer → TPM handoff"
echo "Creating trigger using trigger_create_tickets..."

trigger_create_tickets "Test Feature" 3 "/tmp/test-breakdown.md"

# Verify trigger created
if [ ! -f "$STARFORGE_CLAUDE_DIR/triggers/"tpm-create_tickets-*.trigger ]; then
    echo -e "${RED}✗ FAIL${NC} - Trigger not created"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Trigger created"

# Simulate Stop hook
echo "Running Stop hook..."
echo '{"event": "stop"}' | "$STARFORGE_CLAUDE_DIR/hooks/stop.py" 2>&1 | tee /tmp/hook-output.txt

# Verify notification shown
if ! grep -q "Next Agent: tpm" /tmp/hook-output.txt; then
    echo -e "${RED}✗ FAIL${NC} - Handoff notification not shown"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Handoff notification displayed"

# Verify trigger archived
if ls "$STARFORGE_CLAUDE_DIR/triggers/"tpm-create_tickets-*.trigger 2>/dev/null; then
    echo -e "${RED}✗ FAIL${NC} - Trigger not archived"
    exit 1
fi
if [ ! -d "$STARFORGE_CLAUDE_DIR/triggers/processed" ]; then
    echo -e "${RED}✗ FAIL${NC} - Processed directory not created"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Trigger archived to processed/"

# Verify handoff logged
if ! grep -q "senior-engineer -> tpm" "$STARFORGE_CLAUDE_DIR/agent-handoff.log"; then
    echo -e "${RED}✗ FAIL${NC} - Handoff not logged"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Handoff logged"

echo ""

# Test 2: TPM → Orchestrator workflow
echo -e "${YELLOW}[TEST 2]${NC} TPM → Orchestrator handoff"
echo "Creating trigger using trigger_work_ready..."

trigger_work_ready 5 "[42,43,44,45,46]"

# Run hook
echo '{"event": "stop"}' | "$STARFORGE_CLAUDE_DIR/hooks/stop.py" 2>&1 | tee /tmp/hook-output.txt

# Verify orchestrator notification
if ! grep -q "Next Agent: orchestrator" /tmp/hook-output.txt; then
    echo -e "${RED}✗ FAIL${NC} - Orchestrator notification not shown"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Orchestrator handoff works"

echo ""

# Test 3: Orchestrator → Junior Dev workflow
echo -e "${YELLOW}[TEST 3]${NC} Orchestrator → Junior Dev handoff"
echo "Creating trigger using trigger_junior_dev..."

trigger_junior_dev "junior-dev-a" 42

# Run hook
echo '{"event": "stop"}' | "$STARFORGE_CLAUDE_DIR/hooks/stop.py" 2>&1 | tee /tmp/hook-output.txt

# Verify junior-dev notification
if ! grep -q "Next Agent: junior-dev-a" /tmp/hook-output.txt; then
    echo -e "${RED}✗ FAIL${NC} - Junior dev notification not shown"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Junior dev handoff works"

echo ""

# Test 4: Junior Dev → QA workflow
echo -e "${YELLOW}[TEST 4]${NC} Junior Dev → QA handoff"
echo "Creating trigger using trigger_qa_review..."

trigger_qa_review "junior-dev-a" 123 42

# Run hook
echo '{"event": "stop"}' | "$STARFORGE_CLAUDE_DIR/hooks/stop.py" 2>&1 | tee /tmp/hook-output.txt

# Verify QA notification
if ! grep -q "Next Agent: qa-engineer" /tmp/hook-output.txt; then
    echo -e "${RED}✗ FAIL${NC} - QA notification not shown"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - QA handoff works"

echo ""

# Test 5: QA → Orchestrator workflow
echo -e "${YELLOW}[TEST 5]${NC} QA → Orchestrator handoff (loop)"
echo "Creating trigger using trigger_next_assignment..."

trigger_next_assignment 3 "[42,43,44]"

# Run hook
echo '{"event": "stop"}' | "$STARFORGE_CLAUDE_DIR/hooks/stop.py" 2>&1 | tee /tmp/hook-output.txt

# Verify orchestrator notification (completing the loop)
if ! grep -q "Next Agent: orchestrator" /tmp/hook-output.txt; then
    echo -e "${RED}✗ FAIL${NC} - Loop-back notification not shown"
    exit 1
fi
echo -e "${GREEN}✓ PASS${NC} - Workflow loop works"

echo ""
echo "========================================"
echo "Integration Test Summary"
echo "========================================"
echo -e "${GREEN}All 5 integration tests passed!${NC}"
echo ""
echo "Verified workflows:"
echo "  1. Senior Engineer → TPM"
echo "  2. TPM → Orchestrator"
echo "  3. Orchestrator → Junior Dev"
echo "  4. Junior Dev → QA"
echo "  5. QA → Orchestrator (loop)"
echo ""
echo "Handoff log:"
cat "$STARFORGE_CLAUDE_DIR/agent-handoff.log"
echo ""

# Cleanup
rm -f /tmp/hook-output.txt
rm -f "$STARFORGE_CLAUDE_DIR/triggers/"*.trigger

echo -e "${GREEN}✓ Integration test complete!${NC}"
