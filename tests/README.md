# StarForge Test Framework

Comprehensive E2E testing for StarForge's latest features including Mermaid architecture anchors, autonomous daemon, permission-free helpers, and PR safety features.

---

## 🎯 Features Tested

### 1. Mermaid Architecture Anchors
- **PR #158:** Architecture diagram templates
- **PR #159:** Senior-engineer diagram generation
- **PR #160:** TPM diagram embedding in GitHub tickets
- **PR #162:** Junior-engineer diagram review protocol

### 2. Autonomous Daemon & Discord
- **PR #136/#138:** Autonomous daemon for 24/7 operation
- **PR #144:** Discord webhook integration
- **PR #156:** Remove TTY requirement from daemon
- **PR #161:** Daemon lifecycle notifications

### 3. Permission-Free Helper Scripts
- **PR #143:** Permission-free helper scripts foundation
- **PR #152:** TPM refactored to use helpers
- **PR #153:** Orchestrator refactored to use helpers
- **PR #154:** Senior-engineer refactored to use helpers
- **PR #155:** Junior-engineer refactored to use helpers

### 4. PR Safety Features
- **PR #151:** Skip directories when copying hooks (no `__pycache__` errors)
- **PR #157:** Require human approval for ALL PR merges

---

## 📋 Prerequisites

Before running tests, ensure you have:

1. **GitHub CLI** (`gh`)
   ```bash
   brew install gh
   gh auth login
   ```

2. **jq** (JSON processor)
   ```bash
   brew install jq
   ```

3. **Python 3** (for hook tests)
   ```bash
   python3 --version  # Should be 3.7+
   ```

4. **GitHub Test Repository**
   ```bash
   # Create once, reuse for all test runs
   gh repo create starforge-master-test --public \
     --description "Testing environment for StarForge"
   ```

5. **Discord Webhook** (Optional)
   ```bash
   # Set environment variable to test Discord integration
   export DISCORD_WEBHOOK_URL="https://discordapp.com/api/webhooks/YOUR/WEBHOOK/URL"
   ```

---

## 🚀 Quick Start

### Run All Tests

```bash
# From starforge-master-discord root
bash bin/test-sandbox.sh
```

This will:
1. Check prerequisites
2. Run all 4 E2E test suites
3. Generate comprehensive test report
4. Export results to `tests/reports/TEST_REPORT.md`

### Run Individual Test Suite

```bash
# Architecture flow test
bash tests/e2e/test-architecture-flow.sh

# Daemon & Discord test
bash tests/e2e/test-daemon.sh

# Helper scripts test
bash tests/e2e/test-helpers.sh

# PR safety test
bash tests/e2e/test-pr-safety.sh
```

---

## 📁 Project Structure

```
tests/
├── README.md                      # This file
├── e2e/                           # End-to-end test suites
│   ├── test-architecture-flow.sh  # Mermaid diagram workflow
│   ├── test-daemon.sh             # Daemon & Discord integration
│   ├── test-helpers.sh            # Permission-free helpers
│   └── test-pr-safety.sh          # PR safety features
├── lib/                           # Test libraries
│   └── test-assertions.sh         # Reusable assertion functions
├── fixtures/                      # Test data (empty for now)
└── reports/                       # Generated test reports
    ├── TEST_REPORT.md             # Comprehensive markdown report
    ├── architecture-flow-results.json
    ├── daemon-results.json
    ├── helpers-results.json
    └── pr-safety-results.json

bin/
└── test-sandbox.sh                # Main test orchestrator
```

---

## 🧪 Test Suites Explained

### 1. `test-architecture-flow.sh`

**Purpose:** Validate the complete Mermaid architecture anchor workflow.

**Test Scenarios:**
1. Senior-engineer creates Mermaid diagram
   - Validates diagram syntax
   - Checks for file path annotations
   - Verifies component diagram format

2. TPM embeds diagram in GitHub tickets
   - Creates GitHub issue with diagram
   - Validates Mermaid code block format
   - Checks for review warning message

3. Junior-engineer reviews diagram
   - Simulates 6-step review protocol
   - Validates component identification
   - Checks data flow tracing

4. GitHub renders diagram correctly
   - Validates GitHub native rendering
   - Provides URL for manual verification

5. Architecture templates exist
   - Checks template deployment
   - Validates template syntax
   - Verifies README guidance

