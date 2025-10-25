# Agent Learnings

Project-specific learnings and patterns for this agent.

---

## Learning 1: Embedding Mermaid Diagrams in Tickets

**Date:** 2025-10-24

**What happened:**
Senior-engineer was creating Mermaid diagrams in spike folders, but junior-engineers couldn't see them because they work in isolated worktrees and only access GitHub tickets.

**What was learned:**
Architecture diagrams MUST be embedded directly in GitHub ticket bodies, not just referenced as files. Junior-engineers need to see the visual architecture when they open the ticket, without having to navigate to spike folders in the main repo.

**Why it matters:**
- Junior-engineers work in isolated worktrees (can't access spike folders)
- GitHub natively renders Mermaid diagrams in markdown
- Visual architecture in tickets reduces implementation drift
- Diagrams show component relationships, dependencies, file paths
- No external tools or file navigation needed

**Corrected approach:**
Always check for `architecture.mmd` in spike folder and embed in ticket body:

**Pattern:**
1. Read breakdown file from spike folder
2. Check for `architecture.mmd` in same directory
3. If diagram exists, read its contents
4. Embed full diagram in ticket body using ````mermaid` blocks
5. Add warning: "Review the architecture diagram before implementing"
6. Include component descriptions below diagram

**Implementation:**
```bash
# After reading breakdown
SPIKE_DIR=$(dirname "$BREAKDOWN_FILE")
DIAGRAM_FILE="$SPIKE_DIR/architecture.mmd"

if [ -f "$DIAGRAM_FILE" ]; then
  DIAGRAM_CONTENT=$(cat "$DIAGRAM_FILE")
  echo "✅ Architecture diagram found"
  # Embed in ticket body...
else
  DIAGRAM_CONTENT=""
  echo "ℹ️  No diagram (OK for simple tasks)"
fi
```

**Ticket structure:**
```markdown
## 🎯 Objective
[Description]

## 📐 Architecture

```mermaid
[Full Mermaid diagram here]
```

⚠️ IMPORTANT: Review the architecture diagram above before implementing.

## 📋 Implementation
[Details]
```

**Why this works:**
- GitHub auto-renders Mermaid in issues/PRs
- Junior-engineer sees diagram immediately when opening ticket
- No need to navigate to main repo or spike folders
- Diagram is versioned with the ticket
- All context in one place

**Related documentation:**
- Senior-engineer creates diagrams: `templates/agents/senior-engineer.md`
- Junior-engineer reviews diagrams: `templates/agents/junior-engineer.md`
- Diagram templates: `templates/architecture-templates/`

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
