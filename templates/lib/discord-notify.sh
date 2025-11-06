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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Rate Limiting
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# check_rate_limit <webhook_url>
#
# Enforces Discord's 5 requests per 2 seconds limit per webhook.
# Returns 0 if safe to send, 1 if rate limited.
#
check_rate_limit() {
  local webhook_url=$1

  # Hash webhook URL for filename (last 10 chars for uniqueness)
  local webhook_hash=$(echo -n "$webhook_url" | md5sum 2>/dev/null | cut -c1-10 || echo "default")
  local rate_limit_file="/tmp/discord-rate-limit-${webhook_hash}.log"

  # Get current timestamp
  local now=$(date +%s)

  # Create rate limit file if doesn't exist
  touch "$rate_limit_file" 2>/dev/null || return 0  # Skip rate limiting if can't create file

  # Remove timestamps older than 2 seconds
  if [ -f "$rate_limit_file" ]; then
    local cutoff=$((now - 2))
    awk -v cutoff="$cutoff" '$1 > cutoff' "$rate_limit_file" > "${rate_limit_file}.tmp" 2>/dev/null || true
    mv "${rate_limit_file}.tmp" "$rate_limit_file" 2>/dev/null || true
  fi

  # Count recent requests
  local recent_count=$(wc -l < "$rate_limit_file" 2>/dev/null || echo "0")

  # If 5 or more requests in last 2 seconds, rate limit
  if [ "$recent_count" -ge 5 ]; then
    return 1
  fi

  # Record this request
  echo "$now" >> "$rate_limit_file"
  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Webhook Routing
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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
# send_discord_daemon_notification <agent> <title> <description> <color> <fields_json> <trace_id>
#
# Sends a Discord embed notification to the agent's dedicated channel.
#
# Args:
#   agent: Agent name (e.g., "junior-dev-a", "orchestrator")
#   title: Embed title (e.g., "🚀 Agent Started")
#   description: Embed description/main text
#   color: Decimal color code (use COLOR_* constants)
#   fields_json: JSON array of fields (e.g., '[{"name":"Ticket","value":"#123"}]')
#   trace_id: Trace ID for end-to-end tracking (optional, e.g., "TRACE-1234567890-a3f9b2")
#
# Example:
#   send_discord_daemon_notification \
#     "junior-dev-a" \
#     "✅ Agent Completed" \
#     "**junior-dev-a** finished successfully" \
#     "$COLOR_SUCCESS" \
#     '[{"name":"Duration","value":"5m 23s","inline":true}]' \
#     "TRACE-1234567890-a3f9b2"
#
send_discord_daemon_notification() {
  local agent=$1
  local title=$2
  local description=$3
  local color=$4
  local fields=$5
  local trace_id=${6:-""}

  # Get webhook URL for this agent
  local webhook_url=$(get_webhook_for_agent "$agent")

  # Silently skip if no webhook configured
  if [ -z "$webhook_url" ]; then
    return 0
  fi

  # Check rate limit (retry once if limited)
  if ! check_rate_limit "$webhook_url"; then
    sleep 1
    if ! check_rate_limit "$webhook_url"; then
      # Still rate limited - skip gracefully to avoid blocking daemon
      return 0
    fi
  fi

  # Generate ISO 8601 timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  # Always inject trace_id as first field
  local final_fields=$(echo "$fields" | jq --arg trace "$trace_id" '. = [{"name":"Trace ID","value":$trace,"inline":false}] + .')

  # Build JSON payload using jq to properly escape strings
  local payload=$(jq -n \
    --arg title "$title" \
    --arg description "$description" \
    --argjson color "$color" \
    --argjson fields "$final_fields" \
    --arg timestamp "$timestamp" \
    '{
      embeds: [{
        title: $title,
        description: $description,
        color: $color,
        fields: $fields,
        timestamp: $timestamp,
        footer: {
          text: "StarForge Daemon"
        }
      }]
    }'
  )

  # Send asynchronously to avoid blocking daemon
  # (Failures are silent - Discord notifications are optional)
  curl -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    > /dev/null 2>&1 &
}

#
# send_agent_start_notification <agent> <action> <from_agent> <ticket> <trace_id>
#
# Convenience wrapper for agent start notifications.
#
send_agent_start_notification() {
  local agent=$1
  local action=$2
  local from_agent=$3
  local ticket=${4:-N/A}
  local trace_id=${5:-""}

  send_discord_daemon_notification \
    "$agent" \
    "🚀 Agent Started" \
    "**$agent** is now working" \
    "$COLOR_INFO" \
    "[{\"name\":\"Action\",\"value\":\"$action\",\"inline\":true},{\"name\":\"From\",\"value\":\"$from_agent\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]" \
    "$trace_id"
}

