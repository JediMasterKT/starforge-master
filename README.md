# StarForge - AI Development Team

A portable multi-agent development system for Claude Code that brings a complete AI team to any project.

## What is StarForge?

StarForge is a portable package of specialized AI agents that work together to build software. Install it once, take it anywhere. Each agent has a specific role:

- **Orchestrator**: Coordinates parallel development, assigns work to junior-devs
- **Senior Engineer**: Creates technical breakdowns and architecture designs
- **Junior Engineers**: Implement features in parallel using git worktrees
- **QA Engineer**: Reviews code, validates implementations, runs tests
- **TPM Agent**: Creates GitHub Issues from breakdowns for task tracking

## Experience Vision

**StarForge should feel like Slack + GitHub for an AI team.**

Interact with StarForge the same way you work with human engineers:
1. **Describe what you want** - Natural language, wherever you're comfortable
2. **Walk away** - Agents work autonomously, no babysitting required
3. **Get notified** - Discord/email updates at key milestones
4. **Review output** - GitHub PRs, just like human team members
5. **Provide feedback** - Approve, request changes, iterate

**Current State**: Building toward this vision. Today you'll use CLI commands, but we're working toward fire-and-forget autonomy.

For the complete UX vision and roadmap, see [docs/UX-VISION.md](docs/UX-VISION.md).

## Features

- **🚀 One-Command Installation**: `starforge install` sets up everything
- **📊 Project Analysis**: Automated codebase analysis and documentation generation
- **🔄 Parallel Development**: Multiple agents work simultaneously via git worktrees
- **🤖 Autonomous Daemon**: 24/7 background operation - agents work while you sleep
- **🎯 GitHub Integration**: Automatic issue tracking and PR management
- **🧪 Fully Tested**: TDD approach with 58 installer tests + 38 CLI tests
- **🔒 IP Protected**: .claude/ folder never committed to your repositories
- **🎨 Zero Configuration**: Works out of the box with sensible defaults

## Quick Start

### 1. Install StarForge CLI

```bash
# Clone or download StarForge
cd ~/starforge-master

# Add to PATH
bash install-cli.sh

# Verify installation
source ~/.zshrc  # or source ~/.bashrc
starforge help
```

### 2. Install in a Project

```bash
# Navigate to your project
cd my-project

# Install StarForge
starforge install

# Follow interactive prompts:
# - GitHub remote setup (recommended)
# - Number of junior-dev agents (1-5, default: 3)
# - Proceed with installation
```

### 3. Analyze Your Project (Existing Projects)

```bash
# Generate PROJECT_CONTEXT.md, TECH_STACK.md, and initial-assessment.md
starforge analyze
```

### 4. Start Building

**Option A: Autonomous Mode** (Recommended - 24/7 operation)
```bash
# Start the daemon
starforge daemon start

# Invoke agents - they work autonomously
starforge use senior-engineer  # Create breakdown
# (Agents automatically triggered: TPM → Orchestrator → Junior-devs → QA)

# Check progress anytime
starforge status
starforge daemon status
```

**Option B: Manual Mode** (Interactive)
```bash
# In terminal 1: Monitor agent activity
starforge monitor

# In terminal 2: Invoke agents
starforge use senior-engineer  # Create breakdown
# (TPM automatically creates GitHub Issues)
starforge use orchestrator     # Assign work to junior-devs
```

## Commands

### `starforge install`

Installs StarForge in the current project. Creates:
- `.claude/` directory with agents, scripts, hooks
- Git worktrees for parallel development
- Permissions and settings configuration

**Prerequisites:**
- Git installed
- GitHub CLI (`gh`) installed and authenticated
- `jq` installed for JSON processing
- **Claude Code CLI** (`claude`) installed and available in PATH
- **File watching tool (optional, for automatic trigger monitoring):**
  - macOS: `fswatch` - Install with `brew install fswatch`
  - Linux: `inotifywait` - Install with `sudo apt-get install inotify-tools`
  - Note: If not installed, trigger monitoring will require manual mode

### `starforge analyze`

Launches Main Claude to analyze your project and generate:
- `PROJECT_CONTEXT.md`: What the project does
- `TECH_STACK.md`: Technologies and architecture
- `initial-assessment.md`: Current state analysis

### `starforge update`

Updates StarForge agents and scripts from the latest templates.

**Interactive Mode** (default):
```bash
starforge update
# Shows diff preview, prompts for confirmation
```

