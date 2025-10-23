#!/bin/bash
# Test suite for TPM Agent
# Validates dynamic path resolution and pre-flight checks

set -e

# Test utilities
assert_exit_code() {
  local expected=$1
  local actual=$?
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL: Expected exit code $expected, got $actual"
    exit 1
  fi
  echo "PASS: Exit code $expected"
}

assert_string_not_contains() {
  local haystack="$1"
  local needle="$2"
  if echo "$haystack" | grep -q "$needle"; then
    echo "FAIL: String contains '$needle' but should not"
    exit 1
  fi
  echo "PASS: String does not contain '$needle'"
}

# Test 1: No hard-coded "empowerai" references
test_tpm_agent_no_hardcoded_paths() {
  echo "TEST: No hard-coded 'empowerai' in tpm-agent.md"

  if grep -q "empowerai" /Users/krunaaltavkar/starforge-master-junior-dev-b/templates/agents/tpm-agent.md; then
    echo "FAIL: Found hard-coded 'empowerai' references"
    grep -n "empowerai" /Users/krunaaltavkar/starforge-master-junior-dev-b/templates/agents/tpm-agent.md
    exit 1
  fi

  echo "PASS: No hard-coded 'empowerai' found"
}

# Test 2: TPM agent sources project-env.sh in pre-flight checks
test_tpm_agent_sources_project_env() {
  echo "TEST: TPM agent sources project-env.sh"

  if ! grep -q "source.*project-env.sh" /Users/krunaaltavkar/starforge-master-junior-dev-b/templates/agents/tpm-agent.md; then
    echo "FAIL: TPM agent does not source project-env.sh"
    exit 1
  fi

  echo "PASS: TPM agent sources project-env.sh"
}

# Test 3: TPM agent uses STARFORGE_MAIN_REPO variable
test_tpm_agent_uses_dynamic_vars() {
  echo "TEST: TPM agent uses STARFORGE_MAIN_REPO variable"

  if ! grep -q "STARFORGE_MAIN_REPO" /Users/krunaaltavkar/starforge-master-junior-dev-b/templates/agents/tpm-agent.md; then
    echo "FAIL: TPM agent does not use STARFORGE_MAIN_REPO"
    exit 1
  fi

  echo "PASS: TPM agent uses STARFORGE_MAIN_REPO"
}

# Test 4: TPM agent uses STARFORGE_CLAUDE_DIR for breakdown paths
test_tpm_agent_uses_claude_dir() {
  echo "TEST: TPM agent uses STARFORGE_CLAUDE_DIR"

  if ! grep -q "STARFORGE_CLAUDE_DIR" /Users/krunaaltavkar/starforge-master-junior-dev-b/templates/agents/tpm-agent.md; then
    echo "FAIL: TPM agent does not use STARFORGE_CLAUDE_DIR"
    exit 1
  fi

  echo "PASS: TPM agent uses STARFORGE_CLAUDE_DIR"
}

# Run all tests
echo "========================================"
echo "Running TPM Agent Test Suite"
echo "========================================"
echo ""

test_tpm_agent_no_hardcoded_paths
echo ""

test_tpm_agent_sources_project_env
echo ""

test_tpm_agent_uses_dynamic_vars
echo ""

test_tpm_agent_uses_claude_dir
echo ""

echo "========================================"
echo "All tests passed!"
echo "========================================"
