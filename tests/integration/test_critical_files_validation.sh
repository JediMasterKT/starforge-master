#!/usr/local/bin/bash
# Integration test for critical files validation (Task 2.3)
#
# Tests the check_critical_files() function in bin/starforge doctor command
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/../.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================"
echo "Task 2.3: Critical Files Validation"
echo "================================"
echo ""

# Setup: Create temporary test environment
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
mkdir -p .claude/hooks

echo "Test environment: $TEST_DIR"
echo ""

# Test 1: All critical files present
echo "Test 1: All critical files present"
echo "-----------------------------------"

# Create all critical files
touch .claude/CLAUDE.md
touch .claude/LEARNINGS.md
touch .claude/settings.json
touch .claude/hooks/stop.py

# Execute doctor command (strip ANSI color codes for grep)
if /usr/local/bin/bash "$PROJECT_ROOT/bin/starforge" doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Critical files present"; then
    echo -e "${GREEN}PASS${NC}: Detected all critical files present"
else
    echo -e "${RED}FAIL${NC}: Should detect all critical files present"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 1
fi

echo ""

# Test 2: Missing one critical file
echo "Test 2: Missing one critical file (CLAUDE.md)"
echo "-----------------------------------------------"

# Remove one file
rm .claude/CLAUDE.md

# Execute doctor command and capture output (strip ANSI codes)
output=$(/usr/local/bin/bash "$PROJECT_ROOT/bin/starforge" doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true)

# Check for missing file detection
if echo "$output" | grep -q "Critical files missing"; then
    echo -e "${GREEN}PASS${NC}: Detected missing critical files"
else
    echo -e "${RED}FAIL${NC}: Should detect missing critical files"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 1
fi

# Check for specific missing file listed
if echo "$output" | grep -q ".claude/CLAUDE.md"; then
    echo -e "${GREEN}PASS${NC}: Listed .claude/CLAUDE.md as missing"
else
    echo -e "${RED}FAIL${NC}: Should list .claude/CLAUDE.md as missing"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 1
fi

echo ""

# Test 3: Missing multiple critical files
echo "Test 3: Missing multiple critical files"
echo "----------------------------------------"

# Remove more files
rm .claude/settings.json
rm .claude/hooks/stop.py

# Execute doctor command and capture output (strip ANSI codes)
output=$(/usr/local/bin/bash "$PROJECT_ROOT/bin/starforge" doctor 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true)

# Check that all missing files are listed
if echo "$output" | grep -q ".claude/CLAUDE.md" && \
   echo "$output" | grep -q ".claude/settings.json" && \
   echo "$output" | grep -q ".claude/hooks/stop.py"; then
    echo -e "${GREEN}PASS${NC}: Listed all 3 missing files"
else
    echo -e "${RED}FAIL${NC}: Should list all 3 missing files"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 1
fi

echo ""

# Test 4: Exit code validation
echo "Test 4: Exit code validation"
echo "-----------------------------"

# All files present - should exit 0
touch .claude/CLAUDE.md
touch .claude/settings.json
touch .claude/hooks/stop.py

if /usr/local/bin/bash "$PROJECT_ROOT/bin/starforge" doctor > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}: Returns exit code 0 when all files present"
else
    echo -e "${RED}FAIL${NC}: Should return exit code 0 when all files present"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 1
fi

# Missing file - should exit non-zero
rm .claude/CLAUDE.md

if ! /usr/local/bin/bash "$PROJECT_ROOT/bin/starforge" doctor > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}: Returns non-zero exit code when files missing"
else
    echo -e "${RED}FAIL${NC}: Should return non-zero exit code when files missing"
    cd - > /dev/null
    rm -rf "$TEST_DIR"
    exit 1
fi

echo ""

# Teardown
cd - > /dev/null
rm -rf "$TEST_DIR"

echo "================================"
echo -e "${GREEN}ALL TESTS PASSED${NC}"
echo "================================"
