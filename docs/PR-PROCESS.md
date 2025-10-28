# Pull Request Review Process

## Critical Issue Identified

**Date:** 2025-10-28
**Issue:** PRs are being merged after CI passes but BEFORE qa-engineer review completes

**Evidence:**
- PR #289: Merged at 02:38 AM, QA review created at 03:08 AM (30 min AFTER merge)
- PR #292: Merged at 02:56 AM, QA review created at 02:53 AM (concurrent with merge)

**Impact:**
- Critical bugs merged to main (CLAUDE.md/LEARNINGS.md preservation issues)
- Testing gaps not caught pre-merge (update with modified configs)
- Follow-up PRs required for issues that should have been caught before merge

---

## Recommended PR Workflow

### Phase 1: Development & CI
1. **Developer creates PR**
2. **Automated CI tests run** (18 test suites via `.github/workflows/pr-validation.yml`)
3. **CI must pass** before proceeding

### Phase 2: QA Review (REQUIRED BEFORE MERGE)
4. **Request `qa-engineer` review** by commenting `/review` or `qa-engineer review completed?`
5. **qa-engineer creates review document** at `docs/PR-{NUMBER}-REVIEW.md`
6. **Review includes:**
   - Code analysis
   - Test coverage verification
   - Security assessment
   - Edge case identification
   - Overall verdict (APPROVED / NEEDS CHANGES / BLOCKED)
   - Confidence level

7. **If issues found:**
   - Developer fixes issues
   - CI runs again
   - QA re-reviews

8. **QA approval required** before merge

### Phase 3: Merge
9. **Only merge after:**
   - ✅ All CI tests pass
   - ✅ QA review completed
   - ✅ QA verdict: APPROVED
   - ✅ All critical/high issues resolved

10. **Merge to main**

---

## Label-Based QA Workflow (Automated Enforcement)

**Status:** ✅ **IMPLEMENTED** (as of 2025-10-28)

StarForge uses GitHub labels and status checks to enforce pre-merge QA review. This prevents PRs from being merged before qa-engineer approval.

### How It Works

**1. PR Creation** (junior-engineer/orchestrator)
   - Creates PR with `--label needs-review` flag
   - Label triggers required GitHub status check "Require QA Review"
   - Status check **FAILS** → merge button disabled
   - PR cannot be merged until QA approval

**2. QA Review** (qa-engineer)
   - Reviews PR using 5-gate quality process
   - Manages labels based on verdict

**3. Label Management by Verdict**

| Verdict | Label Changes | Status Check | Merge State |
|---------|---------------|--------------|-------------|
| **APPROVED** | Remove `needs-review`<br>Add `qa-approved` | ✅ **PASSES** | ✅ **Merge allowed** |
| **NEEDS CHANGES** | Keep `needs-review`<br>Add `qa-needs-changes` | ❌ **FAILS** | ❌ **Merge blocked** |
| **BLOCKED** | Keep `needs-review`<br>Add `qa-blocked` | ❌ **FAILS** | ❌ **Merge blocked** |

**4. Merge Decision**
   - Once qa-engineer removes `needs-review` label, status check passes
   - Human or orchestrator can now merge the PR
   - System enforces QA approval automatically

### Automated Status Check

The workflow is enforced by `.github/workflows/require-qa-review.yml`:

```yaml
name: Require QA Review
on:
  pull_request:
    types: [opened, synchronize, labeled, unlabeled]

jobs:
  check-qa-label:
    runs-on: ubuntu-latest
    steps:
      - name: Check for needs-review label
        uses: actions/github-script@v7
        with:
          script: |
            const labels = context.payload.pull_request.labels.map(l => l.name);

            if (labels.includes('needs-review')) {
              core.setFailed('❌ QA review required');
            } else {
              core.info('✅ QA review complete');
            }
```

### PR Label Legend

| Label | Meaning | Added By | Status Check |
|-------|---------|----------|--------------|
| 🟡 `needs-review` | QA review required before merge | junior-engineer (at PR creation) | ❌ Blocks merge |
| 🟢 `qa-approved` | QA reviewed and approved | qa-engineer (after approval) | ✅ Allows merge |
| 🔴 `qa-blocked` | Critical issues (security, 3+ gate failures) | qa-engineer (if blocked) | ❌ Blocks merge |
| 🟠 `qa-needs-changes` | Fixable issues found, resubmit after fixes | qa-engineer (if needs changes) | ❌ Blocks merge |

### Developer Workflow

**Junior-Engineer:**
```bash
# Step 1: Create PR (automatically adds needs-review label)
gh pr create \
  --title "feat: Implement feature X" \
  --body "..." \
  --label "needs-review"
# → Status check FAILS, merge blocked

# Step 2: Wait for qa-engineer review...
# → qa-engineer runs 5-gate quality process

# Step 3a: If NEEDS CHANGES or BLOCKED:
# → Fix issues identified in QA review
# → Push updates to PR branch
# → CI re-runs automatically
# → qa-engineer re-reviews
# → Cycle repeats until APPROVED

# Step 3b: If APPROVED:
# → qa-engineer removes 'needs-review' label
# → qa-engineer adds 'qa-approved' label
# → Status check PASSES
# → Merge button enabled
# → Human/orchestrator can now merge
```