**Non-Interactive Mode** (for automation/CI/CD):
```bash
starforge update --force
# Skips interactive prompt, applies changes immediately
```

Use `--force` when:
- Running in CI/CD pipelines
- Using in Claude Code (non-TTY environment)
- Automating updates in scripts

### `starforge use <agent>`

Invokes a specific agent:
```bash
starforge use orchestrator
starforge use senior-engineer
starforge use junior-engineer
starforge use qa-engineer
starforge use tpm-agent
```

### `starforge monitor`

Starts the trigger monitor to watch agent handoffs in real-time. Run in a separate terminal.

**File Watching:**
- Requires `fswatch` (macOS) or `inotifywait` (Linux) for automatic file watching
- Falls back to manual mode if not available
- See installation instructions in Prerequisites section

### `starforge daemon <command>`

Manages the autonomous daemon for 24/7 agent operation. The daemon watches for triggers in the background and automatically invokes agents without user supervision.

**Commands:**
```bash
starforge daemon start    # Start daemon in background
starforge daemon stop     # Stop the daemon gracefully
starforge daemon status   # Show daemon status and recent activity
starforge daemon restart  # Restart the daemon
starforge daemon logs     # Tail the daemon log file
```

**Workflow Modes:**

**Manual Mode** (Interactive):
```bash
# Terminal 1: Monitor triggers
starforge monitor

# Terminal 2: Invoke agents manually
starforge use senior-engineer
starforge use orchestrator
```

**Autonomous Mode** (Fire-and-Forget):
```bash
# Start daemon - agents work autonomously
starforge daemon start

# Check what's happening
starforge daemon status
starforge status

# Stop when done
starforge daemon stop
```

**How It Works:**

The daemon uses the Claude Code CLI (`claude`) to invoke agents in non-interactive mode:

```bash
# Real agent invocation (not simulation)
.claude/bin/mcp-server.sh | claude \
  --print \
  --permission-mode bypassPermissions \
  "Use the orchestrator agent. Process this trigger..."
```

**Key Features:**
- **Real Agent Execution**: Uses `claude --print` for non-interactive invocation
- **MCP Integration**: Agent tools provided via MCP server piped to stdin
- **Permission Bypass**: Pre-approved permissions in `.claude/settings.json`
- **Background Operation**: Runs without terminal/TTY requirement
- **FIFO Processing**: Handles triggers in chronological order
- **Error Recovery**: Moves malformed triggers to `failed/` directory
- **Activity Logging**: Full logs in `.claude/logs/daemon.log`
- **Graceful Shutdown**: Proper cleanup on stop

**Prerequisites:**
- Requires `fswatch` (macOS) or `inotifywait` (Linux)
- Install with: `brew install fswatch` (macOS) or `sudo apt-get install inotify-tools` (Linux)
- **Claude Code CLI** must be installed and available in PATH
- Run `which claude` to verify - should return `/usr/local/bin/claude` or similar

**Troubleshooting:**

If you encounter "claude CLI not found" errors:

1. **Verify Claude CLI is installed:**
   ```bash
   which claude
   # Should return: /usr/local/bin/claude (or similar)
   ```

2. **Install Claude Code CLI if missing:**
   - Visit: https://docs.claude.com/claude-code
   - Follow installation instructions for your platform
   - Verify with: `claude --version`

3. **Check PATH environment:**
   ```bash
   echo $PATH
   # Ensure /usr/local/bin is included
   ```

4. **Test manual invocation:**
   ```bash
   # Try invoking claude directly
   echo "Hello" | claude --print "Say hello back"
   # Should return a response from Claude
   ```

5. **Check daemon logs:**
   ```bash
   starforge daemon logs
   # Look for "claude: command not found" errors
   ```

If the daemon fails to start, check:
- `tail -f .claude/logs/daemon.log` for detailed error messages
- Ensure all prerequisites (fswatch, jq, gh, claude) are installed
- Verify `.claude/bin/mcp-server.sh` exists and is executable

### `starforge status`

Shows current state:
- Active git worktrees
- Agent status (working/idle)
- GitHub queue (ready tickets, in-progress, needs-review)
- Recent agent activity

### `starforge help`

Shows comprehensive help and usage examples.

## Workflow

### Autonomous Mode (Recommended)

**For Existing Projects:**
1. **Install**: `starforge install`
2. **Analyze**: `starforge analyze`
3. **Start Daemon**: `starforge daemon start`
4. **Plan**: `starforge use senior-engineer` (creates breakdown)
   - TPM automatically creates GitHub Issues
   - Orchestrator automatically assigns work to junior-devs
   - Junior-devs autonomously implement features
   - QA automatically reviews PRs
