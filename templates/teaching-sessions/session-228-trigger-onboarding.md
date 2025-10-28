# Teaching Session: Trigger Creation Onboarding (Issue #228)

**Session ID:** session-228-trigger-onboarding
**Date:** 2025-10-28
**Agent:** teacher-agent
**Teaching Mode:** Directness (Challenge-based learning)
**Learning Module:** starforge-triggers-101

---

## Session Metadata

**Start Time:** [TO BE FILLED - Unix timestamp]
**End Time:** [TO BE FILLED - Unix timestamp]
**First Success Time:** [TO BE FILLED - Unix timestamp]
**Total Duration:** [TO BE CALCULATED]
**Time to First Success:** [TO BE CALCULATED]

---

## Learner Profile

**Name:** [TO BE FILLED]
**Experience Level:** New to StarForge
**Prior Knowledge:**
- [ ] JSON syntax
- [ ] File system navigation
- [ ] Basic bash commands
- [ ] GitHub workflow

**Learning Objective:** Master trigger creation for autonomous agent invocation

---

## Teaching Approach: Directness Mode

**Why Directness?**
Per teacher-agent definition, Directness mode is the **preferred default** teaching approach. It emphasizes:
- Minimal scaffolding
- Challenge-based learning (present problem, let learner discover)
- Fast feedback loops
- Learning through doing, not passive reading

