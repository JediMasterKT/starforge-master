# Contributing to StarForge

Thank you for your interest in contributing to StarForge! This document outlines the development workflow and guidelines.

## Development Workflow

StarForge uses a **feature branch + pull request** workflow to ensure code quality and facilitate collaboration.

### The Golden Rule

**NEVER commit directly to `main`.**

All changes must go through the pull request review process.

### Step-by-Step Workflow

#### 1. Fork and Clone (First Time Only)

```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/starforge-master.git
cd starforge-master

# Add upstream remote
git remote add upstream https://github.com/JediMasterKT/starforge-master.git
```

#### 2. Create a Feature Branch

```bash
# Make sure you're on main
git checkout main

# Pull latest changes
git pull upstream main

# Create a feature branch with descriptive name
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

**Branch Naming Convention:**
- `feature/` - New features (e.g., `feature/marketplace-integration`)
- `fix/` - Bug fixes (e.g., `fix/shell-detection-bug`)
- `docs/` - Documentation only (e.g., `docs/api-reference`)
- `refactor/` - Code refactoring (e.g., `refactor/cli-structure`)
- `test/` - Test additions/fixes (e.g., `test/installer-validation`)
- `workflow/` - CI/CD and workflow changes (e.g., `workflow/branch-protection`)

#### 3. Make Your Changes

```bash
# Edit files
# Test your changes locally
# Add tests if applicable
```

**For installer scripts:**
```bash
# Test the installer
bash tests/test-installer.sh

# Test CLI installation
bash bin/verify-cli.sh
```

**For backend changes (if working on agent templates):**
```bash
# Test agent definitions work in a sample project
cd /path/to/test-project
starforge update
starforge use senior-engineer
```

#### 4. Commit Your Changes

```bash
# Stage your changes
git add .

# Commit with a clear message
git commit -m "feat: Add feature X

Detailed description of what changed and why.

Closes #123"
```

**Commit Message Format:**
```
<type>: <subject>

<body (optional)>

<footer (optional)>
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test additions/changes
- `refactor:` - Code refactoring
- `chore:` - Build process, dependency updates

#### 5. Push to Your Fork

```bash
# Push your feature branch to your fork
git push origin feature/your-feature-name
```

#### 6. Create a Pull Request

1. Go to https://github.com/JediMasterKT/starforge-master
2. Click "Pull requests" → "New pull request"
3. Click "compare across forks"
4. Select your fork and branch
5. Fill out the PR template completely
6. Submit for review

#### 7. Address Review Feedback

```bash
# Make requested changes
# Commit them
git add .
git commit -m "fix: Address review feedback"

# Push to update the PR
git push origin feature/your-feature-name
```

#### 8. Merge (Maintainer Only)

Once approved, the maintainer will merge your PR. Do not merge your own PRs.

## Code Review Process

### What Reviewers Look For

1. **Correctness**: Does the code do what it's supposed to?
2. **Tests**: Are there tests? Do they pass?
3. **Documentation**: Is the code documented? Is the README updated?
4. **Style**: Does it follow existing code style?
5. **Backward Compatibility**: Will this break existing installations?
6. **Security**: Are there any security implications?

### Review Timeline

- **Initial review**: Within 48 hours
- **Follow-up reviews**: Within 24 hours

## Testing Guidelines

### Installer Scripts

All changes to installer scripts MUST be tested:

```bash
# Run installer tests
bash tests/test-installer.sh

# Manual verification
bash bin/verify-cli.sh
```

### Agent Definitions

Test agent changes in a real project:

```bash
cd /path/to/test-project
starforge update
starforge use <agent-name>
# Verify agent behaves as expected
```

### CLI Commands

Test new CLI commands thoroughly:

```bash
# Test help text
starforge help

# Test the new command
starforge <new-command>

# Test error cases
starforge <new-command> --invalid-flag
```

## Code Style

### Bash Scripts

- Use `#!/bin/bash` shebang
- Quote all variables: `"$VAR"` not `$VAR`
- Use `set -e` for error handling
- Add comments for complex logic
- Follow existing formatting (2-space indents)

### Markdown Files

- Use ATX-style headers (`#` not underlines)
- Keep lines under 100 characters when possible
- Use code fences with language identifiers
- Include examples for complex concepts

## What to Contribute

### High-Priority Contributions

- **Bug fixes**: Found a bug? Fix it!
- **Documentation**: Improve existing docs, add examples
- **Test coverage**: Add tests for untested code
- **Performance**: Optimize slow operations
- **User experience**: Make StarForge easier to use

### Medium-Priority Contributions

- **New agents**: Add specialized agent definitions
- **CLI enhancements**: New commands, better output
- **Platform support**: Windows compatibility, Linux testing
- **Integration**: IDE plugins, editor extensions

### What NOT to Contribute (Yet)

- **Breaking changes**: Discuss first in an issue
- **Massive refactors**: Propose in an issue first
- **Experimental features**: Create a discussion thread first
- **Paid features**: Needs business strategy alignment

## Questions?

- **Bug reports**: Open an issue with reproduction steps
- **Feature requests**: Open an issue describing the use case
- **Questions**: Open a discussion on GitHub Discussions
- **Security issues**: Email directly to repository owner

## CODEOWNERS

All PRs require approval from `@JediMasterKT`. This ensures:
- Consistent quality standards
- Backward compatibility
- Security review
- User experience coherence

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

---

**Thank you for contributing to StarForge!**

Your contributions help make multi-agent AI development accessible to everyone.
