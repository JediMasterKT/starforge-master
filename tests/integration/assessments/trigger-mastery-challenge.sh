#!/usr/bin/env bash
#
# Skill Mastery Challenge for StarForge Trigger Creation
# Tests ability to create complete, valid trigger without assistance
#

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Scoring criteria (5 total)
CRITERIA_MET=0
TOTAL_CRITERIA=5

# Temporary directory for challenge
CHALLENGE_DIR=$(mktemp -d)
TRIGGER_DIR="$CHALLENGE_DIR/.claude/triggers"
mkdir -p "$TRIGGER_DIR"

echo "========================================"
echo "Skill Mastery Challenge"
echo "StarForge Trigger Creation"
echo "========================================"
echo ""
echo -e "${BLUE}Challenge:${NC}"
echo "The orchestrator needs senior-engineer to conduct a spike investigation"
echo "for ticket #150 about database optimization strategies."
echo ""
echo "Create the complete trigger from scratch WITHOUT reference documentation."
echo ""
echo "Your trigger should be placed in: $TRIGGER_DIR"
echo ""
echo -e "${YELLOW}Press Enter when you're ready to begin...${NC}"
read -r

# Start timer
START_TIME=$(date +%s)

echo ""
echo "Working directory: $CHALLENGE_DIR"
echo "You have 10 minutes. Press Enter when done."
echo ""

# Wait for completion
read -r

# Stop timer
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "Time taken: ${DURATION} seconds"
echo ""
echo "========================================"
echo "Evaluating your trigger..."
echo "========================================"
echo ""

# Find the trigger file
TRIGGER_FILE=$(find "$TRIGGER_DIR" -name "*.json" -type f | head -1)

if [ -z "$TRIGGER_FILE" ]; then
  echo -e "${RED}✗ No trigger file found${NC}"
  echo "Expected location: $TRIGGER_DIR/*.json"
  echo ""
  echo "SCORE: 0"
  rm -rf "$CHALLENGE_DIR"
  exit 1
fi

echo "Found trigger: $(basename "$TRIGGER_FILE")"
echo ""

#
# Criterion 1: Filename Format
#
echo -e "${BLUE}Criterion 1: Filename Format${NC}"
FILENAME=$(basename "$TRIGGER_FILE")

if echo "$FILENAME" | grep -qE "^[0-9]{8}-[0-9]{6}-senior-engineer\.json$"; then
  echo -e "${GREEN}✓ PASS${NC} - Correct format: YYYYMMDD-HHMMSS-senior-engineer.json"
  ((CRITERIA_MET++))
else
  echo -e "${RED}✗ FAIL${NC} - Incorrect filename format"
  echo "Expected: YYYYMMDD-HHMMSS-senior-engineer.json"
  echo "Got: $FILENAME"
fi
echo ""

#
# Criterion 2: Valid JSON Structure
#
echo -e "${BLUE}Criterion 2: Valid JSON Structure${NC}"

if jq empty "$TRIGGER_FILE" 2>/dev/null; then
  echo -e "${GREEN}✓ PASS${NC} - Valid JSON syntax"
  ((CRITERIA_MET++))
else
  echo -e "${RED}✗ FAIL${NC} - Invalid JSON syntax"
  echo "Parse errors detected"
fi
echo ""

#
# Criterion 3: Required Field - to_agent
#
echo -e "${BLUE}Criterion 3: Required Field 'to_agent'${NC}"

TO_AGENT=$(jq -r '.to_agent // empty' "$TRIGGER_FILE" 2>/dev/null)

if [ "$TO_AGENT" = "senior-engineer" ]; then
  echo -e "${GREEN}✓ PASS${NC} - Correct to_agent: senior-engineer"
  ((CRITERIA_MET++))
elif [ -n "$TO_AGENT" ]; then
  echo -e "${RED}✗ FAIL${NC} - Wrong agent: $TO_AGENT"
  echo "Expected: senior-engineer"
else
  echo -e "${RED}✗ FAIL${NC} - Missing 'to_agent' field"
fi
echo ""

#
# Criterion 4: Required Field - task (clear and specific)
#
echo -e "${BLUE}Criterion 4: Task Field (Clear & Specific)${NC}"

TASK=$(jq -r '.task // empty' "$TRIGGER_FILE" 2>/dev/null)

if [ -z "$TASK" ]; then
  echo -e "${RED}✗ FAIL${NC} - Missing 'task' field"
elif [ ${#TASK} -lt 20 ]; then
  echo -e "${RED}✗ FAIL${NC} - Task too vague (< 20 characters)"
  echo "Task: $TASK"
else
  # Check for key terms
  if echo "$TASK" | grep -qi "spike\|investigation\|150\|database\|optimization"; then
    echo -e "${GREEN}✓ PASS${NC} - Task is clear and specific"
    echo "Task: $TASK"
    ((CRITERIA_MET++))
  else
    echo -e "${YELLOW}⚠ PARTIAL${NC} - Task present but missing key details"
    echo "Expected mentions: spike, investigation, ticket #150, database, optimization"
    echo "Task: $TASK"
  fi
fi
echo ""

#
# Criterion 5: Context Object (ticket_id and priority)
#
echo -e "${BLUE}Criterion 5: Context Object${NC}"

TICKET_ID=$(jq -r '.context.ticket_id // empty' "$TRIGGER_FILE" 2>/dev/null)
PRIORITY=$(jq -r '.context.priority // empty' "$TRIGGER_FILE" 2>/dev/null)

context_score=0
if [ "$TICKET_ID" = "150" ]; then
  ((context_score++))
fi
if [ -n "$PRIORITY" ]; then
  ((context_score++))
fi

if [ $context_score -eq 2 ]; then
  echo -e "${GREEN}✓ PASS${NC} - Context includes ticket_id and priority"
  echo "ticket_id: $TICKET_ID"
  echo "priority: $PRIORITY"
  ((CRITERIA_MET++))
elif [ $context_score -eq 1 ]; then
  echo -e "${YELLOW}⚠ PARTIAL${NC} - Context partially complete (1/2)"
  [ -n "$TICKET_ID" ] && echo "ticket_id: $TICKET_ID"
  [ -n "$PRIORITY" ] && echo "priority: $PRIORITY"
else
  echo -e "${RED}✗ FAIL${NC} - Missing or incomplete context"
  echo "Expected: ticket_id=150, priority=(P0/P1/P2)"
fi
echo ""

#
# Calculate Score
#
PERCENTAGE=$(echo "scale=2; ($CRITERIA_MET / $TOTAL_CRITERIA) * 100" | bc -l)

echo "========================================"
echo "Challenge Complete"
echo "========================================"
echo -e "Criteria Met: ${CRITERIA_MET}/${TOTAL_CRITERIA}"
echo -e "Mastery Score: ${PERCENTAGE}%"
echo -e "Time Taken: ${DURATION} seconds"
echo ""

# Show the trigger content
echo "Your trigger:"
cat "$TRIGGER_FILE"
echo ""

# Cleanup
rm -rf "$CHALLENGE_DIR"

if (( $(echo "$PERCENTAGE >= 70" | bc -l) )); then
  echo -e "${GREEN}✓ PASS${NC} - Skill mastery above 70% threshold"
  echo "SCORE: $PERCENTAGE"
  exit 0
else
  echo -e "${RED}✗ FAIL${NC} - Skill mastery below 70% threshold"
  echo "SCORE: $PERCENTAGE"
  exit 1
fi