5. **Check Progress**: `starforge status` or `starforge daemon status`
6. **Review Output**: Check GitHub PRs when notified
7. **Stop Daemon**: `starforge daemon stop` (when done)

**For New Projects:**
1. **Install**: `starforge install`
2. **Brainstorm**: Use Main Claude to explore ideas
3. **Start Daemon**: `starforge daemon start`
4. **Plan**: `starforge use senior-engineer`
5. **Walk Away**: Agents work autonomously - check progress with `starforge status`

### Manual Mode (Interactive)

**For Existing Projects:**
1. **Install**: `starforge install`
2. **Analyze**: `starforge analyze`
3. **Plan**: `starforge use senior-engineer` (creates breakdown)
4. **Create Tickets**: TPM automatically triggered to create GitHub Issues
5. **Monitor**: `starforge monitor` (in separate terminal)
6. **Assign Work**: `starforge use orchestrator`
7. **Check Status**: `starforge status`

**For New Projects:**
1. **Install**: `starforge install`
2. **Brainstorm**: Use Main Claude to explore ideas
3. **Plan**: `starforge use senior-engineer`
4. **Execute**: `starforge use orchestrator`

## How It Works

### Multi-Agent Architecture

StarForge uses specialized agents that communicate via trigger files:

```
Senior Engineer → TPM Agent → Orchestrator → Junior Devs → QA Engineer
     (breakdown)   (tickets)    (assigns)      (code)      (review)
```

### Git Worktrees for Parallelism

Each junior-dev works in its own worktree, enabling true parallel development:

```
my-project/              # Main repo (orchestrator, senior, TPM, QA)
my-project-junior-dev-a/ # Worktree for junior-dev-a
my-project-junior-dev-b/ # Worktree for junior-dev-b
my-project-junior-dev-c/ # Worktree for junior-dev-c
```

### Trigger-Based Communication

Agents communicate asynchronously via JSON trigger files in `.claude/triggers/`:

```json
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm-agent",
  "action": "create-tickets",
  "breakdown_file": ".claude/breakdowns/feature-breakdown.md"
}
```

The trigger monitor watches for these files and notifies you of agent activity.

### Daemon Agent Invocation

The daemon automatically invokes agents when triggers are detected. This uses the Claude Code CLI in non-interactive mode:

**Invocation Flow:**
1. Daemon detects new trigger file in `.claude/triggers/`
2. Validates JSON and extracts target agent
3. Builds prompt from trigger context
4. Invokes agent via MCP server + `claude --print`:
   ```bash
   .claude/bin/mcp-server.sh | claude \
     --print \
     --permission-mode bypassPermissions \
     "Use the orchestrator agent. Task from senior-engineer: assign_work..."
   ```
5. Agent executes with pre-approved permissions from `.claude/settings.json`
6. Output logged to `.claude/logs/daemon.log`
7. Trigger archived to `processed/` or `failed/` based on result

**Key Points:**
- **No simulation**: Real agent execution via `claude` CLI
- **Non-interactive**: Uses `--print` flag for background operation
- **MCP tools**: Agent capabilities provided via MCP server on stdin
- **Permission bypass**: Pre-configured in `.claude/settings.json`
- **Error handling**: Automatic retry with exponential backoff (max 3 attempts)
- **Timeout protection**: 30-minute timeout per agent invocation

## Directory Structure

```
.claude/
├── agents/              # Agent definition files
│   ├── orchestrator.md
│   ├── senior-engineer.md
│   ├── junior-engineer.md
│   ├── qa-engineer.md
│   ├── tpm-agent.md
│   ├── agent-learnings/ # Project-specific learnings
│   └── scratchpads/     # Agent working memory
├── scripts/             # Helper scripts
│   ├── trigger-helpers.sh
│   ├── trigger-monitor.sh
│   └── watch-triggers.sh
├── hooks/               # Git safety hooks
│   ├── block-main-edits.sh
│   └── block-main-bash.sh
├── coordination/        # Agent status files
├── triggers/            # Agent communication
├── breakdowns/          # Technical designs
├── qa/                  # Test reports
├── research/            # Investigation notes
├── spikes/              # Proof-of-concepts
├── CLAUDE.md            # Agent protocol
├── LEARNINGS.md         # Global learnings
└── settings.json        # Permissions and hooks
```