**Challenge Structure:**
1. Present challenge with minimal context
2. Provide one example or hint
3. Let learner attempt
4. Give feedback on attempt (what worked, what didn't)
5. Guide toward solution without giving answer directly
6. Celebrate success, extract learning

---

## Session Flow

### Phase 1: Concept Introduction (5 minutes)

**Explanation Given:**
> "A StarForge trigger is a JSON file that tells the daemon which agent to run and what task to do. Think of it like leaving a work order on someone's desk. The daemon picks it up and processes it."

**Key Points Covered:**
- Triggers enable async work
- Daemon watches `.claude/triggers/` directory
- Filename format matters (timestamp-first for FIFO ordering)
- Three required fields: `to_agent`, `task`, `context`

**Learner Questions:**
[TO BE FILLED - Record actual questions asked]

---

### Phase 2: First Challenge (10 minutes target)

**Challenge Presented:**
> "Create a trigger to assign ticket #42 to junior-dev-a for implementation."

**Scaffolding Provided:**
- Filename format: `YYYYMMDD-HHMMSS-agent.json`
- Directory: `.claude/triggers/`
- Required JSON fields: `to_agent`, `task`, `context`

**Learner Attempt #1:**
[TO BE FILLED - Record what learner tried]

**Feedback Given:**
[TO BE FILLED - What feedback was provided]

**Learner Attempt #2 (if needed):**
[TO BE FILLED]

**Success Achieved:**
- [ ] Correct filename format
- [ ] Valid JSON structure
- [ ] All required fields present
- [ ] File created in correct location
- [ ] Task description is clear and specific

**Time to Complete:** [TO BE FILLED]

---

### Phase 3: Second Challenge - Increased Complexity (10 minutes)

**Challenge Presented:**
> "The orchestrator needs QA to review PR #100 for security issues. Create the trigger with appropriate priority and context."

**Scaffolding:** None (intentionally minimal)

**Learner Attempt:**
[TO BE FILLED]

**Feedback Given:**
[TO BE FILLED]

**Success Indicators:**
- [ ] Applied learning from Challenge 1
- [ ] Added rich context fields (priority, specific requirements)
- [ ] Task description is actionable
- [ ] No assistance needed

**Time to Complete:** [TO BE FILLED]

---

### Phase 4: Debugging Challenge (5 minutes)

**Broken Trigger Presented:**
```json
{
  "agent": "qa-engineer",
  "what_to_do": "Review code",
}
```

**Errors to Find:**
1. Wrong field: `agent` → `to_agent`
2. Wrong field: `what_to_do` → `task`
3. Trailing comma (invalid JSON)
4. Vague task description

**Learner Analysis:**
[TO BE FILLED - What errors did learner identify?]

**Correction Process:**
[TO BE FILLED - How did learner fix it?]

**Success:**
- [ ] Identified all 4 errors
- [ ] Fixed JSON syntax
- [ ] Improved task clarity

---

### Phase 5: Mastery Verification (10 minutes)

**Final Challenge (No Help):**
> "Senior-engineer needs to conduct a spike investigation for ticket #150 about database optimization. Create the complete trigger from scratch."

**Learner Solution:**
[TO BE FILLED - Final trigger created]

**Evaluation:**
- [ ] Filename correct (timestamp-first, agent name)
- [ ] JSON valid (no syntax errors)
- [ ] `to_agent` field correct
- [ ] `task` field clear and specific
- [ ] Context includes ticket_id and priority
- [ ] File placed in `.claude/triggers/`
- [ ] No reference to documentation needed

**Mastery Level:** [TO BE SCORED - 0-100%]

---

## Dialogue Excerpts

### Key Learning Moments

**Moment 1: Understanding FIFO ordering**
- Learner: [TO BE FILLED]
- Teacher: [TO BE FILLED]
- Insight: [TO BE FILLED]

**Moment 2: Realizing task clarity matters**
- Learner: [TO BE FILLED]
- Teacher: [TO BE FILLED]
- Insight: [TO BE FILLED]

**Moment 3: Connecting triggers to daemon behavior**
- Learner: [TO BE FILLED]
- Teacher: [TO BE FILLED]
- Insight: [TO BE FILLED]

---

## Struggles & Corrections

### Struggle 1: [TO BE FILLED]
**What happened:** [Description]
**Why it was hard:** [Analysis]
**How resolved:** [Correction approach]
**Learning extracted:** [What did learner take away]

### Struggle 2: [TO BE FILLED]
[Same format]

---

## Observations

### What Worked Well
1. [TO BE FILLED]
2. [TO BE FILLED]
3. [TO BE FILLED]

### What Didn't Work
1. [TO BE FILLED]
2. [TO BE FILLED]

### Learner Engagement
- Energy level: [High/Medium/Low]
- Question frequency: [Many/Some/Few]
- Frustration points: [TO BE FILLED]
- Breakthrough moments: [TO BE FILLED]

### Teaching Mode Effectiveness
- Was Directness approach appropriate? [Yes/No]
- Should have used different mode? [Which one and why?]
- Scaffolding level: [Too much/Just right/Too little]

---

## Metrics Summary

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Total session time | <60 min | [FILL] | [PASS/FAIL] |
| Time to first success | <15 min | [FILL] | [PASS/FAIL] |
| Challenges completed | 5 | [FILL] | [PASS/FAIL] |
| Mastery score | >70% | [FILL] | [PASS/FAIL] |

---

## Next Steps for Learner

1. **Practice:** Create 3 more triggers independently
2. **Explore:** Read `.claude/agents/*.md` to understand different agents
3. **Monitor:** Use `starforge daemon status` to watch triggers being processed
4. **Advanced:** Learn about trigger chaining via Stop hooks

---

## Teaching Session Evaluation

**Teaching Mode Used:** Directness
**Effectiveness Rating:** [TO BE FILLED - 1-5 scale]
**Would Use Again:** [Yes/No]
**Adaptations Needed:** [TO BE FILLED]

---

## Files Created During Session

1. [TO BE FILLED - List all trigger files created]
2. [TO BE FILLED]

---

## Follow-up Assessment Schedule

- **24-hour retention test:** 2025-10-29 [same time]
- **Mastery challenge:** 2025-10-29 [+30 minutes after retention]
- **Satisfaction survey:** Immediately after session

---

**Session Status:** [IN_PROGRESS / COMPLETED]
**Teacher Notes:** [Any additional observations for future sessions]
