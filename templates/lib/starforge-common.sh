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
