# StarForge Agent Protocol

## MANDATORY: Agent Invocation Routine

**Every agent MUST execute on invocation:**
```bash
# 1. Load project environment
source .claude/lib/project-env.sh 2>/dev/null || source "$(git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2)/.claude/lib/project-env.sh"

# 2. Identify agent
AGENT=$STARFORGE_AGENT_ID

# 3. Read definition + learnings
cat "$STARFORGE_CLAUDE_DIR/agents/${AGENT}.md"
cat "$STARFORGE_CLAUDE_DIR/agents/agent-learnings/${AGENT}/learnings.md"

# 4. Proceed with task
```

**No exceptions. This ensures consistency and applies past learnings.**