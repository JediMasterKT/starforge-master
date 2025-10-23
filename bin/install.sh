#!/bin/bash
# StarForge Installation Script
# Installs AI agent development system into a project

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emoji support
CHECK="✅"
WARN="⚠️ "
ERROR="❌"
INFO="ℹ️ "
ROCKET="🚀"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$STARFORGE_ROOT/templates"

# Target directory is current working directory
TARGET_DIR="$(pwd)"
CLAUDE_DIR="$TARGET_DIR/.claude"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${ROCKET} ${BLUE}StarForge - AI Development Team${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${INFO}Checking prerequisites..."

    local all_good=true

    # Check git
    if command -v git &> /dev/null; then
        echo -e "${CHECK} Git: $(git --version)"
    else
        echo -e "${ERROR} Git: not found"
        all_good=false
    fi

    # Check GitHub CLI
    if command -v gh &> /dev/null; then
        echo -e "${CHECK} GitHub CLI: $(gh --version | head -1)"

        # Check if authenticated
        if gh auth status &> /dev/null; then
            local username=$(gh api user -q .login 2>/dev/null || echo "authenticated")
            echo -e "${CHECK} GitHub Auth: $username"
        else
            echo -e "${WARN}GitHub CLI: not authenticated"
            echo -e "   ${YELLOW}Run: gh auth login${NC}"
        fi
    else
        echo -e "${ERROR} GitHub CLI: not found"
        echo -e "   ${YELLOW}Install from: https://cli.github.com${NC}"
        all_good=false
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        echo -e "${CHECK} jq: $(jq --version)"
    else
        echo -e "${ERROR} jq: not found"
        echo -e "   ${YELLOW}Install: brew install jq${NC}"
        all_good=false
    fi

    # Check terminal-notifier (optional but recommended)
    if command -v terminal-notifier &> /dev/null; then
        echo -e "${CHECK} terminal-notifier: installed"
    else
        echo -e "${INFO} terminal-notifier: not found (optional)"
        echo -e "   ${YELLOW}Install: brew install terminal-notifier${NC}"
    fi

    echo ""

    if [ "$all_good" = false ]; then
        echo -e "${ERROR} ${RED}Prerequisites missing. Please install required tools and try again.${NC}"
        exit 1
    fi
}

# Function to detect project type
detect_project_type() {
    local file_count=$(find . -maxdepth 3 -type f 2>/dev/null | wc -l | tr -d ' ')

    if [ $file_count -gt 0 ]; then
        echo -e "${CHECK} Detected: Existing project with $file_count files"
        PROJECT_TYPE="existing"
    else
        echo -e "${CHECK} Detected: New/empty project"
        PROJECT_TYPE="new"
    fi

    # Check for git repo
    if [ -d ".git" ]; then
        echo -e "${CHECK} Detected: Git repository (.git/ found)"
        HAS_GIT=true
    else
        echo -e "${INFO} No git repository detected"
        HAS_GIT=false
    fi
}

# Function to configure git remote
configure_git_remote() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🔗 ${BLUE}Git Remote Configuration${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check if remote already exists
    if git remote get-url origin &> /dev/null; then
        local remote_url=$(git remote get-url origin)
        echo -e "${CHECK} Remote 'origin' already configured: $remote_url"
        return
    fi

    echo -e "${YELLOW}StarForge agents work best with GitHub for:${NC}"
    echo -e "  ${CHECK} TPM creates GitHub Issues (task tracking)"
    echo -e "  ${CHECK} Junior-devs create Pull Requests (code review)"
    echo -e "  ${CHECK} QA comments on PRs (feedback loop)"
    echo -e "  ${CHECK} Orchestrator tracks progress via GitHub API"
    echo ""
    echo -e "${YELLOW}Without GitHub:${NC}"
    echo -e "  ${WARN}No issue tracking (manual task management)"
    echo -e "  ${WARN}No PR workflow (direct commits to main)"
    echo -e "  ${WARN}No QA integration (manual testing only)"
    echo ""

    echo "? Would you like to set up GitHub remote? (Recommended)"
    echo "  [1] Yes, I have a GitHub repository"
    echo "  [2] Yes, help me create one"
    echo "  [3] No, local only (limited features)"
    read -p "Your choice: " git_choice

    case $git_choice in
        1)
            read -p "? GitHub repository URL: " repo_url
            git remote add origin "$repo_url"
            git branch -M main 2>/dev/null || true
            echo -e "${CHECK} Remote 'origin' added: $repo_url"

            read -p "? Push existing code to GitHub? (y/n): " push_choice
            if [ "$push_choice" = "y" ]; then
                git push -u origin main
                echo -e "${CHECK} Pushed to GitHub"
            fi
            ;;
        2)
            echo ""
            echo -e "${BLUE}Creating GitHub repository...${NC}"
            echo ""
            read -p "? Repository name: " repo_name
            read -p "? Private repository? (y/n) [y]: " private_choice
            private_choice=${private_choice:-y}

            if [ "$private_choice" = "y" ]; then
                gh repo create "$repo_name" --private --source=. --remote=origin --push
            else
                gh repo create "$repo_name" --public --source=. --remote=origin --push
            fi

            echo -e "${CHECK} Repository created and pushed!"
            ;;
        3)
            echo -e "${INFO} Skipping GitHub setup (local only mode)"
            ;;
        *)
            echo -e "${WARN}Invalid choice, skipping GitHub setup"
            ;;
    esac

    echo ""
}