#
# send_agent_progress_notification <agent> <elapsed_min> <ticket> <message> <pr_number> <pr_title> <pr_url>
#
# Convenience wrapper for agent progress notifications.
#
# Args:
#   agent: Agent name (e.g., "qa-engineer")
#   elapsed_min: Minutes elapsed since start
#   ticket: Ticket number (e.g., "310", optional defaults to "N/A")
#   message: Progress message (e.g., "Review PR #304: daemon fix", optional)
#   pr_number: PR number (e.g., "304", optional)
#   pr_title: PR title (e.g., "Add daemon monitoring", optional)
#   pr_url: PR URL (e.g., "https://github.com/user/repo/pull/304", optional)
#
send_agent_progress_notification() {
  local agent=$1
  local elapsed_min=$2
  local ticket=${3:-N/A}
  local message=${4:-}
  local pr_number=${5:-}
  local pr_title=${6:-}
  local pr_url=${7:-}

  # Build description with message if provided
  local description="**$agent** still working"
  if [ -n "$message" ]; then
    description="**$agent** still working

${message}"
  fi

  # Build fields array with proper JSON escaping
  local fields
  if [ -n "$pr_number" ] && [ -n "$pr_url" ]; then
    local pr_display="[#${pr_number}](${pr_url})"
    if [ -n "$pr_title" ]; then
      pr_display="${pr_display}: ${pr_title}"
    fi

    fields=$(jq -n \
      --arg elapsed "${elapsed_min}m" \
      --arg ticket "$ticket" \
      --arg pr_display "$pr_display" \
      '[
        {name: "Elapsed", value: $elapsed, inline: true},
        {name: "Ticket", value: $ticket, inline: true},
        {name: "PR", value: $pr_display, inline: false}
      ]')
  else
    fields=$(jq -n \
      --arg elapsed "${elapsed_min}m" \
      --arg ticket "$ticket" \
      '[
        {name: "Elapsed", value: $elapsed, inline: true},
        {name: "Ticket", value: $ticket, inline: true}
      ]')
  fi

  send_discord_daemon_notification \
    "$agent" \
    "⏳ Agent Progress" \
    "$description" \
    "$COLOR_WARNING" \
    "$fields"
}

#
# send_agent_complete_notification <agent> <duration_min> <duration_sec> <action> <ticket> <message> <pr> <trace_id>
#
# Convenience wrapper for agent completion notifications.
#
send_agent_complete_notification() {
  local agent=$1
  local duration_min=$2
  local duration_sec=$3
  local action=$4
  local ticket=${5:-N/A}
  local message=${6:-}
  local pr=${7:-}
  local trace_id=${8:-""}

  # Build description with optional PR link
  local description="**$agent** finished successfully"

  if [ -n "$message" ]; then
    description="${description}

${message}"
  fi

  if [ -n "$pr" ]; then
    # Extract repo info from git remote
    local repo_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    local pr_url=""

    if [ -n "$repo_url" ]; then
      # Convert git@github.com:user/repo.git to https://github.com/user/repo
      local github_url=$(echo "$repo_url" | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
      pr_url="${github_url}/pull/${pr}"
    fi

    if [ -n "$pr_url" ]; then
      description="${description}

PR: ${pr_url}"
    else
      description="${description}

PR: #${pr}"
    fi
  fi

  send_discord_daemon_notification \
    "$agent" \
    "✅ Agent Completed" \
    "$description" \
    "$COLOR_SUCCESS" \
    "[{\"name\":\"Duration\",\"value\":\"${duration_min}m ${duration_sec}s\",\"inline\":true},{\"name\":\"Action\",\"value\":\"$action\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]" \
    "$trace_id"
}

#
# send_agent_timeout_notification <agent> <action> <ticket> <trace_id>
#
# Convenience wrapper for agent timeout notifications.
#
send_agent_timeout_notification() {
  local agent=$1
  local action=$2
  local ticket=${3:-N/A}
  local trace_id=${4:-""}

  send_discord_daemon_notification \
    "$agent" \
    "⏰ Agent Timeout" \
    "**$agent** exceeded 30-minute limit" \
    "$COLOR_ERROR" \
    "[{\"name\":\"Action\",\"value\":\"$action\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]" \
    "$trace_id"
}

#
# send_agent_error_notification <agent> <exit_code> <duration_min> <ticket> <trace_id>
#
# Convenience wrapper for agent error notifications.
#
send_agent_error_notification() {
  local agent=$1
  local exit_code=$2
  local duration_min=$3
  local ticket=${4:-N/A}
  local trace_id=${5:-""}

  send_discord_daemon_notification \
    "$agent" \
    "❌ Agent Failed" \
    "**$agent** crashed with exit code $exit_code" \
    "$COLOR_ERROR" \
    "[{\"name\":\"Exit Code\",\"value\":\"$exit_code\",\"inline\":true},{\"name\":\"Duration\",\"value\":\"${duration_min}m\",\"inline\":true},{\"name\":\"Ticket\",\"value\":\"$ticket\",\"inline\":true}]" \
    "$trace_id"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# System Alert Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# get_starforge_alerts_webhook
#
# Returns the webhook URL for system-level alerts (#starforge-alerts channel).
# Falls back to generic webhook if not configured.
#
get_starforge_alerts_webhook() {
  echo "${DISCORD_WEBHOOK_STARFORGE_ALERTS:-$DISCORD_WEBHOOK_URL}"
}

#
# send_discord_system_notification <title> <description> <color> <fields_json>
#
# Sends a Discord embed notification to the #starforge-alerts channel.
# Used for system-level events (daemon start/stop, invalid triggers, etc.)
#
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

  # Check rate limit
  if ! check_rate_limit "$webhook_url"; then
    sleep 1
    if ! check_rate_limit "$webhook_url"; then
      return 0
    fi
  fi

  # Generate ISO 8601 timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  # Build JSON payload using jq to properly escape strings
  local payload=$(jq -n \
    --arg title "$title" \
    --arg description "$description" \
    --argjson color "$color" \
    --argjson fields "$fields" \
    --arg timestamp "$timestamp" \
    '{
      embeds: [{
        title: $title,
        description: $description,
        color: $color,
        fields: $fields,
        timestamp: $timestamp,
        footer: {
          text: "StarForge System"
        }
      }]
    }'
  )

  # Send asynchronously
  curl -X POST "$webhook_url" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    > /dev/null 2>&1 &
}

