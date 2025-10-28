#!/usr/bin/env bash
#
# Integration tests for Teacher Agent Effectiveness Validation (Issue #228)
#
# Tests teacher-agent's ability to onboard developers and transfer knowledge
# with measurable outcomes: time, retention, mastery, satisfaction
#

set -e

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Session tracking
SESSION_START=""
SESSION_END=""
ONBOARDING_DURATION=0
FIRST_SUCCESS_TIME=0

# Metrics storage
RETENTION_SCORE=0
MASTERY_SCORE=0
SATISFACTION_SCORE=0

# Helper: Assert less than
assert_less_than() {
  local threshold=$1
  local actual=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if (( $(echo "$actual < $threshold" | bc -l) )); then
    echo -e "${GREEN}✓${NC} $message (actual: $actual < $threshold)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Threshold: $threshold"
    echo "  Actual: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Assert greater than
assert_greater_than() {
  local threshold=$1
  local actual=$2
  local message=$3

  TESTS_RUN=$((TESTS_RUN + 1))

  if (( $(echo "$actual > $threshold" | bc -l) )); then
    echo -e "${GREEN}✓${NC} $message (actual: $actual > $threshold)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  Threshold: $threshold"
    echo "  Actual: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Assert file exists
assert_file_exists() {
  local file=$1
  local message=$2

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -f "$file" ]; then
    echo -e "${GREEN}✓${NC} $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $message"
    echo "  File not found: $file"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi
}

# Helper: Calculate duration in minutes
calculate_duration_minutes() {
  local start=$1
  local end=$2
  echo "scale=2; ($end - $start) / 60" | bc -l
}

#
# TEST 1: Onboarding Time Under 1 Hour
#
test_onboarding_time_under_1_hour() {
  echo -e "\n${YELLOW}TEST 1: Onboarding Time < 1 Hour${NC}"

  # Check if teaching session file exists with timestamps
  local session_file=".claude/teaching-sessions/session-228-trigger-onboarding.md"

  if [ ! -f "$session_file" ]; then
    echo -e "${RED}✗${NC} Teaching session not documented"
    echo "  Missing file: $session_file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Extract start and end timestamps from session file
  SESSION_START=$(grep -m1 "^Start Time:" "$session_file" | awk '{print $3}')
  SESSION_END=$(grep -m1 "^End Time:" "$session_file" | awk '{print $3}')

  if [ -z "$SESSION_START" ] || [ -z "$SESSION_END" ]; then
    echo -e "${RED}✗${NC} Session timestamps not found in $session_file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Calculate duration in minutes
  ONBOARDING_DURATION=$(calculate_duration_minutes "$SESSION_START" "$SESSION_END")

  # Target: < 60 minutes
  assert_less_than 60 "$ONBOARDING_DURATION" "Onboarding completed under 1 hour"
}

#
# TEST 2: Knowledge Retention Above 80%
#
test_knowledge_retention_above_80() {
  echo -e "\n${YELLOW}TEST 2: Knowledge Retention > 80%${NC}"

  # Check if retention assessment was completed
  local assessment_file="tests/integration/assessments/trigger-knowledge-retention.sh"

  if [ ! -f "$assessment_file" ]; then
    echo -e "${RED}✗${NC} Retention assessment not created"
    echo "  Missing file: $assessment_file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Run retention assessment and capture score
  # Assessment script should output: "SCORE: XX.XX"
  local assessment_output
  assessment_output=$(bash "$assessment_file" 2>&1 || true)

  RETENTION_SCORE=$(echo "$assessment_output" | grep "^SCORE:" | awk '{print $2}')

  if [ -z "$RETENTION_SCORE" ]; then
    echo -e "${RED}✗${NC} Retention score not found in assessment output"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Target: > 80%
  assert_greater_than 80 "$RETENTION_SCORE" "Knowledge retention above 80%"
}

#
# TEST 3: Skill Mastery Above 70%
#
test_skill_mastery_above_70() {
  echo -e "\n${YELLOW}TEST 3: Skill Mastery > 70%${NC}"

  # Check if mastery challenge was completed
  local challenge_file="tests/integration/assessments/trigger-mastery-challenge.sh"

  if [ ! -f "$challenge_file" ]; then
    echo -e "${RED}✗${NC} Mastery challenge not created"
    echo "  Missing file: $challenge_file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Run mastery challenge and capture score
  # Challenge script should output: "SCORE: XX.XX"
  local challenge_output
  challenge_output=$(bash "$challenge_file" 2>&1 || true)

  MASTERY_SCORE=$(echo "$challenge_output" | grep "^SCORE:" | awk '{print $2}')

  if [ -z "$MASTERY_SCORE" ]; then
    echo -e "${RED}✗${NC} Mastery score not found in challenge output"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Target: > 70%
  assert_greater_than 70 "$MASTERY_SCORE" "Skill mastery above 70%"
}

#
# TEST 4: Developer Satisfaction Above 4/5
#
test_developer_satisfaction_above_4() {
  echo -e "\n${YELLOW}TEST 4: Developer Satisfaction > 4.0/5.0${NC}"

  # Check if satisfaction survey was completed
  local survey_file="tests/integration/assessments/satisfaction-survey.md"

  if [ ! -f "$survey_file" ]; then
    echo -e "${RED}✗${NC} Satisfaction survey not completed"
    echo "  Missing file: $survey_file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Extract survey scores (questions 1-4 are numeric 1-5 scale)
  local q1 q2 q3 q4
  q1=$(grep -m1 "^Q1 Score:" "$survey_file" | awk '{print $3}')
  q2=$(grep -m1 "^Q2 Score:" "$survey_file" | awk '{print $3}')
  q3=$(grep -m1 "^Q3 Score:" "$survey_file" | awk '{print $3}')
  q4=$(grep -m1 "^Q4 Score:" "$survey_file" | awk '{print $3}')

  if [ -z "$q1" ] || [ -z "$q2" ] || [ -z "$q3" ] || [ -z "$q4" ]; then
    echo -e "${RED}✗${NC} Survey scores incomplete in $survey_file"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Calculate average
  SATISFACTION_SCORE=$(echo "scale=2; ($q1 + $q2 + $q3 + $q4) / 4" | bc -l)

  # Target: > 4.0/5.0
  assert_greater_than 4.0 "$SATISFACTION_SCORE" "Developer satisfaction above 4.0/5.0"
}

#
# TEST 5: Time to First Trigger Success Under 15 Minutes
#
test_time_to_first_trigger_under_15_min() {
  echo -e "\n${YELLOW}TEST 5: First Trigger Success < 15 Minutes${NC}"

  # Check teaching session for first success timestamp
  local session_file=".claude/teaching-sessions/session-228-trigger-onboarding.md"

  if [ ! -f "$session_file" ]; then
    echo -e "${RED}✗${NC} Teaching session not documented"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Extract first success timestamp
  local first_success_ts
  first_success_ts=$(grep -m1 "^First Success Time:" "$session_file" | awk '{print $4}')

  if [ -z "$SESSION_START" ] || [ -z "$first_success_ts" ]; then
    echo -e "${RED}✗${NC} First success timestamp not found"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
  fi

  # Calculate time to first success in minutes
  FIRST_SUCCESS_TIME=$(calculate_duration_minutes "$SESSION_START" "$first_success_ts")

  # Target: < 15 minutes
  assert_less_than 15 "$FIRST_SUCCESS_TIME" "First trigger created under 15 minutes"
}

#
# MAIN TEST RUNNER
#
main() {
  echo "========================================"
  echo "Teacher Agent Effectiveness Validation"
  echo "Issue #228"
  echo "========================================"

  # Run all tests
  test_onboarding_time_under_1_hour || true
  test_knowledge_retention_above_80 || true
  test_skill_mastery_above_70 || true
  test_developer_satisfaction_above_4 || true
  test_time_to_first_trigger_under_15_min || true

  # Summary
  echo ""
  echo "========================================"
  echo -e "Tests Run: ${TESTS_RUN}"
  echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
  echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
  echo "========================================"

  # Metrics summary
  echo ""
  echo "METRICS SUMMARY:"
  echo "----------------"
  [ -n "$ONBOARDING_DURATION" ] && echo "Onboarding Time: ${ONBOARDING_DURATION} minutes (target: < 60)"
  [ -n "$RETENTION_SCORE" ] && echo "Knowledge Retention: ${RETENTION_SCORE}% (target: > 80%)"
  [ -n "$MASTERY_SCORE" ] && echo "Skill Mastery: ${MASTERY_SCORE}% (target: > 70%)"
  [ -n "$SATISFACTION_SCORE" ] && echo "Developer Satisfaction: ${SATISFACTION_SCORE}/5.0 (target: > 4.0)"
  [ -n "$FIRST_SUCCESS_TIME" ] && echo "Time to First Success: ${FIRST_SUCCESS_TIME} minutes (target: < 15)"

  # Exit with appropriate code
  if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All validation criteria met!${NC}"
    exit 0
  else
    echo ""
    echo -e "${RED}✗ Validation incomplete or criteria not met${NC}"
    exit 1
  fi
}

# Run tests
main "$@"
