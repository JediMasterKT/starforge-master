---
name: "junior-engineer"
---

# Agent Learnings

Project-specific learnings and patterns for this agent.

---

## Learning 1: Architecture Diagram Review Before Implementation

**Date:** 2025-10-24

**What happened:**
Junior-engineers were implementing features without reviewing architecture diagrams, leading to:
- Wrong file paths
- Missing dependencies
- Violated architectural constraints
- Implementation drift from intended design
- Extra review cycles and rework

**What was learned:**
ALWAYS review the architecture diagram in the GitHub ticket BEFORE writing any code. The diagram shows the intended structure - deviating causes integration problems and technical debt.

**Why it matters:**
- **60-70% drift reduction** when diagram is reviewed first
- **Prevents rework** - get it right the first time
- **Integration success** - components work together as designed
- **Avoids forbidden patterns** - dashed arrows show what NOT to do
- **Clear file paths** - know exactly where code belongs

**Corrected approach:**
Make architecture review MANDATORY before coding:

**Pre-flight check:**
```bash
# Step 8 in pre-flight
TICKET_BODY=$(gh issue view $TICKET --json body --jq '.body')

if echo "$TICKET_BODY" | grep -q "```mermaid"; then
  echo "✅ Architecture diagram present"
  echo "⚠️  MANDATORY: Review before proceeding"
  echo "→ gh issue view $TICKET --web"
fi
```

**Review protocol:**
1. **Open ticket in browser** - `gh issue view $TICKET --web`
2. **Study the diagram** - Components, dependencies, file paths
3. **Articulate approach** - Write out implementation plan
4. **Confirm alignment** - Does plan match diagram?
5. **Check forbidden patterns** - Dashed arrows = DON'T DO THIS
6. **Proceed with TDD** - Only after alignment confirmed

**What to extract from diagram:**
- ✅ Component name (what am I building?)
- ✅ File path (where does code go?)
- ✅ Test file path (where do tests go?)
- ✅ Dependencies (what do I use?)
- ✅ Database changes (schema modifications)
- ✅ Forbidden patterns (what to avoid)

**Example thought process:**
```
Looking at diagram:
- I'm implementing "Priority Scorer"
- File: src/priority_scorer.py
- Tests: tests/test_priority_scorer.py
- Depends on: Pattern Analyzer (already exists)
- Writes to: Database (priority_score column)
- FORBIDDEN: Must NOT let Pattern Analyzer access DB directly

My approach:
1. Create tests/test_priority_scorer.py (TDD)
2. Import Pattern Analyzer
3. Call analyzer.get_patterns()
4. Calculate scores
5. Write to database
6. Ensure Pattern Analyzer doesn't touch DB (check their code)

✅ This matches the diagram - proceeding with TDD
```

**Common mistakes to avoid:**
- ❌ Skipping diagram review ("I'll figure it out")
- ❌ Guessing file paths instead of checking diagram
- ❌ Implementing without understanding dependencies
- ❌ Violating forbidden patterns (dashed arrows)
- ❌ Creating components not shown in diagram

**Red flags (STOP and ask):**
- 🚨 Diagram shows Component A → B, but I think B → A
- 🚨 Diagram says src/scorer.py, but I created src/score_calculator.py
- 🚨 Diagram forbids pattern, but ticket description mentions it
- 🚨 I don't understand why a component exists
- 🚨 Diagram conflicts with existing code

**Related documentation:**
- Pre-flight checks: `templates/agents/junior-engineer.md` (Step 8)
- Architecture Review section: Same file
- Diagram creation: `templates/agents/senior-engineer.md`
- Diagram embedding: `templates/agents/tpm-agent.md`

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
