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

# Function to check dependencies
check_dependencies() {
    local has_all_required=true
    local platform=$(uname -s)

    echo -e "${BLUE}Checking dependencies...${NC}"
    echo ""

    # Required dependencies
    local required_deps=("git" "jq" "gh")
    local missing_required=()

    for dep in "${required_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            local version=$($dep --version 2>&1 | head -1)
            echo -e "${GREEN}✓${NC} $dep: $version"
        else
            echo -e "${RED}✗${NC} $dep: NOT FOUND"
            missing_required+=("$dep")
            has_all_required=false
        fi
    done

    # Optional dependencies
    local optional_deps=("fswatch")

    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &> /dev/null; then
            local version=$($dep --version 2>&1 | head -1)
            echo -e "${GREEN}✓${NC} $dep: $version"
        else
            echo -e "${YELLOW}⚠${NC}  $dep: NOT FOUND (optional, needed for daemon mode)"
        fi
    done

    echo ""

    # If missing required dependencies, show install instructions
    if [ "$has_all_required" = false ]; then
        echo -e "${RED}❌ Missing required dependencies${NC}"
        echo ""
        echo "Install missing dependencies:"
        echo ""

        for dep in "${missing_required[@]}"; do
            case "$platform" in
                Darwin)
                    echo -e "  ${YELLOW}$dep:${NC} brew install $dep"
                    ;;
                Linux)
                    # Detect Linux distro
                    if [ -f /etc/debian_version ]; then
                        echo -e "  ${YELLOW}$dep:${NC} sudo apt-get install $dep"
                    elif [ -f /etc/redhat-release ]; then
                        echo -e "  ${YELLOW}$dep:${NC} sudo yum install $dep"
                    else
                        echo -e "  ${YELLOW}$dep:${NC} (install via your package manager)"
                    fi
                    ;;
                *)
                    echo -e "  ${YELLOW}$dep:${NC} (install via your package manager)"
                    ;;
            esac
        done

        echo ""
        return 1
    fi

    echo -e "${GREEN}✓ All required dependencies installed${NC}"
    echo ""
    return 0
}

# Function to check permissions
check_permissions() {
    local target_dir="$1"
    local operation="${2:-install}"  # install or update

    echo -e "${BLUE}Checking permissions...${NC}"
    echo ""

    # Check if directory exists and is writable
    if [ -d "$target_dir" ]; then
        if [ ! -w "$target_dir" ]; then
            echo -e "${RED}❌ No write permission: $target_dir${NC}"
            echo ""
            echo "Current permissions:"
            ls -ld "$target_dir"
            echo ""
            echo "Fix with:"
            echo -e "  ${YELLOW}sudo chown -R \$USER $target_dir${NC}"
            echo "  or"
            echo -e "  ${YELLOW}chmod u+w $target_dir${NC}"
            echo ""
            return 1
        fi
    else
        # Check parent directory
        local parent_dir=$(dirname "$target_dir")
        if [ ! -w "$parent_dir" ]; then
            echo -e "${RED}❌ No write permission: $parent_dir${NC}"
            echo ""
            echo "Cannot create $target_dir in non-writable directory"
            echo ""
            echo "Current permissions:"
            ls -ld "$parent_dir"
            echo ""
            echo "Fix with:"
            echo -e "  ${YELLOW}sudo chown -R \$USER $parent_dir${NC}"
            echo ""
            return 1
        fi
    fi

    # Check git worktree permissions (if .git exists)
    if [ -d ".git" ] || [ -f ".git" ]; then
        local git_dir=$(git rev-parse --git-common-dir 2>/dev/null)
        if [ -n "$git_dir" ] && [ ! -w "$git_dir" ]; then
            echo -e "${RED}❌ No write permission: $git_dir${NC}"
            echo ""
            echo "Cannot create git worktrees without write access"
            echo ""
            echo "Fix with:"
            echo -e "  ${YELLOW}sudo chown -R \$USER $git_dir${NC}"
            echo ""
            return 1
        fi
    fi

    echo -e "${GREEN}✓ Permissions OK${NC}"
    echo ""
    return 0
}

# Legacy function for backward compatibility
check_prerequisites() {
    # Call the new dependency check function
    if ! check_dependencies; then
        echo -e "${ERROR} ${RED}Installation aborted: Missing dependencies${NC}"
        exit 1
    fi

    # Additional checks for GitHub authentication (not blocking)
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            local username=$(gh api user -q .login 2>/dev/null || echo "authenticated")
            echo -e "${CHECK} GitHub Auth: $username"
        else
            echo -e "${WARN}GitHub CLI: not authenticated"
            echo -e "   ${YELLOW}Run: gh auth login${NC}"
        fi
    fi

    echo ""
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

# Function to detect corrupted .claude installation
detect_corrupted_installation() {
    local claude_dir="$1"

    # Check if .claude exists but is corrupted
    if [ ! -d "$claude_dir" ]; then
        return 1  # Not corrupted, just doesn't exist
    fi

    # Check for critical files and directories
    local is_corrupted=false

    # Missing settings.json
    if [ ! -f "$claude_dir/settings.json" ]; then
        is_corrupted=true
    fi

    # Malformed settings.json
    if [ -f "$claude_dir/settings.json" ]; then
        if ! jq empty "$claude_dir/settings.json" 2>/dev/null; then
            is_corrupted=true
        fi
    fi

    # Missing CLAUDE.md
    if [ ! -f "$claude_dir/CLAUDE.md" ]; then
        is_corrupted=true
    fi

    # Missing required directories
    for dir in agents hooks scripts; do
        if [ ! -d "$claude_dir/$dir" ]; then
            is_corrupted=true
        fi
    done

    if [ "$is_corrupted" = true ]; then
        return 0  # Corrupted
    else
        return 1  # Not corrupted
    fi
}

# Function to backup corrupted installation and offer reinstall
backup_corrupted_installation() {
    local claude_dir="$1"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_dir="$claude_dir/backups/corrupted-$timestamp"

    echo -e "${YELLOW}Found corrupted installation at $claude_dir${NC}"
    echo ""

    # TTY Check: Detects if running non-interactively (tests, CI/CD, piped input)
    # [ ! -t 0 ] returns true when stdin is NOT a terminal
    # In non-interactive mode, we auto-proceed to avoid hanging
    if [ ! -t 0 ]; then
        # Non-interactive mode: auto-proceed with backup
        echo "Non-interactive mode detected - proceeding with backup automatically"
        echo -e "${BLUE}Creating backup...${NC}"
        mkdir -p "$backup_dir"

        # Copy all existing .claude contents to backup (excluding backups dir itself)
        find "$claude_dir" -maxdepth 1 ! -name backups ! -path "$claude_dir" -exec cp -r {} "$backup_dir/" \; 2>/dev/null || true

        local file_count=$(find "$backup_dir" -type f | wc -l | tr -d ' ')
        echo -e "${GREEN}${CHECK} Backed up $file_count files to:${NC}"
        echo "  $backup_dir"
        echo ""

        echo -e "${BLUE}Removing corrupted installation...${NC}"
        # Remove everything except backups directory
        find "$claude_dir" -maxdepth 1 ! -name backups ! -path "$claude_dir" -exec rm -rf {} \; 2>/dev/null || true
        echo -e "${GREEN}${CHECK} Removed corrupted installation${NC}"
        echo ""

        return 0  # Proceed with install
    fi

    # Interactive mode: prompt user
    echo "Options:"
    echo "  1. Backup corrupted files and reinstall (recommended)"
    echo "  2. Abort installation"
    echo ""
    read -p "Backup and reinstall? [y/n]: " -n 1 -r choice
    echo ""

    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Creating backup...${NC}"
        mkdir -p "$backup_dir"

        # Copy all existing .claude contents to backup (excluding backups dir itself)
        find "$claude_dir" -maxdepth 1 ! -name backups ! -path "$claude_dir" -exec cp -r {} "$backup_dir/" \; 2>/dev/null || true

        local file_count=$(find "$backup_dir" -type f | wc -l | tr -d ' ')
        echo -e "${GREEN}${CHECK} Backed up $file_count files to:${NC}"
        echo "  $backup_dir"
        echo ""

        echo -e "${BLUE}Removing corrupted installation...${NC}"
        # Remove everything except backups directory
        find "$claude_dir" -maxdepth 1 ! -name backups ! -path "$claude_dir" -exec rm -rf {} \; 2>/dev/null || true
        echo -e "${GREEN}${CHECK} Removed corrupted installation${NC}"
        echo ""

        return 0  # Proceed with install
    else
        echo -e "${RED}Installation aborted${NC}"
        return 1  # Don't proceed
    fi
}

# Function to create directory structure
create_structure() {
    echo -e "${INFO}Creating .claude/ directory structure..."

    # Source shared library
    source "$TEMPLATE_DIR/lib/starforge-common.sh"

    # Create directory structure
    ensure_directory_structure "$CLAUDE_DIR"

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

    # Copy hooks (all files, skip directories like __pycache__)
    find "$TEMPLATE_DIR/hooks" -maxdepth 1 -type f -exec cp {} "$CLAUDE_DIR/hooks/" \;
    chmod +x "$CLAUDE_DIR/hooks"/*.sh "$CLAUDE_DIR/hooks"/*.py 2>/dev/null || true

    # Copy lib files
    echo -e "${INFO}Installing library files..."
    cp "$TEMPLATE_DIR/lib"/*.sh "$CLAUDE_DIR/lib/"
    chmod +x "$CLAUDE_DIR/lib"/*.sh
    echo -e "${CHECK} Library installed"

    # Copy protocol files
    cp "$TEMPLATE_DIR/CLAUDE.md" "$CLAUDE_DIR/"
    cp "$TEMPLATE_DIR/LEARNINGS.md" "$CLAUDE_DIR/"

    # Copy settings with placeholder replacement
    sed "s|{{PROJECT_DIR}}|$TARGET_DIR|g" "$TEMPLATE_DIR/settings/settings.json" > "$CLAUDE_DIR/settings.json"

    # Copy .env.example for Discord webhook configuration
    if [ -f "$TEMPLATE_DIR/.env.example" ]; then
        cp "$TEMPLATE_DIR/.env.example" "$TARGET_DIR/.env.example"
        echo -e "${INFO}Added .env.example (configure for Discord notifications)"
    fi

    # Initialize agent learnings (uses shared library)
    source "$TEMPLATE_DIR/lib/starforge-common.sh"
    initialize_agent_learnings "$CLAUDE_DIR" "$STARFORGE_ROOT"

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

# Prompt user to set up Discord notifications
prompt_discord_setup() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔔 Discord Notifications${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "StarForge agents work autonomously and post updates to Discord."
    echo -e "This lets you ${GREEN}walk away and get notified when they're done${NC}."
    echo ""

    # Check if Discord is already configured
    if [ -f ".env" ] && grep -q "DISCORD_WEBHOOK_" ".env" 2>/dev/null; then
        echo -e "${CHECK} Discord notifications already configured"
        echo ""
        return 0
    fi

    # Prompt user
    read -p "Set up Discord notifications now? (y/n) [y]: " setup_discord
    setup_discord=${setup_discord:-y}

    if [ "$setup_discord" = "y" ] || [ "$setup_discord" = "Y" ]; then
        echo ""

        # Check if discord-setup.sh exists
        local discord_setup="$STARFORGE_ROOT/templates/scripts/discord-setup.sh"
        if [ ! -f "$discord_setup" ]; then
            echo -e "${WARN} ${YELLOW}Discord setup script not found${NC}"
            echo -e "   You can set up Discord later with: ${CYAN}starforge setup discord${NC}"
            echo ""
            return 1
        fi

        # Check dependencies
        if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
            echo -e "${WARN} ${YELLOW}Missing dependencies (curl, jq)${NC}"
            echo -e "   You can set up Discord later with: ${CYAN}starforge setup discord${NC}"
            echo ""
            return 1
        fi

        # Run Discord setup wizard
        bash "$discord_setup"
        local setup_status=$?

        if [ $setup_status -eq 0 ]; then
            echo ""
            echo -e "${CHECK} ${GREEN}Discord notifications configured!${NC}"
        else
            echo ""
            echo -e "${WARN} ${YELLOW}Discord setup skipped or failed${NC}"
            echo -e "   You can set up later with: ${CYAN}starforge setup discord${NC}"
        fi
        echo ""
    else
        echo ""
        echo -e "${WARN} ${YELLOW}Skipping Discord setup${NC}"
        echo -e "   You can set up later with: ${CYAN}starforge setup discord${NC}"
        echo -e "   ${RED}Warning: Without notifications, you'll need to monitor agents manually${NC}"
        echo ""
    fi
}

# Main installation flow
main() {
    check_prerequisites

    # Check for corrupted installation BEFORE doing anything else
    if detect_corrupted_installation "$CLAUDE_DIR"; then
        if ! backup_corrupted_installation "$CLAUDE_DIR"; then
            exit 1  # User chose to abort
        fi
    fi

    # Check permissions before proceeding
    if ! check_permissions "$TARGET_DIR" "install"; then
        exit 1
    fi

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

    # Validate directory structure (uses shared library)
    source "$TEMPLATE_DIR/lib/starforge-common.sh"
    validate_directory_structure "$CLAUDE_DIR"

    if [ "$HAS_GIT" = true ]; then
        configure_worktrees
    fi

    update_gitignore

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CHECK} ${GREEN}StarForge setup complete!${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Prompt for Discord notifications setup
    prompt_discord_setup

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
