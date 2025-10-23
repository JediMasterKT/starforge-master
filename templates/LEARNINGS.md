# Global Agent Learnings

Cross-cutting learnings that apply to all agents working on this project.

---

## Learning 1: .claude/ Infrastructure is LOCAL ONLY

**Date:** 2025-10-16

**What happened:**
Main Claude attempted to commit the entire .claude/ directory (agent definitions, coordination files, scripts, hooks) to the git repository and push to remote/production.

**What was learned:**
The .claude/ directory is the user's **local AI agent orchestration system**. It should NEVER be committed to the git repository or pushed to production. This includes:
- Agent definition files (orchestrator.md, junior-engineer.md, etc.)
- Coordination files (status.json files)
- Trigger system files
- Helper scripts (trigger-helpers.sh, watch-triggers.sh)
- Agent learnings and protocols
- Any other .claude/ infrastructure

**Why it matters:**
- .claude/ is personal tooling for managing local AI agents
- It contains workflow-specific coordination logic
- Has no business in production code
- Would expose internal agent orchestration details publicly
- Could confuse project contributors who don't use this agent system

**Corrected approach:**
- Keep ALL .claude/ infrastructure local only
- Never stage, commit, or push any .claude/ files
- Only commit actual project code (features, tests, documentation)
- The .claude/ system coordinates locally to produce commits, but isn't itself committed

**Related:**
- This is different from runtime files (.claude/coordination/, .claude/triggers/, .claude/spikes/) which were already gitignored
- The entire .claude/ directory should remain uncommitted - both infrastructure AND runtime files
