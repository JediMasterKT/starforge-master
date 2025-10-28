# StarForge Release Process

This document outlines the process for creating new StarForge releases.

## Overview

StarForge uses **semantic versioning** (semver) with Git tags and GitHub Releases.

**Format**: `vMAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (incompatible API changes)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

## Release Checklist

### 1. Update VERSION File

**File**: `templates/VERSION`

```bash
# Create version bump branch
git checkout main
git pull origin main
git checkout -b chore/update-version-X.Y.Z

# Edit templates/VERSION
# - Update version number
# - Update commit hash (get latest: git log -1 --format=%h)
# - Update date (YYYY-MM-DD)
# - Add changelog entries
# - Add new_features array
# - Add bug_fixes array
# - Update upgrade_notes

# Commit
git add templates/VERSION
git commit -m "chore: Bump version to vX.Y.Z"

# Push and create PR
git push -u origin chore/update-version-X.Y.Z
gh pr create --title "chore: Bump version to vX.Y.Z" --body "..."
```

### 2. Merge VERSION PR

```bash
# After approval, merge PR to main
gh pr merge <PR-NUMBER> --squash

# Pull updated main
git checkout main
git pull origin main
```

### 3. Create Git Tag

```bash
# Create annotated tag on main
git tag -a vX.Y.Z -m "StarForge vX.Y.Z

[Brief description of release]

## Highlights
- Feature 1
- Feature 2
- Bug fix 1

## PRs Included
- #XXX: Description
- #YYY: Description
"

# Push tag to GitHub
git push origin vX.Y.Z
```

### 4. Create GitHub Release

```bash
# Create release from tag
gh release create vX.Y.Z \
  --title "StarForge vX.Y.Z - [Release Name]" \
  --notes "$(cat <<'EOF'
# StarForge vX.Y.Z - [Release Name]

[Detailed release notes]

## 🆕 New Features
- Feature 1 (#XXX)
- Feature 2 (#YYY)

## 🐛 Bug Fixes
- Fix 1 (#ZZZ)
- Fix 2 (#AAA)

## ⚠️ Breaking Changes
[If any]

## 📊 Stats
- PRs Merged: X
- Lines Changed: +Y / -Z

## 🔗 Links
- [Full Changelog](https://github.com/JediMasterKT/starforge-master/compare/vX.Y.Z-1...vX.Y.Z)
- [Milestone](https://github.com/JediMasterKT/starforge-master/milestone/N)

---

🤖 Built with Claude Code
EOF
)"

# Verify release created
gh release view vX.Y.Z
```

## Version Strategy

### MAJOR Version (X.0.0)

**When to bump**: Breaking changes that require user action

**Examples**:
- Trigger format changes (JSON → YAML)
- Agent definition format changes
- CLI command changes
- Directory structure changes (non-migratable)

**Release Notes Must Include**:
- Migration guide
- Breaking changes list
- "What to do" for each breaking change

### MINOR Version (X.Y.0)

**When to bump**: New features (backward compatible)

**Examples**:
- New agents
- New commands (`starforge new-command`)
- New MCP tools
- New automation capabilities
- Major UX improvements

**Release Notes Should Include**:
- New features list
- How to use new features
- Upgrade notes (if any)

### PATCH Version (X.Y.Z)

**When to bump**: Bug fixes only

**Examples**:
- Security fixes
- Bug fixes
- Performance improvements
- Documentation updates
- Dependency updates

**Release Notes Should Include**:
- Bugs fixed
- Security issues resolved
- Impact of fixes

## Current Versions

| Version | Date | Commit | Status |
|---------|------|--------|--------|
| v1.1.0 | 2025-10-28 | 2ee17ae | Pending (PR #290) |
| v1.0.0 | 2025-10-26 | c7390ca | Released |

## Example: Creating v1.1.0 Release

```bash
# 1. VERSION file already updated in PR #290
# 2. Merge PR #290
gh pr merge 290 --squash

# 3. Pull main
git checkout main
git pull origin main

# 4. Create tag
git tag -a v1.1.0 -m "StarForge v1.1.0

Production-ready release with daemon auto-start and Discord integration.

## Highlights
- Real daemon invocation with Claude CLI
- Discord integration with auto-setup wizard
- Daemon auto-start on install/update
- Version detection and safe migration system

## PRs Included
- #280-#282: Real daemon invocation
- #283, #287: Discord integration
- #284, #288: Daemon auto-start
- #286: Settings.json fixes
- #255, #289: Version detection
"

# 5. Push tag
git push origin v1.1.0

# 6. Create GitHub release
gh release create v1.1.0 \
  --title "StarForge v1.1.0 - Production Ready" \
  --notes "..."  # (Full release notes)

# 7. Announce
# - Update main README.md with latest version badge
# - Post in Discord/Slack
# - Update documentation
```

## Automation (Future)

Consider automating with GitHub Actions:

```yaml
# .github/workflows/release.yml
name: Create Release
on:
  push:
    tags:
      - 'v*'
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Create Release
        run: |
          gh release create ${{ github.ref_name }} \
            --title "StarForge ${{ github.ref_name }}" \
            --notes-file CHANGELOG.md \
            --generate-notes
```

## Version Checking

Users can check their installed version:

```bash
# Check version file
cat .claude/STARFORGE_VERSION | jq -r '.version'

# Check latest release
gh release view --json tagName,publishedAt

# Compare versions
starforge update --check-only  # (Future feature)
```

## Rollback

If a release has issues:

```bash
# Revert to previous version
git checkout v1.0.0

# Create hotfix tag
git tag -a v1.1.1 -m "Hotfix for v1.1.0 issues"
git push origin v1.1.1

# Or delete bad tag (if caught early)
git tag -d v1.1.0
git push origin :refs/tags/v1.1.0
```

## Best Practices

1. **Test before tagging**: Ensure all tests pass on main
2. **Write clear release notes**: Users should understand what changed
3. **Include migration steps**: For breaking changes
4. **Link to PRs**: Provide context for each change
5. **Update CHANGELOG.md**: Keep changelog up to date (future)
6. **Announce releases**: Notify users via Discord/Slack
7. **Tag immediately after merge**: Don't let main diverge from tag

## Questions?

See the #releases channel in Discord or file an issue.
