#!/usr/local/bin/bash
# Integration Test: JSON Configuration Validation (Task 2.5)
#
# Tests the doctor command's JSON validation functionality

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Get repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STARFORGE="$REPO_ROOT/bin/starforge"

echo "=================================="
echo "JSON Configuration Validation Test"
echo "=================================="
echo ""

# Helper to strip ANSI codes
strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Test 1: Valid configuration
echo "Test 1: Valid JSON with hooks.Stop"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir .claude
echo '{"hooks":{"Stop":{"path":".claude/hooks/stop.py"}}}' > .claude/settings.json

OUTPUT=$("$STARFORGE" doctor 2>&1 | strip_ansi)
if echo "$OUTPUT" | grep -q "JSON configuration valid"; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "Expected: JSON configuration valid"
    echo "Got: $OUTPUT"
fi
TESTS_RUN=$((TESTS_RUN + 1))
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 2: Invalid JSON
echo "Test 2: Invalid JSON syntax"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir .claude
echo '{ bad json' > .claude/settings.json

OUTPUT=$("$STARFORGE" doctor 2>&1 | strip_ansi)
if echo "$OUTPUT" | grep -q "not valid JSON"; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "Expected: not valid JSON"
    echo "Got: $OUTPUT"
fi
TESTS_RUN=$((TESTS_RUN + 1))
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 3: Missing hooks.Stop
echo "Test 3: Missing hooks.Stop configuration"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir .claude
echo '{"hooks":{}}' > .claude/settings.json

OUTPUT=$("$STARFORGE" doctor 2>&1 | strip_ansi)
if echo "$OUTPUT" | grep -q "Missing: hooks.Stop configuration"; then
    echo -e "${GREEN}PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}FAIL${NC}"
    echo "Expected: Missing: hooks.Stop configuration"
    echo "Got: $OUTPUT"
fi
TESTS_RUN=$((TESTS_RUN + 1))
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Summary
echo "=================================="
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
echo "=================================="

if [ $TESTS_PASSED -eq $TESTS_RUN ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi
