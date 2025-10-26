#!/bin/bash
# tests/integration/test_run_gh_command.sh
#
# Integration test for starforge_run_gh_command
#
# Verifies the generic gh command wrapper works end-to-end with real GitHub API

set -e

echo "=========================================="
echo "Integration Test: run_gh_command"
echo "=========================================="
echo ""

# Load implementation
source templates/lib/mcp-tools-github.sh

# Test 1: Run safe gh command (issue list)
echo "Test 1: Run safe gh command"
result=$(starforge_run_gh_command "issue list --limit 1 --json number,title")

# Verify it's valid JSON
if ! echo "$result" | jq . >/dev/null 2>&1; then
    echo "FAIL: Invalid JSON returned"
    exit 1
fi

# Verify it's an array
if [ "$(echo "$result" | jq 'type')" != '"array"' ]; then
    echo "FAIL: Expected JSON array"
    exit 1
fi

echo "PASS: Returns valid JSON array"
echo ""

# Test 2: Reject command injection (semicolon)
echo "Test 2: Reject command injection (semicolon)"
result=$(starforge_run_gh_command "issue list; rm -rf /" 2>&1 || true)

if ! echo "$result" | grep -q "error"; then
    echo "FAIL: Should reject command with semicolon"
    exit 1
fi

echo "PASS: Rejects semicolon injection"
echo ""

# Test 3: Reject command injection (pipe)
echo "Test 3: Reject command injection (pipe)"
result=$(starforge_run_gh_command "issue list | cat /etc/passwd" 2>&1 || true)

if ! echo "$result" | grep -q "error"; then
    echo "FAIL: Should reject command with pipe"
    exit 1
fi

echo "PASS: Rejects pipe injection"
echo ""

# Test 4: Reject empty command
echo "Test 4: Reject empty command"
result=$(starforge_run_gh_command "" 2>&1 || true)

if ! echo "$result" | grep -q "error"; then
    echo "FAIL: Should reject empty command"
    exit 1
fi

echo "PASS: Rejects empty command"
echo ""

# Test 5: Run different safe commands
echo "Test 5: Run various safe gh commands"

# Test gh api
result=$(starforge_run_gh_command "api user" 2>&1)
if ! echo "$result" | jq . >/dev/null 2>&1; then
    echo "FAIL: gh api user failed"
    exit 1
fi
echo "  PASS: gh api user"

# Test gh repo view
result=$(starforge_run_gh_command "repo view --json name" 2>&1)
if ! echo "$result" | jq . >/dev/null 2>&1; then
    echo "FAIL: gh repo view failed"
    exit 1
fi
echo "  PASS: gh repo view"

echo ""

# Test 6: Graceful error handling
echo "Test 6: Graceful error handling for invalid gh command"
result=$(starforge_run_gh_command "nonexistent subcommand" 2>&1 || true)

# Should return gh's error message, not crash
if [ -z "$result" ]; then
    echo "FAIL: Should return error message"
    exit 1
fi

echo "PASS: Returns error message for invalid gh command"
echo ""

# Test 7: Command injection with backticks
echo "Test 7: Reject command injection (backticks)"
result=$(starforge_run_gh_command 'issue list `whoami`' 2>&1 || true)

if ! echo "$result" | grep -q "error"; then
    echo "FAIL: Should reject command with backticks"
    exit 1
fi

echo "PASS: Rejects backtick injection"
echo ""

# Test 8: Command injection with $()
echo "Test 8: Reject command injection (\$())"
result=$(starforge_run_gh_command 'issue list $(whoami)' 2>&1 || true)

if ! echo "$result" | grep -q "error"; then
    echo "FAIL: Should reject command with \$()"
    exit 1
fi

echo "PASS: Rejects \$() injection"
echo ""

# Summary
echo "=========================================="
echo "ALL INTEGRATION TESTS PASSED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Safe gh commands execute correctly"
echo "  - Command injection attempts blocked"
echo "  - Empty commands rejected"
echo "  - Error handling graceful"
echo ""

exit 0
