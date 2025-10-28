#!/usr/bin/env bash
#
# Knowledge Retention Assessment for StarForge Trigger Creation
# Should be administered 24 hours after teaching session
#
# Tests conceptual understanding, detail recall, application, and problem-solving
#

set -e

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Scoring
TOTAL_QUESTIONS=4
CORRECT_ANSWERS=0

echo "========================================"
echo "Knowledge Retention Assessment"
echo "StarForge Trigger Creation"
echo "========================================"
echo ""
echo "This assessment tests your understanding 24 hours after the teaching session."
echo "Answer each question to the best of your ability."
echo ""

#
# Question 1: Concept Recall
#
echo -e "${BLUE}Question 1: Concept Recall${NC}"
echo "What is a StarForge trigger and what is its purpose?"
echo ""
echo "Your answer:"
read -r answer_q1

# Grading criteria (keywords to look for)
score_q1=0
if echo "$answer_q1" | grep -qi "json\|file"; then
  ((score_q1++))
fi
if echo "$answer_q1" | grep -qi "daemon"; then
  ((score_q1++))
fi
if echo "$answer_q1" | grep -qi "agent\|invoke"; then
  ((score_q1++))
fi
if echo "$answer_q1" | grep -qi "task\|work"; then
  ((score_q1++))
fi

if [ $score_q1 -ge 3 ]; then
  echo -e "${GREEN}✓ Correct${NC} (Keywords found: $score_q1/4)"
  ((CORRECT_ANSWERS++))
else
  echo -e "${RED}✗ Incomplete${NC} (Keywords found: $score_q1/4)"
  echo "Expected: Mention of JSON file, daemon, agent invocation, task execution"
fi
echo ""

#
# Question 2: Detail Recall
#
echo -e "${BLUE}Question 2: Detail Recall${NC}"
echo "What are the THREE required fields in a trigger JSON file?"
echo ""
echo "Your answer (comma-separated):"
read -r answer_q2

# Grading
score_q2=0
if echo "$answer_q2" | grep -qi "to_agent"; then
  ((score_q2++))
fi
if echo "$answer_q2" | grep -qi "task"; then
  ((score_q2++))
fi
if echo "$answer_q2" | grep -qi "context"; then
  ((score_q2++))
fi

if [ $score_q2 -eq 3 ]; then
  echo -e "${GREEN}✓ Correct${NC} (All 3 fields identified)"
  ((CORRECT_ANSWERS++))
elif [ $score_q2 -eq 2 ]; then
  echo -e "${YELLOW}⚠ Partial${NC} (2/3 fields correct)"
  echo "Expected: to_agent, task, context"
else
  echo -e "${RED}✗ Incorrect${NC} (Found: $score_q2/3)"
  echo "Expected: to_agent, task, context"
fi
echo ""

#
# Question 3: Application
#
echo -e "${BLUE}Question 3: Application${NC}"
echo "You need to create a trigger for qa-engineer to review ticket #250."
echo "What should the filename be? (Use current timestamp format)"
echo ""
echo "Your answer:"
read -r answer_q3

# Grading (check format: YYYYMMDD-HHMMSS-qa-engineer.json)
score_q3=0
if echo "$answer_q3" | grep -qE "^[0-9]{8}-[0-9]{6}"; then
  ((score_q3++))
fi
if echo "$answer_q3" | grep -q "qa-engineer"; then
  ((score_q3++))
fi
if echo "$answer_q3" | grep -q ".json$"; then
  ((score_q3++))
fi

if [ $score_q3 -eq 3 ]; then
  echo -e "${GREEN}✓ Correct${NC} (Format: YYYYMMDD-HHMMSS-qa-engineer.json)"
  ((CORRECT_ANSWERS++))
else
  echo -e "${RED}✗ Incorrect${NC} (Format errors: $((3-score_q3)))"
  echo "Expected format: YYYYMMDD-HHMMSS-qa-engineer.json"
  echo "Example: 20251028-143022-qa-engineer.json"
fi
echo ""

#
# Question 4: Problem-Solving
#
echo -e "${BLUE}Question 4: Problem-Solving${NC}"
echo "Debug this broken trigger:"
echo ""
echo '{
  "agent": "junior-dev-a",
  "what_to_do": "Fix bug",
}'
echo ""
echo "List all errors you can find:"
read -r answer_q4

# Grading
score_q4=0
if echo "$answer_q4" | grep -qi "agent.*to_agent\|to_agent.*agent"; then
  ((score_q4++))
fi
if echo "$answer_q4" | grep -qi "what_to_do.*task\|task.*what_to_do"; then
  ((score_q4++))
fi
if echo "$answer_q4" | grep -qi "trailing.*comma\|comma"; then
  ((score_q4++))
fi
if echo "$answer_q4" | grep -qi "vague\|unclear\|specific"; then
  ((score_q4++))
fi

if [ $score_q4 -ge 3 ]; then
  echo -e "${GREEN}✓ Correct${NC} (Found $score_q4/4 errors)"
  ((CORRECT_ANSWERS++))
elif [ $score_q4 -eq 2 ]; then
  echo -e "${YELLOW}⚠ Partial${NC} (Found 2/4 errors)"
  echo "Expected errors: 'agent'→'to_agent', 'what_to_do'→'task', trailing comma, vague task"
else
  echo -e "${RED}✗ Incomplete${NC} (Found $score_q4/4 errors)"
  echo "Expected errors: 'agent'→'to_agent', 'what_to_do'→'task', trailing comma, vague task"
fi
echo ""

#
# Calculate Final Score
#
PERCENTAGE=$(echo "scale=2; ($CORRECT_ANSWERS / $TOTAL_QUESTIONS) * 100" | bc -l)

echo "========================================"
echo "Assessment Complete"
echo "========================================"
echo -e "Correct Answers: ${CORRECT_ANSWERS}/${TOTAL_QUESTIONS}"
echo -e "Retention Score: ${PERCENTAGE}%"
echo ""

if (( $(echo "$PERCENTAGE >= 80" | bc -l) )); then
  echo -e "${GREEN}✓ PASS${NC} - Knowledge retention above 80% threshold"
  echo "SCORE: $PERCENTAGE"
  exit 0
else
  echo -e "${RED}✗ FAIL${NC} - Knowledge retention below 80% threshold"
  echo "SCORE: $PERCENTAGE"
  exit 1
fi
