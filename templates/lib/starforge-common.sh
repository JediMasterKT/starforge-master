#!/usr/bin/env bash
# StarForge Common Library
# Shared functions for install and update commands

# Ensure complete .claude/ directory structure
ensure_directory_structure() {
    local claude_dir="$1"

    echo "📁 Ensuring directory structure..."

    # Core directories (must exist before file operations)
    mkdir -p "$claude_dir"/{agents,scripts,hooks,bin,lib,coordination,triggers,backups}

    # Subdirectories for organization
    mkdir -p "$claude_dir/triggers/processed"
    mkdir -p "$claude_dir/spikes"
    mkdir -p "$claude_dir/scratchpads"
    mkdir -p "$claude_dir/breakdowns"  # Deprecated but kept for compatibility
    mkdir -p "$claude_dir/research"
    mkdir -p "$claude_dir/qa"

    # Agent-specific subdirectories
    mkdir -p "$claude_dir/agents/agent-learnings"
    mkdir -p "$claude_dir/agents/scratchpads"

    echo "✅ Core directory structure ready"
}

# Initialize agent-learnings with per-agent subdirectories
initialize_agent_learnings() {
    local claude_dir="$1"
    local starforge_dir="$2"

    echo "📚 Initializing agent learnings..."

    # Create per-agent directories
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        mkdir -p "$claude_dir/agents/agent-learnings/$agent"
        mkdir -p "$claude_dir/agents/scratchpads/$agent"

        # Copy template learnings.md if it doesn't exist (preserve user data)
        if [ ! -f "$claude_dir/agents/agent-learnings/$agent/learnings.md" ]; then
            if [ -f "$starforge_dir/templates/agents/agent-learnings/$agent/learnings.md" ]; then
                cp "$starforge_dir/templates/agents/agent-learnings/$agent/learnings.md" \
                   "$claude_dir/agents/agent-learnings/$agent/learnings.md"
                echo "  ✅ Initialized $agent/learnings.md"
            fi
        fi
    done

    echo "✅ Agent learnings initialized"
}

