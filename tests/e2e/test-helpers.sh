#!/bin/bash
# E2E Test: Permission-Free Helper Scripts
# Tests: github-helpers, worktree-helpers, context-helpers, trigger-helpers

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

TEST_DIR="/tmp/starforge-helpers-test-$(date +%s)"
STARFORGE_ROOT="$PROJECT_ROOT"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_test_environment() {
  echo -e "${BLUE}Setting up helper scripts test environment...${NC}"

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

  # Install StarForge
  echo -e "${BLUE}Installing StarForge...${NC}"
  bash "$STARFORGE_ROOT/bin/install.sh" <<EOF
3
n
n
EOF

  echo -e "${GREEN}✓ Helper scripts test environment ready: $TEST_DIR${NC}"
}

cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up helper scripts test environment...${NC}"

  cd /tmp
  rm -rf "$TEST_DIR"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Helper Scripts Exist
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_helper_scripts_exist() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 1: Helper Scripts Existence${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check all helper scripts installed
  assert_file_exists ".claude/scripts/github-helpers.sh" "GitHub helpers installed"
  assert_file_exists ".claude/scripts/worktree-helpers.sh" "Worktree helpers installed"
  assert_file_exists ".claude/scripts/context-helpers.sh" "Context helpers installed"
  assert_file_exists ".claude/scripts/trigger-helpers.sh" "Trigger helpers installed"
  assert_file_exists ".claude/scripts/test-helpers.sh" "Test helpers installed"

  # Check helpers are executable
  assert_command_succeeds "test -x .claude/scripts/github-helpers.sh" \
    "GitHub helpers is executable"

  assert_command_succeeds "test -x .claude/scripts/worktree-helpers.sh" \
    "Worktree helpers is executable"

  assert_command_succeeds "test -x .claude/scripts/context-helpers.sh" \
    "Context helpers is executable"

  assert_command_succeeds "test -x .claude/scripts/trigger-helpers.sh" \
    "Trigger helpers is executable"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: GitHub Helpers (Permission-Free)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_github_helpers() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 2: GitHub Helpers${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Source the helpers
  source .claude/scripts/github-helpers.sh

  # Test helper functions exist
  assert_command_succeeds "type get_repo_name" "get_repo_name function exists"
  assert_command_succeeds "type get_repo_owner" "get_repo_owner function exists"

  # Test functions work without sudo/elevated permissions
  echo -e "${BLUE}Testing permission-free operation...${NC}"

  # Check functions don't require sudo
  assert_command_output_contains "grep -c 'sudo' .claude/scripts/github-helpers.sh" "^0$" \
    "GitHub helpers don't use sudo"

  # Verify no hardcoded paths
  assert_command_output_contains "grep -c '/Users/.*starforge' .claude/scripts/github-helpers.sh" "^0$" \
    "GitHub helpers don't have hardcoded paths"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Worktree Helpers
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_worktree_helpers() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 3: Worktree Helpers${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Source the helpers
  source .claude/scripts/worktree-helpers.sh

  # Test helper functions exist
  assert_command_succeeds "type find_project_root" "find_project_root function exists"
  assert_command_succeeds "type is_worktree" "is_worktree function exists"
  assert_command_succeeds "type get_main_worktree" "get_main_worktree function exists"

  # Test find_project_root
  local project_root=$(find_project_root)
  assert_equals "$TEST_DIR" "$project_root" "find_project_root returns correct path"

  # Test is_worktree (main repo)
  if is_worktree; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} is_worktree should return false for main repo"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} is_worktree correctly identifies main repo"
  fi

  # Test get_main_worktree
  local main_worktree=$(get_main_worktree)
  assert_equals "$TEST_DIR" "$main_worktree" "get_main_worktree returns correct path"

  # Verify no sudo usage
  assert_command_output_contains "grep -c 'sudo' .claude/scripts/worktree-helpers.sh" "^0$" \
    "Worktree helpers don't use sudo"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Context Helpers
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_context_helpers() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 4: Context Helpers${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Source the helpers
  source .claude/scripts/context-helpers.sh

  # Test helper functions exist
  assert_command_succeeds "type get_context_file" "get_context_file function exists"
  assert_command_succeeds "type get_tech_stack_file" "get_tech_stack_file function exists"

  # Create mock context files
  mkdir -p .claude
  cat > .claude/PROJECT_CONTEXT.md << 'EOF'
# Project Context

This is a test project for StarForge.
EOF

  cat > .claude/TECH_STACK.md << 'EOF'
# Tech Stack

- Language: Bash
- Framework: StarForge
EOF

  # Test get_context_file
  local context_file=$(get_context_file)
  assert_equals "$TEST_DIR/.claude/PROJECT_CONTEXT.md" "$context_file" \
    "get_context_file returns correct path"

  # Test get_tech_stack_file
  local tech_stack_file=$(get_tech_stack_file)
  assert_equals "$TEST_DIR/.claude/TECH_STACK.md" "$tech_stack_file" \
    "get_tech_stack_file returns correct path"

  # Verify no sudo usage
  assert_command_output_contains "grep -c 'sudo' .claude/scripts/context-helpers.sh" "^0$" \
    "Context helpers don't use sudo"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Trigger Helpers
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_trigger_helpers() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 5: Trigger Helpers${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Source the helpers
  source .claude/scripts/trigger-helpers.sh

  # Test helper functions exist
  assert_command_succeeds "type create_trigger" "create_trigger function exists"
  assert_command_succeeds "type get_triggers_dir" "get_triggers_dir function exists"

  # Test get_triggers_dir
  local triggers_dir=$(get_triggers_dir)
  assert_equals "$TEST_DIR/.claude/triggers" "$triggers_dir" \
    "get_triggers_dir returns correct path"

  # Test create_trigger
  echo -e "${BLUE}Testing trigger creation...${NC}"

  create_trigger "test-agent" "target-agent" "test_action" "Test message" "Test command"

  # Check trigger file created
  local trigger_count=$(find .claude/triggers -name "*test-agent-to-target-agent.json" -type f | wc -l | tr -d ' ')
  assert_not_equals "0" "$trigger_count" "Trigger file created"

  # Verify trigger has valid JSON
  local trigger_file=$(find .claude/triggers -name "*test-agent-to-target-agent.json" -type f | head -1)
  assert_command_succeeds "jq empty '$trigger_file'" "Trigger file is valid JSON"

  # Check trigger content
  assert_file_contains "$trigger_file" '"from_agent": "test-agent"' "Trigger has from_agent"
  assert_file_contains "$trigger_file" '"to_agent": "target-agent"' "Trigger has to_agent"
  assert_file_contains "$trigger_file" '"message": "Test message"' "Trigger has message"

  # Verify no sudo usage
  assert_command_output_contains "grep -c 'sudo' .claude/scripts/trigger-helpers.sh" "^0$" \
    "Trigger helpers don't use sudo"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Helpers Work in Worktree Isolation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_worktree_isolation() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 6: Worktree Isolation${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create a test worktree
  local worktree_dir="$TEST_DIR-worktree-test"

  echo -e "${BLUE}Creating test worktree...${NC}"
  git worktree add "$worktree_dir" -b test-branch main

  # Navigate to worktree
  cd "$worktree_dir"

  # Source helpers from worktree
  source .claude/scripts/worktree-helpers.sh
  source .claude/scripts/github-helpers.sh
  source .claude/scripts/context-helpers.sh

  # Test helpers work in worktree
  assert_command_succeeds "is_worktree" "is_worktree detects worktree correctly"

  local main_worktree=$(get_main_worktree)
  assert_equals "$TEST_DIR" "$main_worktree" "get_main_worktree finds main repo from worktree"

  local context_file=$(get_context_file)
  assert_contains "$context_file" "PROJECT_CONTEXT.md" "Context helpers work in worktree"

  # Test helpers can access main repo .claude directory
  assert_dir_exists "$TEST_DIR/.claude" "Helpers can reference main repo .claude dir"

  # Navigate back
  cd "$TEST_DIR"

  # Cleanup worktree
  git worktree remove "$worktree_dir" --force

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 7: No Hardcoded Paths
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_no_hardcoded_paths() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 7: No Hardcoded Paths${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check for hardcoded paths in all helper scripts
  local helpers=(
    ".claude/scripts/github-helpers.sh"
    ".claude/scripts/worktree-helpers.sh"
    ".claude/scripts/context-helpers.sh"
    ".claude/scripts/trigger-helpers.sh"
  )

  for helper in "${helpers[@]}"; do
    local helper_name=$(basename "$helper" .sh)

    # Check for /Users/username patterns
    local user_path_count=$(grep -c '/Users/[a-zA-Z]' "$helper" 2>/dev/null || echo "0")
    assert_equals "0" "$user_path_count" "$helper_name has no hardcoded /Users paths"

    # Check for absolute /home patterns
    local home_path_count=$(grep -c '/home/[a-zA-Z]' "$helper" 2>/dev/null || echo "0")
    assert_equals "0" "$home_path_count" "$helper_name has no hardcoded /home paths"

    # Check for hardcoded starforge paths
    local starforge_path_count=$(grep -c '/.*starforge-master[^$]' "$helper" 2>/dev/null || echo "0")
    assert_equals "0" "$starforge_path_count" "$helper_name has no hardcoded starforge paths"
  done

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Runner
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  start_test_suite "E2E: Permission-Free Helper Scripts"

  # Setup
  setup_test_environment

  # Run tests
  test_helper_scripts_exist
  test_github_helpers
  test_worktree_helpers
  test_context_helpers
  test_trigger_helpers
  test_worktree_isolation
  test_no_hardcoded_paths

  # Results
  end_test_suite
  local exit_code=$?

  # Export results
  mkdir -p tests/reports
  export_test_results_json "tests/reports/helpers-results.json"

  # Cleanup
  cleanup_test_environment

  # Final output
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 All helper scripts tests passed!${NC}"
    echo -e "${GREEN}✓ Permission-free operation validated${NC}"
    echo -e "${GREEN}✓ Worktree isolation verified${NC}"
    echo -e "${GREEN}✓ No hardcoded paths detected${NC}"
  else
    echo -e "${RED}❌ Some helper scripts tests failed${NC}"
  fi

  exit $exit_code
}

# Run tests
main "$@"
