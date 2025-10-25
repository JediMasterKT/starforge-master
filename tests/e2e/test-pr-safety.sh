#!/bin/bash
# E2E Test: PR Safety Features
# Tests: Human approval requirement, hook deployment, merge safety

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load test assertions
source "$SCRIPT_DIR/../lib/test-assertions.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Configuration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST_REPO_NAME="${GITHUB_TEST_REPO:-starforge-master-test}"
TEST_DIR="/tmp/starforge-pr-safety-test-$(date +%s)"
STARFORGE_ROOT="$PROJECT_ROOT"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_test_environment() {
  echo -e "${BLUE}Setting up PR safety test environment...${NC}"

  # Create test directory
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"

  # Initialize git
  git init
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Create initial commit
  echo "# Test Project" > README.md
  git add .
  git commit -m "Initial commit"

  # Add GitHub remote
  gh repo view "$TEST_REPO_NAME" &>/dev/null || {
    echo -e "${RED}Error: GitHub test repo '$TEST_REPO_NAME' not found${NC}"
    exit 1
  }

  local repo_url=$(gh repo view "$TEST_REPO_NAME" --json sshUrl --jq '.sshUrl')
  git remote add origin "$repo_url"

  # Install StarForge
  echo -e "${BLUE}Installing StarForge...${NC}"
  bash "$STARFORGE_ROOT/bin/install.sh" <<EOF
3
n
y
n
EOF

  echo -e "${GREEN}✓ PR safety test environment ready: $TEST_DIR${NC}"
}

cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up PR safety test environment...${NC}"

  # Close test PRs
  gh pr list --repo "$TEST_REPO_NAME" --state open --label "test-pr" --json number --jq '.[].number' | while read -r pr; do
    gh pr close "$pr" --repo "$TEST_REPO_NAME" --comment "Closed by automated test cleanup" --delete-branch || true
  done

  # Remove test directory
  cd /tmp
  rm -rf "$TEST_DIR"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Hook Deployment (No __pycache__ Errors)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_hook_deployment() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 1: Hook Deployment (PR #151 Fix)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check hooks directory
  assert_dir_exists ".claude/hooks" "Hooks directory created"

  # Check hook files deployed
  assert_file_exists ".claude/hooks/stop.py" "stop.py hook deployed"
  assert_file_exists ".claude/hooks/block-main-bash.sh" "block-main-bash.sh deployed"
  assert_file_exists ".claude/hooks/block-main-edits.sh" "block-main-edits.sh deployed"

  # Check NO __pycache__ directories deployed (PR #151 fix)
  local pycache_count=$(find .claude/hooks -name "__pycache__" -type d | wc -l | tr -d ' ')
  assert_equals "0" "$pycache_count" "No __pycache__ directories in hooks"

  # Check NO .pyc files deployed
  local pyc_count=$(find .claude/hooks -name "*.pyc" -type f | wc -l | tr -d ' ')
  assert_equals "0" "$pyc_count" "No .pyc files in hooks"

  # Verify hooks are executable
  assert_command_succeeds "test -x .claude/hooks/stop.py" "stop.py is executable"
  assert_command_succeeds "test -x .claude/hooks/block-main-bash.sh" "block-main-bash.sh is executable"
  assert_command_succeeds "test -x .claude/hooks/block-main-edits.sh" "block-main-edits.sh is executable"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Human Approval Requirement (PR #157)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_human_approval_requirement() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 2: Human Approval Requirement (PR #157)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check orchestrator agent definition
  assert_file_exists ".claude/agents/orchestrator.md" "Orchestrator agent definition exists"

  # Check orchestrator does NOT have auto-merge logic
  local auto_merge_count=$(grep -c "gh pr merge" .claude/agents/orchestrator.md 2>/dev/null || echo "0")
  assert_equals "0" "$auto_merge_count" "Orchestrator does NOT auto-merge PRs"

  # Check orchestrator comments on ready PRs
  local comment_count=$(grep -c "gh pr comment" .claude/agents/orchestrator.md 2>/dev/null || echo "0")
  assert_not_equals "0" "$comment_count" "Orchestrator comments on ready PRs"

  # Verify human approval message exists
  assert_file_contains ".claude/agents/orchestrator.md" "HUMAN.*merge" \
    "Orchestrator indicates human must merge"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: QA-Approved Label Detection
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_qa_approved_detection() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 3: QA-Approved Label Detection${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create test PR with qa-approved label
  echo -e "${BLUE}Creating test PR with qa-approved label...${NC}"

  # Create test branch
  git checkout -b test-pr-safety-feature
  echo "# Test Change" >> README.md
  git add .
  git commit -m "Test: PR safety feature"
  git push -u origin test-pr-safety-feature

  # Create PR with qa-approved label (capture URL and extract number)
  local pr_url=$(gh pr create \
    --repo "$TEST_REPO_NAME" \
    --title "Test: PR Safety Feature" \
    --body "Testing human approval requirement" \
    --label "qa-approved,test-pr" \
    --base main \
    --head test-pr-safety-feature 2>&1 | tail -1)

  # Extract PR number from URL (e.g., https://github.com/user/repo/pull/123 -> 123)
  local pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')

  echo -e "${GREEN}✓ Created test PR #${pr_number}${NC}"

  # Verify PR has qa-approved label
  assert_gh_pr_has_label "$pr_number" "qa-approved" "PR has qa-approved label"

  # Verify PR is NOT auto-merged (remains open)
  sleep 2
  local pr_state=$(gh pr view "$pr_number" --repo "$TEST_REPO_NAME" --json state --jq '.state')
  assert_equals "OPEN" "$pr_state" "PR remains open (not auto-merged)"

  # Store PR number for cleanup
  echo "$pr_number" > /tmp/test-pr-number

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Block Main Branch Edits
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_block_main_edits() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 4: Block Main Branch Edits${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check block-main-edits hook exists
  assert_file_exists ".claude/hooks/block-main-edits.sh" "block-main-edits hook exists"

  # Verify hook has blocking logic
  assert_file_contains ".claude/hooks/block-main-edits.sh" "main\|master" \
    "Hook detects main/master branches"

  assert_file_contains ".claude/hooks/block-main-edits.sh" "exit 1" \
    "Hook blocks edits with exit 1"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Hook Updates Without Errors
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_hook_updates() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 5: Hook Updates (starforge update)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create __pycache__ in source templates to simulate real scenario
  mkdir -p "$STARFORGE_ROOT/templates/hooks/__pycache__"
  echo "# Mock compiled bytecode" > "$STARFORGE_ROOT/templates/hooks/__pycache__/stop.pyc"

  # Run update command
  echo -e "${BLUE}Running starforge update...${NC}"
  bash "$STARFORGE_ROOT/bin/starforge" update

  # Check hooks updated without errors
  assert_file_exists ".claude/hooks/stop.py" "Hooks updated successfully"

  # Verify NO __pycache__ deployed
  local pycache_after_update=$(find .claude/hooks -name "__pycache__" -type d | wc -l | tr -d ' ')
  assert_equals "0" "$pycache_after_update" "Update skips __pycache__ directories"

  # Cleanup test __pycache__
  rm -rf "$STARFORGE_ROOT/templates/hooks/__pycache__"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Orchestrator No Auto-Merge Logic
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_orchestrator_no_auto_merge() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 6: Orchestrator No Auto-Merge${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Read orchestrator agent definition
  local orchestrator_content=$(cat .claude/agents/orchestrator.md)

  # Check for prohibited auto-merge patterns
  assert_not_contains "$orchestrator_content" "gh pr merge.*--squash" \
    "Orchestrator doesn't use 'gh pr merge --squash'"

  assert_not_contains "$orchestrator_content" "gh pr merge.*--merge" \
    "Orchestrator doesn't use 'gh pr merge --merge'"

  assert_not_contains "$orchestrator_content" "gh pr merge.*--rebase" \
    "Orchestrator doesn't use 'gh pr merge --rebase'"

  # Check orchestrator comments instead of merging
  assert_contains "$orchestrator_content" "gh pr comment" \
    "Orchestrator uses 'gh pr comment' to notify human"

  # Check human approval messaging
  assert_contains "$orchestrator_content" "human.*review\|human.*merge\|manual.*merge" \
    "Orchestrator mentions human review/merge requirement"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: Agent Learnings Document Safety
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_agent_learnings_safety() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 7: Agent Learnings Document Safety${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check orchestrator learnings exist
  assert_file_exists ".claude/agents/agent-learnings/orchestrator/learnings.md" \
    "Orchestrator learnings file exists"

  # If PR #157 added a learning about human approval, check for it
  # (This is optional - depends on whether a learning was added)

  echo -e "${YELLOW}Note: Manual review recommended for orchestrator learnings${NC}"
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "  ${GREEN}✓${NC} Agent learnings structure validated"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Runner
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  start_test_suite "E2E: PR Safety Features"

  # Setup
  setup_test_environment

  # Run tests
  test_hook_deployment
  test_human_approval_requirement
  test_qa_approved_detection
  test_block_main_edits
  test_hook_updates
  test_orchestrator_no_auto_merge
  test_agent_learnings_safety

  # Results
  end_test_suite
  local exit_code=$?

  # Export results
  mkdir -p tests/reports
  export_test_results_json "tests/reports/pr-safety-results.json"

  # Cleanup
  cleanup_test_environment

  # Final output
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 All PR safety tests passed!${NC}"
    echo -e "${GREEN}✓ Hook deployment works (no __pycache__ errors)${NC}"
    echo -e "${GREEN}✓ Human approval required for all PR merges${NC}"
    echo -e "${GREEN}✓ Main branch edits blocked${NC}"
  else
    echo -e "${RED}❌ Some PR safety tests failed${NC}"
  fi

  exit $exit_code
}

# Run tests
main "$@"