# Validate directory structure is complete
validate_directory_structure() {
    local claude_dir="$1"
    local errors=0

    echo "🔍 Validating directory structure..."

    # Check critical directories
    local required_dirs=(
        "agents"
        "agents/agent-learnings"
        "scripts"
        "lib"
        "bin"
        "hooks"
        "coordination"
        "triggers"
        "triggers/processed"
        "spikes"
    )

    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$claude_dir/$dir" ]; then
            echo "  ❌ Missing: $dir"
            ((errors++))
        fi
    done

    # Check per-agent directories
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        if [ ! -d "$claude_dir/agents/agent-learnings/$agent" ]; then
            echo "  ❌ Missing: agents/agent-learnings/$agent"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✅ Directory structure valid"
        return 0
    else
        echo "❌ Directory structure has $errors errors"
        return 1
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Version Detection and Migration System
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Detect installed StarForge version
detect_installed_version() {
    local claude_dir="$1"

    # Check for VERSION file (added in v1.0.0)
    if [ -f "$claude_dir/STARFORGE_VERSION" ]; then
        local version=$(jq -r '.version // "unknown"' "$claude_dir/STARFORGE_VERSION" 2>/dev/null || echo "unknown")
        if [ "$version" != "unknown" ] && [ -n "$version" ]; then
            echo "$version"
            return 0
        fi
    fi

    # Heuristic detection for pre-v1.0.0
    # Pre-1.0.0 didn't have agent-learnings subdirectories
    if [ ! -d "$claude_dir/agents/agent-learnings" ]; then
        echo "pre-1.0.0"
        return 0
    fi

    # If agent-learnings exists but no VERSION file, assume 1.0.0
    echo "1.0.0"
}

# Migrate from pre-1.0.0 to current version
migrate_from_pre_1_0_0() {
    local target_dir="$1"
    local claude_dir="$2"
    local starforge_dir="$3"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔄 Migrating from pre-v1.0.0${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 1. Create new directory structure
    echo "📁 Creating agent-learnings directories..."
    mkdir -p "$claude_dir/agents/agent-learnings"/{orchestrator,senior-engineer,junior-engineer,qa-engineer,tpm}
    mkdir -p "$claude_dir/agents/scratchpads"/{orchestrator,senior-engineer,junior-engineer,qa-engineer,tpm}
    mkdir -p "$claude_dir/spikes"
    mkdir -p "$claude_dir/research"
    mkdir -p "$claude_dir/qa"
    echo "✅ Directories created"
    echo ""

    # 2. Migrate old learnings if they exist
    echo "📚 Migrating agent learnings..."
    local migrated=0
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        # Check for old flat structure learnings.md
        if [ -f "$claude_dir/agents/${agent}-learnings.md" ]; then
            mv "$claude_dir/agents/${agent}-learnings.md" \
               "$claude_dir/agents/agent-learnings/$agent/learnings.md"
            echo "  ✅ Migrated $agent learnings"
            ((migrated++))
        else
            # Create empty learnings.md from template if exists
            if [ -f "$starforge_dir/templates/agents/agent-learnings/$agent/learnings.md" ]; then
                cp "$starforge_dir/templates/agents/agent-learnings/$agent/learnings.md" \
                   "$claude_dir/agents/agent-learnings/$agent/learnings.md"
                echo "  ✅ Initialized $agent learnings"
            fi
        fi
    done

    if [ $migrated -gt 0 ]; then
        echo "✅ Migrated $migrated agent learning files"
    else
        echo "✅ Agent learnings initialized"
    fi
    echo ""

    # 3. Copy .env.example if missing (for Discord)
    if [ ! -f "$target_dir/.env.example" ] && [ ! -f "$target_dir/.env" ]; then
        if [ -f "$starforge_dir/templates/.env.example" ]; then
            cp "$starforge_dir/templates/.env.example" "$target_dir/.env.example"
            echo "✅ Added .env.example"
            echo ""
            echo -e "${YELLOW}⚠️  ACTION REQUIRED: Configure Discord webhooks${NC}"
            echo -e "   1. Run: ${CYAN}starforge setup discord${NC}"
            echo -e "   2. Or manually copy .env.example to .env and add webhook URLs"
            echo ""
        fi
    fi

    echo -e "${GREEN}✅ Migration complete (pre-1.0.0 → 1.0.0+)${NC}"
    echo ""
}

# Migrate from 1.0.0 to current version
migrate_from_1_0_0() {
    local target_dir="$1"
    local claude_dir="$2"
    local starforge_dir="$3"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔄 Migrating from v1.0.0${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # For 1.0.0, just ensure all new directories exist
    echo "📁 Ensuring all directories exist..."
    ensure_directory_structure "$claude_dir"

    echo -e "${GREEN}✅ Migration complete (1.0.0 → 1.0.0+)${NC}"
    echo ""
}

# Validate StarForge installation after update
validate_installation() {
    local claude_dir="$1"
    local errors=0

    echo "🔍 Validating installation..."

    # Check critical directories
    local critical_dirs=(
        "agents"
        "agents/agent-learnings"
        "scripts"
        "lib"
        "bin"
        "hooks"
        "coordination"
        "triggers"
    )

    for dir in "${critical_dirs[@]}"; do
        if [ ! -d "$claude_dir/$dir" ]; then
            echo "  ❌ Missing directory: $dir"
            ((errors++))
        fi
    done

    # Check per-agent directories
    for agent in orchestrator senior-engineer junior-engineer qa-engineer tpm; do
        if [ ! -d "$claude_dir/agents/agent-learnings/$agent" ]; then
            echo "  ❌ Missing agent-learnings for: $agent"
            ((errors++))
        fi
    done

    # Check critical files
    local critical_files=(
        "CLAUDE.md"
        "settings.json"
    )

    for file in "${critical_files[@]}"; do
        if [ ! -f "$claude_dir/$file" ]; then
            echo "  ❌ Missing file: $file"
            ((errors++))
        fi
    done

    if [ $errors -eq 0 ]; then
        echo "✅ Installation valid"
        return 0
    else
        echo "❌ Installation has $errors errors"
        echo ""
        echo -e "${RED}Installation validation failed!${NC}"
        echo -e "If you have a backup, you can restore it:"
        echo -e "  ${CYAN}starforge restore <backup-name>${NC}"
        echo ""
        return 1
    fi
}
