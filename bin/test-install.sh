#!/bin/bash
# StarForge Installation Test Suite
# Uses TDD to verify installer works correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$STARFORGE_ROOT/.tmp"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Installation Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_file_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-File exists: $file}"

    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (file not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_dir_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local dir="$1"
    local desc="${2:-Directory exists: $dir}"

    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (directory not found: $dir)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_executable() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-File is executable: $file}"

    if [ -x "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (file not executable)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local pattern="$2"
    local desc="${3:-File contains: $pattern}"

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (pattern not found in $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_json_valid() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local desc="${2:-Valid JSON: $file}"

    if jq empty "$file" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (invalid JSON)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_command_exists() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local cmd="$1"
    local desc="${2:-Command exists: $cmd}"

    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (command not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Cleanup function
cleanup_test_project() {
    local test_project="$1"
    if [ -d "$test_project" ]; then
        # Remove worktrees if they exist
        if [ -d "$test_project/.git" ]; then
            cd "$test_project"
            git worktree list --porcelain 2>/dev/null | grep "^worktree" | cut -d' ' -f2 | while read worktree; do
                if [ "$worktree" != "$test_project" ]; then
                    git worktree remove "$worktree" --force 2>/dev/null || true
                fi
            done
            cd - > /dev/null
        fi
        rm -rf "$test_project"
    fi
}

# Test 1: Prerequisites Check
test_prerequisites() {
    echo ""
    echo "Test 1: Prerequisites"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_command_exists "git" "Git is installed"
    assert_command_exists "gh" "GitHub CLI is installed"
    assert_command_exists "jq" "jq is installed"

    # Check gh auth (non-critical)
    TESTS_RUN=$((TESTS_RUN + 1))
    if gh auth status &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} GitHub CLI is authenticated"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC}  GitHub CLI not authenticated (will skip GitHub tests)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        SKIP_GITHUB_TESTS=true
    fi
}

# Test 2: Template Files Exist
test_template_files() {
    echo ""
    echo "Test 2: Template Files"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Agent files
    assert_file_exists "$STARFORGE_ROOT/templates/agents/orchestrator.md" "orchestrator.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/agents/senior-engineer.md" "senior-engineer.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/agents/junior-engineer.md" "junior-engineer.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/agents/qa-engineer.md" "qa-engineer.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/agents/tpm-agent.md" "tpm-agent.md exists"

    # Scripts
    assert_file_exists "$STARFORGE_ROOT/templates/scripts/trigger-helpers.sh" "trigger-helpers.sh exists"
    assert_file_exists "$STARFORGE_ROOT/templates/scripts/trigger-monitor.sh" "trigger-monitor.sh exists"
    assert_file_exists "$STARFORGE_ROOT/templates/scripts/watch-triggers.sh" "watch-triggers.sh exists"

    # Hooks
    assert_file_exists "$STARFORGE_ROOT/templates/hooks/block-main-edits.sh" "block-main-edits.sh exists"
    assert_file_exists "$STARFORGE_ROOT/templates/hooks/block-main-bash.sh" "block-main-bash.sh exists"

    # Config files
    assert_file_exists "$STARFORGE_ROOT/templates/CLAUDE.md" "CLAUDE.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/LEARNINGS.md" "LEARNINGS.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/settings/settings.json" "settings.json exists"
    assert_json_valid "$STARFORGE_ROOT/templates/settings/settings.json" "settings.json is valid JSON"

    # Template files
    assert_file_exists "$STARFORGE_ROOT/templates/PROJECT_CONTEXT.template.md" "PROJECT_CONTEXT.template.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/TECH_STACK.template.md" "TECH_STACK.template.md exists"
    assert_file_exists "$STARFORGE_ROOT/templates/initial-analysis-prompt.md" "initial-analysis-prompt.md exists"
}

# Test 3: Install Script Exists and is Executable
test_install_script() {
    echo ""
    echo "Test 3: Install Script"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    assert_file_exists "$STARFORGE_ROOT/bin/install.sh" "install.sh exists"
    assert_file_executable "$STARFORGE_ROOT/bin/install.sh" "install.sh is executable"
}

# Test 4: Installation in Empty Git Repo
test_install_empty_repo() {
    echo ""
    echo "Test 4: Installation in Empty Git Repo"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local test_project="$TEST_DIR/test-empty-repo"
    cleanup_test_project "$test_project"

    # Create test project
    mkdir -p "$test_project"
    cd "$test_project"
    git init -q
    git config user.name "Test User"
    git config user.email "test@test.com"

    # Create a dummy file and commit
    echo "# Test Project" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Run installer non-interactively
    # Input sequence: 3 (local only git), 1 (agent count), n (skip worktrees)
    echo -e "3\n1\nn" | "$STARFORGE_ROOT/bin/install.sh" > /dev/null 2>&1 || true

    # Verify directory structure
    assert_dir_exists "$test_project/.claude" ".claude directory created"
    assert_dir_exists "$test_project/.claude/agents" "agents directory created"
    assert_dir_exists "$test_project/.claude/scripts" "scripts directory created"
    assert_dir_exists "$test_project/.claude/hooks" "hooks directory created"
    assert_dir_exists "$test_project/.claude/coordination" "coordination directory created"
    assert_dir_exists "$test_project/.claude/triggers" "triggers directory created"
    assert_dir_exists "$test_project/.claude/spikes" "spikes directory created"
    assert_dir_exists "$test_project/.claude/scratchpads" "scratchpads directory created"

    # Verify agent files copied
    assert_file_exists "$test_project/.claude/agents/orchestrator.md" "orchestrator.md copied"
    assert_file_exists "$test_project/.claude/agents/senior-engineer.md" "senior-engineer.md copied"
    assert_file_exists "$test_project/.claude/agents/junior-engineer.md" "junior-engineer.md copied"
    assert_file_exists "$test_project/.claude/agents/qa-engineer.md" "qa-engineer.md copied"
    assert_file_exists "$test_project/.claude/agents/tpm-agent.md" "tpm-agent.md copied"

    # Verify scripts copied and executable
    assert_file_exists "$test_project/.claude/scripts/trigger-helpers.sh" "trigger-helpers.sh copied"
    assert_file_executable "$test_project/.claude/scripts/trigger-helpers.sh" "trigger-helpers.sh is executable"

    # Verify hooks copied and executable
    assert_file_exists "$test_project/.claude/hooks/block-main-edits.sh" "block-main-edits.sh copied"
    assert_file_executable "$test_project/.claude/hooks/block-main-edits.sh" "block-main-edits.sh is executable"

    # Verify config files
    assert_file_exists "$test_project/.claude/CLAUDE.md" "CLAUDE.md copied"
    assert_file_exists "$test_project/.claude/LEARNINGS.md" "LEARNINGS.md copied"
    assert_file_exists "$test_project/.claude/settings.json" "settings.json copied"
    assert_json_valid "$test_project/.claude/settings.json" "settings.json is valid JSON"

    # Verify learning files created
    assert_file_exists "$test_project/.claude/agents/agent-learnings/orchestrator/learnings.md" "orchestrator learnings created"
    assert_file_exists "$test_project/.claude/agents/agent-learnings/senior-engineer/learnings.md" "senior-engineer learnings created"
    assert_file_exists "$test_project/.claude/agents/agent-learnings/junior-engineer/learnings.md" "junior-engineer learnings created"

    # Verify .gitignore updated
    assert_file_exists "$test_project/.gitignore" ".gitignore exists"
    assert_file_contains "$test_project/.gitignore" ".claude/" ".gitignore contains .claude/"

    # Verify paths in settings.json updated
    assert_file_contains "$test_project/.claude/settings.json" "$test_project" "settings.json has correct path"

    cd - > /dev/null
    cleanup_test_project "$test_project"
}

# Test 5: Installation in Existing Project with Files
test_install_existing_project() {
    echo ""
    echo "Test 5: Installation in Existing Project"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local test_project="$TEST_DIR/test-existing-project"
    cleanup_test_project "$test_project"

    # Create test project with some files
    mkdir -p "$test_project/src"
    cd "$test_project"
    git init -q
    git config user.name "Test User"
    git config user.email "test@test.com"

    # Create mock project files
    echo "# Existing Project" > README.md
    echo "print('hello')" > src/main.py
    echo "def test_main(): pass" > src/test_main.py

    git add -A
    git commit -q -m "Existing project"

    # Run installer non-interactively
    # Input sequence: 3 (local only git), 1 (agent count), n (skip worktrees)
    echo -e "3\n1\nn" | "$STARFORGE_ROOT/bin/install.sh" > /dev/null 2>&1 || true

    # Verify installation succeeded
    assert_dir_exists "$test_project/.claude" ".claude installed in existing project"

    # Verify original files untouched
    assert_file_exists "$test_project/src/main.py" "Original files preserved"
    assert_file_contains "$test_project/src/main.py" "hello" "Original file content preserved"

    cd - > /dev/null
    cleanup_test_project "$test_project"
}

# Test 6: Worktree Creation
test_worktree_creation() {
    echo ""
    echo "Test 6: Worktree Creation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local test_project="$TEST_DIR/test-worktree"
    cleanup_test_project "$test_project"

    # Create test project
    mkdir -p "$test_project"
    cd "$test_project"
    git init -q
    git config user.name "Test User"
    git config user.email "test@test.com"

    echo "# Test" > README.md
    git add README.md
    git commit -q -m "Initial commit"

    # Run installer requesting 2 worktrees
    # Input sequence: 3 (local only git), 2 (agent count), y (proceed with worktrees)
    echo -e "3\n2\ny" | "$STARFORGE_ROOT/bin/install.sh" > /dev/null 2>&1 || true

    # Verify worktrees created
    local project_name=$(basename "$test_project")
    local parent_dir=$(dirname "$test_project")

    assert_dir_exists "$parent_dir/${project_name}-junior-dev-a" "Worktree A created"
    assert_dir_exists "$parent_dir/${project_name}-junior-dev-b" "Worktree B created"

    # Verify worktrees are valid git repos (worktrees have .git file, not directory)
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ -f "$parent_dir/${project_name}-junior-dev-a/.git" ]; then
        echo -e "  ${GREEN}✓${NC} Worktree A is valid git worktree"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Worktree A is not a valid git worktree"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cd - > /dev/null
    cleanup_test_project "$test_project"
    rm -rf "$parent_dir/${project_name}-junior-dev-a" 2>/dev/null || true
    rm -rf "$parent_dir/${project_name}-junior-dev-b" 2>/dev/null || true
}

# Test 7: Settings.json Path Replacement
test_settings_path_replacement() {
    echo ""
    echo "Test 7: Settings Path Replacement"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local test_project="$TEST_DIR/test-settings-path"
    cleanup_test_project "$test_project"

    mkdir -p "$test_project"
    cd "$test_project"
    git init -q
    git config user.name "Test User"
    git config user.email "test@test.com"
    echo "test" > file.txt
    git add -A
    git commit -q -m "init"

    # Run installer
    # Input sequence: 3 (local only git), 1 (agent count), n (skip worktrees)
    echo -e "3\n1\nn" | "$STARFORGE_ROOT/bin/install.sh" > /dev/null 2>&1 || true

    # Check settings.json has correct path
    assert_file_contains "$test_project/.claude/settings.json" "$test_project" "settings.json has correct project path"

    # Verify no old paths remain
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! grep -q "/Users/krunaaltavkar/empowerai" "$test_project/.claude/settings.json" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Old paths removed from settings.json"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} Old paths still in settings.json"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cd - > /dev/null
    cleanup_test_project "$test_project"
}

# Run all tests
run_all_tests() {
    test_prerequisites
    test_template_files
    test_install_script
    test_install_empty_repo
    test_install_existing_project
    test_worktree_creation
    test_settings_path_replacement
}

# Main execution
run_all_tests

# Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total tests:  $TESTS_RUN"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
else
    echo -e "Failed:       $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo ""
    exit 1
fi
