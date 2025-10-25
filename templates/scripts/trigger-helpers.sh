#!/bin/bash
# Helper functions for creating trigger files
# Purpose: Eliminate permission prompts from piped trigger commands
# Workaround for: https://github.com/anthropics/claude-code/issues/5465

# Source project environment detection
# Try current directory first, then fallback to main repo
if [ -f ".claude/lib/project-env.sh" ]; then
  source .claude/lib/project-env.sh
elif [ -f ".claude/scripts/worktree-helpers.sh" ]; then
  # Use worktree helper instead of piped command
  source .claude/scripts/worktree-helpers.sh
  MAIN_REPO=$(get_main_repo_path)
  source "$MAIN_REPO/.claude/lib/project-env.sh"
else
  echo "ERROR: project-env.sh not found. Run 'starforge install' first."
  exit 1
fi

# Use environment variables from project-env.sh
TRIGGER_DIR="$STARFORGE_CLAUDE_DIR/triggers"
LOG_FILE="$STARFORGE_CLAUDE_DIR/trigger-history.log"

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

# ============================================================================
# VALIDATION FUNCTIONS (Used by QA Engineer - Level 4 Verification)
# ============================================================================

# Find latest trigger file for an agent/action
# Replaces: ls -t $STARFORGE_CLAUDE_DIR/triggers/orchestrator-assign_next_work-*.trigger 2>/dev/null | head -1
get_latest_trigger_file() {
  local agent=${1:-"orchestrator"}
  local action=${2:-"assign_next_work"}

  ls -t "$STARFORGE_CLAUDE_DIR/triggers/${agent}-${action}-"*.trigger 2>/dev/null | head -1
}

# Verify trigger file exists
verify_trigger_exists() {
  local trigger_file=$1

  if [ ! -f "$trigger_file" ]; then
    echo "❌ CRITICAL: Trigger file not found: $trigger_file"
    return 1
  fi

  echo "✅ Trigger file exists: $trigger_file"
  return 0
}

# Verify trigger is valid JSON
verify_trigger_json() {
  local trigger_file=$1

  if [ ! -f "$trigger_file" ]; then
    echo "❌ Trigger file not found"
    return 1
  fi

  jq empty "$trigger_file" 2>/dev/null

  if [ $? -ne 0 ]; then
    echo "❌ TRIGGER INVALID JSON"
    cat "$trigger_file"
    return 1
  fi

  echo "✅ Trigger is valid JSON"
  return 0
}

# Extract field from trigger (using jq)
# Replaces: jq -r '.to_agent' "$TRIGGER_FILE"
get_trigger_field() {
  local trigger_file=$1
  local field=$2

  if [ ! -f "$trigger_file" ]; then
    echo "❌ Trigger file not found"
    return 1
  fi

  jq -r ".$field" "$trigger_file" 2>/dev/null
}

# Verify trigger has required fields
verify_trigger_fields() {
  local trigger_file=$1
  local expected_to_agent=$2
  local expected_action=$3

  if [ ! -f "$trigger_file" ]; then
    echo "❌ Trigger file not found"
    return 1
  fi

  local to_agent=$(get_trigger_field "$trigger_file" "to_agent")
  local action=$(get_trigger_field "$trigger_file" "action")

  if [ "$to_agent" != "$expected_to_agent" ]; then
    echo "❌ TRIGGER INCORRECT to_agent: expected '$expected_to_agent', got '$to_agent'"
    return 1
  fi

  if [ "$action" != "$expected_action" ]; then
    echo "❌ TRIGGER INCORRECT action: expected '$expected_action', got '$action'"
    return 1
  fi

  echo "✅ Trigger fields correct: to_agent=$to_agent, action=$action"
  return 0
}

# Verify trigger data integrity (Level 4 check)
# Ensures count matches array length
verify_trigger_data_integrity() {
  local trigger_file=$1
  local count_field=${2:-"context.count"}
  local array_field=${3:-"context.completed_tickets"}

  if [ ! -f "$trigger_file" ]; then
    echo "❌ Trigger file not found"
    return 1
  fi

  local count=$(jq -r ".$count_field" "$trigger_file" 2>/dev/null)
  local array_length=$(jq -r ".$array_field | length" "$trigger_file" 2>/dev/null)

  if [ "$count" != "$array_length" ]; then
    echo "❌ TRIGGER DATA INTEGRITY FAILED"
    echo "   Count ($count_field): $count"
    echo "   Array length ($array_field): $array_length"
    return 1
  fi

  echo "✅ Trigger data integrity verified: count=$count, array_length=$array_length"
  return 0
}

# Full trigger verification (all checks)
# Used by QA engineer after approval
verify_trigger_complete() {
  local trigger_file=$1
  local expected_to_agent=$2
  local expected_action=$3

  echo ""
  echo "🔍 Verifying trigger: $trigger_file"
  echo ""

  # Check 1: File exists
  verify_trigger_exists "$trigger_file" || return 1

  # Small delay for filesystem sync
  sleep 1

  # Check 2: Valid JSON
  verify_trigger_json "$trigger_file" || return 1

  # Check 3: Required fields
  verify_trigger_fields "$trigger_file" "$expected_to_agent" "$expected_action" || return 1

  # Check 4: Data integrity (if applicable)
  if [[ "$expected_action" == "assign_next_work" ]]; then
    verify_trigger_data_integrity "$trigger_file" "context.count" "context.completed_tickets" || return 1
  fi

  echo ""
  echo "✅ TRIGGER VERIFICATION COMPLETE"
  echo ""

  return 0
}

# Count pending triggers for an agent
count_pending_triggers() {
  local agent=$1

  if [ -z "$agent" ]; then
    echo "0"
    return 0
  fi

  local count=$(ls "$STARFORGE_CLAUDE_DIR/triggers/${agent}-"*.trigger 2>/dev/null | wc -l | tr -d ' ')

  echo "$count"
}

# List all pending triggers
list_pending_triggers() {
  ls -t "$STARFORGE_CLAUDE_DIR/triggers/"*.trigger 2>/dev/null
}

# Move trigger to processed (after completion)
archive_trigger() {
  local trigger_file=$1

  if [ ! -f "$trigger_file" ]; then
    echo "❌ Trigger file not found"
    return 1
  fi

  mv "$trigger_file" "$TRIGGER_DIR/processed/" 2>/dev/null

  if [ $? -eq 0 ]; then
    echo "✅ Trigger archived: $(basename $trigger_file)"
    return 0
  else
    echo "❌ Failed to archive trigger"
    return 1
  fi
}