# Function to create directory structure
create_structure() {
    echo -e "${INFO}Creating .claude/ directory structure..."

    mkdir -p "$CLAUDE_DIR"/{agents,scripts,hooks,coordination,triggers/processed,spikes,scratchpads,breakdowns,research,qa,lib}
    mkdir -p "$CLAUDE_DIR/agents/agent-learnings"/{orchestrator,senior-engineer,junior-engineer,qa-engineer,tpm}
    mkdir -p "$CLAUDE_DIR/agents/scratchpads"/{orchestrator,senior-engineer,junior-engineer,qa-engineer,tpm}

    echo -e "${CHECK} Created directory structure"
}

# Function to copy agent files
copy_agent_files() {
    echo -e "${INFO}Installing agent definitions..."

    # Copy agent definition files
    cp "$TEMPLATE_DIR/agents"/*.md "$CLAUDE_DIR/agents/"

    # Copy scripts
    cp "$TEMPLATE_DIR/scripts"/*.sh "$CLAUDE_DIR/scripts/"
    chmod +x "$CLAUDE_DIR/scripts"/*.sh

    # Copy hooks
    cp "$TEMPLATE_DIR/hooks"/*.sh "$CLAUDE_DIR/hooks/"
    chmod +x "$CLAUDE_DIR/hooks"/*.sh

    # Copy lib files
    echo -e "${INFO}Installing library files..."
    cp "$TEMPLATE_DIR/lib/project-env.sh" "$CLAUDE_DIR/lib/"
    chmod +x "$CLAUDE_DIR/lib/project-env.sh"
    echo -e "${CHECK} Library installed"

    # Copy protocol files
    cp "$TEMPLATE_DIR/CLAUDE.md" "$CLAUDE_DIR/"
    cp "$TEMPLATE_DIR/LEARNINGS.md" "$CLAUDE_DIR/"

    # Copy settings with placeholder replacement
    sed "s|{{PROJECT_DIR}}|$TARGET_DIR|g" "$TEMPLATE_DIR/settings/settings.json" > "$CLAUDE_DIR/settings.json"

    # Create empty learning files
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        cat > "$CLAUDE_DIR/agents/agent-learnings/$agent/learnings.md" << 'EOF'
# Agent Learnings

Project-specific learnings and patterns for this agent.

---

## Template for New Learnings

```markdown
## Learning N: [Title]

**Date:** YYYY-MM-DD

**What happened:**
[Description of situation]

**What was learned:**
[Key insight or pattern discovered]

**Why it matters:**
[Impact and importance]

**Corrected approach:**
[How to do it right]

**Related documentation:**
[Links to relevant agent files or protocols]
```
EOF
    done

    echo -e "${CHECK} Installed agent definitions:${NC}"
    echo -e "   - orchestrator, senior-engineer, junior-engineer"
    echo -e "   - qa-engineer, tpm-agent"
}

# Function to configure worktrees
configure_worktrees() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "🤖 ${BLUE}Agent Team Setup${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "StarForge uses AI agents that work in parallel on different tasks."
    echo ""

    read -p "? How many junior-dev agents do you want? (1-5) [3]: " agent_count
    agent_count=${agent_count:-3}

    # Validate input
    if ! [[ "$agent_count" =~ ^[1-5]$ ]]; then
        echo -e "${WARN}Invalid input. Using default: 3"
        agent_count=3
    fi

    echo ""
    echo -e "${INFO} You chose $agent_count agents. This means:"
    echo -e "   - $agent_count tasks can be worked on simultaneously"
    echo -e "   - $agent_count git worktrees will be created"

    if [ $agent_count -le 2 ]; then
        echo -e "   - Lower resource usage, good for smaller projects"
    else
        echo -e "   - Higher throughput, good for larger projects"
    fi

    echo ""
    read -p "? Proceed? (y/n) [y]: " proceed
    proceed=${proceed:-y}

    if [ "$proceed" != "y" ]; then
        echo -e "${WARN}Skipping worktree creation"
        return
    fi

    # Create worktrees
    local project_name=$(basename "$TARGET_DIR")
    local parent_dir=$(dirname "$TARGET_DIR")
    local letters=(a b c d e)

    echo ""
    echo -e "${INFO}Creating git worktrees..."

    for i in $(seq 0 $(($agent_count - 1))); do
        local letter=${letters[$i]}
        local worktree_name="${project_name}-junior-dev-${letter}"
        local worktree_path="$parent_dir/$worktree_name"

        # Create worktree
        if [ -d "$worktree_path" ]; then
            echo -e "${WARN}Worktree already exists: $worktree_path"
        else
            # Create worktree on main branch (use -b to create new tracking branch)
            # The worktree will be on the same commit as main but have its own working directory
            if git worktree add "$worktree_path" -b "worktree-${letter}" main 2>/dev/null; then
                echo -e "${CHECK} Worktree: $worktree_path"
            elif git worktree add "$worktree_path" -b "worktree-${letter}" master 2>/dev/null; then
                echo -e "${CHECK} Worktree: $worktree_path"
            else
                echo -e "${ERROR} Failed to create worktree: $worktree_path"
                continue
            fi
        fi
    done

    echo ""
    echo -e "${CHECK} Created $agent_count git worktrees for parallel development"
}

# Function to add to gitignore
update_gitignore() {
    echo -e "${INFO}Protecting StarForge IP..."

    if [ -f ".gitignore" ]; then
        if ! grep -q ".claude/" ".gitignore"; then
            echo ".claude/" >> ".gitignore"
            echo -e "${CHECK} Added .claude/ to .gitignore"
        else
            echo -e "${CHECK} .claude/ already in .gitignore"
        fi
    else
        echo ".claude/" > ".gitignore"
        echo -e "${CHECK} Created .gitignore with .claude/"
    fi

    echo ""
    echo -e "${WARN} ${YELLOW}IMPORTANT: .claude/ is StarForge intellectual property${NC}"
    echo -e "   - Never commit to git"
    echo -e "   - Do not modify agent definitions"
    echo -e "   - Only PROJECT_CONTEXT.md and TECH_STACK.md are yours to edit"
}

# Main installation flow
main() {
    check_prerequisites
    detect_project_type

    if [ "$HAS_GIT" = false ]; then
        echo ""
        read -p "? Initialize git repository? (y/n) [y]: " init_git
        init_git=${init_git:-y}

        if [ "$init_git" = "y" ]; then
            git init
            git add -A
            git commit -m "Initial commit"
            echo -e "${CHECK} Git repository initialized"
            HAS_GIT=true
        fi
    fi

    if [ "$HAS_GIT" = true ]; then
        configure_git_remote
    fi

    create_structure
    copy_agent_files

    if [ "$HAS_GIT" = true ]; then
        configure_worktrees
    fi

    update_gitignore

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CHECK} ${GREEN}StarForge setup complete!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ "$PROJECT_TYPE" = "existing" ]; then
        echo -e "${BLUE}📚 Next steps:${NC}"
        echo ""
        echo -e "1. ${YELLOW}Analyze your project:${NC}"
        echo -e "   $ starforge analyze"
        echo ""
        echo -e "   This will:"
        echo -e "   - Scan all files in your repository"
        echo -e "   - Generate PROJECT_CONTEXT.md and TECH_STACK.md"
        echo -e "   - Create initial-assessment.md"
        echo ""
        echo -e "2. ${YELLOW}Start the trigger monitor (in a separate terminal):${NC}"
        echo -e "   $ starforge monitor"
        echo ""
        echo -e "3. ${YELLOW}Invoke senior-engineer to create breakdown:${NC}"
        echo -e "   $ starforge use senior-engineer"
        echo ""
    else
        echo -e "${BLUE}📚 Next steps for new project:${NC}"
        echo ""
        echo -e "1. ${YELLOW}Brainstorm your project vision:${NC}"
        echo -e "   $ starforge brainstorm"
        echo ""
        echo -e "2. ${YELLOW}Start the trigger monitor:${NC}"
        echo -e "   $ starforge monitor"
        echo ""
    fi

    echo -e "4. ${YELLOW}View system status:${NC}"
    echo -e "   $ starforge status"
    echo ""
    echo -e "5. ${YELLOW}Learn more:${NC}"
    echo -e "   $ starforge help"
    echo ""
    echo -e "${ROCKET} ${GREEN}Happy building!${NC}"
    echo ""
}

# Run main installation
main