## Testing

StarForge is built with TDD. All tests pass before release:

```bash
# Run installer tests (58 tests)
cd ~/starforge-master
bash ./bin/test-install.sh

# Run CLI tests (38 tests)
bash ./bin/test-cli.sh
```

## GitHub Integration

StarForge works best with GitHub:

- **TPM creates Issues**: Automatic ticket creation from breakdowns
- **Junior-devs create PRs**: Each feature gets a pull request
- **QA comments on PRs**: Feedback directly in code review
- **Orchestrator tracks progress**: GitHub API for work visibility

**Without GitHub**, you can still use StarForge in local-only mode with limited features.

## Requirements

- **macOS** (tested on macOS 14+)
- **Git** 2.20+
- **GitHub CLI** (`gh`) - for GitHub integration
- **jq** - for JSON processing
- **Claude Code CLI** (`claude`) - for AI agents
- **terminal-notifier** (optional) - for desktop notifications

Install prerequisites:
```bash
brew install gh jq terminal-notifier
gh auth login
```

**Installing Claude Code CLI:**
- Visit: https://docs.claude.com/claude-code
- Follow installation instructions
- Verify: `claude --version`

## Configuration

StarForge is zero-configuration by default. Advanced users can modify:

- `.claude/settings.json`: Permissions and hooks
- `.claude/agents/agent-learnings/`: Project-specific knowledge
- Number of junior-devs during installation (1-5)

### Agent Detection

StarForge uses **dynamic agent detection** that automatically adapts to your configuration:

- **Supports unlimited agents**: Not limited to 3 agents - use 1, 2, 5, 10, or more
- **Flexible naming patterns**:
  - Standard: `project-junior-dev-a`, `project-junior-dev-b`, ... `project-junior-dev-z`
  - Custom numbers: `project-dev-1`, `project-dev-2`, ... `project-dev-10`
- **Automatic detection**: Reads from git worktree configuration
- **No hardcoded limits**: Add as many agents as your workflow needs

The system detects agent identity by:
1. Pattern matching directory names (junior-dev-{letter} or dev-{number})
2. Verifying against actual git worktrees
3. Falling back to "main" for non-agent directories

## Important Notes

### StarForge IP

The `.claude/` folder contains StarForge intellectual property:
- **Never commit** `.claude/` to git (automatically in .gitignore)
- **Never modify** agent definition files
- **Never distribute** StarForge agents outside of licensed use

You own:
- `PROJECT_CONTEXT.md`
- `TECH_STACK.md`
- All code generated by agents

### Worktree Management

Worktrees are created during installation. To remove:
```bash
git worktree list
git worktree remove <path>
```

To add more agents beyond the initial installation:
```bash
# Add 4th agent (standard naming)
git worktree add ../my-project-junior-dev-d -b worktree-d main

# Add 5th agent (standard naming)
git worktree add ../my-project-junior-dev-e -b worktree-e main

# Add custom-named agents (also supported)
git worktree add ../my-project-dev-1 -b dev-1 main
git worktree add ../my-project-dev-2 -b dev-2 main
```

**Note**: Dynamic agent detection will automatically recognize any agent worktree following these patterns:
- `{project}-junior-dev-{letter}` (e.g., a, b, c, d, e, ... z)
- `{project}-dev-{number}` (e.g., 1, 2, 3, ... 10, 11, ...)

## Troubleshooting

### "StarForge not installed"
Run `starforge install` in your project directory.

### "Claude Code CLI not found"
Install from: https://docs.claude.com/claude-code

Verify installation:
```bash
which claude
claude --version
```

If installed but not found, check your PATH:
```bash
echo $PATH
# Ensure directory containing 'claude' is included
```

### "GitHub CLI not authenticated"
Run: `gh auth login`

### Worktree creation fails
Ensure you're in a git repository with at least one commit.

### Tests failing
Ensure all prerequisites are installed and you're running from `~/starforge-master/`.

### Daemon fails to start

Check prerequisites:
```bash
# Verify all required tools
which fswatch  # or inotifywait on Linux
which jq
which gh
which claude

# Check daemon logs
tail -f .claude/logs/daemon.log
```

Common issues:
- **fswatch not installed**: `brew install fswatch` (macOS)
- **claude not found**: Install Claude Code CLI (see Requirements)
- **Permission errors**: Check `.claude/settings.json` permissions
- **MCP server missing**: Run `starforge update` to deploy latest templates

