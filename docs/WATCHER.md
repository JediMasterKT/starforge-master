# Trigger Watcher Documentation

## Overview

`bin/watch-triggers.sh` monitors the `.claude/triggers/` directory for new trigger files and routes them automatically to agent queues.

## Features

- **Fast Detection**: Detects triggers in <1 second using file system events
- **Multiple Backends**: Supports fswatch (macOS), inotifywait (Linux), and polling fallback
- **Graceful Shutdown**: Responds to SIGTERM for clean exit
- **Comprehensive Logging**: All events logged to `.claude/watcher.log`
- **Error Handling**: Invalid triggers moved to processed/ with error marker
- **Queue Integration**: Ready for queue system (issues #52, #55, #59)

## Usage

### Start Watcher

```bash
# Run in foreground
./bin/watch-triggers.sh

# Run in background
./bin/watch-triggers.sh &
```

### Force Polling Mode

If you want to test polling fallback:

```bash
USE_POLLING=1 ./bin/watch-triggers.sh
```

### Custom Log File

```bash
WATCHER_LOG=/path/to/custom.log ./bin/watch-triggers.sh
```

### Stop Watcher

```bash
# Send SIGTERM for graceful shutdown
kill -TERM <PID>

# Or use Ctrl+C if running in foreground
```

## How It Works

1. **Startup**: Processes any existing triggers in `.claude/triggers/`
2. **Detection**: Watches for new `.trigger` files using:
   - **fswatch** (macOS) - preferred, real-time events
   - **inotifywait** (Linux) - real-time events
   - **Polling** - fallback, checks every 2 seconds
3. **Processing**:
   - Validates JSON structure
   - Extracts `to_agent`, `from_agent`, `action`
   - Routes to queue (when available) or archives to `processed/`
4. **Logging**: All events logged with timestamps

## Trigger File Format

Valid trigger files must be JSON with these fields:

```json
{
  "from_agent": "junior-dev-a",
  "to_agent": "qa-engineer",
  "action": "review_pr",
  "timestamp": "2025-10-22T00:00:00Z",
  "message": "PR #63 ready for review",
  "context": {
    "pr": 63,
    "ticket": 36
  }
}
```

**Required fields:**
- `to_agent` - Target agent identifier

**Optional fields:**
- `from_agent` - Source agent identifier
- `action` - Action type (e.g., "review_pr", "implement_ticket")
- `timestamp` - ISO 8601 timestamp
- `message` - Human-readable description
- `context` - Additional context (JSON object)

## Error Handling

### Invalid JSON

If trigger file contains invalid JSON:
- Error logged
- File moved to `processed/<filename>.invalid`

### Missing to_agent

If `to_agent` field is missing:
- Error logged
- File moved to `processed/<filename>.invalid`

### Router Unavailable

If `.claude/lib/router.sh` doesn't exist:
- Warning logged
- File moved to `processed/` (archived)
- Ready for queue integration later

## Performance

- **fswatch mode**: <100ms detection time
- **inotifywait mode**: <100ms detection time
- **Polling mode**: ~2 second detection time
- **Multiple triggers**: Handles 10+ triggers/second

## Dependencies

### Required
- bash
- jq (JSON parsing)
- `.claude/lib/project-env.sh` (environment detection)

### Optional
- fswatch (macOS) - Install via `brew install fswatch`
- inotifywait (Linux) - Install via `apt-get install inotify-tools`

Without file watchers, automatically falls back to polling.

## Integration with Queue System

When queue infrastructure is complete (issues #52, #55, #59), the watcher will:

1. Call `.claude/lib/router.sh` function `route_trigger_to_queue()`
2. Place tasks in `.claude/queues/{agent}/pending/`
3. Update queue metrics
4. Notify target agent

Currently, triggers are archived to `processed/` until queue system is ready.

## Testing

Run the comprehensive test suite:

```bash
./tests/test-watch-triggers.sh
```

Tests cover:
- Script existence and permissions
- fswatch/inotifywait detection
- Trigger file detection (<1 second)
- Multiple trigger handling
- Graceful shutdown (SIGTERM)
- Polling fallback
- Logging

## Monitoring

### View Logs

```bash
# Real-time log monitoring
tail -f .claude/watcher.log

# Last 50 events
tail -50 .claude/watcher.log

# Search for errors
grep ERROR .claude/watcher.log
```

### Check Status

```bash
# Is watcher running?
ps aux | grep watch-triggers.sh

# How many triggers processed?
grep "Completed processing" .claude/watcher.log | wc -l
```

## Troubleshooting

### Watcher not starting

Check that project-env.sh exists:
```bash
ls -la .claude/lib/project-env.sh
```

### Triggers not detected

1. Check watcher is running: `ps aux | grep watch-triggers`
2. Check log file: `tail -f .claude/watcher.log`
3. Verify trigger format: `jq . .claude/triggers/your-trigger.trigger`

### High CPU usage

- Polling mode uses more CPU than fswatch/inotifywait
- Install fswatch (macOS) or inotify-tools (Linux) for better performance

## Future Enhancements

- Queue routing (blocked by #52, #55, #59)
- Metrics dashboard
- Dead letter queue for failed triggers
- Priority-based processing
- Webhook notifications