#
# send_daemon_start_notification
#
# Notify when daemon starts (optional - only if webhook configured).
#
send_daemon_start_notification() {
  send_discord_system_notification \
    "🟢 Daemon Started" \
    "StarForge daemon is now running" \
    "$COLOR_SUCCESS" \
    '[]'
}

#
# send_daemon_stop_notification
#
# Notify when daemon stops (optional - only if webhook configured).
#
send_daemon_stop_notification() {
  send_discord_system_notification \
    "🔴 Daemon Stopped" \
    "StarForge daemon has shut down" \
    "$COLOR_WARNING" \
    '[]'
}

#
# send_trigger_invalid_notification <trigger_file> <validation_error>
#
# Notify when trigger is rejected for human visibility.
#
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

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PR-Specific Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# send_pr_ready_notification <agent> <pr_number> <pr_title> <test_status> <coverage_change> <pr_url>
#
# Sends notification when PR is ready for review.
#
# Args:
#   agent: Agent name (e.g., "junior-dev-a")
#   pr_number: PR number (e.g., "200")
#   pr_title: PR title (e.g., "Add authentication feature")
#   test_status: Test status (e.g., "47/47")
#   coverage_change: Coverage change (e.g., "87% → 91%")
#   pr_url: PR URL (e.g., "https://github.com/user/repo/pull/200")
#
send_pr_ready_notification() {
  local agent=$1
  local pr_number=$2
  local pr_title=$3
  local test_status=$4
  local coverage_change=$5
  local pr_url=$6

  local description="Feature implemented (#${pr_number})
PR ready for review
✅ All tests passing (${test_status})
📊 Coverage: ${coverage_change}

👉 Review PR: ${pr_url}"

  local fields='[]'

  send_discord_daemon_notification \
    "$agent" \
    "🟢 PR Ready for Review" \
    "$description" \
    "$COLOR_SUCCESS" \
    "$fields"
}

