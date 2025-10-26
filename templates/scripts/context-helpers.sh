#!/bin/bash
# Context Reading Helpers
# Purpose: Use MCP tools to access StarForge context files
# Updated for MCP integration (Issue #188)

# Ensure MCP tools are loaded
if [ -z "$(type -t get_project_context 2>/dev/null)" ]; then
    # MCP tools not loaded, load them
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/../lib/mcp-tools-trigger.sh" 2>/dev/null || true
fi

# Get project context (first 15 lines)
# Uses MCP tool: get_project_context from mcp-tools-trigger.sh
# Returns PROJECT_CONTEXT.md contents via MCP
get_project_context() {
    # Call MCP tool (already defined in mcp-tools-trigger.sh)
    # If not available, fall back to direct read
    if type -t get_project_context_mcp >/dev/null 2>&1; then
        get_project_context_mcp | head -15
    elif [ -f "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" ]; then
        cat "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" | head -15
    else
        echo "❌ PROJECT_CONTEXT.md not found"
        return 1
    fi
}

# Get building summary from project context
# Uses grep on MCP tool output
get_building_summary() {
    if [ -f "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" ]; then
        # Use MCP tool if available, otherwise direct read
        if type -t get_project_context_mcp >/dev/null 2>&1; then
            get_project_context_mcp | grep '##.*Building' | head -1
        else
            grep '##.*Building' "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" | head -1
        fi
    else
        echo "Unknown"
    fi
}

# Get tech stack (first 15 lines)
# Uses MCP tool: get_tech_stack from mcp-tools-trigger.sh
# Returns TECH_STACK.md contents via MCP
get_tech_stack() {
    # Call MCP tool (already defined in mcp-tools-trigger.sh)
    # If not available, fall back to direct read
    if type -t get_tech_stack_mcp >/dev/null 2>&1; then
        get_tech_stack_mcp | head -15
    elif [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        cat "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -15
    else
        echo "❌ TECH_STACK.md not found"
        return 1
    fi
}

# Get primary technology
# Uses grep on MCP tool output
get_primary_tech() {
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        # Use MCP tool if available, otherwise direct read
        if type -t get_tech_stack_mcp >/dev/null 2>&1; then
            get_tech_stack_mcp | grep 'Primary:' | head -1
        else
            grep 'Primary:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1
        fi
    else
        echo "Unknown"
    fi
}

# Get test command from tech stack
# Uses grep on MCP tool output
get_test_command() {
    if [ -f "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" ]; then
        # Use MCP tool if available, otherwise direct read
        if type -t get_tech_stack_mcp >/dev/null 2>&1; then
            get_tech_stack_mcp | grep 'Command:' | head -1 | cut -d'`' -f2
        else
            grep 'Command:' "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" | head -1 | cut -d'`' -f2
        fi
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
# Uses starforge_read_file MCP tool if available
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

    # Try MCP tool first, fall back to direct read
    local content=""
    if type -t starforge_read_file >/dev/null 2>&1; then
        # Convert absolute path to relative for MCP tool
        local relative_path="${learnings_file#$STARFORGE_MAIN_REPO/}"
        content=$(starforge_read_file "$relative_path" 2>/dev/null | jq -r '.content' 2>/dev/null)
    fi

    # Fallback to direct read if MCP failed
    if [ -z "$content" ]; then
        content=$(cat "$learnings_file" 2>/dev/null)
    fi

    # Count learning headers
    local count=$(echo "$content" | grep -c "^##.*Learning" 2>/dev/null || echo "0")
    echo "$count"
}

# ============================================================================
# BREAKDOWN ANALYSIS HELPERS (for senior-engineer)
# ============================================================================

# Get the most recent spike directory
# Uses standard shell commands (no MCP needed for directory listing)
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
# Uses starforge_read_file MCP tool if available
get_feature_name_from_breakdown() {
    local breakdown_file=$1

    if [ ! -f "$breakdown_file" ]; then
        return 1
    fi

    # Try MCP tool first
    local content=""
    if type -t starforge_read_file >/dev/null 2>&1; then
        # Convert to relative path
        local relative_path="${breakdown_file#$STARFORGE_MAIN_REPO/}"
        content=$(starforge_read_file "$relative_path" 2>/dev/null | jq -r '.content' 2>/dev/null)
    fi

    # Fallback to direct read
    if [ -z "$content" ]; then
        content=$(cat "$breakdown_file")
    fi

    # Extract feature name from "# Task Breakdown: Feature Name" line
    local feature_name=$(echo "$content" | grep "^# Task Breakdown:" | sed 's/# Task Breakdown: //')

    if [ -n "$feature_name" ]; then
        echo "$feature_name"
        return 0
    else
        return 1
    fi
}

# Count subtasks in breakdown file
# Uses starforge_read_file MCP tool if available
get_subtask_count_from_breakdown() {
    local breakdown_file=$1

    if [ ! -f "$breakdown_file" ]; then
        echo "0"
        return 1
    fi

    # Try MCP tool first
    local content=""
    if type -t starforge_read_file >/dev/null 2>&1; then
        # Convert to relative path
        local relative_path="${breakdown_file#$STARFORGE_MAIN_REPO/}"
        content=$(starforge_read_file "$relative_path" 2>/dev/null | jq -r '.content' 2>/dev/null)
    fi

    # Fallback to direct read
    if [ -z "$content" ]; then
        content=$(cat "$breakdown_file" 2>/dev/null)
    fi

    # Count lines starting with "### Subtask"
    local count=$(echo "$content" | grep -c "^### Subtask" 2>/dev/null || echo "0")
    echo "$count"
    return 0
}

# ============================================================================
# MCP TOOL WRAPPERS (for compatibility)
# ============================================================================

# Wrapper for get_project_context MCP tool
# Returns raw content without MCP JSON wrapper
get_project_context_mcp() {
    if type -t get_project_context >/dev/null 2>&1 && [ "$(type -t get_project_context)" = "function" ]; then
        # Get MCP response and extract text content
        local mcp_response=$(get_project_context 2>/dev/null)
        echo "$mcp_response" | jq -r '.content[0].text' 2>/dev/null || echo "$mcp_response"
    else
        # MCP tool not available, use direct read
        cat "$STARFORGE_CLAUDE_DIR/PROJECT_CONTEXT.md" 2>/dev/null
    fi
}

# Wrapper for get_tech_stack MCP tool
# Returns raw content without MCP JSON wrapper
get_tech_stack_mcp() {
    if type -t get_tech_stack >/dev/null 2>&1 && [ "$(type -t get_tech_stack)" = "function" ]; then
        # Get MCP response and extract text content
        local mcp_response=$(get_tech_stack 2>/dev/null)
        echo "$mcp_response" | jq -r '.content[0].text' 2>/dev/null || echo "$mcp_response"
    else
        # MCP tool not available, use direct read
        cat "$STARFORGE_CLAUDE_DIR/TECH_STACK.md" 2>/dev/null
    fi
}
