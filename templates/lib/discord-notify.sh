#!/usr/bin/env bash
#
# discord-notify.sh - Discord notification helper for StarForge daemon
#
# Sends rich embeds to per-agent Discord channels for real-time visibility
# into agent activity.
#

# Color codes (decimal for Discord embeds)
COLOR_SUCCESS=5763719   # Green
COLOR_INFO=3447003      # Blue
COLOR_WARNING=16776960  # Yellow
COLOR_ERROR=15158332    # Red

#
# get_webhook_for_agent <agent_name>
#
# Returns the Discord webhook URL for the specified agent.
# Falls back to generic webhook if agent-specific webhook not configured.
#
# Example:
#   webhook=$(get_webhook_for_agent "junior-dev-a")
#   # Looks for $DISCORD_WEBHOOK_JUNIOR_DEV_A first
#
get_webhook_for_agent() {
  local agent=$1

  # Convert agent name to env var format
  # junior-dev-a → JUNIOR_DEV_A
  # orchestrator → ORCHESTRATOR
  # qa-engineer → QA_ENGINEER
  local agent_upper=$(echo "$agent" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
  local webhook_var="DISCORD_WEBHOOK_${agent_upper}"

  # Try agent-specific webhook first (using eval for portability)
  local webhook_url=$(eval echo \$${webhook_var})

  # Fallback to generic webhook
  if [ -z "$webhook_url" ]; then
    webhook_url="$DISCORD_WEBHOOK_URL"
  fi

  echo "$webhook_url"
}

#
# send_discord_daemon_notification <agent> <title> <description> <color> <fields_json>
#
# Sends a Discord embed notification to the agent's dedicated channel.
#
# Args:
#   agent: Agent name (e.g., "junior-dev-a", "orchestrator")
#   title: Embed title (e.g., "🚀 Agent Started")
#   description: Embed description/main text
#   color: Decimal color code (use COLOR_* constants)
#   fields_json: JSON array of fields (e.g., '[{"name":"Ticket","value":"#123"}]')
#
# Example:
#   send_discord_daemon_notification \
#     "junior-dev-a" \
#     "✅ Agent Completed" \
#     "**junior-dev-a** finished successfully" \
#     "$COLOR_SUCCESS" \
#     '[{"name":"Duration","value":"5m 23s","inline":true}]'
#
send_discord_daemon_notification() {
  local agent=$1
  local title=$2
  local description=$3
  local color=$4
  local fields=$5

  # Get webhook URL for this agent
  local webhook_url=$(get_webhook_for_agent "$agent")

  # Silently skip if no webhook configured
  if [ -z "$webhook_url" ]; then
    return 0
  fi

  # Generate ISO 8601 timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  # Build JSON payload with Discord embed format
  local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "fields": $fields,
    "timestamp": "$timestamp",
    "footer": {
      "text": "StarForge Daemon"
    }
  }]
}
EOF
)

  # Send asynchronously to avoid blocking daemon
  # (Failures are silent - Discord notifications are optional)
  curl -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    > /dev/null 2>&1 &
}

#
# send_agent_start_notification <agent> <action> <from_agent> <ticket>
#
# Convenience wrapper for agent start notifications.
#
send_agent_start_notification() {
  local agent=$1
  local action=$2
  local from_agent=$3
  local ticket=${4:-N/A}

  send_discord_daemon_notification \
    "$agent" \
    "🚀 Agent Started" \
    "**$agent** is now working" \
    "$COLOR_INFO" \
    "[{\"name\":\"Action\",\"value\":\"$action\",\"inline\":true},{\"name\":\"From\",\"value\":\"$from_agent\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]"
}

#
# send_agent_progress_notification <agent> <elapsed_min> <ticket>
#
# Convenience wrapper for agent progress notifications.
#
send_agent_progress_notification() {
  local agent=$1
  local elapsed_min=$2
  local ticket=${3:-N/A}

  send_discord_daemon_notification \
    "$agent" \
    "⏳ Agent Progress" \
    "**$agent** still working" \
    "$COLOR_WARNING" \
    "[{\"name\":\"Elapsed\",\"value\":\"${elapsed_min}m\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]"
}

#
# send_agent_complete_notification <agent> <duration_min> <duration_sec> <action> <ticket>
#
# Convenience wrapper for agent completion notifications.
#
send_agent_complete_notification() {
  local agent=$1
  local duration_min=$2
  local duration_sec=$3
  local action=$4
  local ticket=${5:-N/A}

  send_discord_daemon_notification \
    "$agent" \
    "✅ Agent Completed" \
    "**$agent** finished successfully" \
    "$COLOR_SUCCESS" \
    "[{\"name\":\"Duration\",\"value\":\"${duration_min}m ${duration_sec}s\",\"inline\":true},{\"name\":\"Action\",\"value\":\"$action\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]"
}

#
# send_agent_timeout_notification <agent> <action> <ticket>
#
# Convenience wrapper for agent timeout notifications.
#
send_agent_timeout_notification() {
  local agent=$1
  local action=$2
  local ticket=${3:-N/A}

  send_discord_daemon_notification \
    "$agent" \
    "⏰ Agent Timeout" \
    "**$agent** exceeded 30-minute limit" \
    "$COLOR_ERROR" \
    "[{\"name\":\"Action\",\"value\":\"$action\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]"
}

#
# send_agent_error_notification <agent> <exit_code> <duration_min> <ticket>
#
# Convenience wrapper for agent error notifications.
#
send_agent_error_notification() {
  local agent=$1
  local exit_code=$2
  local duration_min=$3
  local ticket=${4:-N/A}

  send_discord_daemon_notification \
    "$agent" \
    "❌ Agent Failed" \
    "**$agent** crashed with exit code $exit_code" \
    "$COLOR_ERROR" \
    "[{\"name\":\"Exit Code\",\"value\":\"$exit_code\",\"inline\":true},{\"name\":\"Duration\",\"value\":\"${duration_min}m\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]"
}
