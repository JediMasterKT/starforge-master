#!/bin/bash
# Compensation Transactions (Saga Pattern)
# Provides rollback capabilities for multi-step operations

# Global array to track compensation actions (LIFO stack)
declare -a COMPENSATION_STACK=()

# Compensation log file
COMPENSATION_LOG="${STARFORGE_CLAUDE_DIR:-.claude}/logs/compensation.log"
mkdir -p "$(dirname "$COMPENSATION_LOG")"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Compensation Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Register a compensation action
# Usage: register_compensation "description" "rollback_command"
# Example: register_compensation "GitHub label update" "gh issue edit 42 --remove-label in-progress --add-label ready"
register_compensation() {
  local description="$1"
  local rollback_cmd="$2"

  if [ -z "$description" ] || [ -z "$rollback_cmd" ]; then
    echo "ERROR: register_compensation requires description and command" >&2
    return 1
  fi

  # Add to compensation stack (format: "description|||command")
  COMPENSATION_STACK+=("$description|||$rollback_cmd")
}

# Execute all registered compensations in reverse order (LIFO)
# Usage: execute_compensations "failure_reason"
execute_compensations() {
  local reason="${1:-Unknown failure}"

  if [ ${#COMPENSATION_STACK[@]} -eq 0 ]; then
    echo "No compensations to execute"
    return 0
  fi

  echo ""
  echo "🔄 ROLLING BACK ASSIGNMENT (reason: $reason)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Log rollback start
  log_compensation_event "ROLLBACK_START" "$reason" "${#COMPENSATION_STACK[@]} actions"

  local success_count=0
  local fail_count=0

  # Execute in reverse order (LIFO - Last In First Out)
  for ((i=${#COMPENSATION_STACK[@]}-1; i>=0; i--)); do
    local entry="${COMPENSATION_STACK[i]}"
    local description="${entry%%|||*}"
    local rollback_cmd="${entry#*|||}"

    echo "  [$((${#COMPENSATION_STACK[@]} - i))/${#COMPENSATION_STACK[@]}] Rolling back: $description"
    echo "      Command: $rollback_cmd"

    # Execute rollback command
    if eval "$rollback_cmd" 2>/dev/null; then
      echo "      ✅ Rollback succeeded"
      success_count=$((success_count + 1))
      log_compensation_event "ROLLBACK_SUCCESS" "$description" "$rollback_cmd"
    else
      echo "      ⚠️  Rollback failed (manual cleanup may be needed)"
      fail_count=$((fail_count + 1))
      log_compensation_event "ROLLBACK_FAILED" "$description" "$rollback_cmd"
    fi
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ Rollback complete: $success_count succeeded, $fail_count failed"

  if [ $fail_count -gt 0 ]; then
    echo "⚠️  $fail_count rollback actions failed - manual cleanup may be required"
    echo "   Check compensation log: $COMPENSATION_LOG"
  fi

  # Log rollback end
  log_compensation_event "ROLLBACK_END" "$reason" "$success_count succeeded, $fail_count failed"

  # Clear compensation stack
  COMPENSATION_STACK=()
}

# Clear all registered compensations without executing
# Usage: clear_compensations
clear_compensations() {
  COMPENSATION_STACK=()
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Logging Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Log compensation event
# Usage: log_compensation_event "event_type" "description" "details"
log_compensation_event() {
  local event_type="$1"
  local description="$2"
  local details="${3:-}"

  local timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

  cat >> "$COMPENSATION_LOG" << LOG
[$timestamp] $event_type
  Description: $description
  Details: $details
LOG

  # Add separator for readability
  if [ "$event_type" = "ROLLBACK_END" ]; then
    echo "" >> "$COMPENSATION_LOG"
  fi
}

# Log operation failure (before rollback)
# Usage: log_failure "operation" "ticket" "agent" "reason"
log_failure() {
  local operation="$1"
  local ticket="${2:-N/A}"
  local agent="${3:-N/A}"
  local reason="$4"

  local timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

  cat >> "$COMPENSATION_LOG" << LOG
[$timestamp] OPERATION_FAILURE
  Operation: $operation
  Ticket: $ticket
  Agent: $agent
  Reason: $reason
  Action: Initiating rollback
LOG
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Helper Functions for Common Operations
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Execute command with compensation tracking
# Usage: exec_with_compensation "description" "forward_command" "rollback_command"
# Returns: 0 on success, 1 on failure
exec_with_compensation() {
  local description="$1"
  local forward_cmd="$2"
  local rollback_cmd="$3"

  # Execute forward command
  if eval "$forward_cmd" 2>&1; then
    # Success - register compensation
    register_compensation "$description" "$rollback_cmd"
    return 0
  else
    # Failure - do not register compensation
    return 1
  fi
}

# Safe exit with automatic compensation
# Usage: compensation_exit "reason" [exit_code]
compensation_exit() {
  local reason="$1"
  local exit_code="${2:-1}"

  # Execute all compensations
  execute_compensations "$reason"

  # Exit with specified code
  exit "$exit_code"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Compensation Statistics
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Show compensation statistics
# Usage: show_compensation_stats [days]
show_compensation_stats() {
  local days="${1:-7}"

  if [ ! -f "$COMPENSATION_LOG" ]; then
    echo "No compensation log found"
    return 0
  fi

  local cutoff_date=$(date -u -v-${days}d +"%Y-%m-%dT%H:%M:%S" 2>/dev/null || date -u -d "$days days ago" +"%Y-%m-%dT%H:%M:%S")

  echo "Compensation Statistics (last $days days)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Count rollbacks
  local rollback_count=$(grep -c "ROLLBACK_START" "$COMPENSATION_LOG" 2>/dev/null || echo "0")
  echo "Total rollbacks: $rollback_count"

  # Count failures
  local failure_count=$(grep -c "OPERATION_FAILURE" "$COMPENSATION_LOG" 2>/dev/null || echo "0")
  echo "Total failures: $failure_count"

  # Count failed rollbacks
  local failed_rollback_count=$(grep -c "ROLLBACK_FAILED" "$COMPENSATION_LOG" 2>/dev/null || echo "0")
  echo "Failed rollbacks (needs manual cleanup): $failed_rollback_count"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$failed_rollback_count" -gt 0 ]; then
    echo ""
    echo "⚠️  Manual cleanup required for $failed_rollback_count failed rollbacks"
    echo "   Review log: $COMPENSATION_LOG"
  fi
}
