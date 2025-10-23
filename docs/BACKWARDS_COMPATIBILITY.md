# Backwards Compatibility Guide

## Overview

StarForge supports both **manual** and **automatic** workflows, ensuring backwards compatibility with existing usage patterns while enabling new queue-based automation.

## Workflow Modes

### Manual Mode (Original Workflow)

The original workflow where you manually invoke agents using `starforge use` commands continues to work unchanged.

**Use when:**
- Learning StarForge for the first time
- Working on a single task interactively
- Preferring direct control over agent invocation
- File watcher tools (fswatch/inotifywait) are unavailable

**How it works:**
```bash
# Invoke agents manually
starforge use senior-engineer  # Create breakdown
starforge use orchestrator     # Assign work
starforge use qa-engineer      # Review code
```

Agents create trigger files in `.claude/triggers/` which remain there until:
1. You manually check them, or
2. You start the watcher (automatic mode)

### Automatic Mode (New Workflow)

The new queue-based workflow where a watcher automatically routes trigger files to agent queues.

**Use when:**
- Running multiple agents in parallel
- Want hands-off agent coordination
- Need real-time visibility into agent activity
- Have fswatch (macOS) or inotifywait (Linux) installed

**How it works:**
```bash
# Terminal 1: Start the watcher
starforge monitor

# Terminal 2: Trigger agents (they auto-route)
starforge use senior-engineer  # Automatically routes to TPM
# Junior devs pick up from queue automatically
```

The watcher:
- Monitors `.claude/triggers/` for new `.trigger` files
- Routes them to appropriate agent queues (`.claude/queues/{agent}/pending/`)
- Archives processed triggers to `.claude/triggers/processed/`
- Logs all activity to `.claude/watcher.log`

## Coexistence

Both modes work together seamlessly:

1. **Manual triggers are picked up by watcher**: If you create triggers manually and later start the watcher, it will process any existing triggers

2. **Watcher can be stopped/started**: You can run the watcher temporarily, stop it, and resume manual workflow

3. **Same trigger format**: Both modes use identical JSON trigger file format

4. **No migration needed**: Existing projects continue working without changes

## Trigger File Format

The trigger format is **unchanged** and works in both modes:

```json
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm-agent",
  "action": "create-tickets",
  "timestamp": "2025-10-23T00:00:00Z",
  "breakdown_file": ".claude/breakdowns/feature.md"
}
```

Optional `context` field (new, but optional):
```json
{
  "from_agent": "orchestrator",
  "to_agent": "junior-dev-a",
  "action": "implement-ticket",
  "context": {
    "ticket": 42,
    "priority": "high"
  }
}
```

## Queue System Fallback

The queue system fails gracefully when unavailable:

- **If router.sh missing**: Triggers are archived to `.claude/triggers/processed/` (logged)
- **If watcher not running**: Triggers remain in `.claude/triggers/` for manual processing
- **If fswatch/inotifywait unavailable**: Watcher falls back to polling mode (2-second interval)

## Migration Path

No migration is needed! Your existing workflow continues unchanged:

### Staying with Manual Mode
```bash
# Nothing changes - keep using starforge as before
starforge use senior-engineer
starforge use orchestrator
```

### Trying Automatic Mode
```bash
# Just start the watcher in a separate terminal
starforge monitor

# Your existing commands work the same way
starforge use senior-engineer
# (Now automatically routed to TPM queue)
```

### Hybrid Approach
```bash
# Use automatic mode when working on large features
starforge monitor  # Start watcher

# Use manual mode for quick one-off tasks
# (Stop watcher with Ctrl+C first)
starforge use qa-engineer  # Direct invocation
```

## Breaking Changes

**None.** This update is 100% backwards compatible:

- ✅ Manual `starforge use` commands unchanged
- ✅ Trigger file format unchanged (context field is optional)
- ✅ Agent definitions unchanged
- ✅ Directory structure unchanged (queue dirs only created when used)
- ✅ GitHub integration unchanged
- ✅ Git worktrees unchanged

## FAQ

**Q: Do I need to install fswatch/inotifywait?**
A: No. The watcher will fall back to polling mode if these tools are unavailable.

**Q: What happens if I forget to start the watcher?**
A: Nothing breaks. Triggers remain in `.claude/triggers/` and you can process them manually or start the watcher later.

**Q: Can I switch between modes?**
A: Yes. Stop the watcher (Ctrl+C) to use manual mode, or start it to use automatic mode.

**Q: Do my existing scripts/workflows break?**
A: No. All existing functionality remains unchanged.

**Q: Is the queue system required?**
A: No. It's an optional enhancement. Manual workflow works without it.

## Testing

Backwards compatibility is validated by comprehensive test suite:

```bash
bash tests/test_backwards_compatibility.sh
```

This runs 25 tests covering:
- Manual invocation without watcher
- Automatic routing with watcher
- Mode coexistence
- Trigger format compatibility
- CLI command functionality
- Documentation completeness
- Graceful degradation

All tests must pass before release.

## See Also

- [README.md](../README.md) - Main documentation
- [test_backwards_compatibility.sh](../tests/test_backwards_compatibility.sh) - Test suite
- [watch-triggers.sh](../bin/watch-triggers.sh) - Watcher implementation
- [router.sh](../.claude/lib/router.sh) - Queue routing logic
