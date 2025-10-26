#!/bin/bash
# StarForge Trigger Router Library
# Routes trigger files to agent queues
# Part of queue system implementation

# Source discord-notify.sh for notification functions
# (Tests may mock these functions, so check if already loaded)
if [ -z "$(type -t send_discord_daemon_notification 2>/dev/null)" ]; then
    # Try to source discord-notify.sh from multiple possible locations
    if [ -f "$(dirname "${BASH_SOURCE[0]}")/discord-notify.sh" ]; then
        source "$(dirname "${BASH_SOURCE[0]}")/discord-notify.sh"
    elif [ -f ".claude/lib/discord-notify.sh" ]; then
        source .claude/lib/discord-notify.sh
    elif [ -f "templates/lib/discord-notify.sh" ]; then
        source templates/lib/discord-notify.sh
    fi
fi

# Source logger if available (tests provide their own)
if [ -z "$(type -t log_info 2>/dev/null)" ]; then
    # Fallback logger functions
    log_info() {
        local component="$1"
        local message="$2"
        echo "[$(date -Iseconds)] [INFO] [$component] $message" >> .claude/router.log
    }

    log_error() {
        local component="$1"
        local message="$2"
        echo "[$(date -Iseconds)] [ERROR] [$component] $message" >> .claude/router.log
    }

    log_warn() {
        local component="$1"
        local message="$2"
        echo "[$(date -Iseconds)] [WARN] [$component] $message" >> .claude/router.log
    }
fi

