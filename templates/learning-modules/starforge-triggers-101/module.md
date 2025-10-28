# StarForge Triggers 101

**Learning Module for Issue #228 Validation**

---

## Learning Objectives

By the end of this module, learners will be able to:
1. Explain what a StarForge trigger is and its role in the orchestration system
2. Identify the required JSON fields for a valid trigger file
3. Create a trigger file from scratch with proper filename and structure
4. Place trigger files in the correct directory for daemon processing
5. Debug common trigger creation errors

---

## Prerequisites

- Basic understanding of JSON syntax
- Familiarity with file system navigation
- Access to a StarForge installation

---

## Module Content

### 1. What is a StarForge Trigger?

**Concept:**
A trigger is a JSON file that tells the StarForge daemon which agent to invoke and what task to perform. Think of it as a work order that the daemon picks up and processes.

**Why it matters:**
Triggers enable asynchronous, autonomous agent invocation. You create a trigger file, walk away, and the daemon handles the rest—just like delegating work to a human team member.

**Real-world analogy:**
Creating a trigger is like leaving a sticky note on a colleague's desk: "Please review PR #123 for security issues." The note (trigger) sits there until they (daemon) pick it up and act on it.

---

### 2. Trigger File Structure

**Required JSON Fields:**

```json
{
  "to_agent": "agent-name",
  "task": "Description of what needs to be done",
  "context": {
    "ticket_id": "123",
    "priority": "P1",
    "additional_info": "Any extra context"
  }
}
```

**Field Breakdown:**

- `to_agent` (string, required): Which agent should handle this task
  - Valid values: `junior-dev-a`, `qa-engineer`, `senior-engineer`, `orchestrator`, `teacher-agent`

- `task` (string, required): Clear description of what needs to be done
  - Be specific: "Review PR #123 for security vulnerabilities" ✅
  - Avoid vague: "Check the code" ❌

- `context` (object, optional but recommended): Additional metadata
  - `ticket_id`: GitHub issue number
  - `priority`: P0, P1, P2 (helps with prioritization)
  - Any other key-value pairs that help the agent understand the task

---

### 3. Trigger Filename Format

**Pattern:** `YYYYMMDD-HHMMSS-to_agent.json`

**Example:** `20251028-143022-qa-engineer.json`

**Why this format?**
- YYYYMMDD-HHMMSS: Timestamp ensures FIFO processing order
- to_agent: Makes it clear which agent will handle it
- .json: Identifies it as a JSON trigger file

**Common mistakes:**
- ❌ `trigger.json` (no timestamp, no agent name)
- ❌ `qa-engineer-20251028.json` (timestamp not first)
- ✅ `20251028-143022-qa-engineer.json` (correct!)

---

### 4. Trigger File Location

**Directory:** `.claude/triggers/`

**Full path example:**
```
/path/to/your/project/.claude/triggers/20251028-143022-qa-engineer.json
```

**Daemon behavior:**
- Daemon watches `.claude/triggers/` directory
- Picks up triggers in FIFO order (oldest timestamp first)
- Deletes trigger file after processing (moves to `.claude/triggers/.processed/`)

---

### 5. Complete Example: Creating a Trigger

**Scenario:** Assign ticket #42 to junior-dev-a for implementation.

**Step 1:** Create the JSON content
```json
{
  "to_agent": "junior-dev-a",
  "task": "Implement feature described in ticket #42: Add user authentication to API endpoints",
  "context": {
    "ticket_id": "42",
    "priority": "P1",
    "estimated_effort": "2 hours"
  }
}
```

**Step 2:** Generate timestamp
```bash
timestamp=$(date +"%Y%m%d-%H%M%S")
# Example output: 20251028-143022
```

**Step 3:** Create filename
```bash
filename="${timestamp}-junior-dev-a.json"
# Example: 20251028-143022-junior-dev-a.json
```

**Step 4:** Write file to triggers directory
```bash
cat > .claude/triggers/$filename <<EOF
{
  "to_agent": "junior-dev-a",
  "task": "Implement feature described in ticket #42: Add user authentication to API endpoints",
  "context": {
    "ticket_id": "42",
    "priority": "P1",
    "estimated_effort": "2 hours"
  }
}
EOF
```

**Step 5:** Verify file was created
```bash
ls -la .claude/triggers/$filename
cat .claude/triggers/$filename | jq .
```

---

## Practice Challenges

### Challenge 1: Basic Trigger Creation
**Task:** Create a trigger to assign ticket #100 to qa-engineer for code review.

**Success criteria:**
- Correct filename format with timestamp
- Valid JSON structure
- All required fields present
- File placed in correct directory

---

### Challenge 2: Complex Context
**Task:** Create a trigger for senior-engineer to conduct a security audit on PR #200, including context about previous vulnerabilities found.

**Success criteria:**
- Rich context object with multiple fields
- Clear, specific task description
- Appropriate priority level set

---

### Challenge 3: Debugging Broken Trigger
**Task:** Fix this broken trigger:

```json
{
  "agent": "qa-engineer",
  "what_to_do": "Review code",
}
```

**Issues to find:**
- Wrong field name (`agent` should be `to_agent`)
- Wrong field name (`what_to_do` should be `task`)
- Trailing comma (invalid JSON)
- Vague task description

---

## Assessment Criteria

**Knowledge Check Questions:**
1. What are the three required components of a trigger filename?
2. Which JSON field specifies the target agent?
3. Where should trigger files be placed?
4. Why is timestamp-first naming important?

**Practical Assessment:**
- Create a complete, valid trigger from scratch in < 5 minutes
- Debug a broken trigger and explain what was wrong
- Describe the lifecycle of a trigger (creation → processing → completion)

**Mastery Indicators:**
- Can create triggers without reference documentation
- Understands when to use rich context vs. minimal context
- Can troubleshoot common trigger errors independently

---

## Common Pitfalls

1. **Forgetting the timestamp:** Daemon won't process files without proper timestamp format
2. **Invalid JSON:** Missing quotes, trailing commas, unclosed brackets
3. **Vague task descriptions:** "Fix the bug" doesn't tell the agent what to do
4. **Wrong directory:** Placing triggers outside `.claude/triggers/`
5. **Incorrect agent names:** Typos like `junior-dev` instead of `junior-dev-a`

---

## Next Steps

After mastering trigger creation:
1. Learn about trigger lifecycle and monitoring (`starforge daemon status`)
2. Explore advanced context fields for different agent types
3. Understand Stop hooks and trigger chaining
4. Study the orchestration flow (PRIMARY CLAUDE → daemon → agents)

---

## Resources

- Agent definitions: `.claude/agents/*.md`
- Daemon documentation: `docs/daemon-integration-summary.md`
- Trigger examples: `.claude/triggers/.processed/` (historical triggers)
- Daemon logs: `.claude/logs/daemon.log`

---

**Module Version:** 1.0
**Last Updated:** 2025-10-28
**Teaching Mode Used:** Directness (challenge-based learning with minimal scaffolding)