#
# send_qa_approved_notification <agent> <pr_number> <validation_results> <merge_command>
#
# Sends notification when QA approves PR.
#
# Args:
#   agent: Agent name (e.g., "qa-engineer")
#   pr_number: PR number (e.g., "200")
#   validation_results: Validation summary (e.g., "Security: ✅  Performance: ✅  Tests: ✅")
#   merge_command: Command to merge (e.g., "gh pr merge 200 --squash")
#
send_qa_approved_notification() {
  local agent=$1
  local pr_number=$2
  local validation_results=$3
  local merge_command=$4

  local description="PR #${pr_number} approved for merge
No issues found
${validation_results}

👉 Merge: \`${merge_command}\`"

  local fields='[]'

  send_discord_daemon_notification \
    "$agent" \
    "✅ QA Approved" \
    "$description" \
    "$COLOR_SUCCESS" \
    "$fields"
}

#
# send_tests_failed_notification <agent> <pr_number> <error_message> <error_location> <logs_command>
#
# Sends notification when tests fail with @mention for urgent attention.
#
# Args:
#   agent: Agent name (e.g., "junior-dev-b")
#   pr_number: PR number (e.g., "201")
#   error_message: Error message (e.g., "TypeError: Cannot read property 'email' of undefined")
#   error_location: Error location (e.g., "at auth.ts:42:18")
#   logs_command: Command to view logs (e.g., "starforge logs junior-dev-b")
#
send_tests_failed_notification() {
  local agent=$1
  local pr_number=$2
  local error_message=$3
  local error_location=$4
  local logs_command=$5

  # Get user mention from config (if configured)
  local user_mention="${DISCORD_USER_ID:-}"
  local mention_text=""
  if [ -n "$user_mention" ]; then
    mention_text="${user_mention} - Need human review
"
  fi

  local description="Tests failing on PR #${pr_number}
\`\`\`
${error_message}
${error_location}
\`\`\`

${mention_text}👉 View logs: \`${logs_command}\`"

  local fields='[]'

  send_discord_daemon_notification \
    "$agent" \
    "❌ Tests Failed" \
    "$description" \
    "$COLOR_ERROR" \
    "$fields"
}

#
# send_feature_complete_notification <agent> <pr_count> <coverage_change> <time_elapsed> <merge_instructions>
#
# Sends notification when entire feature (multiple PRs) is complete.
#
# Args:
#   agent: Agent name (e.g., "orchestrator")
#   pr_count: Number of PRs (e.g., "3")
#   coverage_change: Coverage change (e.g., "87% → 93%")
#   time_elapsed: Time elapsed (e.g., "4h 23m")
#   merge_instructions: Instructions to merge (e.g., "Merge all PRs: gh pr merge 200 201 202 --squash")
#
send_feature_complete_notification() {
  local agent=$1
  local pr_count=$2
  local coverage_change=$3
  local time_elapsed=$4
  local merge_instructions=$5

  local description="All tickets completed
PRs ready: ${pr_count}
📊 Coverage: ${coverage_change}
⏱️  Time: ${time_elapsed}

👉 ${merge_instructions}"

  local fields='[]'

  send_discord_daemon_notification \
    "$agent" \
    "🎉 Feature Complete" \
    "$description" \
    "$COLOR_SUCCESS" \
    "$fields"
}

#
# send_dlq_alert <trigger_filename> <agent> <trace_id> <failure_reason> <exit_code>
#
# Sends alert when trigger moves to dead letter queue after 3 failed attempts.
# Includes @mention if DISCORD_USER_ID is configured.
#
# Args:
#   trigger_filename: Name of trigger file (e.g., "agent-action-123.trigger")
#   agent: Agent name that failed (e.g., "junior-dev-a")
#   trace_id: Unique trace ID for this trigger
#   failure_reason: Human-readable failure description
#   exit_code: Last exit code from agent invocation
#
send_dlq_alert() {
  local trigger_filename=$1
  local agent=$2
  local trace_id=$3
  local failure_reason=$4
  local exit_code=$5

  # Build mention string if user ID configured
  local mention=""
  if [ -n "$DISCORD_USER_ID" ]; then
    mention="<@${DISCORD_USER_ID}> "
  fi

  local description="${mention}⚠️ Trigger failed 3 times and moved to dead letter queue

**Trigger:** \`${trigger_filename}\`
**Agent:** ${agent}
**Exit Code:** ${exit_code}
**Reason:** ${failure_reason}

**Recovery:**
\`\`\`bash
starforge dlq retry ${trigger_filename}
\`\`\`

**View all DLQ triggers:**
\`\`\`bash
starforge dlq list
\`\`\`"

  local fields=$(cat << FIELDS_JSON
[
  {"name": "Trace ID", "value": "${trace_id}", "inline": false},
  {"name": "Status", "value": "⏸️ Paused (in DLQ)", "inline": true},
  {"name": "Manual Action Required", "value": "Review and retry manually", "inline": true}
]
FIELDS_JSON
)

  send_discord_daemon_notification \
    "$agent" \
    "💀 Dead Letter Queue Alert" \
    "$description" \
    "$COLOR_ERROR" \
    "$fields" \
    "$trace_id"
}
