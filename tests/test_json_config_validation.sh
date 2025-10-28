#!/usr/local/bin/bash
# Test: JSON Configuration Validation (Task 2.5)
#
# Tests the check_json_config() function in bin/starforge
# Requires Bash 4.0+ for starforge CLI

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

# Get absolute path to repo root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "========================================="
echo "Test: JSON Configuration Validation"
echo "========================================="
echo ""

echo "----------------------------------------"
echo "Test Suite: check_json_config()"
echo "----------------------------------------"
echo ""

# Helper to strip ANSI color codes
strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Test 1: Valid JSON with hooks.Stop configuration
echo "Test 1: Valid JSON with hooks.Stop"
TESTS_RUN=$((TESTS_RUN + 1))

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude
echo '{"hooks":{"Stop":{"path":".claude/hooks/stop.py","type":"python"}}}' > .claude/settings.json

if "$REPO_ROOT/bin/starforge" doctor 2>&1 | strip_ansi | grep -q "JSON configuration valid"; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 2: Invalid JSON syntax
echo "Test 2: Invalid JSON syntax"
TESTS_RUN=$((TESTS_RUN + 1))

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude
echo '{ invalid json' > .claude/settings.json

if "$REPO_ROOT/bin/starforge" doctor 2>&1 | strip_ansi | grep -q "not valid JSON"; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 3: Missing settings.json file
echo "Test 3: Missing settings.json file"
TESTS_RUN=$((TESTS_RUN + 1))

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude

if "$REPO_ROOT/bin/starforge" doctor 2>&1 | strip_ansi | grep -q "settings.json not found"; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 4: Valid JSON but missing hooks.Stop
echo "Test 4: Valid JSON missing hooks.Stop"
TESTS_RUN=$((TESTS_RUN + 1))

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude
echo '{"hooks":{"Start":{"path":".claude/hooks/start.sh"}}}' > .claude/settings.json

if "$REPO_ROOT/bin/starforge" doctor 2>&1 | strip_ansi | grep -q "Missing: hooks.Stop configuration"; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 5: Empty JSON object
echo "Test 5: Empty JSON object"
TESTS_RUN=$((TESTS_RUN + 1))

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude
echo '{}' > .claude/settings.json

if "$REPO_ROOT/bin/starforge" doctor 2>&1 | strip_ansi | grep -q "JSON configuration incomplete"; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

# Test 6: Error message includes jq debug command
echo "Test 6: Error message includes jq debug command"
TESTS_RUN=$((TESTS_RUN + 1))

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude
echo '{ bad json }' > .claude/settings.json

if "$REPO_ROOT/bin/starforge" doctor 2>&1 | strip_ansi | grep -q "jq.*settings.json"; then
    echo -e "${GREEN}✓ PASS${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAIL${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
cd "$REPO_ROOT"
rm -rf "$TEST_DIR"
echo ""

echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
