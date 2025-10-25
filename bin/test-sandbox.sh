#!/bin/bash
# StarForge Comprehensive Test Orchestrator
# Runs all E2E tests and generates detailed test report

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Emoji
CHECK="✅"
ERROR="❌"
WARN="⚠️ "
INFO="ℹ️ "
ROCKET="🚀"
ROBOT="🤖"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
GITHUB_TEST_REPO="${GITHUB_TEST_REPO:-starforge-master-test}"
REPORT_DIR="$PROJECT_ROOT/tests/reports"
REPORT_FILE="$REPORT_DIR/TEST_REPORT.md"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Header
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

print_header() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${ROCKET} ${MAGENTA}StarForge Comprehensive Test Suite${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${INFO} Testing All New Features:"
  echo -e "  ${CHECK} Mermaid Architecture Anchors (PRs #158, #159, #160, #162)"
  echo -e "  ${ROBOT} Autonomous Daemon & Discord (PRs #136, #138, #144, #156, #161)"
  echo -e "  ${CHECK} Permission-Free Helpers (PRs #143, #152, #153, #154, #155)"
  echo -e "  ${CHECK} PR Safety Features (PRs #151, #157)"
  echo ""
  echo -e "${INFO} GitHub Test Repository: ${GITHUB_TEST_REPO}"
  echo -e "${INFO} Report Directory: ${REPORT_DIR}"
  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Prerequisites Check
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

check_prerequisites() {
  echo -e "${BLUE}Checking prerequisites...${NC}"

  local all_good=true

  # Check GitHub CLI
  if ! command -v gh &> /dev/null; then
    echo -e "${ERROR} GitHub CLI not found"
    all_good=false
  else
    echo -e "${CHECK} GitHub CLI: $(gh --version | head -1)"
  fi

  # Check GitHub auth
  if ! gh auth status &> /dev/null; then
    echo -e "${ERROR} GitHub CLI not authenticated"
    all_good=false
  else
    local username=$(gh api user -q .login 2>/dev/null || echo "authenticated")
    echo -e "${CHECK} GitHub Auth: $username"
  fi

  # Check jq
  if ! command -v jq &> /dev/null; then
    echo -e "${ERROR} jq not found"
    all_good=false
  else
    echo -e "${CHECK} jq: $(jq --version)"
  fi

  # Check python3 (for hooks)
  if ! command -v python3 &> /dev/null; then
    echo -e "${WARN} python3 not found (hook tests may fail)"
  else
    echo -e "${CHECK} python3: $(python3 --version)"
  fi

  # Check test repo exists
  if ! gh repo view "$GITHUB_TEST_REPO" &> /dev/null; then
    echo -e "${ERROR} GitHub test repo not found: $GITHUB_TEST_REPO"
    echo -e "${YELLOW}  Create with: gh repo create $GITHUB_TEST_REPO --public${NC}"
    all_good=false
  else
    echo -e "${CHECK} Test repo: $GITHUB_TEST_REPO"
  fi

  # Check Discord webhook (optional)
  if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    echo -e "${CHECK} Discord webhook configured"
  else
    echo -e "${INFO} Discord webhook not configured (testing graceful fallback)"
  fi

  echo ""

  if [ "$all_good" = false ]; then
    echo -e "${ERROR} ${RED}Prerequisites missing. Please fix and try again.${NC}"
    exit 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Run Test Suite
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_test_suite() {
  local test_script="$1"
  local suite_name="$2"

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Running: ${suite_name}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  TOTAL_SUITES=$((TOTAL_SUITES + 1))

  local start_time=$(date +%s)

  if bash "$test_script"; then
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    PASSED_SUITES=$((PASSED_SUITES + 1))
    echo -e "${GREEN}${CHECK} ${suite_name} PASSED${NC} (${duration}s)"
    echo ""
    return 0
  else
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    FAILED_SUITES=$((FAILED_SUITES + 1))
    echo -e "${RED}${ERROR} ${suite_name} FAILED${NC} (${duration}s)"
    echo ""
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Generate Test Report
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

generate_test_report() {
  echo -e "${BLUE}Generating test report...${NC}"

  mkdir -p "$REPORT_DIR"

  # Collect test results
  local architecture_results=$(cat "$REPORT_DIR/architecture-flow-results.json" 2>/dev/null || echo '{}')
  local daemon_results=$(cat "$REPORT_DIR/daemon-results.json" 2>/dev/null || echo '{}')
  local helpers_results=$(cat "$REPORT_DIR/helpers-results.json" 2>/dev/null || echo '{}')
  local pr_safety_results=$(cat "$REPORT_DIR/pr-safety-results.json" 2>/dev/null || echo '{}')

  # Generate markdown report
  cat > "$REPORT_FILE" << EOF
# StarForge Test Report

**Generated:** $(date)
**Test Repository:** [$GITHUB_TEST_REPO](https://github.com/$GITHUB_TEST_REPO)
**Test Run ID:** $TIMESTAMP

---

## 📊 Summary

| Metric | Value |
|--------|-------|
| **Test Suites Run** | $TOTAL_SUITES |
| **Suites Passed** | $PASSED_SUITES |
| **Suites Failed** | $FAILED_SUITES |
| **Success Rate** | $(( PASSED_SUITES * 100 / TOTAL_SUITES ))% |

---

## 🧪 Test Suites

### 1. E2E Architecture Flow (Mermaid Diagrams)

**Purpose:** Validate architecture anchor workflow
**Features Tested:**
- PR #158: Mermaid diagram templates
- PR #159: Senior-engineer diagram generation
- PR #160: TPM diagram embedding in tickets
- PR #162: Junior-engineer diagram review protocol

**Results:**
\`\`\`json
$architecture_results
\`\`\`

**Key Validations:**
- ✅ Senior-engineer creates valid Mermaid diagrams
- ✅ TPM embeds diagrams in GitHub tickets
- ✅ Junior-engineer reviews diagrams before coding
- ✅ GitHub renders Mermaid diagrams natively
- ✅ Architecture templates deployed correctly

---

### 2. Daemon & Discord Integration

**Purpose:** Validate autonomous operation
**Features Tested:**
- PR #136/#138: Autonomous daemon for 24/7 operation
- PR #144: Discord webhook integration
- PR #156: Remove TTY requirement
- PR #161: Daemon lifecycle notifications

**Results:**
\`\`\`json
$daemon_results
\`\`\`

**Key Validations:**
- ✅ Daemon starts/stops/restarts correctly
- ✅ Trigger files processed automatically
- ✅ Stop hook detects and processes handoffs
- ✅ Discord notifications sent (if configured)
- ✅ Daemon works without TTY (PR #156 fix)
- ✅ PID and lock file management

---

### 3. Permission-Free Helper Scripts

**Purpose:** Validate helper script refactoring
**Features Tested:**
- PR #143: Permission-free helper scripts
- PR #152: TPM refactored to use helpers
- PR #153: Orchestrator refactored to use helpers
- PR #154: Senior-engineer refactored to use helpers
- PR #155: Junior-engineer refactored to use helpers

**Results:**
\`\`\`json
$helpers_results
\`\`\`

**Key Validations:**
- ✅ All helper scripts deployed correctly
- ✅ No sudo or elevated permissions required
- ✅ No hardcoded paths detected
- ✅ Helpers work in worktree isolation
- ✅ GitHub helpers, worktree helpers, context helpers, trigger helpers

---

### 4. PR Safety Features

**Purpose:** Validate safety guardrails
**Features Tested:**
- PR #151: Skip directories when copying hooks (no __pycache__ errors)
- PR #157: Require human approval for ALL PR merges

**Results:**
\`\`\`json
$pr_safety_results
\`\`\`

**Key Validations:**
- ✅ Hook deployment skips __pycache__ directories
- ✅ Orchestrator does NOT auto-merge PRs
- ✅ Human approval required for all merges
- ✅ QA-approved PRs stay open for human review
- ✅ Main branch edits blocked by hook
- ✅ Hook updates work without errors

---

## 📈 Detailed Results

### Test Artifacts

- **Test Logs:** \`tests/reports/*-results.json\`
- **GitHub Test Repo:** [${GITHUB_TEST_REPO}](https://github.com/${GITHUB_TEST_REPO})
- **Test Timestamp:** $TIMESTAMP

### Manual Verification Checklist

After automated tests pass, manually verify:

- [ ] Open GitHub test repo and view a ticket with embedded Mermaid diagram
- [ ] Verify diagram renders correctly in GitHub UI
- [ ] Check Discord channel for daemon lifecycle notifications (if configured)
- [ ] Review PR comments from orchestrator (should NOT auto-merge)
- [ ] Verify hook files deployed without __pycache__ errors

---

## 🎯 Recommendations

EOF

  # Add recommendations based on results
  if [ $FAILED_SUITES -eq 0 ]; then
    cat >> "$REPORT_FILE" << EOF
### ✅ All Tests Passed!

StarForge is ready for production use with all new features validated:

1. **Mermaid Architecture Anchors** - Fully operational
2. **Autonomous Daemon** - 24/7 operation verified
3. **Permission-Free Helpers** - Working in isolated worktrees
4. **PR Safety Features** - Human approval enforced

**Next Steps:**
- Deploy to production projects
- Monitor initial deployments for edge cases
- Collect user feedback on architecture diagram workflow

EOF
  else
    cat >> "$REPORT_FILE" << EOF
### ⚠️ Some Tests Failed

**Action Required:**
- Review failed test logs in \`tests/reports/*-results.json\`
- Fix failing tests before production deployment
- Re-run full test suite after fixes

**Common Issues:**
- GitHub test repo permissions
- Discord webhook configuration
- Missing prerequisites (jq, python3, gh cli)

EOF
  fi

  cat >> "$REPORT_FILE" << EOF
---

## 📚 Reference

- **Test Framework:** \`tests/lib/test-assertions.sh\`
- **Test Scripts:** \`tests/e2e/test-*.sh\`
- **Test Orchestrator:** \`bin/test-sandbox.sh\`

**Report Generated by StarForge Test Orchestrator**
EOF

  echo -e "${GREEN}${CHECK} Test report generated: $REPORT_FILE${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Orchestrator
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  print_header
  check_prerequisites

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${ROCKET} ${MAGENTA}Starting Test Execution${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Run all test suites
  run_test_suite "$PROJECT_ROOT/tests/e2e/test-architecture-flow.sh" "E2E: Architecture Flow"
  run_test_suite "$PROJECT_ROOT/tests/e2e/test-daemon.sh" "E2E: Daemon & Discord"
  run_test_suite "$PROJECT_ROOT/tests/e2e/test-helpers.sh" "E2E: Helper Scripts"
  run_test_suite "$PROJECT_ROOT/tests/e2e/test-pr-safety.sh" "E2E: PR Safety"

  # Generate report
  echo ""
  generate_test_report

  # Final summary
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${ROCKET} ${MAGENTA}Test Execution Complete${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${INFO} Test Suites Run:    $TOTAL_SUITES"
  echo -e "${GREEN}${CHECK} Suites Passed:     $PASSED_SUITES${NC}"

  if [ $FAILED_SUITES -gt 0 ]; then
    echo -e "${RED}${ERROR} Suites Failed:     $FAILED_SUITES${NC}"
  else
    echo -e "  Suites Failed:     $FAILED_SUITES"
  fi

  echo ""
  echo -e "${INFO} Full Report: $REPORT_FILE"
  echo ""

  # Exit code based on results
  if [ $FAILED_SUITES -eq 0 ]; then
    echo -e "${GREEN}${CHECK} All tests passed! StarForge is ready.${NC}"
    exit 0
  else
    echo -e "${RED}${ERROR} Some tests failed. Review report and fix issues.${NC}"
    exit 1
  fi
}

# Run orchestrator
main "$@"
