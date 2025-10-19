#!/bin/bash
# Helper functions for creating trigger files

# Auto-detect main repo (works in worktrees)
MAIN_REPO=$(git worktree list --porcelain | grep "^worktree" | head -1 | cut -d' ' -f2)
if [ -z "$MAIN_REPO" ]; then
  # Fallback if git worktree not available
  MAIN_REPO=$(pwd)
fi
TRIGGER_DIR="$MAIN_REPO/.claude/triggers"
LOG_FILE="$MAIN_REPO/.claude/trigger-history.log"

# Ensure trigger directory exists
mkdir -p "$TRIGGER_DIR"
mkdir -p "$TRIGGER_DIR/processed"

# Generic trigger creation
create_trigger() {
  local from_agent=$1
  local to_agent=$2
  local action=$3
  local message=$4
  local command=$5
  shift 5
  local context="$@"
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local trigger_file="$TRIGGER_DIR/${to_agent}-${action}-$(date +%s).trigger"
  
  cat > "$trigger_file" << TRIGGER
{
  "from_agent": "$from_agent",
  "to_agent": "$to_agent",
  "action": "$action",
  "context": $context,
  "timestamp": "$timestamp",
  "message": "$message",
  "command": "$command"
}
TRIGGER
  
  echo "✅ Trigger created: $trigger_file"
  
  # 🔔 SEND macOS NOTIFICATION
  if command -v terminal-notifier &> /dev/null; then
    terminal-notifier -title "🤖 $from_agent → $to_agent" -subtitle "Action: $action" -message "$message" -sender com.googlecode.iterm2 2>/dev/null || true
    # Play sound separately (terminal-notifier sound doesn't work with -sender)
    afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
  elif command -v osascript &> /dev/null; then
    osascript -e "display notification \"$message\" with title \"🤖 $from_agent → $to_agent\" subtitle \"Action: $action\" sound name \"Ping\"" 2>/dev/null || true
  fi
  
  # 📝 LOG TO HISTORY
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $from_agent → $to_agent | $action | $message" >> "$LOG_FILE"
  
  # Terminal visual alert
  echo -e "\033[1;33m⚡ HANDOFF TRIGGERED\033[0m"
  echo -e "\033[1;36m🤖 $from_agent → $to_agent\033[0m"
  echo -e "\033[1;32m📋 $message\033[0m"
}

# Orchestrator: Trigger junior-dev assignment
trigger_junior_dev() {
  local agent_id=$1  # junior-dev-a, junior-dev-b, or junior-dev-c
  local ticket=$2
  
  create_trigger \
    "orchestrator" \
    "$agent_id" \
    "implement_ticket" \
    "Ticket #$ticket assigned to $agent_id" \
    "Use junior-engineer. I am $agent_id." \
    "{\"ticket\": $ticket}"
}

# Junior-dev: Trigger QA review
trigger_qa_review() {
  local agent_id=$1  # who is creating the trigger
  local pr_number=$2
  local ticket=$3
  
  create_trigger \
    "$agent_id" \
    "qa-engineer" \
    "review_pr" \
    "PR #$pr_number ready for review (ticket #$ticket)" \
    "Use qa-engineer. Review PR #$pr_number." \
    "{\"pr\": $pr_number, \"ticket\": $ticket}"
}

# QA: Trigger orchestrator for next assignment
trigger_next_assignment() {
  local completed_count=$1
  local completed_tickets=$2  # JSON array like "[42,43,44]"
  
  create_trigger \
    "qa-engineer" \
    "orchestrator" \
    "assign_next_work" \
    "$completed_count tickets completed. Assign next batch." \
    "Use orchestrator. Assign next available tickets." \
    "{\"completed_tickets\": $completed_tickets, \"count\": $completed_count}"
}

# TPM: Trigger orchestrator after tickets created
trigger_work_ready() {
  local ticket_count=$1
  local ticket_list=$2  # JSON array like "[42,43,44,45,46]"
  
  create_trigger \
    "tpm" \
    "orchestrator" \
    "assign_tickets" \
    "$ticket_count new tickets ready for assignment" \
    "Use orchestrator. Assign next available tickets." \
    "{\"tickets\": $ticket_list, \"count\": $ticket_count}"
}

# Senior-engineer: Trigger TPM after breakdown
trigger_create_tickets() {
  local feature_name=$1
  local subtask_count=$2
  local breakdown_file=$3
  
  create_trigger \
    "senior-engineer" \
    "tpm" \
    "create_tickets" \
    "$subtask_count subtasks ready for $feature_name" \
    "Use tpm. Create GitHub issues from senior-engineer's breakdown." \
    "{\"feature\": \"$feature_name\", \"subtasks\": $subtask_count, \"breakdown\": \"$breakdown_file\"}"
}