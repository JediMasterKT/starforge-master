#!/bin/bash
# Context Reading Helpers
# Purpose: Eliminate permission prompts from piped context reading commands
# Workaround for: https://github.com/anthropics/claude-code/issues/5465

# Get project context (first 15 lines)
# Replaces: cat "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" | head -15
get_project_context() {
    if [ -f "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" ]; then
        cat "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" | head -15
    else
        echo "❌ PROJECT_CONTEXT.md not found"
        return 1
    fi
}

# Get building summary from project context
# Replaces: grep '##.*Building' "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" | head -1
get_building_summary() {
    if [ -f "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" ]; then
        grep '##.*Building' "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" | head -1
    else
        echo "Unknown"
    fi
}

# Get tech stack (first 15 lines)
# Replaces: cat "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -15
get_tech_stack() {
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        cat "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -15
    else
        echo "❌ TECH_STACK.md not found"
        return 1
    fi
}

# Get primary technology
# Replaces: grep 'Primary:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1
get_primary_tech() {
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        grep 'Primary:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1
    else
        echo "Unknown"
    fi
}

# Get test command from tech stack
# Replaces: grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2
get_test_command() {
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2
    else
        echo "pytest"  # Default fallback
    fi
}

# Get full tech stack summary (one-liner for logs)
get_tech_stack_summary() {
    echo "Tech Stack: $(get_primary_tech)"
}

# Verify context files exist
check_context_files() {
    local missing=0

    if [ ! -f "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" ]; then
        echo "❌ PROJECT_CONTEXT.md missing"
        missing=1
    fi

    if [ ! -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        echo "❌ TECH_STACK.md missing"
        missing=1
    fi

    return $missing
}

# Count learning entries in learnings file
# Replaces: grep -c "^##.*Learning" "$LEARNINGS" || echo "0"
count_learnings() {
    local learnings_file=$1

    if [ -z "$learnings_file" ]; then
        echo "❌ Learnings file path required"
        return 1
    fi

    if [ ! -f "$learnings_file" ]; then
        echo "0"
        return 0  # Not an error, just no learnings yet
    fi

    local count=$(grep -c "^##.*Learning" "$learnings_file" 2>/dev/null || echo "0")

    echo "$count"
}
