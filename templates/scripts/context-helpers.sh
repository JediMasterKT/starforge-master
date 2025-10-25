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

# ============================================================================
# BREAKDOWN ANALYSIS HELPERS (for senior-engineer)
# ============================================================================

# Get the most recent spike directory
# Replaces: ls -td "$STARFORGE_CLAUDE_DIR/spikes/spike-"* | head -1
get_latest_spike_dir() {
    if [ ! -d "$STARFORGE_CLAUDE_DIR/spikes" ]; then
        return 1
    fi

    # Use ls -td to sort by time (newest first), filter for spike- pattern
    local spike_dir=$(ls -td "$STARFORGE_CLAUDE_DIR/spikes/spike-"* 2>/dev/null | head -1)

    if [ -n "$spike_dir" ]; then
        echo "$spike_dir"
        return 0
    else
        return 1
    fi
}

# Extract feature name from breakdown file
# Replaces: grep "^# Task Breakdown:" "$BREAKDOWN_PATH" | sed 's/# Task Breakdown: //'
get_feature_name_from_breakdown() {
    local breakdown_file=$1

    if [ ! -f "$breakdown_file" ]; then
        return 1
    fi

    # Extract feature name from "# Task Breakdown: Feature Name" line
    local feature_name=$(grep "^# Task Breakdown:" "$breakdown_file" | sed 's/# Task Breakdown: //')

    if [ -n "$feature_name" ]; then
        echo "$feature_name"
        return 0
    else
        return 1
    fi
}

# Count subtasks in breakdown file
# Replaces: grep -c "^### Subtask" "$BREAKDOWN_PATH"
get_subtask_count_from_breakdown() {
    local breakdown_file=$1

    if [ ! -f "$breakdown_file" ]; then
        echo "0"
        return 1
    fi

    # Count lines starting with "### Subtask"
    # Use grep -c which returns count, or 0 if no matches
    local count
    count=$(grep -c "^### Subtask" "$breakdown_file" 2>/dev/null)

    # grep -c returns 0 if no matches, non-zero exit code if no file
    # We already checked file exists, so we can safely use the count
    if [ $? -eq 0 ]; then
        echo "$count"
        return 0
    else
        echo "0"
        return 0
    fi
}
