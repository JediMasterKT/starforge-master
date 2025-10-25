#!/bin/bash
#
# discord-notify.sh - Discord notification helper for StarForge daemon
#
# Sends rich embeds to Discord channels for agent lifecycle events and system alerts
#

# Discord color codes
COLOR_SUCCESS=5763719    # Green
COLOR_INFO=3447003       # Blue
COLOR_WARNING=16776960   # Yellow
COLOR_ERROR=15158332     # Red

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Webhook Routing
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# get_webhook_for_agent - Route notifications to per-agent Discord channels
# Usage: get_webhook_for_agent "qa-engineer"
# Returns: Discord webhook URL for the agent's channel
get_webhook_for_agent() {
  local agent=$1

  # Convert agent name to env var format: junior-dev-a → DISCORD_WEBHOOK_JUNIOR_DEV_A
  local agent_upper=$(echo "$agent" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
  local webhook_var="DISCORD_WEBHOOK_${agent_upper}"

  # Use eval for portability (bash indirection doesn't work in zsh)
  local webhook_url=$(eval echo \${webhook_var})

  # Fallback to generic webhook if agent-specific not configured
  if [ -z "$webhook_url" ]; then
    webhook_url="$DISCORD_WEBHOOK_URL"
  fi

  echo "$webhook_url"
}

# get_starforge_alerts_webhook - Get webhook for system-level alerts
# Usage: get_starforge_alerts_webhook
# Returns: Discord webhook URL for #starforge-alerts channel
get_starforge_alerts_webhook() {
  echo "${DISCORD_WEBHOOK_STARFORGE_ALERTS:-$DISCORD_WEBHOOK_URL}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Notification Sender
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# send_discord_daemon_notification - Send a Discord embed notification
# Usage: send_discord_daemon_notification "agent" "title" "description" COLOR_CODE "fields_json"
# Example:
#   send_discord_daemon_notification "qa-engineer" "Agent Started" "Processing PR #161" $COLOR_INFO '[{"name":"Ticket","value":"#161","inline":true}]'
send_discord_daemon_notification() {
  local agent=$1
  local title=$2
  local description=$3
  local color=$4
  local fields=${5:-[]}

  # Get webhook URL for this agent
  local webhook_url=$(get_webhook_for_agent "$agent")

  # Skip if no webhook configured
  if [ -z "$webhook_url" ]; then
    return 0
  fi

  # Timestamp in ISO 8601 format
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build JSON payload with Discord embed format
  local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "fields": $fields,
    "timestamp": "$timestamp",
    "footer": {"text": "StarForge Daemon"}
  }]
}
EOF
)

  # Send asynchronously to avoid blocking daemon
  curl -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    > /dev/null 2>&1 &
}

# send_discord_system_notification - Send system-level notification to #starforge-alerts
# Usage: send_discord_system_notification "title" "description" COLOR_CODE "fields_json"
send_discord_system_notification() {
  local title=$1
  local description=$2
  local color=$3
  local fields=${4:-[]}

  # Get starforge-alerts webhook
  local webhook_url=$(get_starforge_alerts_webhook)

  # Skip if no webhook configured
  if [ -z "$webhook_url" ]; then
    return 0
  fi

  # Timestamp in ISO 8601 format
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build JSON payload
  local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "$title",
    "description": "$description",
    "color": $color,
    "fields": $fields,
    "timestamp": "$timestamp",
    "footer": {"text": "StarForge System"}
  }]
}
EOF
)

  # Send asynchronously
  curl -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    > /dev/null 2>&1 &
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agent Lifecycle Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# send_agent_start_notification - Notify when agent starts work
# Usage: send_agent_start_notification "qa-engineer" "161" "review_pr"
send_agent_start_notification() {
  local agent=$1
  local ticket=${2:-"N/A"}
  local action=${3:-"unknown"}

  local fields='[{"name":"Ticket","value":"'"$ticket"'","inline":true},{"name":"Action","value":"'"$action"'","inline":true}]'

  send_discord_daemon_notification \
    "$agent" \
    "🚀 Agent Started" \
    "**$agent** is now working" \
    "$COLOR_INFO" \
    "$fields"
}