### Agent invocation fails in daemon mode

If you see errors like "claude: command not found" in daemon logs:

1. **Verify PATH in daemon context:**
   ```bash
   # Check what PATH the daemon sees
   grep "PATH" .claude/logs/daemon.log
   ```

2. **Ensure claude is in system PATH:**
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   export PATH="/usr/local/bin:$PATH"

   # Reload
   source ~/.zshrc
   ```

3. **Test invocation manually:**
   ```bash
   # From project root
   .claude/bin/mcp-server.sh | claude --print "Hello"
   ```

4. **Check MCP server:**
   ```bash
   # Verify MCP server exists and is executable
   ls -la .claude/bin/mcp-server.sh
   chmod +x .claude/bin/mcp-server.sh
   ```

## Examples

### Adding a new feature to existing project

```bash
# 1. Analyze current state
starforge analyze

# 2. Review generated docs
cat PROJECT_CONTEXT.md
cat TECH_STACK.md
cat initial-assessment.md

# 3. Create breakdown
starforge use senior-engineer
# Provide: "Add user authentication with JWT"

# 4. Monitor in separate terminal
starforge monitor

# 5. Assign work
starforge use orchestrator
# TPM will have created tickets already

# 6. Check progress
starforge status
```

### Starting a new iOS app

```bash
# 1. Create and initialize
mkdir my-ios-app
cd my-ios-app
git init

# 2. Install StarForge
starforge install

# 3. Plan with senior engineer
starforge use senior-engineer
# Describe your app vision

# 4. Execute
starforge use orchestrator
```

## Contributing

StarForge welcomes contributions! Whether it's bug fixes, new features, or documentation improvements, your help is appreciated.

### Development Workflow

StarForge uses a **feature branch + pull request** workflow:

1. **Fork** the repository
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes** and test thoroughly
4. **Commit** with clear messages: `git commit -m "feat: Add feature X"`
5. **Push** to your fork: `git push origin feature/your-feature`
6. **Create a Pull Request** on GitHub

**Important:** Never commit directly to `main`. All changes must go through PR review.

### What to Contribute

**High Priority:**
- Bug fixes and issue resolutions
- Documentation improvements
- Test coverage additions
- User experience enhancements

**Medium Priority:**
- New agent definitions
- CLI command enhancements
- Platform compatibility (Windows, Linux)

**Discuss First:**
- Breaking changes
- Major refactors
- New paid features

### Testing Requirements

All contributions must include appropriate tests:

```bash
# Test installer changes
bash tests/test-installer.sh

# Test CLI changes
bash bin/verify-cli.sh
```

### Code Review

All pull requests require approval from `@JediMasterKT` (enforced via CODEOWNERS). This ensures:
- Consistent quality standards
- Backward compatibility
- Security review
- User experience coherence

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Architecture Decisions

### Why Git Worktrees?

Traditional branching creates conflicts when multiple agents work simultaneously. Worktrees provide:
- **True parallelism**: Each agent has its own working directory
- **No branch conflicts**: Agents can't interfere with each other
- **Shared history**: All worktrees reference the same repository
- **Easy cleanup**: Remove worktree without affecting others

### Why Trigger Files?

Asynchronous communication scales better than synchronous:
- **Non-blocking**: Agents don't wait for each other
- **Auditable**: All handoffs are recorded
- **Debuggable**: Easy to trace agent interactions
- **Flexible**: Add new agents without changing protocols

### Why .gitignore .claude/?

StarForge agents are proprietary. Users license StarForge but don't own the agent definitions. This protects IP while allowing users to benefit from the system.

## License

StarForge is proprietary software. The `.claude/` folder and all agent definitions are intellectual property and must not be distributed, modified, or committed to version control.

Generated code and documentation (PROJECT_CONTEXT.md, TECH_STACK.md, etc.) belong to the user.

## Support

For issues, questions, or feedback:
- GitHub Issues: Create an issue in your StarForge installation
- Documentation: See `.claude/CLAUDE.md` for agent protocols
- Help: Run `starforge help` for quick reference

## Changelog

### v1.0.0 (2025-01-XX)
- Initial release
- 5 specialized agents (orchestrator, senior-engineer, junior-engineer, qa-engineer, tpm-agent)
- Git worktree-based parallel development
- GitHub integration
- TDD test suites (58 installer + 38 CLI tests)
- Interactive installation
- Project analysis
- Trigger monitoring
- Status reporting

---

**Happy building with your AI team!** 🚀
