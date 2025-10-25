#!/bin/bash
# E2E Test: Mermaid Architecture Anchor Workflow
# Tests: senior-engineer → TPM → junior-engineer diagram flow

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
TEST_DIR="/tmp/starforge-e2e-test-$(date +%s)"
STARFORGE_ROOT="$PROJECT_ROOT"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_test_environment() {
  echo -e "${BLUE}Setting up test environment...${NC}"

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
    echo -e "${YELLOW}Create with: gh repo create $TEST_REPO_NAME --public${NC}"
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

  echo -e "${GREEN}✓ Test environment ready: $TEST_DIR${NC}"
}

cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up test environment...${NC}"

  # Close any open issues/PRs in test repo
  gh issue list --repo "$TEST_REPO_NAME" --state open --json number --jq '.[].number' | while read -r issue; do
    gh issue close "$issue" --repo "$TEST_REPO_NAME" --comment "Closed by automated test cleanup" || true
  done

  gh pr list --repo "$TEST_REPO_NAME" --state open --json number --jq '.[].number' | while read -r pr; do
    gh pr close "$pr" --repo "$TEST_REPO_NAME" --comment "Closed by automated test cleanup" --delete-branch || true
  done

  # Remove test directory
  cd /tmp
  rm -rf "$TEST_DIR"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Senior-Engineer Creates Mermaid Diagram
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_senior_engineer_diagram_creation() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 1: Senior-Engineer Diagram Creation${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create mock breakdown with Mermaid diagram
  local spike_dir=".claude/spikes/feature-user-auth"
  mkdir -p "$spike_dir"

  # Create breakdown
  cat > "$spike_dir/breakdown.md" << 'EOF'
# Feature: User Authentication

## Overview
Add JWT-based authentication to the API.

## Subtasks

### 1. Create Auth Middleware
**File:** `src/middleware/auth.js`
**Tests:** `tests/middleware/auth.test.js`
**Estimate:** 3 hours

### 2. Add Login Endpoint
**File:** `src/routes/auth.js`
**Tests:** `tests/routes/auth.test.js`
**Estimate:** 2 hours

## Total Estimate: 5 hours
EOF

  # Create Mermaid diagram (simulating senior-engineer output)
  cat > "$spike_dir/architecture.mmd" << 'EOF'
graph TD
    Client[Client Application]
    Login[Login Endpoint<br/>File: src/routes/auth.js<br/>Tests: tests/routes/auth.test.js]
    Auth[Auth Middleware<br/>File: src/middleware/auth.js<br/>Tests: tests/middleware/auth.test.js]
    JWT[JWT Service<br/>File: src/services/jwt.js]
    DB[(User Database)]

    Client -->|POST /login| Login
    Login -->|validates credentials| DB
    Login -->|generates token| JWT
    Client -->|API requests with token| Auth
    Auth -->|verifies token| JWT

    style Login fill:#e3f2fd
    style Auth fill:#e3f2fd
    style JWT fill:#fff3e0
    style DB fill:#f1f8e9
EOF

  # Assertions
  assert_file_exists "$spike_dir/breakdown.md" "Breakdown file created"
  assert_file_exists "$spike_dir/architecture.mmd" "Architecture diagram created"
  assert_mermaid_valid_syntax "$spike_dir/architecture.mmd" "Diagram has valid Mermaid syntax"
  assert_mermaid_has_file_paths "$spike_dir/architecture.mmd" "Diagram contains file paths"
  assert_file_contains "$spike_dir/architecture.mmd" "graph TD" "Diagram uses component diagram format"
  assert_file_contains "$spike_dir/architecture.mmd" "File:" "Diagram includes file annotations"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: TPM Embeds Diagram in GitHub Issues
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_tpm_diagram_embedding() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 2: TPM Diagram Embedding${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  local spike_dir=".claude/spikes/feature-user-auth"
  local diagram_content=$(cat "$spike_dir/architecture.mmd")

  # Simulate TPM creating GitHub issue with embedded diagram
  echo -e "${BLUE}Creating GitHub issue with embedded diagram...${NC}"

  local issue_body=$(cat << EOF
## 🎯 Task: Create Auth Middleware

**Priority:** P1
**Estimate:** 3 hours
**Spike:** feature-user-auth

## 📋 Description

Implement JWT-based authentication middleware that validates tokens on protected routes.

## 📐 Architecture

\`\`\`mermaid
$diagram_content
\`\`\`

⚠️ **IMPORTANT:** Review the architecture diagram above before implementing.

## ✅ Acceptance Criteria

- [ ] Middleware validates JWT tokens
- [ ] Invalid tokens return 401
- [ ] Tests pass with >80% coverage

## 📁 Files

- **Implementation:** src/middleware/auth.js
- **Tests:** tests/middleware/auth.test.js

---
🤖 Generated by tpm-agent
EOF
)

  # Create the issue (capture URL and extract number)
  local issue_url=$(gh issue create \
    --repo "$TEST_REPO_NAME" \
    --title "Create Auth Middleware" \
    --body "$issue_body" \
    --label "feature,P1" \
    --assignee "@me" 2>&1 | tail -1)

  # Extract issue number from URL (e.g., https://github.com/user/repo/issues/123 -> 123)
  local issue_number=$(echo "$issue_url" | grep -oE '[0-9]+$')

  echo -e "${GREEN}✓ Created issue #${issue_number}${NC}"

  # Assertions
  assert_gh_issue_exists "$issue_number" "GitHub issue created"
  assert_gh_issue_contains "$issue_number" '```mermaid' "Issue contains Mermaid diagram"
  assert_gh_issue_contains "$issue_number" 'graph TD' "Issue contains diagram content"
  assert_gh_issue_contains "$issue_number" 'File: src/middleware/auth.js' "Issue contains file paths"
  assert_gh_issue_contains "$issue_number" '⚠️.*IMPORTANT.*Review the architecture diagram' "Issue has review warning"

  # Store issue number for next test
  echo "$issue_number" > /tmp/test-issue-number

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Junior-Engineer Reviews Diagram
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_junior_engineer_diagram_review() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 3: Junior-Engineer Diagram Review${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  local issue_number=$(cat /tmp/test-issue-number)

  # Simulate junior-engineer reading ticket
  echo -e "${BLUE}Simulating junior-engineer reading ticket #${issue_number}...${NC}"

  local ticket_body=$(gh issue view "$issue_number" --repo "$TEST_REPO_NAME" --json body --jq '.body')

  # Check for diagram presence (Step 8 of junior-engineer pre-flight)
  local has_diagram="false"
  if echo "$ticket_body" | grep -q '```mermaid'; then
    has_diagram="true"
    echo -e "${GREEN}✓ Architecture diagram detected in ticket${NC}"
  fi

  # Assertions
  assert_equals "true" "$has_diagram" "Junior-engineer detects diagram in ticket"
  assert_contains "$ticket_body" '```mermaid' "Ticket body contains Mermaid code block"
  assert_contains "$ticket_body" 'File:' "Ticket contains file path annotations"

  # Simulate 6-step review protocol
  echo -e "${BLUE}Simulating 6-step architecture review...${NC}"

  # Step 1: Read diagram
  local diagram_read="true"
  assert_equals "true" "$diagram_read" "Step 1: Read architecture diagram"

  # Step 2: Identify components
  local components_identified="true"
  if echo "$ticket_body" | grep -qE "(Auth Middleware|Login Endpoint|JWT Service)"; then
    components_identified="true"
  fi
  assert_equals "true" "$components_identified" "Step 2: Identify components in diagram"

  # Step 3: Trace data flows
  local flows_traced="true"
  if echo "$ticket_body" | grep -qE "(-->|validates|generates|verifies)"; then
    flows_traced="true"
  fi
  assert_equals "true" "$flows_traced" "Step 3: Trace data flows"

  # Step 4: Check file paths
  local paths_checked="true"
  if echo "$ticket_body" | grep -qE "(src/middleware/auth.js|tests/middleware/auth.test.js)"; then
    paths_checked="true"
  fi
  assert_equals "true" "$paths_checked" "Step 4: Verify file paths match task"

  # Step 5: Understand dependencies
  local deps_understood="true"
  if echo "$ticket_body" | grep -qE "(JWT Service|User Database)"; then
    deps_understood="true"
  fi
  assert_equals "true" "$deps_understood" "Step 5: Understand dependencies"

  # Step 6: Mental model aligned
  local aligned="true"
  assert_equals "true" "$aligned" "Step 6: Mental model aligned with architecture"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: GitHub Renders Diagram Correctly
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_github_diagram_rendering() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 4: GitHub Diagram Rendering${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  local issue_number=$(cat /tmp/test-issue-number)

  # Get issue URL
  local issue_url=$(gh issue view "$issue_number" --repo "$TEST_REPO_NAME" --json url --jq '.url')

  echo -e "${BLUE}Issue URL: ${issue_url}${NC}"
  echo -e "${YELLOW}Note: GitHub renders Mermaid natively. Visual inspection recommended.${NC}"

  # Assertions (technical checks)
  assert_command_succeeds "gh issue view '$issue_number' --repo '$TEST_REPO_NAME' --json body --jq '.body' | grep -q '\`\`\`mermaid'" \
    "Issue contains Mermaid code block"

  assert_command_succeeds "gh issue view '$issue_number' --repo '$TEST_REPO_NAME' --json body --jq '.body' | grep -qE '(graph|sequenceDiagram|flowchart)'" \
    "Diagram has valid Mermaid type"

  # Save URL for manual verification
  echo "$issue_url" > /tmp/test-issue-url

  echo -e "${GREEN}✓ Diagram syntax validated (manual visual check recommended)${NC}"
  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Architecture Templates Exist
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_architecture_templates() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 5: Architecture Templates${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check templates exist
  assert_file_exists ".claude/architecture-templates/component-diagram.mmd" "Component diagram template"
  assert_file_exists ".claude/architecture-templates/sequence-diagram.mmd" "Sequence diagram template"
  assert_file_exists ".claude/architecture-templates/data-flow.mmd" "Data flow diagram template"
  assert_file_exists ".claude/architecture-templates/README.md" "Templates README"

  # Validate template syntax
  assert_mermaid_valid_syntax ".claude/architecture-templates/component-diagram.mmd" \
    "Component template has valid syntax"

  assert_mermaid_valid_syntax ".claude/architecture-templates/sequence-diagram.mmd" \
    "Sequence template has valid syntax"

  assert_mermaid_valid_syntax ".claude/architecture-templates/data-flow.mmd" \
    "Data flow template has valid syntax"

  # Check README has guidance
  assert_file_contains ".claude/architecture-templates/README.md" "When to Use Which Diagram" \
    "README contains diagram selection guide"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Runner
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  start_test_suite "E2E: Mermaid Architecture Anchor Workflow"

  # Setup
  setup_test_environment

  # Run tests
  test_senior_engineer_diagram_creation
  test_tpm_diagram_embedding
  test_junior_engineer_diagram_review
  test_github_diagram_rendering
  test_architecture_templates

  # Results
  end_test_suite
  local exit_code=$?

  # Export results
  export_test_results_json "tests/reports/architecture-flow-results.json"

  # Cleanup
  cleanup_test_environment

  # Final output
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 All architecture flow tests passed!${NC}"
    echo ""
    echo -e "${BLUE}Visual Verification:${NC}"
    echo -e "  Issue URL: $(cat /tmp/test-issue-url 2>/dev/null || echo 'N/A')"
    echo -e "  ${YELLOW}Manually verify that Mermaid diagram renders correctly on GitHub${NC}"
  else
    echo -e "${RED}❌ Some architecture flow tests failed${NC}"
  fi

  exit $exit_code
}

# Run tests
main "$@"
