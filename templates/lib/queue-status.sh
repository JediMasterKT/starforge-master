#!/bin/bash
# StarForge Queue Status Library
# Provides real-time visibility into trigger queue and agent status

# Get comprehensive queue status
# Returns JSON with counts for pending, processing, completed, failed, and DLQ triggers
get_queue_status() {
  local claude_dir="${STARFORGE_CLAUDE_DIR:-$PWD/.claude}"
  local trigger_dir="$claude_dir/triggers"
  local dlq_dir="$trigger_dir/dead-letter"
  local processed_dir="$trigger_dir/processed"

  # Performance: Use find with -maxdepth 1 to avoid deep scans
  local pending_count=0
  local processing_count=0
  local completed_count_1h=0
  local failed_count_1h=0
  local dlq_count=0

  # Count pending triggers (.trigger files)
  if [ -d "$trigger_dir" ]; then
    pending_count=$(find "$trigger_dir" -maxdepth 1 -name "*.trigger" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Count processing triggers (.processing files)
  if [ -d "$trigger_dir" ]; then
    processing_count=$(find "$trigger_dir" -maxdepth 1 -name "*.processing" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Count completed (last hour) - files in processed/ with mtime < 1 hour
  if [ -d "$processed_dir" ]; then
    completed_count_1h=$(find "$processed_dir" -maxdepth 1 -name "*.completed" -type f -mmin -60 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Count failed (last hour) - files in processed/failed/ with mtime < 1 hour
  if [ -d "$processed_dir/failed" ]; then
    failed_count_1h=$(find "$processed_dir/failed" -maxdepth 1 -name "*.failed" -type f -mmin -60 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Count DLQ triggers
  if [ -d "$dlq_dir" ]; then
    dlq_count=$(find "$dlq_dir" -maxdepth 1 -name "*.trigger" -type f 2>/dev/null | wc -l | tr -d ' ')
  fi

  # Return JSON
  cat <<EOF
{
  "pending": $pending_count,
  "processing": $processing_count,
  "completed_1h": $completed_count_1h,
  "failed_1h": $failed_count_1h,
  "dlq": $dlq_count
}
EOF
}

# Get agent status (which agents are busy, what they're working on)
# Returns JSON array with agent status information
get_agent_status() {
  local claude_dir="${STARFORGE_CLAUDE_DIR:-$PWD/.claude}"
  local trigger_dir="$claude_dir/triggers"
  local agent_slots_file="$claude_dir/daemon/agent-slots.json"
  local parallel_mode="${PARALLEL_DAEMON:-false}"

  # Check if parallel mode is enabled
  if [ "$parallel_mode" = "true" ] && [ -f "$agent_slots_file" ]; then
    # Parallel mode: Read from agent-slots.json
    get_agent_status_parallel "$agent_slots_file"
  else
    # Sequential mode: Infer from .processing files
    get_agent_status_sequential "$trigger_dir"
  fi
}

# Get agent status in parallel mode (from agent-slots.json)
get_agent_status_parallel() {
  local slots_file=$1

  if [ ! -f "$slots_file" ]; then
    echo "[]"
    return
  fi

  # Parse agent-slots.json to extract busy agents
  # Expected format: {"agent-name": {"status": "busy", "trigger": "...", "started": timestamp}}
  local agents_json=$(jq -c '[to_entries[] | select(.value.status == "busy") | {
    agent: .key,
    trigger: .value.trigger,
    started: .value.started,
    duration_seconds: (now - (.value.started | tonumber))
  }]' "$slots_file" 2>/dev/null || echo "[]")

  echo "$agents_json"
}

# Get agent status in sequential mode (infer from .processing files)
get_agent_status_sequential() {
  local trigger_dir=$1

  if [ ! -d "$trigger_dir" ]; then
    echo "[]"
    return
  fi

  # Find all .processing files
  local processing_files=$(find "$trigger_dir" -maxdepth 1 -name "*.processing" -type f 2>/dev/null)

  if [ -z "$processing_files" ]; then
    echo "[]"
    return
  fi

  # Build JSON array
  local agents_json="["
  local first=true

  for file in $processing_files; do
    local basename=$(basename "$file" .processing)
    local started=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
    local now=$(date +%s)
    local duration=$((now - started))

    # Try to extract agent name from trigger file content
    local agent="unknown"
    if [ -f "$file" ]; then
      agent=$(jq -r '.to_agent // .to // "unknown"' "$file" 2>/dev/null || echo "unknown")
    fi

    if [ "$first" = true ]; then
      first=false
    else
      agents_json="$agents_json,"
    fi

    agents_json="$agents_json{\"agent\":\"$agent\",\"trigger\":\"$basename\",\"started\":$started,\"duration_seconds\":$duration}"
  done

  agents_json="$agents_json]"
  echo "$agents_json"
}

# Check if daemon is running
is_daemon_running() {
  local claude_dir="${STARFORGE_CLAUDE_DIR:-$PWD/.claude}"
  local pid_file="$claude_dir/daemon/daemon.pid"

  if [ ! -f "$pid_file" ]; then
    return 1
  fi

  local pid=$(cat "$pid_file")
  if ps -p "$pid" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Format duration in human-readable format (e.g., "2m 30s", "1h 15m")
format_duration() {
  local seconds=$1

  if [ "$seconds" -lt 60 ]; then
    echo "${seconds}s"
  elif [ "$seconds" -lt 3600 ]; then
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    echo "${minutes}m ${secs}s"
  else
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    echo "${hours}h ${minutes}m"
  fi
}
