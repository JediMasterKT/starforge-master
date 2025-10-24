#!/bin/bash
# Agent Isolation Validator Library
# Shared library for enforcing agent-based access control

# Function: validate_agent_access
# Purpose: Check if agent has permission for operation on target
# Args:
#   $1 - agent_type (orchestrator, junior-dev-a, qa-engineer, etc.)
#   $2 - operation (bash, edit)
#   $3 - target (command string or file path)
#   $4 - cwd (current working directory)
# Returns:
#   0 - Allow
#   2 - Block (with error message to stderr)

validate_agent_access() {
    local agent_type="$1"
    local operation="$2"
    local target="$3"
    local cwd="$4"

    # Default to "main" if agent ID not set
    if [ -z "$agent_type" ] || [ "$agent_type" = "null" ]; then
        agent_type="main"
    fi

    case "$agent_type" in
        orchestrator)
            # Orchestrator can modify coordination and triggers only
            if [[ "$target" =~ \.claude/(coordination|triggers)/ ]]; then
                return 0
            fi
            # Block source code modifications
            if [[ "$target" =~ (^|/)src/ ]] || [[ "$target" =~ (^|/)tests/ ]]; then
                echo "❌ BLOCKED: Orchestrator cannot modify source code" >&2
                echo "💡 Orchestrator coordinates agents but does not write code" >&2
                return 2
            fi
            # Block worktree modifications
            if [[ "$target" =~ -junior-dev-[abc] ]] || [[ "$cwd" =~ -junior-dev-[abc] ]]; then
                echo "❌ BLOCKED: Orchestrator cannot modify worktrees" >&2
                echo "💡 Junior-devs own their worktrees" >&2
                return 2
            fi
            ;;

        junior-dev-*)
            # Junior-devs work in their own worktree
            # Check if we're in the matching worktree
            if [[ "$cwd" =~ $agent_type ]]; then
                # In own worktree, allow most things (other checks still apply)
                return 0
            fi
            # Block modifications to main repo source
            if [[ "$target" =~ (^|/)src/ ]] || [[ "$target" =~ (^|/)tests/ ]]; then
                echo "❌ BLOCKED: Junior-dev cannot modify main repo source" >&2
                echo "💡 Work in your assigned worktree: check \$STARFORGE_WORKTREE_PATH" >&2
                return 2
            fi
            # Block modifications to agent infrastructure
            if [[ "$target" =~ \.claude/agents/ ]] || [[ "$target" =~ \.claude/hooks/ ]] || [[ "$target" =~ \.claude/lib/ ]]; then
                echo "❌ BLOCKED: Junior-dev cannot modify agent infrastructure" >&2
                echo "💡 Agent definitions and hooks are managed by system" >&2
                return 2
            fi
            # Block modifications to other worktrees
            if [[ "$target" =~ -junior-dev-[abc] ]] && [[ ! "$target" =~ $agent_type ]]; then
                echo "❌ BLOCKED: Junior-dev cannot modify other worktrees" >&2
                echo "💡 Each junior-dev has their own isolated worktree" >&2
                return 2
            fi
            ;;

        qa-engineer)
            # QA can write reports but not source code
            if [[ "$target" =~ \.claude/qa-reports/ ]]; then
                return 0
            fi
            # Block source code file modifications
            if [[ "$target" =~ \.(py|js|ts|jsx|tsx|go|rs|java|cpp|c|h)$ ]]; then
                if [[ "$target" =~ (^|/)src/ ]] || [[ "$target" =~ (^|/)tests/ ]]; then
                    echo "❌ BLOCKED: QA Engineer cannot modify source code" >&2
                    echo "💡 QA validates code but does not write it" >&2
                    return 2
                fi
            fi
            ;;

        tpm-agent)
            # TPM is read-only for local files, uses gh for GitHub operations
            if [ "$operation" = "edit" ]; then
                echo "❌ BLOCKED: TPM Agent is read-only for local files" >&2
                echo "💡 Use 'gh issue create' or 'gh pr create' for GitHub operations" >&2
                return 2
            fi
            ;;

        senior-engineer)
            # Senior-engineer writes breakdowns to spikes only
            if [[ "$target" =~ \.claude/spikes/ ]]; then
                return 0
            fi
            # Block source code modifications
            if [[ "$target" =~ (^|/)src/ ]] || [[ "$target" =~ (^|/)tests/ ]]; then
                echo "❌ BLOCKED: Senior Engineer cannot modify source code directly" >&2
                echo "💡 Create breakdowns in .claude/spikes/, junior-devs implement" >&2
                return 2
            fi
            # Block agent infrastructure
            if [[ "$target" =~ \.claude/agents/ ]]; then
                echo "❌ BLOCKED: Senior Engineer cannot modify agent definitions" >&2
                echo "💡 Agent definitions are managed by system" >&2
                return 2
            fi
            ;;

        main)
            # Human user (main), allow most things
            # Other layers (dangerous commands, credentials) still protect
            return 0
            ;;

        *)
            # Unknown agent type, default to restrictive
            echo "⚠️  WARNING: Unknown agent type: $agent_type (defaulting to main)" >&2
            return 0
            ;;
    esac

    # Default: allow (other layers may still block)
    return 0
}
