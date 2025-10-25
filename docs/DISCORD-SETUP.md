# Discord Workflow Notifications Setup

This guide explains how to configure Discord notifications for StarForge daemon workflow events.

## Overview

Discord notifications provide real-time visibility into your StarForge agents' activities:

- **🚀 Agent Started** - When an agent begins work
- **⏳ Agent Progress** - Progress updates every 5 minutes
- **✅ Agent Completed** - When an agent finishes successfully
- **❌ Agent Failed** - When an agent crashes with exit code
- **⏰ Agent Timeout** - When an agent exceeds the 30-minute limit
- **🟢 Daemon Started** - When the daemon begins running
- **🔴 Daemon Stopped** - When the daemon shuts down
- **🚫 Invalid Trigger** - When a malformed trigger is rejected

## Prerequisites

1. Discord server with admin access
2. Channel(s) for agent notifications
3. Discord webhook URLs

## Step 1: Create Discord Webhooks

### Option A: Single Webhook (All agents → one channel)

1. In Discord, go to **Server Settings** → **Integrations** → **Webhooks**
2. Click **New Webhook**
3. Name it `StarForge Notifications`
4. Select channel (e.g., `#starforge-activity`)
5. Click **Copy Webhook URL**
6. Save URL for Step 2

### Option B: Per-Agent Webhooks (Separate channels per agent)

Create a webhook for each agent you want to track:

1. **junior-engineer** → `#junior-engineer-activity`
2. **qa-engineer** → `#qa-activity`
3. **orchestrator** → `#orchestrator-activity`
4. **tpm-agent** → `#tpm-activity`

Repeat the webhook creation process for each channel.

### Option C: System Alerts Channel (Recommended)

Create a dedicated channel for system-level alerts:

1. Create channel `#starforge-alerts`
2. Create webhook for daemon start/stop and invalid trigger notifications
3. Copy webhook URL

## Step 2: Configure Environment Variables

Create or edit `.env` in your project root:

```bash
# Option A: Single webhook (all agents use this)
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1234567890/ABCDEFGHIJKLMNOP..."

# Option B: Per-agent webhooks (override for specific agents)
DISCORD_WEBHOOK_JUNIOR_ENGINEER="https://discord.com/api/webhooks/1111111111/AAAA..."
DISCORD_WEBHOOK_QA_ENGINEER="https://discord.com/api/webhooks/2222222222/BBBB..."
DISCORD_WEBHOOK_ORCHESTRATOR="https://discord.com/api/webhooks/3333333333/CCCC..."
DISCORD_WEBHOOK_TPM_AGENT="https://discord.com/api/webhooks/4444444444/DDDD..."

# Option C: System alerts channel (daemon start/stop, invalid triggers)
DISCORD_WEBHOOK_STARFORGE_ALERTS="https://discord.com/api/webhooks/5555555555/EEEE..."
```

### Webhook Routing Logic

1. Agent-specific webhook (e.g., `DISCORD_WEBHOOK_JUNIOR_ENGINEER`) - highest priority
2. Fallback to `DISCORD_WEBHOOK_URL` if agent-specific not configured
3. System notifications always use `DISCORD_WEBHOOK_STARFORGE_ALERTS` (fallback to `DISCORD_WEBHOOK_URL`)

## Step 3: Verify Installation

Check that discord-notify.sh is available:

```bash
ls -la .claude/lib/discord-notify.sh
```

If missing, run:

```bash
starforge update
```

## Step 4: Test Notifications

### Test Individual Functions

Create a test script `test-discord.sh`:

```bash
#!/bin/bash

# Load discord-notify.sh
source .claude/lib/discord-notify.sh

# Test agent start notification
send_agent_start_notification "junior-engineer" "implement_feature" "orchestrator" "PR-161"

# Wait to see notification appear in Discord
sleep 2

# Test completion notification
send_agent_complete_notification "junior-engineer" 5 23 "implement_feature" "PR-161"

# Test error notification
send_agent_error_notification "qa-engineer" 1 12 "PR-161"

# Test timeout notification
send_agent_timeout_notification "tpm-agent" "create_tickets" "PR-161"

# Test system notification
send_daemon_start_notification
```

Run the test:

```bash
chmod +x test-discord.sh
./test-discord.sh
```

Check your Discord channels for notifications.

### Test with Real Daemon

1. Start the daemon:

```bash
starforge daemon start
```

2. Create a test trigger:

```bash
starforge send junior-engineer implement_feature "Test Discord integration" --ticket PR-TEST
```

3. Watch Discord channels for:
   - 🚀 Agent Started notification
   - ⏳ Progress updates (if agent runs > 5 minutes)
   - ✅ Agent Completed notification

## Discord Notification Format

All notifications use Discord's embed format with:

- **Title**: Emoji + event description (e.g., "🚀 Agent Started")
- **Description**: Agent name and status
- **Fields**: Contextual data (Ticket, Action, Duration, etc.)
- **Color**:
  - 🔵 Blue (`COLOR_INFO`) - Start, Progress
  - 🟢 Green (`COLOR_SUCCESS`) - Complete, Daemon Start
  - 🟡 Yellow (`COLOR_WARNING`) - Timeout, Daemon Stop
  - 🔴 Red (`COLOR_ERROR`) - Failed, Invalid Trigger
- **Timestamp**: ISO 8601 format (UTC)
- **Footer**: "StarForge Daemon" or "StarForge System"

## Rate Limiting

Discord enforces **5 requests per 2 seconds** per webhook. StarForge automatically:

1. Tracks webhook calls in `/tmp/discord-rate-limit-{hash}.log`
2. Blocks if rate limit exceeded
3. Retries once after 1-second delay
4. Gracefully skips if still rate-limited (to avoid blocking daemon)

**Note**: Rate limiting is per-webhook, so using multiple webhooks increases total throughput.

## Troubleshooting

### Notifications not appearing

**Check 1: Webhook URL valid?**

```bash
# Test webhook directly
curl -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test from StarForge"}'
```

You should see "Test from StarForge" in the Discord channel.

**Check 2: .env loaded?**

```bash
# Verify environment variable set
echo $DISCORD_WEBHOOK_URL
```

If empty, ensure `.env` is in project root and daemon was restarted after creating it.

**Check 3: discord-notify.sh sourced?**

```bash
# Check if functions are available
type send_agent_start_notification
```

If "not found", run `starforge update` to deploy latest templates.

### Rate limit errors

If you see rate limit warnings in daemon logs:

1. **Reduce notification frequency**: Increase progress monitor interval (default: 5 min)
2. **Use multiple webhooks**: Separate agents into different channels
3. **Disable progress notifications**: Comment out progress monitor in daemon-runner.sh

### Notifications delayed

Discord notifications are sent **asynchronously** (via background `curl &`). This ensures:

- ✅ Daemon never blocks waiting for Discord API
- ✅ Agent execution continues immediately
- ⚠️ Notifications may arrive 1-2 seconds after event

This is by design - agent performance > notification latency.

## Advanced Configuration

### Custom Progress Interval

Edit `templates/bin/daemon-runner.sh`:

```bash
# Change from 300 (5 min) to 600 (10 min)
monitor_agent_progress() {
  local interval=600  # 10 minutes
  ...
}
```

Redeploy:

```bash
starforge update
```

### Disable Specific Notifications

Comment out unwanted calls in `templates/bin/daemon-runner.sh`:

```bash
# Disable progress notifications
# if type send_agent_progress_notification &>/dev/null; then
#   send_agent_progress_notification "$agent" "$elapsed_min" "$ticket"
# fi
```

### Custom Notification Messages

Edit `templates/lib/discord-notify.sh` to customize embed titles, descriptions, or colors:

```bash
send_agent_complete_notification() {
  ...
  send_discord_daemon_notification \
    "$agent" \
    "🎉 Success!"  # Custom title
    "**$agent** crushed it in $duration_display"  # Custom description
    "$COLOR_SUCCESS" \
    "$fields"
}
```

## Security Notes

1. **Keep webhook URLs secret** - Anyone with the URL can post to your channel
2. **Use .gitignore** - Ensure `.env` is in `.gitignore` (already configured in StarForge)
3. **Regenerate if exposed** - If webhook URL leaked, delete and recreate in Discord settings

## Example Workflow

**Scenario**: Orchestrator triggers junior-engineer to implement PR #161

**Discord Timeline**:

```
14:32:15  🚀 Agent Started
          junior-engineer triggered by orchestrator
          Action: implement_feature | Ticket: PR-161

14:37:15  ⏳ Agent Progress
          junior-engineer still working (5 minutes elapsed)
          Ticket: PR-161

14:42:15  ⏳ Agent Progress
          junior-engineer still working (10 minutes elapsed)
          Ticket: PR-161

14:45:38  ✅ Agent Completed
          junior-engineer finished in 13m 23s
          Action: implement_feature | Ticket: PR-161
```

**Benefits**:

- Real-time visibility into agent activity
- No need to tail daemon logs
- Team-wide awareness of automation progress
- Historical record of agent performance

## Next Steps

- [CI-First QA Documentation](CI-BRANCH-PROTECTION.md) - Configure CI integration
- [Agent Learnings](../templates/agents/agent-learnings/) - Train agents based on Discord feedback
- [Daemon Architecture](parallel-daemon-execution.md) - Understand daemon internals

---

**Questions?** Open an issue or ask in Discord.
