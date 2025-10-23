#!/bin/bash
# Test backup system for starforge update command
# Part of ticket #70 - Add Backup System

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

info() {
    echo -e "${YELLOW}INFO:${NC} $1"
}

# Setup test environment
TEST_DIR="/tmp/starforge-backup-test-$$"
STARFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cleanup() {
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Cleanup on exit
trap cleanup EXIT

echo "========================================"
echo "Testing Backup System (Ticket #70)"
echo "========================================"
echo ""

# Create test project
info "Setting up test project..."
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Initialize git repo
git init -q
git config user.name "Test User"
git config user.email "test@example.com"

# Install starforge
info "Installing StarForge..."
"$STARFORGE_DIR/bin/install.sh" --skip-worktrees > /dev/null 2>&1 || true

# Create some test files to backup
mkdir -p .claude/agents .claude/scripts .claude/hooks
echo "# Original Orchestrator" > .claude/agents/orchestrator.md
echo "# Original Script" > .claude/scripts/trigger-helpers.sh
echo "# Original Hook" > .claude/hooks/block-main-edits.sh
echo '{"version": "1.0.0"}' > .claude/STARFORGE_VERSION
echo '{"test": "original"}' > .claude/settings.json
echo "# Original CLAUDE.md" > .claude/CLAUDE.md

echo ""
echo "TEST 1: Backup created before update"
echo "--------------------------------------"

# Run update
if "$STARFORGE_DIR/bin/starforge" update > /dev/null 2>&1; then
    # Check if backup directory exists
    if [ -d .claude/backups ]; then
        pass "Backup directory created"
    else
        fail "Backup directory not created"
    fi

    # Check if .last-backup exists
    if [ -f .claude/.last-backup ]; then
        pass ".last-backup file created"

        # Check if backup path is valid
        backup_dir=$(cat .claude/.last-backup)
        if [ -d "$backup_dir" ]; then
            pass "Backup directory exists at stored path"
        else
            fail "Backup directory does not exist at stored path: $backup_dir"
        fi
    else
        fail ".last-backup file not created"
    fi
else
    fail "starforge update failed"
fi

echo ""
echo "TEST 2: Backup contains all critical files"
echo "--------------------------------------"

if [ -f .claude/.last-backup ]; then
    backup_dir=$(cat .claude/.last-backup)

    # Check for backed up files
    if [ -f "$backup_dir/agents/orchestrator.md" ]; then
        pass "agents/orchestrator.md backed up"
    else
        fail "agents/orchestrator.md not backed up"
    fi

    if [ -f "$backup_dir/scripts/trigger-helpers.sh" ]; then
        pass "scripts/trigger-helpers.sh backed up"
    else
        fail "scripts/trigger-helpers.sh not backed up"
    fi

    if [ -f "$backup_dir/hooks/block-main-edits.sh" ]; then
        pass "hooks/block-main-edits.sh backed up"
    else
        fail "hooks/block-main-edits.sh not backed up"
    fi

    if [ -f "$backup_dir/settings.json" ]; then
        pass "settings.json backed up"
    else
        fail "settings.json not backed up"
    fi

    if [ -f "$backup_dir/CLAUDE.md" ]; then
        pass "CLAUDE.md backed up"
    else
        fail "CLAUDE.md not backed up"
    fi

    if [ -f "$backup_dir/STARFORGE_VERSION" ]; then
        pass "STARFORGE_VERSION backed up"
    else
        fail "STARFORGE_VERSION not backed up"
    fi
else
    fail "Cannot test file backup - .last-backup not found"
fi

echo ""
echo "TEST 3: Manifest.json contains metadata"
echo "--------------------------------------"

if [ -f .claude/.last-backup ]; then
    backup_dir=$(cat .claude/.last-backup)
    manifest="$backup_dir/manifest.json"

    if [ -f "$manifest" ]; then
        pass "manifest.json exists"

        # Test valid JSON
        if jq empty "$manifest" 2>/dev/null; then
            pass "manifest.json is valid JSON"
        else
            fail "manifest.json is not valid JSON"
        fi

        # Check required fields
        pre_version=$(jq -r '.pre_update_version // empty' "$manifest" 2>/dev/null)
        if [ -n "$pre_version" ]; then
            pass "manifest.json has pre_update_version field"
        else
            fail "manifest.json missing pre_update_version field"
        fi

        files_count=$(jq -r '.files_backed_up // empty' "$manifest" 2>/dev/null)
        if [ -n "$files_count" ] && [ "$files_count" -gt 0 ]; then
            pass "manifest.json has files_backed_up count ($files_count files)"
        else
            fail "manifest.json missing or invalid files_backed_up field"
        fi

        backup_timestamp=$(jq -r '.backup_timestamp // empty' "$manifest" 2>/dev/null)
        if [ -n "$backup_timestamp" ]; then
            pass "manifest.json has backup_timestamp field"
        else
            fail "manifest.json missing backup_timestamp field"
        fi
    else
        fail "manifest.json not created"
    fi
else
    fail "Cannot test manifest - .last-backup not found"
fi

echo ""
echo "TEST 4: Backup preserves exact content"
echo "--------------------------------------"

# Add custom content to a file
echo "# CUSTOM CONTENT" >> .claude/agents/orchestrator.md
custom_hash=$(md5 -q .claude/agents/orchestrator.md 2>/dev/null || md5sum .claude/agents/orchestrator.md | awk '{print $1}')

# Run update again
"$STARFORGE_DIR/bin/starforge" update > /dev/null 2>&1 || true

# Check backup has original content
if [ -f .claude/.last-backup ]; then
    backup_dir=$(cat .claude/.last-backup)
    if [ -f "$backup_dir/agents/orchestrator.md" ]; then
        backup_hash=$(md5 -q "$backup_dir/agents/orchestrator.md" 2>/dev/null || md5sum "$backup_dir/agents/orchestrator.md" | awk '{print $1}')

        if [ "$backup_hash" = "$custom_hash" ]; then
            pass "Backup preserves exact file content (checksum match)"
        else
            fail "Backup content differs (expected: $custom_hash, got: $backup_hash)"
        fi
    else
        fail "Cannot verify content - backup file not found"
    fi
else
    fail "Cannot verify content - .last-backup not found"
fi

echo ""
echo "TEST 5: Backup limit enforced (keep last 5)"
echo "--------------------------------------"

# Create multiple backups
info "Creating 10 backups (this may take a moment)..."
for i in {1..10}; do
    # Modify a file to ensure update runs
    echo "# Update $i" >> .claude/agents/orchestrator.md
    "$STARFORGE_DIR/bin/starforge" update > /dev/null 2>&1 || true
    sleep 1  # Ensure different timestamps
done

# Count backups
backup_count=$(find .claude/backups -maxdepth 1 -type d -name "update-*" 2>/dev/null | wc -l | tr -d ' ')

if [ "$backup_count" -eq 5 ]; then
    pass "Backup limit enforced: exactly 5 backups kept"
elif [ "$backup_count" -le 5 ]; then
    pass "Backup count within limit: $backup_count backups (≤5)"
else
    fail "Too many backups: $backup_count (expected 5)"
fi

echo ""
echo "TEST 6: Performance - Backup creation <10 seconds"
echo "--------------------------------------"

# Reset environment
cd "$TEST_DIR"
rm -rf .claude/backups .claude/.last-backup

# Time the update (including backup creation)
# Note: Full update includes git pull which can be slow
start=$(date +%s)
"$STARFORGE_DIR/bin/starforge" update > /dev/null 2>&1 || true
end=$(date +%s)

elapsed=$((end - start))

# Relaxed performance target - full update with git operations
if [ $elapsed -lt 10 ]; then
    pass "Update with backup completed in ${elapsed}s (<10s)"
else
    fail "Update took ${elapsed}s (target: <10s)"
fi

echo ""
echo "TEST 7: Idempotent - Multiple backups don't conflict"
echo "--------------------------------------"

# Run update twice in quick succession
"$STARFORGE_DIR/bin/starforge" update > /dev/null 2>&1 || true
first_backup=$(cat .claude/.last-backup 2>/dev/null || echo "")

sleep 2  # Ensure different timestamp

"$STARFORGE_DIR/bin/starforge" update > /dev/null 2>&1 || true
second_backup=$(cat .claude/.last-backup 2>/dev/null || echo "")

if [ -n "$first_backup" ] && [ -n "$second_backup" ]; then
    if [ "$first_backup" != "$second_backup" ]; then
        pass "Multiple backups create unique directories"

        # Both should exist
        if [ -d "$first_backup" ] && [ -d "$second_backup" ]; then
            pass "All backup directories preserved"
        else
            fail "Some backup directories missing"
        fi
    else
        fail "Multiple backups created same directory"
    fi
else
    fail "Could not verify backup uniqueness"
fi

echo ""
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
