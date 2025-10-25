# StarForge Helper Scripts

## Purpose

These helper scripts eliminate permission prompts in StarForge agent workflows by encapsulating piped bash commands into callable functions. This is a workaround for Claude Code's permission pattern matching bug documented in [GitHub Issue #5465](https://github.com/anthropics/claude-code/issues/5465).

## The Problem

Claude Code's permission system has two levels:
1. **Script path matching** (works): `"Bash(./.claude/scripts/* *)"`
2. **Command pattern matching** (broken): `"Bash(git *)"`

Command patterns fail to match:
- Piped commands: `git status | head -5`
- Command chains: `mkdir -p foo && cd foo`
- Commands with complex flags: `gh pr diff 135 | head -100`
- Even simple commands in some cases: `mkdir -p tests/hooks`

### Impact

Without these helpers, StarForge agents face ~60 permission prompts per ticket workflow across 100-150 tickets, resulting in **6,000-9,000 prompts** (completely unusable for autonomous workflows).

## The Solution

Helper scripts bypass the permission bug because:
1. Script invocation uses path-based matching (which works)
2. Commands inside scripts run without re-checking permissions
3. Single permission entry allows all helper scripts: `"Bash(./.claude/scripts/* *)"`

## Available Helper Scripts

### 1. context-helpers.sh

Read project context files without permission prompts.

**Functions:**
- `get_project_context()` - Get first 15 lines of PROJECT_CONTEXT.md
- `get_building_summary()` - Extract "## Building" summary
- `get_tech_stack()` - Get first 15 lines of TECH_STACK.md
- `get_primary_tech()` - Extract primary technology
- `get_test_command()` - Extract test command (e.g., `pytest`)
- `get_tech_stack_summary()` - One-liner tech summary
- `check_context_files()` - Verify context files exist

**Example:**
```bash
source .claude/scripts/context-helpers.sh

get_project_context
echo "Building: $(get_building_summary)"
TEST_CMD=$(get_test_command)
```

### 2. github-helpers.sh

GitHub CLI operations without permission prompts.

**Functions:**
- `get_ticket_from_pr <pr_number>` - Extract ticket # from PR body
- `get_pr_diff_summary <pr_number> [lines]` - Get PR diff (default 100 lines)
- `get_pr_diff_full <pr_number>` - Get complete PR diff
- `get_ready_ticket_count()` - Count tickets with "ready" label
- `get_pending_pr_count()` - Count PRs needing review
- `get_latest_trigger [agent] [action]` - Find newest trigger file
- `get_pr_details <pr_number> [fields]` - Get PR JSON
- `get_issue_details <issue_number> [fields]` - Get issue JSON
- `get_prs_by_label <label>` - List PRs with label
- `get_issues_by_label <label>` - List issues with label
- `check_gh_auth()` - Verify GitHub CLI authenticated

**Example:**
```bash
source .claude/scripts/github-helpers.sh

TICKET=$(get_ticket_from_pr 135)
get_pr_diff_summary 135 50
PENDING=$(get_pending_pr_count)
```

### 3. test-helpers.sh

Test execution and coverage analysis without permission prompts.

**Functions:**
- `run_tests_with_coverage [test_path] [coverage_path] [output_file]` - Run tests with coverage
- `get_coverage_percentage [coverage_file]` - Extract coverage %
- `check_missing_docstrings [source_path]` - Count undocumented functions
- `run_test_suite <test_pattern>` - Run specific test suite
- `run_regression_tests [ignore_pattern]` - Run all tests except ignored
- `get_test_summary [test_path]` - Get test results summary
- `verify_tests_passing [test_path]` - Check if all tests pass

**Example:**
```bash
source .claude/scripts/test-helpers.sh

run_tests_with_coverage "tests/" "src" "coverage.txt"
COVERAGE=$(get_coverage_percentage "coverage.txt")
MISSING=$(check_missing_docstrings "src/")
```

### 4. worktree-helpers.sh

Git worktree operations without permission prompts.

**Functions:**
- `get_main_repo_path()` - Get main repository path
- `is_worktree()` - Check if current dir is a worktree
- `list_worktrees()` - List all worktrees
- `get_worktree_path <branch_name>` - Get worktree path for branch
- `count_worktrees()` - Count active worktrees
- `has_worktree <branch_name>` - Check if branch has worktree
- `get_current_branch()` - Get current branch name
- `verify_main_repo()` - Verify running from main repo (not worktree)

