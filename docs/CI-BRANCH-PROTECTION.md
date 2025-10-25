# Branch Protection Rules for CI-First QA

This document explains how to configure GitHub branch protection rules to enforce CI-first QA process.

## Why Branch Protection?

Branch protection ensures that:
1. **ALL 17 CI test jobs must pass** before a PR can be approved
2. **qa-engineer cannot bypass failing tests** (system enforced)
3. **PRs are always up-to-date** with main before merging
4. **Quality standards are maintained** automatically

## Setup Instructions

### Navigate to Branch Protection Settings

1. Go to your GitHub repository
2. Click **Settings** → **Branches** (in left sidebar)
3. Under "Branch protection rules", click **Add rule** (or edit existing `main` rule)

### Configure Protection for `main` Branch

**Branch name pattern:** `main`

### Required Settings

#### 1. Require status checks to pass before merging ✅

**Enable:** ☑️ Require status checks to pass before merging

**Enable:** ☑️ Require branches to be up to date before merging

**Select required checks:** (search and select ALL 17 checks)

- ✅ `Setup Dependencies`
- ✅ `Installation Tests`
- ✅ `CLI Tests`
- ✅ `Foundation Tests`
- ✅ `Router Tests`
- ✅ `Logger Tests`
- ✅ `Routing Tests`
- ✅ `Hardcoded Patterns Tests`
- ✅ `Fresh Install E2E Tests`
- ✅ `GitHub Workflow Tests`
- ✅ `Settings Permissions Tests`
- ✅ `Senior Engineer Tests`
- ✅ `TPM Refactoring Tests`
- ✅ `Junior Engineer Template Tests`
- ✅ `GitHub Helpers Tests`
- ✅ `Sandbox Tests`
- ✅ `E2E Test Suite`
- ✅ `Documentation Check`

**IMPORTANT:** All 17 checks must be selected. If a check is not selected, PRs can be merged even if that check fails.

#### 2. Require pull request reviews before merging (Optional but Recommended)

**Enable:** ☑️ Require pull request reviews before merging

**Require approvals:** `1` (qa-engineer must approve)

**Dismiss stale pull request approvals when new commits are pushed:** ☑️

This ensures that if junior-dev pushes fixes after qa-engineer approval, qa must re-review.

#### 3. Do not allow bypassing the above settings (CRITICAL)

**Enable:** ☑️ Do not allow bypassing the above settings

This prevents admins from merging PRs with failing CI (enforces quality for everyone).

### Optional but Recommended Settings

#### Require signed commits
**Enable:** ☑️ Require signed commits

Ensures commits are verified (prevents impersonation).

#### Include administrators
**Enable:** ☑️ Include administrators

Applies branch protection rules to repository administrators (no one can bypass).

### Save Changes

Click **Create** (or **Save changes** if editing existing rule)

## Verification

To verify branch protection is working:

1. Create a test PR with failing tests
2. Try to approve it
3. You should see: "Merging is blocked - Required status checks must pass"
4. Fix the tests
5. CI re-runs automatically
6. Once all checks pass, merge button becomes enabled

## Effect on qa-engineer Workflow

After enabling branch protection:

1. **qa-engineer cannot approve PRs with red CI** (system blocks it)
2. **qa-engineer's job changes:**
   - ❌ OLD: Run tests manually
   - ✅ NEW: Analyze CI failures, guide junior-dev to fix
3. **Token usage drops by 65%** (from ~8,500 to ~3,000 per PR)

## Troubleshooting

### Problem: "Required status check 'X' is not present"

**Cause:** CI check name changed or workflow renamed

**Fix:**
1. Edit branch protection rule
2. Remove old check
3. Add new check (search for updated name)
4. Save changes

### Problem: "Merge button still enabled despite failing tests"

**Cause:** Not all required checks are selected

**Fix:**
1. Edit branch protection rule
2. Verify ALL 17 checks are selected (see list above)
3. Save changes
4. Refresh PR page

### Problem: "CI passed but merge still blocked"

**Cause:** PR branch is outdated (not up-to-date with main)

**Fix:**
1. Update PR branch: Click "Update branch" button on PR
2. Wait for CI to re-run
3. Once passing, merge button will be enabled

## CI-First QA Metrics

After enabling branch protection, track these metrics:

- **CI pass rate:** >90% (junior-devs writing better tests upfront)
- **QA review time:** <1h per PR (down from 4h with manual testing)
- **Token usage:** ~3,000 per PR (down from ~8,500)
- **Bugs found in production:** Lower (CI catches regressions automatically)

## Related Documentation

- [QA Engineer v3 (CI-First)](../templates/agents/qa-engineer.md)
- [Junior Engineer TDD Workflow](../templates/agents/junior-engineer.md)
- [GitHub Actions Workflow](../.github/workflows/pr-validation.yml)
- [Documentation Check Script](../bin/check-documentation.sh)

---

**Questions?** Open an issue or ask in Discord.