# send_agent_complete_notification - Notify when agent completes work
# Usage: send_agent_complete_notification "qa-engineer" "161" "Successfully reviewed PR"
send_agent_complete_notification() {
  local agent=$1
  local ticket=${2:-"N/A"}
  local summary=${3:-"Work completed"}

  local fields='[{"name":"Ticket","value":"'"$ticket"'","inline":true}]'

  send_discord_daemon_notification \
    "$agent" \
    "✅ Agent Completed" \
    "**$agent** finished: $summary" \
    "$COLOR_SUCCESS" \
    "$fields"
}

# send_agent_error_notification - Notify when agent encounters error
# Usage: send_agent_error_notification "qa-engineer" "161" "Failed to fetch PR details"
send_agent_error_notification() {
  local agent=$1
  local ticket=${2:-"N/A"}
  local error_msg=${3:-"Unknown error"}

  local fields='[{"name":"Ticket","value":"'"$ticket"'","inline":true}]'

  send_discord_daemon_notification \
    "$agent" \
    "❌ Agent Failed" \
    "**$agent** encountered an error: $error_msg" \
    "$COLOR_ERROR" \
    "$fields"
}

# send_agent_timeout_notification - Notify when agent times out
# Usage: send_agent_timeout_notification "qa-engineer" "161" "Timeout after 30 minutes"
send_agent_timeout_notification() {
  local agent=$1
  local ticket=${2:-"N/A"}
  local timeout_msg=${3:-"Agent timed out"}

  local fields='[{"name":"Ticket","value":"'"$ticket"'","inline":true}]'

  send_discord_daemon_notification \
    "$agent" \
    "⏰ Agent Timeout" \
    "**$agent** timed out: $timeout_msg" \
    "$COLOR_WARNING" \
    "$fields"
}

# send_agent_progress_notification - Notify agent still working (every 5 min)
# Usage: send_agent_progress_notification "qa-engineer" "161" "Running tests..."
send_agent_progress_notification() {
  local agent=$1
  local ticket=${2:-"N/A"}
  local progress_msg=${3:-"Still working..."}

  local fields='[{"name":"Ticket","value":"'"$ticket"'","inline":true}]'

  send_discord_daemon_notification \
    "$agent" \
    "⏳ Agent Progress" \
    "**$agent** is still working: $progress_msg" \
    "$COLOR_INFO" \
    "$fields"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# System Alert Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# send_trigger_invalid_notification - Notify when trigger is rejected (human visibility)
# Usage: send_trigger_invalid_notification "qa-engineer-review_pr-123.trigger" "Missing required field: to_agent"
send_trigger_invalid_notification() {
  local trigger_file=$1
  local validation_error=$2

  local fields='[{"name":"File","value":"'"$trigger_file"'","inline":false},{"name":"Error","value":"'"$validation_error"'","inline":false}]'

  send_discord_system_notification \
    "🚫 Invalid Trigger Rejected" \
    "The daemon rejected a malformed trigger file" \
    "$COLOR_ERROR" \
    "$fields"
}

# send_daemon_start_notification - Notify when daemon starts (optional)
# Usage: send_daemon_start_notification
send_daemon_start_notification() {
  send_discord_system_notification \
    "🟢 Daemon Started" \
    "StarForge daemon is now running" \
    "$COLOR_SUCCESS" \
    '[]'
}

# send_daemon_stop_notification - Notify when daemon stops (optional)
# Usage: send_daemon_stop_notification
send_daemon_stop_notification() {
  send_discord_system_notification \
    "🔴 Daemon Stopped" \
    "StarForge daemon has shut down" \
    "$COLOR_WARNING" \
    '[]'
}