**Expected Duration:** ~30-45 seconds

---

### 2. `test-daemon.sh`

**Purpose:** Validate autonomous daemon operation and Discord integration.

**Test Scenarios:**
1. Daemon lifecycle management
   - Start/stop/restart operations
   - PID file and lock management
   - Process monitoring

2. Trigger file processing
   - Daemon detects triggers
   - Processes handoffs automatically
   - Logs to agent-handoff.log

3. Stop hook integration
   - Hook executes without errors
   - Processes trigger files
   - Archives to processed/

4. Discord notifications (optional)
   - Sends webhook notifications
   - Handles graceful fallback if not configured
   - Validates HTTP response codes

5. No TTY requirement (PR #156 fix)
   - Daemon starts in non-TTY environment
   - Validates background operation

6. Daemon restart functionality
   - Old process stops cleanly
   - New process starts with different PID
   - Status command works correctly

**Expected Duration:** ~20-30 seconds

---

### 3. `test-helpers.sh`

**Purpose:** Validate permission-free helper script refactoring.

**Test Scenarios:**
1. Helper scripts exist and are executable
   - github-helpers.sh
   - worktree-helpers.sh
   - context-helpers.sh
   - trigger-helpers.sh

2. GitHub helpers
   - Functions exist and work
   - No sudo usage detected
   - No hardcoded paths

3. Worktree helpers
   - find_project_root works
   - is_worktree detects correctly
   - get_main_worktree finds main repo

4. Context helpers
   - get_context_file works
   - get_tech_stack_file works
   - No sudo usage

5. Trigger helpers
   - create_trigger works
   - get_triggers_dir finds correct path
   - Valid JSON generation

6. Worktree isolation
   - Helpers work from worktree
   - Can access main repo .claude dir
   - get_main_worktree works from worktree

7. No hardcoded paths
   - No /Users/username patterns
   - No /home/username patterns
   - No hardcoded starforge paths

**Expected Duration:** ~15-20 seconds

---

### 4. `test-pr-safety.sh`

**Purpose:** Validate PR safety guardrails and deployment fixes.

**Test Scenarios:**
1. Hook deployment (PR #151 fix)
   - Hooks deployed correctly
   - NO `__pycache__` directories
   - NO `.pyc` files
   - Hooks are executable

2. Human approval requirement (PR #157)
   - Orchestrator has NO `gh pr merge` commands
   - Orchestrator uses `gh pr comment` instead
   - Human approval messaging present

3. QA-approved label detection
   - Creates PR with `qa-approved` label
   - PR remains OPEN (not auto-merged)
   - Validates orchestrator behavior

4. Block main branch edits
   - block-main-edits hook exists
   - Hook detects main/master branches
   - Hook blocks with exit 1

5. Hook updates without errors
   - `starforge update` works
   - Skips `__pycache__` during update
   - Hooks updated successfully

6. Orchestrator no auto-merge logic
   - No `gh pr merge --squash` patterns
   - No `gh pr merge --merge` patterns
   - Comments instead of merging

7. Agent learnings structure
   - Learnings files exist
   - Structure validated

**Expected Duration:** ~25-35 seconds

---

## 📊 Test Assertions Library

The `tests/lib/test-assertions.sh` library provides reusable assertion functions:

### Test Suite Management
- `start_test_suite <name>` - Initialize test suite
- `end_test_suite` - Finalize and show results
- `export_test_results_json <file>` - Export JSON results

### Core Assertions
- `assert_true <condition> <message>`
- `assert_false <condition> <message>`
- `assert_equals <expected> <actual> <message>`
- `assert_not_equals <value> <actual> <message>`
- `assert_contains <haystack> <needle> <message>`
- `assert_not_contains <haystack> <needle> <message>`

### File System Assertions
- `assert_file_exists <path> <message>`
- `assert_file_not_exists <path> <message>`
- `assert_dir_exists <path> <message>`
- `assert_file_contains <path> <pattern> <message>`

### Command Assertions
- `assert_command_succeeds <command> <message>`
- `assert_command_fails <command> <message>`
- `assert_command_output_contains <command> <pattern> <message>`

### GitHub Assertions
- `assert_gh_issue_exists <number> <message>`
- `assert_gh_issue_contains <number> <pattern> <message>`
- `assert_gh_pr_exists <number> <message>`
- `assert_gh_pr_has_label <number> <label> <message>`

### Process Assertions
- `assert_process_running <pid> <message>`
- `assert_process_not_running <pid> <message>`

### Mermaid Diagram Assertions
- `assert_mermaid_valid_syntax <file> <message>`
- `assert_mermaid_has_file_paths <file> <message>`

---

## 📈 Test Reports

After running tests, check:

### Markdown Report
```bash
cat tests/reports/TEST_REPORT.md
```

Contains:
- Executive summary
- Test suite results
- Detailed validations
- Manual verification checklist
- Recommendations

### JSON Results
```bash
# Individual test results
cat tests/reports/architecture-flow-results.json
cat tests/reports/daemon-results.json
cat tests/reports/helpers-results.json
cat tests/reports/pr-safety-results.json
```

Each contains:
- Suite name
- Timestamp
- Tests run/passed/failed
- Duration
- Success boolean

---

## 🔧 Configuration

### GitHub Test Repository

Set custom test repository:
```bash
export GITHUB_TEST_REPO="your-org/your-test-repo"
bash bin/test-sandbox.sh
```

### Discord Webhook

Enable Discord integration tests:
```bash
export DISCORD_WEBHOOK_URL="https://discordapp.com/api/webhooks/YOUR/WEBHOOK"
bash bin/test-sandbox.sh
```

Without this, daemon tests will validate graceful fallback behavior.

---

## 🐛 Troubleshooting

### "GitHub test repo not found"

Create the test repository:
```bash
gh repo create starforge-master-test --public
```

### "GitHub CLI not authenticated"

Authenticate with GitHub:
```bash
gh auth login
```

### "Hook tests fail with Python errors"

Ensure Python 3.7+ is installed:
```bash
python3 --version
# If missing: brew install python3
```

### "Permission denied" errors

Make test scripts executable:
```bash
chmod +x bin/test-sandbox.sh
chmod +x tests/e2e/*.sh
chmod +x tests/lib/*.sh
```

### "Discord webhook tests fail"

This is expected if `DISCORD_WEBHOOK_URL` is not set. Tests should pass with:
```
✓ Graceful fallback when Discord not configured
```

---

## 🎯 Manual Verification

After automated tests pass, manually verify:

1. **GitHub Diagram Rendering**
   - Open test repository issues
   - View ticket with embedded Mermaid diagram
   - Confirm diagram renders as visual graph (not code)

2. **Discord Notifications**
   - Check Discord channel for test notifications
   - Verify formatting and content

3. **PR Comments**
   - View test PRs in GitHub
   - Confirm orchestrator commented (didn't auto-merge)
   - Verify human approval messaging

---

## 📚 Writing New Tests

### Create a New Test Suite

1. Create test file:
   ```bash
   touch tests/e2e/test-my-feature.sh
   chmod +x tests/e2e/test-my-feature.sh
   ```

2. Use template structure:
   ```bash
   #!/bin/bash
   set -e

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../lib/test-assertions.sh"

   setup_test_environment() {
     # Setup logic
   }

   cleanup_test_environment() {
     # Cleanup logic
   }

   test_my_feature() {
     echo -e "${CYAN}Testing my feature...${NC}"
     assert_true "true" "My assertion"
   }

   main() {
     start_test_suite "My Feature Tests"
     setup_test_environment
     test_my_feature
     end_test_suite
     cleanup_test_environment
   }

   main "$@"
   ```

3. Add to orchestrator:
   ```bash
   # Edit bin/test-sandbox.sh
   run_test_suite "$PROJECT_ROOT/tests/e2e/test-my-feature.sh" "My Feature"
   ```

---

## 🤝 Contributing

When adding new features to StarForge:

1. **Add corresponding tests** to validate the feature
2. **Update test assertions** if new validation types are needed
3. **Document tests** in this README
4. **Run full test suite** before submitting PRs
5. **Include test results** in PR description

---

## 📞 Support

- **Issues:** https://github.com/JediMasterKT/starforge-master/issues
- **Test Framework Author:** Claude Code (Anthropic)
- **StarForge Project:** https://github.com/JediMasterKT/starforge-master

---

**Test Framework Version:** 1.0.0
**Last Updated:** 2025-10-24
**License:** MIT
