# Changelog

All notable changes to StarForge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Real agent invocation in daemon mode using `claude --print` CLI
- MCP server integration for non-interactive agent execution
- Comprehensive daemon troubleshooting guide in README.md
- Claude CLI verification steps for daemon setup
- PATH configuration documentation for daemon context

### Changed
- **BREAKING**: Daemon now requires Claude Code CLI (`claude`) installed and in PATH
- Daemon agent invocation now uses real `claude` CLI instead of simulation
- Updated daemon invocation to use `--print` flag for non-interactive execution
- Improved error messages when `claude` CLI is not found
- Enhanced daemon logging to show real agent execution

### Fixed
- Removed simulation/workaround code from sequential daemon execution
- Corrected claude CLI invocation flags (removed invalid `--mcp stdio`, added `--print`)
- Fixed TTY requirement for daemon background operation

### Documentation
- Added "How It Works" section for daemon agent invocation
- Added troubleshooting section for "claude CLI not found" errors
- Documented MCP server integration and stdin piping
- Added daemon invocation flow diagram
- Clarified prerequisites: Claude Code CLI required for daemon mode

## [1.0.0] - 2025-01-XX

### Added
- Initial release
- 5 specialized agents (orchestrator, senior-engineer, junior-engineer, qa-engineer, tpm-agent)
- Git worktree-based parallel development
- GitHub integration for issue tracking and PR management
- Autonomous daemon for 24/7 agent operation
- Interactive installation with `starforge install`
- Project analysis with `starforge analyze`
- Trigger-based asynchronous agent communication
- Status reporting with `starforge status`
- Manual trigger monitoring with `starforge monitor`
- TDD test suites (58 installer tests + 38 CLI tests)
- Zero-configuration setup with sensible defaults
- Dynamic agent detection supporting unlimited agents
- Discord notifications for key milestones
- Permission bypass for autonomous operation
- FIFO trigger processing with error recovery
- Graceful daemon shutdown and crash recovery

### Prerequisites
- macOS 14+ (tested)
- Git 2.20+
- GitHub CLI (`gh`)
- jq for JSON processing
- Claude Code CLI (`claude`)
- fswatch (macOS) or inotifywait (Linux) for file watching
- terminal-notifier (optional) for desktop notifications

---

## Migration Guide

### Upgrading from Pre-1.0 (Simulation Mode)

If you were using an earlier version of StarForge with daemon simulation:

1. **Install Claude Code CLI:**
   ```bash
   # Visit https://docs.claude.com/claude-code for installation
   # Verify installation
   which claude
   claude --version
   ```

2. **Update StarForge:**
   ```bash
   cd your-project
   starforge update --force
   ```

3. **Restart Daemon:**
   ```bash
   starforge daemon stop
   starforge daemon start
   ```

4. **Verify Real Execution:**
   ```bash
   # Check logs for real agent invocations
   starforge daemon logs
   # Look for "INVOKE" entries with real agent execution
   ```

### Breaking Changes

- **Claude CLI Required**: The daemon now requires the Claude Code CLI (`claude`) to be installed and available in PATH. Previously, the daemon used a simulation mode that did not require this.

- **No Simulation Mode**: The `PARALLEL_DAEMON` feature flag's simulation workaround has been removed in favor of real agent execution. All agent invocations now use `claude --print`.

- **MCP Server Required**: The daemon expects `.claude/bin/mcp-server.sh` to be present and executable. Run `starforge update` to deploy this if missing.

### What's Not Changed

- Trigger file format remains the same
- Agent definitions are backward compatible
- Git worktree structure unchanged
- GitHub integration remains the same
- All `starforge` CLI commands work identically
