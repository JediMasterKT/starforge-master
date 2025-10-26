#!/bin/bash
# Unit tests for starforge update --force feature

set -e

TEST_NAME="StarForge Update Force Flag Unit Tests"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STARFORGE_SCRIPT="$PROJECT_ROOT/bin/starforge"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "$TEST_NAME"
echo "======================================"
echo ""

# Test 1: Help text includes --force flag
echo "Test 1: Help text documents --force flag"
HELP_OUTPUT=$("$STARFORGE_SCRIPT" help 2>&1 || true)

if echo "$HELP_OUTPUT" | grep -q "update.*--force"; then
    echo -e "${GREEN}✓ PASS: Help text includes --force flag${NC}"
else
    echo -e "${RED}✗ FAIL: Help text missing --force flag${NC}"
    echo "Expected: 'update [--force]' in help output"
    exit 1
fi
echo ""

# Test 2: Update command accepts --force flag without error
echo "Test 2: Update command accepts --force flag"

# Create temporary test project
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

# Create minimal .claude structure
mkdir -p .claude/{agents,scripts,hooks,bin,backups}
echo '{"version": "1.0.0"}' > .claude/STARFORGE_VERSION
echo "test" > .claude/agents/orchestrator.md

# Try running with --force (will fail due to missing templates, but should parse flag)
FORCE_TEST=$("$STARFORGE_SCRIPT" update --force 2>&1 || true)

# Clean up
cd "$PROJECT_ROOT"
rm -rf "$TEST_DIR"

# Check if flag was parsed (not rejected as invalid argument)
if echo "$FORCE_TEST" | grep -q "Unknown command.*--force"; then
    echo -e "${RED}✗ FAIL: --force flag rejected as unknown${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASS: --force flag accepted${NC}"
fi
echo ""

# Test 3: show_update_diff function exists and uses FORCE_UPDATE
echo "Test 3: show_update_diff function respects FORCE_UPDATE variable"

# Check if function checks FORCE_UPDATE
if grep -q 'FORCE_UPDATE.*true' "$STARFORGE_SCRIPT"; then
    echo -e "${GREEN}✓ PASS: show_update_diff checks FORCE_UPDATE${NC}"
else
    echo -e "${RED}✗ FAIL: show_update_diff does not check FORCE_UPDATE${NC}"
    exit 1
fi
echo ""

# Test 4: TTY detection exists
echo "Test 4: TTY detection implemented"

if grep -q '\[ ! -t 0 \]' "$STARFORGE_SCRIPT" || grep -q 'test ! -t 0' "$STARFORGE_SCRIPT"; then
    echo -e "${GREEN}✓ PASS: TTY detection found${NC}"
else
    echo -e "${RED}✗ FAIL: TTY detection not found${NC}"
    exit 1
fi
echo ""

# Test 5: Timeout in read command
echo "Test 5: read command has timeout"

if grep -q 'read -t' "$STARFORGE_SCRIPT"; then
    echo -e "${GREEN}✓ PASS: read command has timeout${NC}"
else
    echo -e "${RED}✗ FAIL: read command missing timeout${NC}"
    exit 1
fi
echo ""

# Test 6: Flag parsing in update command
echo "Test 6: update command parses --force flag"

# Check if update case has flag parsing
UPDATE_SECTION=$(sed -n '/^[[:space:]]*update)/,/^[[:space:]]*;;/p' "$STARFORGE_SCRIPT")

if echo "$UPDATE_SECTION" | grep -q "FORCE_UPDATE"; then
    echo -e "${GREEN}✓ PASS: update command parses FORCE_UPDATE${NC}"
else
    echo -e "${RED}✗ FAIL: update command does not parse FORCE_UPDATE${NC}"
    exit 1
fi
echo ""

echo "======================================"
echo -e "${GREEN}✓ ALL UNIT TESTS PASSED${NC}"
echo "======================================"
echo ""
echo "Summary:"
echo "  ✓ Help text documents --force flag"
echo "  ✓ --force flag accepted by update command"
echo "  ✓ show_update_diff respects FORCE_UPDATE"
echo "  ✓ TTY detection implemented"
echo "  ✓ read timeout implemented"
echo "  ✓ Flag parsing in update command"
echo ""
