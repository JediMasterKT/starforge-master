# Teaching Module Documentation: StarForge Triggers 101

**Module ID:** starforge-triggers-101
**Version:** 1.0
**Created:** 2025-10-28
**Status:** Ready for Validation (Issue #228)

---

## Overview

This teaching module provides structured onboarding for trigger creation in StarForge. It uses the **Directness** teaching mode (challenge-based learning) to help developers master trigger creation in under 1 hour.

---

## Learning Objectives

By completing this module, learners will be able to:

1. **Explain** what a StarForge trigger is and its role in orchestration
2. **Identify** the required JSON fields for valid triggers
3. **Create** trigger files with proper filename format and structure
4. **Place** triggers in the correct directory for daemon processing
5. **Debug** common trigger creation errors

---

## Prerequisites

**Required Knowledge:**
- Basic JSON syntax
- File system navigation
- Basic bash commands

**Required Access:**
- StarForge installation
- Write access to project `.claude/triggers/` directory

**Estimated Prerequisite Time:** 0 minutes (assumes knowledge exists)

---

## Module Structure

### Duration Estimate
- **Total Time:** 40-60 minutes
- **Concept Introduction:** 5 minutes
- **Challenge 1 (Basic):** 10 minutes
- **Challenge 2 (Complex):** 10 minutes
- **Challenge 3 (Debugging):** 5 minutes
- **Challenge 4 (Mastery):** 10 minutes
- **Review & Questions:** 5-10 minutes

### Teaching Mode
**Directness (Challenge-Based Learning)**

**Why this mode?**
- Fastest path to competency
- Learning through doing, not passive reading
- Immediate feedback on attempts
- Minimal scaffolding encourages problem-solving

### Content Location
**Module Content:** `templates/learning-modules/starforge-triggers-101/module.md`

---

## Learning Flow

### Phase 1: Concept Introduction (5 min)
**Objective:** Understand what triggers are and why they matter

**Content Delivered:**
- Definition: Triggers are JSON work orders for the daemon
- Purpose: Enable async, autonomous agent invocation
- Analogy: Like leaving a sticky note on a colleague's desk
- Key components: filename format, JSON structure, directory location

**Success Indicator:** Learner can explain trigger purpose in their own words

---

### Phase 2: Basic Challenge (10 min)
**Challenge:** "Create a trigger to assign ticket #42 to junior-dev-a"

**Scaffolding Provided:**
- Filename format hint: `YYYYMMDD-HHMMSS-agent.json`
- Required fields: `to_agent`, `task`, `context`
- Directory: `.claude/triggers/`

**Success Criteria:**
- ✅ Correct filename format
- ✅ Valid JSON syntax
- ✅ All required fields present
- ✅ Task description is clear

**Target Time:** <10 minutes to first success

---

### Phase 3: Complex Challenge (10 min)
**Challenge:** "QA needs to review PR #100 for security issues. Create the trigger."

**Scaffolding:** None (intentionally minimal)

**Success Criteria:**
- ✅ Applied learning from Challenge 1
- ✅ Rich context (priority, requirements)
- ✅ No reference to docs needed

**Mastery Indicator:** Completes without assistance

---

### Phase 4: Debugging Challenge (5 min)
**Challenge:** Debug broken trigger with 4 errors

**Errors:**
1. Wrong field: `agent` → `to_agent`
2. Wrong field: `what_to_do` → `task`
3. Invalid JSON: trailing comma
4. Vague task description

**Success Criteria:**
- ✅ Identifies all 4 errors
- ✅ Explains why each is wrong
- ✅ Fixes all issues

---

### Phase 5: Mastery Verification (10 min)
**Challenge:** "Senior-engineer needs spike for ticket #150 on database optimization. Create complete trigger from scratch."

**Scaffolding:** Zero (pure mastery test)

**Success Criteria:**
- ✅ Filename perfect (timestamp-first, agent name, .json)
- ✅ JSON valid
- ✅ All fields correct
- ✅ Context rich (ticket_id, priority)
- ✅ No documentation referenced

**Mastery Threshold:** >70% (4/5 criteria)

---

## Assessment Framework

### Immediate Assessment (During Session)
- **Observable:** Completion time for each challenge
- **Observable:** Number of attempts before success
- **Observable:** Types of errors made

### 24-Hour Retention Test
**Script:** `tests/integration/assessments/trigger-knowledge-retention.sh`

**Questions:**
1. Concept recall (keywords: JSON, daemon, agent, task)
2. Detail recall (3 required fields)
3. Application (filename format)
4. Problem-solving (debug broken trigger)

**Target:** >80% correct

### Skill Mastery Challenge
**Script:** `tests/integration/assessments/trigger-mastery-challenge.sh`

**Evaluation Criteria:**
1. Filename format (20%)
2. Valid JSON (20%)
3. Correct to_agent (20%)
4. Clear task (20%)
5. Complete context (20%)

**Target:** >70% (4/5 criteria)

### Satisfaction Survey
**Template:** `tests/integration/assessments/satisfaction-survey.md`

**Questions:**
1. Helpfulness (1-5 scale)
2. Clarity (1-5 scale)
3. Challenge effectiveness (1-5 scale)
4. Confidence level (1-5 scale)
5. Improvement suggestions (open response)

**Target:** Average >4.0/5.0

---

## Success Metrics (Issue #228 Validation)

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| Onboarding time | <60 min | Session timestamps |
| Time to first success | <15 min | Challenge 1 completion |
| Knowledge retention | >80% | 24-hour assessment |
| Skill mastery | >70% | Mastery challenge |
| Developer satisfaction | >4.0/5.0 | Survey average |

---

## Common Learner Struggles

### Struggle 1: Timestamp Format Confusion
**Symptom:** Creates filename like `qa-engineer-20251028.json`

**Root Cause:** Not understanding FIFO ordering requirement

**Resolution:** Explain daemon processes oldest-first, needs timestamp-first format

**Teaching Tip:** Show what happens if timestamp is wrong (daemon ignores it)

---

### Struggle 2: JSON Syntax Errors
**Symptom:** Trailing commas, missing quotes, unclosed brackets

**Root Cause:** Unfamiliarity with strict JSON requirements

**Resolution:** Use `jq` to validate, show exact error message

**Teaching Tip:** Practice with online JSON validator first

---

### Struggle 3: Vague Task Descriptions
**Symptom:** Task field says "Fix bug" or "Review code"

**Root Cause:** Not realizing agent needs specific instructions

**Resolution:** Compare vague vs. specific examples side-by-side

**Teaching Tip:** Ask "If YOU received this trigger, would you know exactly what to do?"

---

## Teaching Mode Effectiveness

### Why Directness Works Here

**Advantages:**
- Fast learning curve (40-60 min vs. 4+ hours traditional)
- High engagement through challenges
- Immediate feedback reinforces correct behavior
- Problem-solving builds confidence

**Disadvantages:**
- May frustrate learners who prefer step-by-step guides
- Requires teacher availability for feedback
- Struggle points can cause delays

### When to Switch Modes

**Use Concept Mode instead if:**
- Learner has no JSON experience
- Learner prefers theory before practice
- Multiple complex concepts need explanation

**Use Problem Mode (Polya) instead if:**
- Learner gets stuck on challenges repeatedly
- Need to teach problem decomposition
- Debugging is a learning objective

---

## Next Steps After Module Completion

### Immediate Practice (Required)
1. Create 3 more triggers independently
2. Monitor daemon processing (`starforge daemon status`)
3. Review `.claude/triggers/.processed/` for examples

### Advanced Learning (Optional)
1. Study agent definitions (`.claude/agents/*.md`)
2. Learn trigger chaining via Stop hooks
3. Understand orchestration flow (PRIMARY CLAUDE → daemon → agents)
4. Explore MCP integration for external tools

---

## Module Maintenance

### Update Triggers
- Agent list changes (new agents added)
- JSON structure changes (new required fields)
- Daemon behavior changes (processing rules)

### Version History
- **v1.0 (2025-10-28):** Initial version for Issue #228 validation

---

## Related Documentation

- **Module Content:** `templates/learning-modules/starforge-triggers-101/module.md`
- **Session Template:** `templates/teaching-sessions/session-228-trigger-onboarding.md`
- **Retention Test:** `tests/integration/assessments/trigger-knowledge-retention.sh`
- **Mastery Challenge:** `tests/integration/assessments/trigger-mastery-challenge.sh`
- **Satisfaction Survey:** `tests/integration/assessments/satisfaction-survey.md`
- **Integration Test:** `tests/integration/test_teacher_agent_effectiveness.sh`
- **Teacher Agent Definition:** `templates/agents/teacher-agent.md`

---

## Usage Instructions

### For Teachers
1. Review module content: `templates/learning-modules/starforge-triggers-101/module.md`
2. Copy session template: `templates/teaching-sessions/session-228-trigger-onboarding.md`
3. Conduct session using Directness mode
4. Document session (timestamps, struggles, observations)
5. Administer assessments 24 hours later
6. Update learnings: `templates/agents/agent-learnings/teacher-agent/learnings.md`

### For Self-Learners
1. Read module content
2. Complete all challenges in order
3. Self-assess using mastery challenge script
4. Review daemon logs to see triggers processing

---

**Module Status:** Ready for validation (Issue #228)