**Example:**
```bash
source .claude/scripts/worktree-helpers.sh

if is_worktree; then
  MAIN=$(get_main_repo_path)
  echo "Running from worktree. Main repo: $MAIN"
fi
```

### 5. trigger-helpers.sh

Agent trigger creation and validation without permission prompts.

**Trigger Creation Functions:**
- `create_trigger <from> <to> <action> <message> <command> <context>` - Generic trigger
- `trigger_junior_dev <agent_id> <ticket>` - Assign ticket to junior dev
- `trigger_qa_review <agent_id> <pr_number> <ticket>` - Request QA review
- `trigger_next_assignment <count> <tickets_json>` - Request next work assignment
- `trigger_work_ready <count> <tickets_json>` - Notify work is ready
- `trigger_create_tickets <feature> <count> <file>` - Request ticket creation

**Validation Functions (Level 4):**
- `get_latest_trigger_file [agent] [action]` - Find latest trigger
- `verify_trigger_exists <trigger_file>` - Check trigger exists
- `verify_trigger_json <trigger_file>` - Validate JSON syntax
- `get_trigger_field <trigger_file> <field>` - Extract trigger field
- `verify_trigger_fields <file> <to_agent> <action>` - Verify required fields
- `verify_trigger_data_integrity <file> [count_field] [array_field]` - Check data consistency
- `verify_trigger_complete <file> <to_agent> <action>` - Full verification (all checks)
- `count_pending_triggers <agent>` - Count pending triggers
- `list_pending_triggers()` - List all pending triggers
- `archive_trigger <trigger_file>` - Move trigger to processed/

**Example:**
```bash
source .claude/scripts/trigger-helpers.sh

# Create trigger
trigger_qa_review "junior-dev-a" 135 42

# Verify trigger
TRIGGER=$(get_latest_trigger_file "qa-engineer" "review_pr")
verify_trigger_complete "$TRIGGER" "qa-engineer" "review_pr"
```

## Usage in Agents

All StarForge agents should source these helpers in their pre-flight checks:

```bash
# Source project environment
source .claude/lib/project-env.sh

# Source helper scripts (permission-free wrappers)
source $STARFORGE_CLAUDE_DIR/scripts/context-helpers.sh
source $STARFORGE_CLAUDE_DIR/scripts/github-helpers.sh
source $STARFORGE_CLAUDE_DIR/scripts/test-helpers.sh
source $STARFORGE_CLAUDE_DIR/scripts/worktree-helpers.sh
source $STARFORGE_CLAUDE_DIR/scripts/trigger-helpers.sh

# Now use helper functions instead of piped commands
get_project_context
TICKET=$(get_ticket_from_pr $PR_NUMBER)
run_tests_with_coverage
```

## Permission Configuration

The `.claude/settings.json` file must include:

```json
{
  "permissions": {
    "allow": [
      "Bash(./.claude/scripts/* *)"
    ]
  }
}
```

This single entry allows all helper scripts to run without prompts, regardless of their internal commands.

## Testing

To verify zero prompts:

```bash
# Test individual helpers
source .claude/scripts/context-helpers.sh
get_project_context  # Should not prompt

source .claude/scripts/github-helpers.sh
get_pending_pr_count  # Should not prompt

# Test full workflow (qa-engineer as proof-of-concept)
# Should complete with zero permission prompts
```

## Migration Guide

When refactoring agents to use helpers:

### Before (causes prompts):
```bash
cat $STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md | head -15
gh pr view 135 --json body --jq .body | grep -o '#[0-9]\+' | head -1 | tr -d '#'
pytest --cov=src --cov-report=term-missing | tee coverage.txt
```

### After (no prompts):
```bash
get_project_context
TICKET=$(get_ticket_from_pr 135)
run_tests_with_coverage "tests/" "src" "coverage.txt"
```

## Maintenance

When adding new piped commands:

1. Identify the command causing prompts
2. Add helper function to appropriate script
3. Update this README with new function
4. Refactor agents to use new helper
5. Test for zero prompts

## Future Work

These helpers will remain necessary until Anthropic fixes GitHub issue #5465. When fixed:
- Helpers can remain (won't hurt)
- OR agents can revert to direct commands
- Permission system will work as originally designed

## References

- **GitHub Issue**: https://github.com/anthropics/claude-code/issues/5465
- **StarForge Documentation**: `.claude/agents/`
- **Project Environment**: `.claude/lib/project-env.sh`
