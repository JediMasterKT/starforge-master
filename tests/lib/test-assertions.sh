#!/bin/bash
# Test Assertions Library for StarForge
# Provides reusable test assertion functions with colorized output

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test state
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_START_TIME=""
TEST_SUITE_NAME=""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Suite Management
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

start_test_suite() {
  local suite_name="$1"
  TEST_SUITE_NAME="$suite_name"
  TEST_START_TIME=$(date +%s)
  TESTS_RUN=0
  TESTS_PASSED=0
  TESTS_FAILED=0

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}🧪 Test Suite: ${suite_name}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

end_test_suite() {
  local end_time=$(date +%s)
  local duration=$((end_time - TEST_START_TIME))

  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}📊 Test Suite Results: ${TEST_SUITE_NAME}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Tests Run:    ${TESTS_RUN}"
  echo -e "  ${GREEN}Passed:       ${TESTS_PASSED}${NC}"
  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed:       ${TESTS_FAILED}${NC}"
  else
    echo -e "  Failed:       ${TESTS_FAILED}"
  fi
  echo -e "  Duration:     ${duration}s"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Return exit code based on failures
  if [ $TESTS_FAILED -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Assertion Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_true() {
  local condition="$1"
  local message="${2:-Assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$condition" = "true" ] || [ "$condition" = "0" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Expected: true${NC}"
    echo -e "    ${YELLOW}Got:      ${condition}${NC}"
    return 1
  fi
}

assert_false() {
  local condition="$1"
  local message="${2:-Assertion failed}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$condition" = "false" ] || [ "$condition" != "0" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Expected: false${NC}"
    echo -e "    ${YELLOW}Got:      ${condition}${NC}"
    return 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Values should be equal}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Expected: ${expected}${NC}"
    echo -e "    ${YELLOW}Got:      ${actual}${NC}"
    return 1
  fi
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local message="${3:-Values should not be equal}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ "$not_expected" != "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Should not equal: ${not_expected}${NC}"
    echo -e "    ${YELLOW}But got:          ${actual}${NC}"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should contain substring}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if echo "$haystack" | grep -q "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Haystack: ${haystack:0:100}${NC}"
    echo -e "    ${YELLOW}Needle:   ${needle}${NC}"
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should not contain substring}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! echo "$haystack" | grep -q "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Haystack: ${haystack:0:100}${NC}"
    echo -e "    ${YELLOW}Should not contain: ${needle}${NC}"
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# File System Assertions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_file_exists() {
  local file_path="$1"
  local message="${2:-File should exist: $file_path}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -f "$file_path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}File not found: ${file_path}${NC}"
    return 1
  fi
}

assert_file_not_exists() {
  local file_path="$1"
  local message="${2:-File should not exist: $file_path}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ ! -f "$file_path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}File exists but shouldn't: ${file_path}${NC}"
    return 1
  fi
}

assert_dir_exists() {
  local dir_path="$1"
  local message="${2:-Directory should exist: $dir_path}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ -d "$dir_path" ]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Directory not found: ${dir_path}${NC}"
    return 1
  fi
}

assert_file_contains() {
  local file_path="$1"
  local pattern="$2"
  local message="${3:-File should contain pattern: $pattern}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ ! -f "$file_path" ]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}File not found: ${file_path}${NC}"
    return 1
  fi

  if grep -q "$pattern" "$file_path"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}File: ${file_path}${NC}"
    echo -e "    ${YELLOW}Pattern not found: ${pattern}${NC}"
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Command Execution Assertions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_command_succeeds() {
  local command="$1"
  local message="${2:-Command should succeed: $command}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if eval "$command" &>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Command: ${command}${NC}"
    echo -e "    ${YELLOW}Exit code: $?${NC}"
    return 1
  fi
}

assert_command_fails() {
  local command="$1"
  local message="${2:-Command should fail: $command}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! eval "$command" &>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Command: ${command}${NC}"
    echo -e "    ${YELLOW}Should have failed but succeeded${NC}"
    return 1
  fi
}

