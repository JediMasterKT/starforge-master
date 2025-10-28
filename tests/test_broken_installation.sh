#!/bin/bash
# Integration test for broken installation detection
#
# Tests the corrupted .claude/ detection and recovery mechanism

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

# Helper function to report test results
pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    FAILED=$((FAILED + 1))
}

# Get path to starforge BEFORE changing directories
SCRIPT_LOCATION="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_BIN="$SCRIPT_LOCATION/../bin/starforge"

# Setup test environment
TEST_DIR=$(mktemp -d)
echo "Test directory: $TEST_DIR"
cd "$TEST_DIR"

# Initialize git repo (required for starforge install)
git init
git config user.name "Test User"
git config user.email "test@test.com"

echo ""
echo "=========================================="
echo "Test 1: Detect corrupted settings.json"
echo "=========================================="
mkdir -p .claude/agents .claude/hooks .claude/scripts
echo "invalid json" > .claude/settings.json
touch .claude/CLAUDE.md

# Run install - should detect corruption
output=$($STARFORGE_BIN install 2>&1 || true)

if echo "$output" | grep -q "corrupted"; then
    pass "Detected corrupted settings.json"
else
    fail "Did not detect corrupted settings.json"
fi

# Cleanup
rm -rf .claude

echo ""
echo "=========================================="
echo "Test 2: Detect missing CLAUDE.md"
echo "=========================================="
mkdir -p .claude/agents .claude/hooks .claude/scripts
echo '{}' > .claude/settings.json

# Run install - should detect corruption
output=$($STARFORGE_BIN install 2>&1 || true)

if echo "$output" | grep -q "corrupted"; then
    pass "Detected missing CLAUDE.md"
else
    fail "Did not detect missing CLAUDE.md"
fi

# Cleanup
rm -rf .claude

echo ""
echo "=========================================="
echo "Test 3: Detect missing required directories"
echo "=========================================="
mkdir -p .claude
echo '{}' > .claude/settings.json
touch .claude/CLAUDE.md
# Missing agents/, hooks/, scripts/ directories

# Run install - should detect corruption
output=$($STARFORGE_BIN install 2>&1 || true)

if echo "$output" | grep -q "corrupted"; then
    pass "Detected missing required directories"
else
    fail "Did not detect missing required directories"
fi

# Cleanup
rm -rf .claude

echo ""
echo "=========================================="
echo "Test 4: Accept clean installation"
echo "=========================================="
# No .claude directory at all - should proceed normally without corruption warning
if [ -d .claude ]; then
    rm -rf .claude
fi

# Run install - should NOT detect corruption (just install fresh)
output=$($STARFORGE_BIN install 2>&1 <<< "n" || true)

if echo "$output" | grep -q "corrupted"; then
    fail "False positive: detected corruption on clean install"
else
    pass "Clean installation proceeded without corruption warning"
fi

# Cleanup
rm -rf .claude

echo ""
echo "=========================================="
echo "Test 5: Backup creates timestamped directory"
echo "=========================================="
mkdir -p .claude/agents .claude/hooks .claude/scripts
echo "invalid json" > .claude/settings.json
touch .claude/CLAUDE.md
echo "test content" > .claude/test-file.txt

# Run install and accept backup
output=$($STARFORGE_BIN install 2>&1 <<< "y" || true)

if [ -d .claude/backups ]; then
    backup_count=$(find .claude/backups -maxdepth 1 -type d -name "corrupted-*" | wc -l | tr -d ' ')
    if [ "$backup_count" -ge 1 ]; then
        pass "Backup directory created"

        # Verify test-file.txt was backed up
        backup_dir=$(find .claude/backups -maxdepth 1 -type d -name "corrupted-*" | head -1)
        if [ -f "$backup_dir/test-file.txt" ]; then
            pass "Files were backed up to timestamped directory"
        else
            fail "Files were not backed up"
        fi
    else
        fail "No backup directory created"
    fi
else
    fail "No backups directory exists"
fi

# Cleanup test directory
cd /
rm -rf "$TEST_DIR"

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
