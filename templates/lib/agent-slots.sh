#!/bin/bash
# StarForge Agent Slot Management Library
# Manages parallel agent execution slots with PID tracking
# Used by daemon-runner.sh for concurrent agent operations

# Ensure CLAUDE_DIR is set
if [ -z "$CLAUDE_DIR" ]; then
  echo "ERROR: CLAUDE_DIR not set. Source project-env.sh first." >&2
  return 1
fi

# Agent slots file location
SLOTS_FILE="${SLOTS_FILE:-$CLAUDE_DIR/daemon/agent-slots.json}"

# Initialize slots file if it doesn't exist
if [ ! -f "$SLOTS_FILE" ]; then
  mkdir -p "$(dirname "$SLOTS_FILE")"
  echo '{}' > "$SLOTS_FILE"
fi

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Slot Management Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# is_agent_busy - Check if agent has running process
# Usage: is_agent_busy "junior-dev-a"
# Returns: 0 (true) if busy, 1 (false) if idle
is_agent_busy() {
  local agent=$1

  if [ ! -f "$SLOTS_FILE" ]; then
    return 1  # Not busy if file doesn't exist
  fi

  local agent_status=$(jq -r ".\"$agent\".status // \"idle\"" "$SLOTS_FILE" 2>/dev/null || echo "idle")

  if [ "$agent_status" = "busy" ]; then
    return 0  # Busy
  else
    return 1  # Idle
  fi
}

# mark_agent_busy - Acquire slot with PID and context
# Usage: mark_agent_busy "junior-dev-a" "12345" "52"
# Args:
#   $1 - agent ID (e.g., "junior-dev-a")
#   $2 - process PID
#   $3 - ticket number (optional, can be empty for QA/orchestrator)
mark_agent_busy() {
  local agent=$1
  local pid=$2
  local ticket=$3
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create temporary file for atomic update
  local temp_file=$(mktemp)

  # Build JSON update
  if [ -n "$ticket" ]; then
    # With ticket (junior-dev agents)
    jq --arg agent "$agent" \
       --arg pid "$pid" \
       --arg ticket "$ticket" \
       --arg timestamp "$timestamp" \
       '.[$agent] = {
         "status": "busy",
         "pid": $pid,
         "ticket": $ticket,
         "started_at": $timestamp
       }' "$SLOTS_FILE" > "$temp_file"
  else
    # Without ticket (qa-engineer, orchestrator)
    jq --arg agent "$agent" \
       --arg pid "$pid" \
       --arg timestamp "$timestamp" \
       '.[$agent] = {
         "status": "busy",
         "pid": $pid,
         "ticket": null,
         "started_at": $timestamp
       }' "$SLOTS_FILE" > "$temp_file"
  fi

  # Atomic move
  mv "$temp_file" "$SLOTS_FILE"
}

# mark_agent_idle - Release slot
# Usage: mark_agent_idle "junior-dev-a"
mark_agent_idle() {
  local agent=$1

  # Create temporary file for atomic update
  local temp_file=$(mktemp)

  # Update agent status to idle, clear PID and ticket
  jq --arg agent "$agent" \
     '.[$agent] = {
       "status": "idle",
       "pid": null,
       "ticket": null,
       "started_at": null
     }' "$SLOTS_FILE" > "$temp_file"

  # Atomic move
  mv "$temp_file" "$SLOTS_FILE"
}

# get_agent_pid - Retrieve running PID
# Usage: pid=$(get_agent_pid "junior-dev-a")
# Returns: PID or empty string if idle
get_agent_pid() {
  local agent=$1

  if [ ! -f "$SLOTS_FILE" ]; then
    echo ""
    return
  fi

  local pid=$(jq -r ".\"$agent\".pid // \"\"" "$SLOTS_FILE" 2>/dev/null || echo "")

  # Convert "null" to empty string
  if [ "$pid" = "null" ]; then
    echo ""
  else
    echo "$pid"
  fi
}

# get_agent_ticket - Retrieve current ticket number
# Usage: ticket=$(get_agent_ticket "junior-dev-a")
# Returns: Ticket number or empty string
get_agent_ticket() {
  local agent=$1

  if [ ! -f "$SLOTS_FILE" ]; then
    echo ""
    return
  fi

  local ticket=$(jq -r ".\"$agent\".ticket // \"\"" "$SLOTS_FILE" 2>/dev/null || echo "")

  # Convert "null" to empty string
  if [ "$ticket" = "null" ]; then
    echo ""
  else
    echo "$ticket"
  fi
}

# get_agent_started_at - Retrieve start timestamp
# Usage: started_at=$(get_agent_started_at "junior-dev-a")
# Returns: ISO8601 timestamp or empty string
get_agent_started_at() {
  local agent=$1

  if [ ! -f "$SLOTS_FILE" ]; then
    echo ""
    return
  fi

  local started_at=$(jq -r ".\"$agent\".started_at // \"\"" "$SLOTS_FILE" 2>/dev/null || echo "")

  # Convert "null" to empty string
  if [ "$started_at" = "null" ]; then
    echo ""
  else
    echo "$started_at"
  fi
}

# list_busy_agents - Get list of all currently busy agents
# Usage: busy_agents=$(list_busy_agents)
# Returns: Newline-separated list of agent IDs
list_busy_agents() {
  if [ ! -f "$SLOTS_FILE" ]; then
    echo ""
    return
  fi

  jq -r 'to_entries[] | select(.value.status == "busy") | .key' "$SLOTS_FILE" 2>/dev/null || echo ""
}

# get_agent_count_busy - Count of busy agents
# Usage: count=$(get_agent_count_busy)
# Returns: Number of busy agents
get_agent_count_busy() {
  if [ ! -f "$SLOTS_FILE" ]; then
    echo "0"
    return
  fi

  local count=$(jq '[.[] | select(.status == "busy")] | length' "$SLOTS_FILE" 2>/dev/null || echo "0")
  echo "$count"
}

# cleanup_orphaned_pids - Remove stale PIDs from slots
# Usage: cleanup_orphaned_pids
# Checks if PIDs are still running, clears if dead
cleanup_orphaned_pids() {
  if [ ! -f "$SLOTS_FILE" ]; then
    return
  fi

  local busy_agents=$(list_busy_agents)

  while IFS= read -r agent; do
    [ -z "$agent" ] && continue

    local pid=$(get_agent_pid "$agent")

    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      # Process dead, clear slot
      mark_agent_idle "$agent"
      echo "Cleaned up orphaned PID $pid for $agent" >&2
    fi
  done <<< "$busy_agents"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Status Display Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# print_agent_status - Display formatted status for all agents
# Usage: print_agent_status
print_agent_status() {
  if [ ! -f "$SLOTS_FILE" ]; then
    echo "No agent slots initialized"
    return
  fi

  echo "Agent Status:"
  echo "============================================"

  jq -r 'to_entries[] | "\(.key): \(.value.status) (PID: \(.value.pid // "none"), Ticket: \(.value.ticket // "none"), Started: \(.value.started_at // "none"))"' "$SLOTS_FILE"

  echo "============================================"
  echo "Total busy: $(get_agent_count_busy)"
}
