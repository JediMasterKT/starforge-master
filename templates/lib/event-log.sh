#!/bin/bash
# Structured event logging (JSONL format)

EVENT_DIR="${STARFORGE_CLAUDE_DIR:-.claude}/events"
mkdir -p "$EVENT_DIR"

# Log structured event
# Usage: log_event AGENT ACTION [key=value...]
# Example: log_event "orchestrator" "ticket_assigned" ticket=42 agent=junior-dev-a
log_event() {
  local agent=$1
  local action=$2
  shift 2

  # Validate arguments
  if [ -z "$agent" ] || [ -z "$action" ]; then
    echo "ERROR: log_event requires AGENT and ACTION" >&2
    return 1
  fi

  # Build context JSON from key=value pairs
  local context_json="{}"

  while [ $# -gt 0 ]; do
    local pair="$1"
    if [[ "$pair" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
      local key="${BASH_REMATCH[1]}"
      local value="${BASH_REMATCH[2]}"

      # Use jq to safely add each key-value pair to context
      context_json=$(echo "$context_json" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')
    fi
    shift
  done

  # Build event JSON using jq (handles all escaping)
  # Use -c for compact output (JSONL format: one JSON object per line)
  local timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")
  local event=$(jq -nc \
    --arg ts "$timestamp" \
    --arg agent "$agent" \
    --arg action "$action" \
    --argjson ctx "$context_json" \
    '{timestamp: $ts, agent: $agent, action: $action, context: $ctx}')

  # Append to daily log file
  local log_file="$EVENT_DIR/$(date +%Y-%m-%d).jsonl"
  echo "$event" >> "$log_file"
}

# Query events (helper for CLI)
query_events() {
  local filter="$1"
  local event_files=("$EVENT_DIR"/*.jsonl)

  if [ ! -f "${event_files[0]}" ]; then
    echo "No events found" >&2
    return 1
  fi

  # Use jq to filter events
  cat "${event_files[@]}" 2>/dev/null | jq -r "$filter" 2>/dev/null || echo "Invalid filter: $filter" >&2
}
