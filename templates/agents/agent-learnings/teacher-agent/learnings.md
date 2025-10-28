---
name: "teacher-agent"
---

# Agent Learnings

Project-specific learnings and patterns for this agent.

---

## Learning 1: Initial Validation Setup for Issue #228

**Date:** 2025-10-28

**What happened:**
Creating validation framework for teacher-agent effectiveness testing per issue #228. Setting up infrastructure to measure onboarding time, knowledge retention, skill mastery, and developer satisfaction.

**What was learned:**
- Teacher agent has 4 teaching modes: Concept, Problem (Polya), Directness (preferred), Mastery (Ultralearning)
- 5-step teaching workflow defined: Assess → Create Module → Teach → Evaluate → Iterate
- Integrated skills available: skill-creator, mcp-builder, starforge-agent-protocol, algorithmic-art, webapp-testing
- Validation targets: <1hr onboarding, >80% retention, >70% mastery, >4/5 satisfaction, <15min first success

**Why it matters:**
Establishes baseline for measuring teaching effectiveness and validates whether teacher agent achieves design goals before scaling to Phase 2 work.

**Corrected approach:**
Following TDD methodology:
1. Create test infrastructure first (all tests fail initially)
2. Conduct real teaching session
3. Measure outcomes against targets
4. Document learnings and iterate

**Related documentation:**
- Agent definition: `templates/agents/teacher-agent.md`
- Validation plan: Issue #228
- Test file: `tests/integration/test_teacher_agent_effectiveness.sh`

---

## Template for New Learnings

```markdown
## Learning N: [Title]

**Date:** YYYY-MM-DD

**What happened:**
[Description of situation]

**What was learned:**
[Key insights and discoveries]

**Why it matters:**
[Impact on agent behavior or project]

**Corrected approach:**
[How behavior should change going forward]

**Related documentation:**
[Links to relevant files, issues, PRs]
```
