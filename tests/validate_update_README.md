# Update Validation Test

**Purpose:** Automated test to validate that `starforge update` preserves user data and updates templates correctly.

**Location:** `tests/validate_update.sh`

**Phase:** 3, Task 3.2 of the MVP plan

## What It Tests

The validation script tests 10 critical aspects of the update command:

1. **Update command completes without errors** - The update process runs successfully
2. **Junior engineer learning files preserved** - User data in `.claude/agents/agent-learnings/junior-engineer/` is not deleted
3. **Senior engineer learning files preserved** - User data in `.claude/agents/agent-learnings/senior-engineer/` is not deleted
4. **Custom learning files preserved** - Additional user-created learning files are not deleted
5. **Agent definition files updated** - Template files are updated to latest versions (OLD VERSION markers removed)
6. **Script files updated** - Script templates are refreshed with latest versions
7. **Backup directory created** - A timestamped backup is created before update
8. **Backup contains old versions** - The backup preserves the previous file versions
9. **Coordination files preserved** - Agent status files in `.claude/coordination/` are not deleted
10. **File counts correct** - Expected number of files exist after update
11. **Doctor detects no critical errors** - `starforge doctor` reports critical files and agents present

## Running the Test

### Quick Run

```bash
# From project root
bash tests/validate_update.sh
```

### With Bash 5+ (Recommended)

```bash
# Use newer bash for better compatibility
/usr/local/bin/bash tests/validate_update.sh
```

### Expected Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running StarForge Update Validation...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Test directory: /var/folders/.../starforge-update-test-XXXXXX

Setting up test environment...
✓ Test environment ready

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Running: starforge update --force
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Update command completed successfully

Check 1: Junior engineer learning files preserved
✅ User learning file preserved (junior-engineer)

Check 2: Senior engineer learning files preserved
✅ User learning file preserved (senior-engineer)

Check 3: Custom learning files preserved
✅ Custom learning file preserved

Check 4: Template files updated to latest version
✅ Agent file updated to latest version (OLD VERSION MARKER removed)

Check 5: Script files updated
✅ Script files updated

Check 6: Backup directory created
✅ Backup created (timestamp: 20251027-210940)

Check 7: Coordination files preserved (user data)
✅ Coordination files preserved

Check 8: File counts correct after update
✅ File counts correct (12 lib, 3 bin, 5 agents)

Check 9: Starforge doctor detects no critical errors
✅ Doctor detects no critical errors (critical files and agents present)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 Update validation PASSED (10/10 checks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Summary:
  ✅ Update command completes without errors
  ✅ Junior engineer learning files preserved (not deleted)
  ✅ Senior engineer learning files preserved (not deleted)
  ✅ Custom learning files preserved
  ✅ Agent definition files updated to latest versions
  ✅ Script files updated to latest versions
  ✅ Backup directory created with timestamp
  ✅ Backup contains old versions of files
  ✅ Coordination files preserved
  ✅ File counts correct after update
  ✅ starforge doctor detects no critical errors

Cleaning up test artifacts...
✓ Cleanup complete
```

## Exit Codes

- **0** - All checks passed
- **1** - One or more checks failed

## Test Scenario

The test simulates a realistic update scenario:

1. **Setup:** Creates a temporary project with a complete `.claude/` structure (as if StarForge was already installed)
2. **User Data:** Creates test learning files (junior-engineer, senior-engineer, custom learning)
3. **Old Version:** Modifies an agent file to simulate an old version (adds OLD VERSION MARKER)
4. **Run Update:** Executes `starforge update --force` (non-interactive mode)
5. **Validate:** Checks that user data is preserved and templates are updated
6. **Cleanup:** Removes temporary test directory

## Implementation Details

### Non-Interactive Mode

The test uses `--force` flag to run update non-interactively:
```bash
starforge update --force
```

This skips the interactive prompts and is suitable for CI/CD pipelines.

### Bash Version Detection

The script auto-detects the best bash version to use:
```bash
if command -v /usr/local/bin/bash >/dev/null 2>&1; then
    BASH_BIN="/usr/local/bin/bash"  # Prefer Homebrew bash 5+
else
    BASH_BIN="bash"  # Fallback to system bash
fi
```

### What Files Are Updated

The update command updates:
- Agent definitions (`.claude/agents/*.md`)
- Scripts (`.claude/scripts/*.sh`)
- Hooks (`.claude/hooks/*`)
- Bin scripts (`.claude/bin/*.sh`)
- Protocol files (`CLAUDE.md`, `LEARNINGS.md`)
- Settings (`settings.json`)

The update command **preserves** (does not modify):
- Agent learnings (`.claude/agents/agent-learnings/**/*`)
- Breakdowns (`.claude/breakdowns/`)
- Triggers (`.claude/triggers/`)
- Coordination files (`.claude/coordination/`)
- User documentation (`PROJECT_CONTEXT.md`, `TECH_STACK.md`)
- Library files (`.claude/lib/*.sh` - only updated during install)

## Troubleshooting

### Bash Version Error

If you see:
```
❌ Bash version too old: 3.2.57
```

Install bash 5+ via Homebrew:
```bash
brew install bash
```

Then run with explicit path:
```bash
/usr/local/bin/bash tests/validate_update.sh
```

### Test Fails in Check 4 or 5

If agent/script files are not being updated:
- Check that `templates/` directory exists and has the latest files
- Ensure `bin/starforge` update command is copying files correctly
- Verify file permissions (templates should be readable)

### Doctor Check Fails (Check 9)

The test is lenient on doctor failures because test environments may be minimal. As long as "Critical files present" and "Agent definitions present" are detected, the test passes.

## CI Integration

To add this test to CI pipelines:

```yaml
# .github/workflows/test.yml
- name: Validate Update Command
  run: /usr/local/bin/bash tests/validate_update.sh
```

The test is designed to:
- Run in isolated temp directory (no side effects)
- Clean up after itself automatically
- Exit with proper exit codes (0=pass, 1=fail)
- Provide detailed output for debugging

## Related Tests

- `tests/test_starforge_update_force.sh` - Unit tests for `--force` flag
- `tests/verify_update_diff.sh` - Manual verification of diff preview feature
- `tests/test_update_diff.sh` - Automated tests for diff preview

## Maintenance

When adding new files to `templates/`:
1. Update expected counts in Check 8 if needed
2. Test that new files are copied correctly in Check 5
3. Verify doctor command recognizes new files in Check 9

When modifying update logic in `bin/starforge`:
1. Run this validation test to ensure backward compatibility
2. Check that user data preservation still works
3. Verify backup system captures all changes
