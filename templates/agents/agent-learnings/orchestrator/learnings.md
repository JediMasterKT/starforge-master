---
name: "orchestrator"
---

# Agent Learnings

Project-specific learnings and patterns for this agent.

---

## Learning 1: CRITICAL - Must Use trigger-helpers.sh for ALL Trigger Creation

**Date:** 2025-10-25

**What happened:**
Orchestrator created malformed .json trigger files that couldn't be processed by the daemon. The daemon only processes .trigger files with the correct schema.

**What was learned:**
NEVER manually create trigger files. ALWAYS use trigger-helpers.sh functions.

**Why it matters:**
- Daemon's `get_next_trigger()` only finds `*.trigger` files (not `.json`)
- Manual triggers have wrong schema (missing `from_agent`, `to_agent`, `action`, `context`)
- Broken triggers = agents never get work assigned

**Corrected approach:**
```bash
# ✅ CORRECT - Use helper functions
source .claude/scripts/trigger-helpers.sh

# For junior-dev agents
trigger_junior_dev "junior-dev-a" 123

# For QA engineer
trigger_qa_review "orchestrator" 456

# For senior engineer
trigger_senior_engineer "orchestrator" 789
```

**NEVER do this:**
```bash
# ❌ WRONG - Manual JSON creation
cat > .claude/triggers/agent-123.json << EOF
{"issue": 123, "agent": "junior-dev-a"}
EOF
```

**Related documentation:**
- .claude/scripts/trigger-helpers.sh
- .claude/agents/orchestrator.md (lines 154-156, 340-355)

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
