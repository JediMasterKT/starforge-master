# StarForge Developer Configuration

This directory contains configuration files for developers working **ON** the StarForge project itself (not users of StarForge as a tool).

## Purpose

**Who needs this:**
- Developers modifying StarForge's source code
- Contributors working on StarForge features, bug fixes, or improvements

**Who doesn't need this:**
- Users installing StarForge to use it in their projects
- Users who just want autonomous AI development for their codebase

## Files in this directory

- **CLAUDE.md** - Developer-specific documentation about StarForge architecture, including special notes about `bin/starforge` CLI development
- **settings.json** - Claude Code permissions allowing edits to `bin/starforge` and other StarForge development tasks

## Setup Instructions

### One-time Setup (after cloning starforge repo)

```bash
# From starforge-master root directory
cp dev-config/CLAUDE.md .claude/
cp dev-config/settings.json .claude/
```

**Then restart Claude Code** to load the new permissions.

### After `starforge update`

The `starforge update` command will overwrite `.claude/` with the latest from `templates/`. After updating, you'll need to re-copy the dev config:

```bash
# After running: starforge update
cp dev-config/CLAUDE.md .claude/
cp dev-config/settings.json .claude/
```

Then restart Claude Code again.

## Why is this separate?

**Architecture separation:**
- `templates/` = Configuration deployed to ALL StarForge users (tool users + developers)
- `dev-config/` = Configuration only for developers working on StarForge itself
- `.claude/` = Working copy (gitignored, gets overwritten by `starforge update`)

**The problem we're solving:**
- Regular users don't need permission to edit `bin/starforge`
- Regular users don't need developer documentation about StarForge internals
- Deploying dev permissions to all users would violate principle of least privilege

**The solution:**
- `templates/` contains user-facing configs (locked down)
- `dev-config/` contains developer configs (permissive, opt-in)
- Developers manually copy when needed

## Future: User vs Developer Install Paths

Eventually, StarForge will have two install methods:

1. **Users** (tool users):
   - Install via package manager (`brew install starforge` or similar)
   - Never clone the repo
   - Get `templates/` configs only
   - Cannot modify StarForge itself (by design)

2. **Developers** (working on StarForge):
   - Clone the repo (`git clone https://github.com/krunal/starforge.git`)
   - Copy `dev-config/` to `.claude/`
   - Can modify all StarForge source code
   - Can test changes before submitting PRs

Until then, this opt-in `dev-config/` approach separates the two use cases.

## Questions?

If you're unsure whether you need this:
- **Are you fixing a bug in StarForge?** → Yes, copy these files
- **Are you adding a feature to StarForge?** → Yes, copy these files
- **Are you just using StarForge for your project?** → No, ignore this directory
