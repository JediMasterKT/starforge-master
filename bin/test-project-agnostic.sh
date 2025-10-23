#!/bin/bash
# Project-Agnostic Installation Test Script
# Validates that StarForge installation works with any project name and agent count
# This prevents hardcoding issues like Issue #36

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validate parameters
if [ $# -ne 2 ]; then
    echo -e "${RED}ERROR: Invalid arguments${NC}"
    echo "Usage: $0 <project_name> <agent_count>"
    echo "Example: $0 my-app 3"
    exit 1
fi

PROJECT_NAME="$1"
AGENT_COUNT="$2"

# Validate agent count is a number
if ! [[ "$AGENT_COUNT" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Agent count must be a positive integer${NC}"
    exit 1
fi

# Validate agent count range
if [ "$AGENT_COUNT" -lt 1 ]; then
    echo -e "${RED}ERROR: Agent count must be at least 1${NC}"
    exit 1
fi

# Warn if exceeding current installer limit (5 agents)
if [ "$AGENT_COUNT" -gt 5 ]; then
    echo -e "${YELLOW}WARNING: Current installer supports max 5 agents. Test will validate up to 5.${NC}"
    echo -e "${YELLOW}This test script is prepared for 10+ agents when installer is updated.${NC}"
    AGENT_COUNT=5  # Cap at current installer limit
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_REPOS_DIR="/tmp/test-repos"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Testing Installation: $PROJECT_NAME ($AGENT_COUNT agents)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cleanup function
cleanup() {
    local project_path="$TEST_REPOS_DIR/$PROJECT_NAME"

    if [ -d "$project_path" ]; then
        cd "$project_path" 2>/dev/null || true

        # Remove all worktrees
        if [ -d "$project_path/.git" ]; then
            git worktree list --porcelain 2>/dev/null | grep "^worktree" | cut -d' ' -f2 | while read -r worktree; do
                if [ "$worktree" != "$project_path" ]; then
                    echo "Removing worktree: $worktree"
                    git worktree remove "$worktree" --force 2>/dev/null || true
                    rm -rf "$worktree" 2>/dev/null || true
                fi
            done
        fi

        cd /tmp 2>/dev/null || true
        rm -rf "$project_path"
    fi

    # Clean up any leftover worktrees
    for letter in a b c d e f g h i j; do
        local worktree_path="$TEST_REPOS_DIR/${PROJECT_NAME}-junior-dev-${letter}"
        if [ -d "$worktree_path" ]; then
            echo "Cleaning up leftover worktree: $worktree_path"
            rm -rf "$worktree_path"
        fi
    done
}

# Run cleanup before starting
cleanup

# Create test directory
mkdir -p "$TEST_REPOS_DIR"
PROJECT_PATH="$TEST_REPOS_DIR/$PROJECT_NAME"

echo "📁 Creating temporary repository: $PROJECT_PATH"

# Create temporary git repository
mkdir -p "$PROJECT_PATH"
cd "$PROJECT_PATH"

git init -q
git config user.name "Test User"
git config user.email "test@test.com"

# Create initial commit
echo "# $PROJECT_NAME" > README.md
git add README.md
git commit -q -m "Initial commit"

echo -e "${GREEN}✓${NC} Repository created"
echo ""

# Run installation
echo "🚀 Running StarForge installation..."
echo ""

# Run installer non-interactively
# Input: 3 (local git only), <AGENT_COUNT>, y (proceed with worktrees)
echo -e "3\n$AGENT_COUNT\ny" | "$STARFORGE_ROOT/bin/install.sh" > /tmp/install-output.log 2>&1 || {
    echo -e "${RED}✗ Installation failed${NC}"
    cat /tmp/install-output.log
    cleanup
    exit 1
}

echo -e "${GREEN}✓${NC} Installation completed"
echo ""

# Test 1: Verify .claude directory created
echo "🔍 Test 1: Verify .claude directory created"
if [ -d "$PROJECT_PATH/.claude" ]; then
    echo -e "${GREEN}✓${NC} .claude directory exists"
else
    echo -e "${RED}✗${NC} .claude directory not found"
    cleanup
    exit 1
fi

# Test 2: Verify worktrees created with correct names
echo ""
echo "🔍 Test 2: Verify worktrees created"

# Map agent count to letters (a-j for 1-10)
LETTERS=("a" "b" "c" "d" "e" "f" "g" "h" "i" "j")

for i in $(seq 0 $((AGENT_COUNT - 1))); do
    letter="${LETTERS[$i]}"
    worktree_name="${PROJECT_NAME}-junior-dev-${letter}"
    worktree_path="$TEST_REPOS_DIR/$worktree_name"

    if [ -d "$worktree_path" ]; then
        echo -e "${GREEN}✓${NC} Worktree created: $worktree_name"
    else
        echo -e "${RED}✗${NC} Worktree not found: $worktree_name"
        cleanup
        exit 1
    fi
done

# Verify extra worktrees were NOT created
if [ "$AGENT_COUNT" -lt 10 ]; then
    next_letter="${LETTERS[$AGENT_COUNT]}"
    extra_worktree="$TEST_REPOS_DIR/${PROJECT_NAME}-junior-dev-${next_letter}"

    if [ -d "$extra_worktree" ]; then
        echo -e "${RED}✗${NC} Extra worktree found (should not exist): ${PROJECT_NAME}-junior-dev-${next_letter}"
        cleanup
        exit 1
    else
        echo -e "${GREEN}✓${NC} No extra worktrees created (correct count)"
    fi
fi

# Test 3: Verify agent detection in worktree
echo ""
echo "🔍 Test 3: Verify agent detection"

first_letter="${LETTERS[0]}"
first_worktree="$TEST_REPOS_DIR/${PROJECT_NAME}-junior-dev-${first_letter}"

cd "$first_worktree"

# Source project-env.sh from main repo (worktrees don't have .claude, it's in .gitignore)
if [ -f "$PROJECT_PATH/.claude/lib/project-env.sh" ]; then
    source "$PROJECT_PATH/.claude/lib/project-env.sh"

    # Check STARFORGE_AGENT_ID
    if [ "$STARFORGE_AGENT_ID" = "junior-dev-${first_letter}" ]; then
        echo -e "${GREEN}✓${NC} Agent ID detected correctly: $STARFORGE_AGENT_ID"
    else
        echo -e "${RED}✗${NC} Agent ID incorrect: expected junior-dev-${first_letter}, got $STARFORGE_AGENT_ID"
        cleanup
        exit 1
    fi

    # Check STARFORGE_PROJECT_NAME
    if [ "$STARFORGE_PROJECT_NAME" = "$PROJECT_NAME" ]; then
        echo -e "${GREEN}✓${NC} Project name detected correctly: $STARFORGE_PROJECT_NAME"
    else
        echo -e "${RED}✗${NC} Project name incorrect: expected $PROJECT_NAME, got $STARFORGE_PROJECT_NAME"
        cleanup
        exit 1
    fi

    # Check STARFORGE_MAIN_REPO (resolve paths to handle /tmp vs /private/tmp on macOS)
    RESOLVED_MAIN_REPO=$(cd "$STARFORGE_MAIN_REPO" && pwd -P)
    RESOLVED_PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd -P)
    if [ "$RESOLVED_MAIN_REPO" = "$RESOLVED_PROJECT_PATH" ]; then
        echo -e "${GREEN}✓${NC} Main repo path detected correctly"
    else
        echo -e "${RED}✗${NC} Main repo path incorrect: expected $RESOLVED_PROJECT_PATH, got $RESOLVED_MAIN_REPO"
        cleanup
        exit 1
    fi

    # Check STARFORGE_IS_WORKTREE
    if [ "$STARFORGE_IS_WORKTREE" = "true" ]; then
        echo -e "${GREEN}✓${NC} Worktree status detected correctly"
    else
        echo -e "${RED}✗${NC} Worktree status incorrect: expected true, got $STARFORGE_IS_WORKTREE"
        cleanup
        exit 1
    fi
else
    echo -e "${RED}✗${NC} project-env.sh not found in main repo"
    cleanup
    exit 1
fi

# Test 4: Check no hardcoded references in .claude/
echo ""
echo "🔍 Test 4: Check for hardcoded references"

cd "$PROJECT_PATH"

# List of patterns that should NOT appear in .claude/ files
# These are typical hardcoded values from Issue #36
FORBIDDEN_PATTERNS=(
    "empowerai"
    "/Users/krunaaltavkar/empowerai"
)

FOUND_ISSUES=false

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    # Search for pattern, excluding this test script, test files, and LEARNINGS.md (which contains examples)
    if grep -r "$pattern" .claude/ 2>/dev/null | grep -v "test" | grep -v ".git" | grep -v "LEARNINGS.md" > /dev/null; then
        echo -e "${RED}✗${NC} Found hardcoded reference to: $pattern"
        grep -r "$pattern" .claude/ 2>/dev/null | grep -v "test" | grep -v "LEARNINGS.md" | head -5
        FOUND_ISSUES=true
    fi
done

if [ "$FOUND_ISSUES" = "false" ]; then
    echo -e "${GREEN}✓${NC} No hardcoded references found"
fi

# Test 5: Verify project-env.sh is sourced in worktree
echo ""
echo "🔍 Test 5: Verify environment in all worktrees"

for i in $(seq 0 $((AGENT_COUNT - 1))); do
    letter="${LETTERS[$i]}"
    worktree_name="${PROJECT_NAME}-junior-dev-${letter}"
    worktree_path="$TEST_REPOS_DIR/$worktree_name"

    cd "$worktree_path"

    # Source from main repo and test
    # Note: unset variables first to ensure fresh detection
    unset STARFORGE_AGENT_ID STARFORGE_PROJECT_NAME STARFORGE_ENV_LOADED STARFORGE_ENV_SOURCE_DIR

    if source "$PROJECT_PATH/.claude/lib/project-env.sh" 2>/dev/null; then
        if [ "$STARFORGE_AGENT_ID" = "junior-dev-${letter}" ] && \
           [ "$STARFORGE_PROJECT_NAME" = "$PROJECT_NAME" ]; then
            echo -e "${GREEN}✓${NC} Worktree $worktree_name: environment valid"
        else
            echo -e "${RED}✗${NC} Worktree $worktree_name: environment invalid"
            echo "  Expected: junior-dev-${letter}, $PROJECT_NAME"
            echo "  Got: $STARFORGE_AGENT_ID, $STARFORGE_PROJECT_NAME"
            cleanup
            exit 1
        fi
    else
        echo -e "${RED}✗${NC} Failed to source project-env.sh in $worktree_name"
        cleanup
        exit 1
    fi
done

# Cleanup
echo ""
echo "🧹 Cleaning up test environment..."
cleanup

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ All tests passed!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