# Route trigger file to queue
# Args:
#   $1 - Path to trigger file
# Returns:
#   0 on success, 1 on failure
route_trigger_to_queue() {
    local trigger_file="$1"

    if [ -z "$trigger_file" ]; then
        log_error "router" "No trigger file specified"
        return 1
    fi

    if [ ! -f "$trigger_file" ]; then
        log_error "router" "Trigger file not found: $trigger_file"
        return 1
    fi

    # Validate JSON
    if ! jq empty "$trigger_file" 2>/dev/null; then
        log_error "router" "Invalid JSON in trigger file: $trigger_file"
        # Move to invalid directory
        local invalid_dir=".claude/triggers/invalid"
        mkdir -p "$invalid_dir"
        mv "$trigger_file" "$invalid_dir/" 2>/dev/null
        return 1
    fi

    # Extract fields from trigger
    local agent=$(jq -r '.to_agent' "$trigger_file" 2>/dev/null)
    local action=$(jq -r '.action' "$trigger_file" 2>/dev/null)
    local context=$(jq -c '.context' "$trigger_file" 2>/dev/null)

    # Validate required fields
    if [ -z "$agent" ] || [ "$agent" = "null" ]; then
        log_error "router" "Missing 'to_agent' field in trigger: $trigger_file"
        local invalid_dir=".claude/triggers/invalid"
        mkdir -p "$invalid_dir"
        mv "$trigger_file" "$invalid_dir/" 2>/dev/null
        return 1
    fi

    if [ -z "$action" ] || [ "$action" = "null" ]; then
        log_error "router" "Missing 'action' field in trigger: $trigger_file"
        local invalid_dir=".claude/triggers/invalid"
        mkdir -p "$invalid_dir"
        mv "$trigger_file" "$invalid_dir/" 2>/dev/null
        return 1
    fi

    # Set default context if missing
    if [ -z "$context" ] || [ "$context" = "null" ]; then
        context="{}"
    fi

    # Create task ID (timestamp-based for FIFO ordering)
    # Use nanoseconds for uniqueness within same second
    local timestamp=$(date +%s)
    local random_suffix=$(( RANDOM % 10000 ))
    local task_id="task-${timestamp}-${random_suffix}"

    # Ensure queue directory exists
    local queue_dir=".claude/queues/$agent/pending"
    mkdir -p "$queue_dir"

    # Create task file
    local task_file="$queue_dir/$task_id.json"

    cat > "$task_file" <<EOF
{
  "id": "$task_id",
  "agent": "$agent",
  "action": "$action",
  "context": $context,
  "created_at": "$(date -Iseconds)",
  "priority": "normal",
  "retry_count": 0,
  "source_trigger": "$trigger_file"
}
EOF

    # Validate created task file
    if ! jq empty "$task_file" 2>/dev/null; then
        log_error "router" "Failed to create valid task file: $task_file"
        rm -f "$task_file"
        return 1
    fi

    # Archive original trigger
    local processed_dir=".claude/triggers/processed"
    mkdir -p "$processed_dir"

    # Use basename to avoid path issues
    local trigger_basename=$(basename "$trigger_file")
    mv "$trigger_file" "$processed_dir/$trigger_basename" 2>/dev/null

    # Log success
    log_info "router" "Routed $action to $agent queue (task: $task_id)"

    return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agent Blocked Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# notify_agent_blocked <agent> <question> <ticket>
#
# Sends Discord notification with @mention when agent needs human input.
# This triggers push notification with sound on user's mobile device.
#
# Args:
#   agent: Agent name (e.g., "junior-dev-a")
#   question: Question/ambiguity encountered (max 200 chars)
#   ticket: Ticket number (e.g., "42")
#
# Example:
#   notify_agent_blocked "junior-dev-a" "Should I use REST or GraphQL?" "42"
#
notify_agent_blocked() {
    local agent=$1
    local question=$2
    local ticket=$3

    # Validate inputs
    if [ -z "$agent" ]; then
        log_error "router" "notify_agent_blocked: agent required"
        return 1
    fi

    if [ -z "$question" ]; then
        question="Agent is blocked, check logs"
    fi

    if [ -z "$ticket" ]; then
        ticket="N/A"
    fi

    # Truncate question to 200 chars
    if [ ${#question} -gt 200 ]; then
        question="${question:0:197}..."
    fi

    # Escape special characters for JSON
    question=$(echo "$question" | sed 's/"/\\"/g' | sed "s/'/\\'/g")

    # Build description with @mention if DISCORD_USER_ID set
    local description
    if [ -n "$DISCORD_USER_ID" ]; then
        description="<@${DISCORD_USER_ID}> - Agent needs input

**Agent:** $agent
**Question:** $question
**Ticket:** #$ticket

**Action:** Run \`starforge use $agent\` to continue or reply in this thread."
    else
        description="**Agent:** $agent
**Question:** $question
**Ticket:** #$ticket

**Action:** Run \`starforge use $agent\` to continue or reply in this thread."
    fi

    # Build fields JSON
    local fields='[
  {"name":"Question","value":"'"$question"'","inline":false},
  {"name":"Ticket","value":"#'"$ticket"'","inline":true},
  {"name":"Action","value":"Run `starforge use '"$agent"'` to continue","inline":true}
]'

    # Send notification with warning color (yellow)
    send_discord_daemon_notification \
        "$agent" \
        "⚠️ Agent Blocked - Human Input Needed" \
        "$description" \
        "$COLOR_WARNING" \
        "$fields"

    log_info "router" "Agent $agent blocked notification sent (ticket: $ticket)"
}

# Export function for use in other scripts
export -f notify_agent_blocked

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# QA Review Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# notify_qa_approved <pr_number> <pr_url>
#
# Sends Discord notification when QA approves PR.
# Uses green color (COLOR_SUCCESS).
#
# Args:
#   pr_number: PR number (e.g., "167")
#   pr_url: Full PR URL (e.g., "https://github.com/user/repo/pull/167")
#
# Example:
#   notify_qa_approved "167" "https://github.com/user/repo/pull/167"
#
notify_qa_approved() {
    local pr_number="$1"
    local pr_url="$2"

    # Validate inputs
    if [ -z "$pr_number" ] || [ -z "$pr_url" ]; then
        log_warn "router" "notify_qa_approved: Missing required arguments"
        return 1
    fi

    # Build notification description
    local description="PR #${pr_number} approved for merge
✅ All quality gates passed
✅ Ready to merge

👉 View PR: ${pr_url}"

    # Send notification to qa-engineer channel
    send_discord_daemon_notification \
        "qa-engineer" \
        "✅ QA Approved" \
        "$description" \
        "$COLOR_SUCCESS" \
        '[]'

    log_info "router" "Sent QA approved notification for PR #${pr_number}"
    return 0
}

#
# notify_qa_rejected <pr_number> <pr_url> <feedback>
#
# Sends Discord notification when QA requests changes on PR.
# Uses yellow color (COLOR_WARNING).
# Truncates feedback to 200 chars to keep notification concise.
#
# Args:
#   pr_number: PR number (e.g., "167")
#   pr_url: Full PR URL (e.g., "https://github.com/user/repo/pull/167")
#   feedback: QA feedback/issues (will be truncated to 200 chars)
#
# Example:
#   notify_qa_rejected "167" "https://github.com/user/repo/pull/167" "Please add integration tests"
#
notify_qa_rejected() {
    local pr_number="$1"
    local pr_url="$2"
    local feedback="$3"

    # Validate inputs
    if [ -z "$pr_number" ] || [ -z "$pr_url" ]; then
        log_warn "router" "notify_qa_rejected: Missing required arguments"
        return 1
    fi

    # Handle empty feedback
    if [ -z "$feedback" ]; then
        feedback="No feedback provided"
    fi

    # Truncate feedback to 200 chars
    if [ ${#feedback} -gt 200 ]; then
        feedback="${feedback:0:200}..."
    fi

    # Build notification description
    local description="PR #${pr_number} needs changes
❌ QA requested changes

**Feedback:**
${feedback}

👉 View PR: ${pr_url}"

    # Send notification to qa-engineer channel
    send_discord_daemon_notification \
        "qa-engineer" \
        "⚠️ QA Changes Requested" \
        "$description" \
        "$COLOR_WARNING" \
        '[]'

    log_info "router" "Sent QA rejected notification for PR #${pr_number}"
    return 0
}

#
# notify_pr_created <pr_number> <pr_url> <ticket> <agent>
#
# Sends Discord notification when PR is created and ready for review.
#
# Args:
#   pr_number: PR number (e.g., "167")
#   pr_url: Full PR URL (e.g., "https://github.com/user/repo/pull/167")
#   ticket: Ticket number (e.g., "42")
#   agent: Agent name (e.g., "junior-dev-a")
#
# Example:
#   notify_pr_created "167" "https://github.com/user/repo/pull/167" "42" "junior-dev-a"
#
notify_pr_created() {
    local pr_number=$1
    local pr_url=$2
    local ticket=$3
    local agent=$4

    # Skip notification if send_discord_daemon_notification not available
    if ! type send_discord_daemon_notification &>/dev/null; then
        return 0
    fi

    # Skip notification if PR number empty (log warning)
    if [ -z "$pr_number" ]; then
        log_warn "router" "notify_pr_created: Empty PR number, skipping notification"
        return 0
    fi

    # Build title
    local title="📋 PR Ready for Review"

    # Build description with clickable PR link
    local description="**${agent}** opened [PR #${pr_number}](${pr_url})"

    # Use COLOR_INFO (blue) - defined in discord-notify.sh
    local color="${COLOR_INFO:-3447003}"

    # Build fields JSON array with Ticket and PR
    local fields="[{\"name\":\"Ticket\",\"value\":\"#${ticket}\",\"inline\":true},{\"name\":\"PR\",\"value\":\"#${pr_number}\",\"inline\":true}]"

    # Send notification via discord-notify.sh
    send_discord_daemon_notification \
        "$agent" \
        "$title" \
        "$description" \
        "$color" \
        "$fields"
}

# Export functions for use in other scripts
export -f notify_qa_approved
export -f notify_qa_rejected
export -f notify_pr_created

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CI Test Failure Notifications
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#
# notify_tests_failed <pr_number> <test_name> <error_message> <logs_url>
#
# Sends Discord notification when CI tests fail on a PR.
# Used by GitHub Actions workflows to alert when tests fail.
#
# Args:
#   pr_number: PR number (e.g., "201")
#   test_name: Name of failed test (e.g., "test-router")
#   error_message: Error message (will be truncated to 500 chars)
#   logs_url: URL to CI logs (e.g., GitHub Actions run URL)
#
# Example:
#   notify_tests_failed "201" "test-router" "AssertionError: Expected 0, got 1" "https://github.com/..."
#
notify_tests_failed() {
    local pr_number=$1
    local test_name=$2
    local error_message=$3
    local logs_url=$4

    # Validate inputs
    if [ -z "$pr_number" ]; then
        log_error "router" "notify_tests_failed: pr_number required"
        return 1
    fi

    if [ -z "$test_name" ]; then
        test_name="Unknown test"
    fi

    if [ -z "$error_message" ]; then
        error_message="Test failed (see logs for details)"
    fi

    # Truncate error message to 500 chars
    if [ ${#error_message} -gt 500 ]; then
        error_message="${error_message:0:497}...

(see full logs for complete error)"
    fi

    # Escape special characters for JSON
    error_message=$(echo "$error_message" | sed 's/"/\\"/g')
    test_name=$(echo "$test_name" | sed 's/"/\\"/g')

    # Build description
    local description="Tests failing on PR #${pr_number}

**Failed Test:** ${test_name}

**Error:**
\`\`\`
${error_message}
\`\`\`"

    # Add logs link if provided
    if [ -n "$logs_url" ]; then
        description="${description}

👉 [View Full CI Logs](${logs_url})"
    fi

    # Build fields JSON
    local fields='[
  {"name":"PR Number","value":"#'"$pr_number"'","inline":true},
  {"name":"Failed Test","value":"'"$test_name"'","inline":true}
]'

    # Send notification to starforge-alerts channel with error color (red)
    # This uses send_discord_system_notification for system-level alerts
    if [ -n "$(type -t send_discord_system_notification 2>/dev/null)" ]; then
        send_discord_system_notification \
            "❌ CI Tests Failed" \
            "$description" \
            "$COLOR_ERROR" \
            "$fields"
    else
        log_warn "router" "Discord notification functions not available"
    fi

    log_info "router" "Test failure notification sent for PR #$pr_number (test: $test_name)"
}

# Export function for use in other scripts
export -f notify_tests_failed