**QA-Engineer:**
```bash
# After completing 5-gate review, manage labels based on verdict:

# APPROVED (all gates passed):
gh pr edit $PR_NUMBER \
  --remove-label "needs-review" \
  --add-label "qa-approved"
# → Status check passes, merge unblocked

# NEEDS CHANGES (fixable issues):
gh pr edit $PR_NUMBER \
  --add-label "qa-needs-changes"
# → Keep needs-review, status check fails, merge blocked

# BLOCKED (critical issues: security OR 3+ gate failures):
gh pr edit $PR_NUMBER \
  --add-label "qa-blocked"
# → Keep needs-review, status check fails, merge blocked
```

### Benefits of Label-Based Workflow

✅ **Automated enforcement** - GitHub prevents premature merges automatically
✅ **No manual discipline required** - System enforces workflow, not humans
✅ **Clear communication** - Labels show PR status at a glance
✅ **Solo-dev friendly** - Works without branch protection rules
✅ **Prevents incidents** - Catches issues before merge (prevents PR #289/#292 incidents)
✅ **Audit trail** - Label history shows review timeline
✅ **Integration-ready** - Labels can trigger Discord notifications, metrics, etc.

---

## QA Review Quality Standards

### Must Include
1. **Overall Verdict**: APPROVED / NEEDS CHANGES / BLOCKED
2. **Confidence Level**: Percentage (e.g., 95%)
3. **Issues List**: Categorized by severity (Critical, High, Medium, Low)
4. **Testing Evidence**: What was tested and results
5. **Security Assessment**: Potential vulnerabilities
6. **Edge Cases**: Identified scenarios that need attention

### Review Document Location
- Path: `docs/PR-{NUMBER}-REVIEW.md`
- Must be committed to PR branch before merge
- Should be referenced in PR comments

---

## Communication

### Developer → QA
- Comment on PR: "Ready for QA review"
- Or: "qa-engineer review completed?"
- Tag any specific concerns or areas needing extra scrutiny

### QA → Developer
- Create review document: `docs/PR-{NUMBER}-REVIEW.md`
- Comment on PR with:
  - Link to review document
  - Overall verdict
  - Summary of critical issues (if any)
  - Approval or request for changes

### Before Merge
- QA must explicitly approve in PR comments or GitHub review system
- All critical/high issues must be resolved
- Updated code must be re-reviewed if significant changes

---

## Consequences of Current Process

**What Happened with PR #289/292:**

| What Should Happen | What Actually Happened | Result |
|-------------------|----------------------|---------|
| QA review before merge | QA review after merge | Critical bugs in main |
| Test with modified configs | Tested only fresh install | User data loss bug not caught |
| Fix issues pre-merge | Fix issues in follow-up PRs | PR #292, #295 needed |
| One PR to fix issue | Three PRs total (#289, #292, #295) | Extra work, main temporarily broken |

**Cost:**
- 2 follow-up PRs required
- main branch had data loss bug for ~20 minutes
- Extra review cycles and testing
- User had to catch issues that QA should have caught

---

## Action Items

### Immediate (Owner: Repository Admin)
- [ ] Enable GitHub branch protection rules for `main` branch
- [ ] Require 1 approval before merge
- [ ] Require all CI checks to pass

### Short-term (Owner: Development Team)
- [ ] Update all agent instructions to emphasize pre-merge QA review
- [ ] Add PR template with QA review checklist
- [ ] Document this process in CONTRIBUTING.md

### Long-term (Owner: Development Team)
- [x] Create automated label/tag system for PR states: ✅ **COMPLETED**
  - `needs-review` (added at PR creation)
  - `qa-approved` (added by qa-engineer after approval)
  - `qa-blocked` (added by qa-engineer for critical issues)
  - `qa-needs-changes` (added by qa-engineer for fixable issues)
  - See "Label-Based QA Workflow" section above for details
- [ ] Integrate Discord notifications for PR state changes
- [ ] Consider CODEOWNERS file to auto-request reviews

---

## References

- **PR #289**: Version detection/migration - merged before QA complete
- **PR #292**: LEARNINGS.md preservation - follow-up to fix missed issue
- **PR #295**: Comment fix - follow-up to fix QA-identified issue
- **docs/PR-289-REVIEW.md**: QA review created post-merge
- **docs/PR-292-REVIEW.md**: QA review created post-merge
- **docs/UX-VISION.md**: "Does this make StarForge feel more like a human team?" - Current process does not

---

## Questions?

If you have questions about this process, see:
- `.github/workflows/pr-validation.yml` - CI test configuration
- `docs/PR-*-REVIEW.md` - Example QA review documents
- GitHub branch protection docs: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches

---

**Document created:** 2025-10-28
**Last updated:** 2025-10-28
**Triggered by:** PR #289/#292/#295 post-merge issue discovery
**Status:** ✅ IMPLEMENTED - Label-based QA workflow active
