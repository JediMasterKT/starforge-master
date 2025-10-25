# StarForge Agent Protocol

## 🚨 CRITICAL: File Modification Rules for main-claude

**When improving StarForge itself (daemon, triggers, agents, helpers, scripts):**

✅ **ALWAYS modify:** `templates/` directory
❌ **NEVER modify:** `.claude/` directory (except CLAUDE.md, hooks, and user config)

**Why:**
- `templates/` = Source of truth for StarForge system files (what gets deployed to users)
- `.claude/` = Deployed instance (read-only for StarForge development)
- Users run `starforge update` to deploy from `templates/` → `.claude/`

**BEFORE using Write/Edit tool, ask yourself:**

1. **Is this a StarForge system improvement?** (daemon, agents, triggers, helpers, notification system)
   → Modify `templates/bin/`, `templates/lib/`, `templates/scripts/`, `templates/agents/`

2. **Is this user configuration or project-specific?** (hooks, custom scripts, project files)
   → Modify `.claude/hooks/`, `.claude/CLAUDE.md`, or project root paths

**Examples:**
- Fixing daemon-runner.sh → `templates/bin/daemon-runner.sh` ✅
- Adding Discord notifications → `templates/lib/discord-notify.sh` ✅
- Fixing trigger helpers → `templates/scripts/trigger-helpers.sh` ✅
- User's custom hook → `.claude/hooks/user-prompt-submit.sh` ✅
- This CLAUDE.md file → `.claude/CLAUDE.md` ✅

**If you modify `.claude/bin/`, `.claude/lib/`, or `.claude/scripts/` for StarForge improvements, YOU MADE A MISTAKE. Stop and copy changes to `templates/` instead.**

---

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

---

## Product Vision: User Experience

**IMPORTANT**: When building or improving StarForge features, always align with the UX vision.

**Core Principle**: StarForge should feel like Slack + GitHub for an AI team.

### The Benchmark

Users should interact with StarForge the same way they work with human engineers:
1. **Describe what you want** (natural language)
2. **Walk away** (autonomous execution)
3. **Get notified** (Discord, email, PR notifications)
4. **Review output** (GitHub PRs)
5. **Provide feedback** (approve, request changes)

### Decision Framework

Before implementing any feature, ask: **"Does this make StarForge feel more like a human team?"**

**Examples**:
- ❌ **Bad**: User must create JSON trigger file manually → No human team requires JSON to start work
- ✅ **Good**: User says "work on ticket #42" → Exactly how you'd delegate to humans

- ❌ **Bad**: User approves every file read → You don't micromanage human engineers
- ✅ **Good**: One-time trust grant for project scope → Like giving engineer repo access

- ❌ **Bad**: User watches agent work in terminal → You don't sit behind devs watching them code
- ✅ **Good**: User gets Discord notification when PR ready → Like human posting "PR up for review"

### Key Targets

| Metric | Current | Target |
|--------|---------|--------|
| Permission prompts per feature | 50+ | <5 |
| Active supervision time | Continuous | <5 min |
| Async capability | 0% | 100% |

### Full Vision Document

For complete details, see: **[docs/UX-VISION.md](../docs/UX-VISION.md)**

**Use this vision to guide all feature development, agent design, and user interaction decisions.**