assert_command_output_contains() {
  local command="$1"
  local pattern="$2"
  local message="${3:-Command output should contain: $pattern}"

  TESTS_RUN=$((TESTS_RUN + 1))

  local output=$(eval "$command" 2>&1)

  if echo "$output" | grep -q "$pattern"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Command: ${command}${NC}"
    echo -e "    ${YELLOW}Pattern: ${pattern}${NC}"
    echo -e "    ${YELLOW}Output preview: ${output:0:100}${NC}"
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# GitHub Assertions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_gh_issue_exists() {
  local issue_number="$1"
  local message="${2:-GitHub issue #$issue_number should exist}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if gh issue view "$issue_number" &>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Issue #${issue_number} not found${NC}"
    return 1
  fi
}

assert_gh_issue_contains() {
  local issue_number="$1"
  local pattern="$2"
  local message="${3:-GitHub issue #$issue_number should contain: $pattern}"

  TESTS_RUN=$((TESTS_RUN + 1))

  local issue_body=$(gh issue view "$issue_number" --json body --jq '.body' 2>/dev/null)

  if [ -z "$issue_body" ]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Issue #${issue_number} not found${NC}"
    return 1
  fi

  if echo "$issue_body" | grep -q "$pattern"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Issue #${issue_number}${NC}"
    echo -e "    ${YELLOW}Pattern not found: ${pattern}${NC}"
    return 1
  fi
}

assert_gh_pr_exists() {
  local pr_number="$1"
  local message="${2:-GitHub PR #$pr_number should exist}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if gh pr view "$pr_number" &>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}PR #${pr_number} not found${NC}"
    return 1
  fi
}

assert_gh_pr_has_label() {
  local pr_number="$1"
  local label="$2"
  local message="${3:-GitHub PR #$pr_number should have label: $label}"

  TESTS_RUN=$((TESTS_RUN + 1))

  local labels=$(gh pr view "$pr_number" --json labels --jq '.labels[].name' 2>/dev/null | tr '\n' ' ')

  if echo "$labels" | grep -qw "$label"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}PR #${pr_number}${NC}"
    echo -e "    ${YELLOW}Labels: ${labels}${NC}"
    echo -e "    ${YELLOW}Missing: ${label}${NC}"
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Process Assertions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_process_running() {
  local pid="$1"
  local message="${2:-Process should be running: PID $pid}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if kill -0 "$pid" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Process not running: PID ${pid}${NC}"
    return 1
  fi
}

assert_process_not_running() {
  local pid="$1"
  local message="${2:-Process should not be running: PID $pid}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if ! kill -0 "$pid" 2>/dev/null; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}Process still running: PID ${pid}${NC}"
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mermaid Diagram Assertions (NEW!)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

assert_mermaid_valid_syntax() {
  local mermaid_file="$1"
  local message="${2:-Mermaid diagram should have valid syntax: $mermaid_file}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ ! -f "$mermaid_file" ]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}File not found: ${mermaid_file}${NC}"
    return 1
  fi

  # Check for basic Mermaid syntax markers
  local content=$(cat "$mermaid_file")

  if echo "$content" | grep -qE "(graph|sequenceDiagram|flowchart|classDiagram)"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}No valid Mermaid diagram type found${NC}"
    return 1
  fi
}

assert_mermaid_has_file_paths() {
  local mermaid_file="$1"
  local message="${2:-Mermaid diagram should contain file paths}"

  TESTS_RUN=$((TESTS_RUN + 1))

  if [ ! -f "$mermaid_file" ]; then
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}File not found: ${mermaid_file}${NC}"
    return 1
  fi

  # Check for file path patterns (File:, src/, tests/)
  if grep -qE "(File:|src/|tests/|lib/|components/)" "$mermaid_file"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} ${message}"
    return 0
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} ${message}"
    echo -e "    ${YELLOW}No file paths found in diagram${NC}"
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Reporting
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

export_test_results_json() {
  local output_file="$1"

  cat > "$output_file" << EOF
{
  "suite": "$TEST_SUITE_NAME",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests_run": $TESTS_RUN,
  "tests_passed": $TESTS_PASSED,
  "tests_failed": $TESTS_FAILED,
  "duration_seconds": $(($(date +%s) - TEST_START_TIME)),
  "success": $([ $TESTS_FAILED -eq 0 ] && echo "true" || echo "false")
}
EOF

  echo -e "${BLUE}Test results exported to: ${output_file}${NC}"
}
