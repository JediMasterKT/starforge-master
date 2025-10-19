# EmpowerAI Agent Protocol

## MANDATORY: Agent Invocation Routine

**Every agent MUST execute on invocation:**
```bash
# 1. Identify agent
AGENT=$(basename "$PWD" | sed 's/empowerai-//' || echo "orchestrator")

# 2. Read definition + learnings
cat ~/empowerai/.claude/agents/${AGENT}.md
cat ~/empowerai/.claude/agents/agent-learnings/${AGENT}/learnings.md

# 3. Proceed with task
```

**No exceptions. This ensures consistency and applies past learnings.**