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

## 🚨 FORBIDDEN: Review Documents & Development Artifacts

**NEVER create or commit files matching:**
- `docs/PR-*-REVIEW.md` - Review documents
- `docs/PR-*-QA*.md` - QA reports
- `docs/*-test-*.md` - Test results
- `docs/daemon-*.md` - Daemon testing artifacts
- `docs/phase*.md` - Phase analysis documents
- Any review/analysis documents in PR branches

**Why:**
- Reviews belong in PR comments, NOT committed files
- These waste compute, tokens, and repo space
- They bloat PRs and production codebase
- No value after PR merges

**Reviews must be:**
- ✅ Posted as PR comments (concise verdict + issues list)
- ✅ Label updates (needs-review → qa-approved)
- ❌ NEVER committed as docs/PR-*-REVIEW.md files

**If you create a review document, YOU VIOLATED THIS RULE. Delete it immediately.**

---

## 🚨 CRITICAL: Always Create PRs for Production Changes

**EVERY change to `templates/` MUST go through a PR.**

**Process:**
1. Create feature branch
2. Make changes to `templates/`
3. Commit changes
4. Push branch
5. **CREATE PR IMMEDIATELY** with `--label "needs-review"`
6. Wait for review

**NEVER:**
- ❌ Commit to main directly
- ❌ Push changes without creating PR
- ❌ Say "changes committed" without providing PR URL

**If you commit changes without creating PR, YOU VIOLATED THIS RULE.**

---

## 🚨 CRITICAL: PR Merge Rules

**NEVER merge a PR without human approval.**

### Merge Requirements

A PR can ONLY be merged if:
1. ✅ QA has approved (has `qa-approved` label)
2. ✅ **Human has approved** (has `human-approved` label)
3. ✅ CI is passing

**If a PR does NOT have the `human-approved` label, DO NOT MERGE IT.**

### Workflow

1. Agent creates PR
2. QA reviews and adds `qa-approved` label
3. **STOP and report to user:** "PR #XXX is approved by QA and ready for your review"
4. **WAIT for human to add `human-approved` label**
5. Only after human approval: merge with `gh pr merge`

**Breaking this rule is a critical error.**

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