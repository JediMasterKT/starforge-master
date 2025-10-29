#!/bin/bash
# Dead Letter Queue (DLQ) for Failed Triggers
# Handles triggers that fail after max retries
# Issue #332: https://github.com/JediMasterKT/starforge-master/issues/332

# Move trigger to dead letter queue after all retries exhausted
#
# Args:
#   $1 - trigger_file: Path to trigger file (.trigger or .processing)
#   $2 - failure_reason: Human-readable failure description
#   $3 - exit_code: Last exit code from agent invocation
#   $4 - trace_id: Unique trace ID for this trigger
#   $5 - retry_timestamps: JSON array of retry attempt timestamps
#
# Returns:
#   0 on success, 1 on failure (but trigger still moved even if metadata fails)
move_to_dlq() {
  local trigger_file=$1
  local failure_reason=$2
  local exit_code=$3
  local trace_id=$4
  local retry_timestamps=$5

  # Use STARFORGE_CLAUDE_DIR if available, fallback to .claude
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local dlq_dir="$claude_dir/triggers/dead-letter"

  # Ensure DLQ directory exists
  mkdir -p "$dlq_dir"

  # Extract trigger filename
  local trigger_filename=$(basename "$trigger_file")
  local dlq_trigger_file="$dlq_dir/$trigger_filename"

  # Extract trigger details for metadata
  local to_agent=$(jq -r '.to_agent // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local from_agent=$(jq -r '.from_agent // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local action=$(jq -r '.action // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local message=$(jq -r '.message // ""' "$trigger_file" 2>/dev/null || echo "")

  # Move trigger to DLQ
  mv "$trigger_file" "$dlq_trigger_file" 2>/dev/null

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to move trigger to DLQ: $trigger_file" >&2
    return 1
  fi

  # Create metadata file
  local metadata_file="$dlq_trigger_file.meta.json"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  cat > "$metadata_file" << META_JSON
{
  "trigger_filename": "$trigger_filename",
  "trace_id": "$trace_id",
  "agent": "$to_agent",
  "from_agent": "$from_agent",
  "action": "$action",
  "message": "$message",
  "failure_reason": "$failure_reason",
  "exit_code": $exit_code,
  "retry_timestamps": $retry_timestamps,
  "dlq_entry_timestamp": "$timestamp",
  "retry_count": $(echo "$retry_timestamps" | jq 'length' 2>/dev/null || echo "0")
}
META_JSON

  # Send Discord alert (if function available)
  if type send_dlq_alert &>/dev/null; then
    send_dlq_alert "$trigger_filename" "$to_agent" "$trace_id" "$failure_reason" "$exit_code"
  fi

  # Log DLQ move
  if type log_event &>/dev/null; then
    log_event "DLQ" "Trigger moved to dead letter queue: $trigger_filename (exit: $exit_code)" "$trace_id"
  else
    echo "[DLQ] Trigger moved to dead letter queue: $trigger_filename (exit: $exit_code)" >&2
  fi

  return 0
}

# List all DLQ triggers with metadata
#
# Returns:
#   Formatted list of DLQ triggers, or empty if none
list_dlq_triggers() {
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local dlq_dir="$claude_dir/triggers/dead-letter"

  if [ ! -d "$dlq_dir" ]; then
    echo "Dead letter queue is empty"
    return 0
  fi

  local trigger_count=$(find "$dlq_dir" -name "*.trigger" -type f 2>/dev/null | wc -l | tr -d ' ')

  if [ "$trigger_count" -eq 0 ]; then
    echo "Dead letter queue is empty"
    return 0
  fi

  echo "Dead Letter Queue ($trigger_count triggers):"
  echo ""
  echo "Trigger | Agent | Trace ID | Failure Reason | Exit Code | DLQ Entry Time"
  echo "--------|-------|----------|----------------|-----------|----------------"

  for trigger_file in "$dlq_dir"/*.trigger; do
    local filename=$(basename "$trigger_file")
    local meta_file="$trigger_file.meta.json"

    if [ -f "$meta_file" ]; then
      local agent=$(jq -r '.agent' "$meta_file" 2>/dev/null || echo "unknown")
      local trace_id=$(jq -r '.trace_id' "$meta_file" 2>/dev/null || echo "unknown")
      local failure_reason=$(jq -r '.failure_reason' "$meta_file" 2>/dev/null || echo "unknown")
      local exit_code=$(jq -r '.exit_code' "$meta_file" 2>/dev/null || echo "?")
      local dlq_time=$(jq -r '.dlq_entry_timestamp' "$meta_file" 2>/dev/null || echo "unknown")

      # Truncate failure reason to 40 chars
      if [ ${#failure_reason} -gt 40 ]; then
        failure_reason="${failure_reason:0:37}..."
      fi

      echo "$filename | $agent | $trace_id | $failure_reason | $exit_code | $dlq_time"
    else
      echo "$filename | unknown | unknown | (no metadata) | ? | unknown"
    fi
  done

  echo ""
  echo "Recovery: starforge dlq retry <trigger-filename>"
  echo "Cleanup:  starforge dlq cleanup (removes triggers >7 days old)"
}

# Retry a DLQ trigger (move back to active queue)
#
# Args:
#   $1 - trigger_filename: Name of trigger file to retry (e.g., "agent-action-123.trigger")
#
# Returns:
#   0 on success, 1 on failure
retry_dlq_trigger() {
  local trigger_filename=$1

  if [ -z "$trigger_filename" ]; then
    echo "ERROR: Trigger filename required" >&2
    echo "Usage: starforge dlq retry <trigger-filename>" >&2
    return 1
  fi

  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local dlq_dir="$claude_dir/triggers/dead-letter"
  local triggers_dir="$claude_dir/triggers"

  local dlq_trigger_file="$dlq_dir/$trigger_filename"
  local dest_trigger_file="$triggers_dir/$trigger_filename"

  if [ ! -f "$dlq_trigger_file" ]; then
    echo "ERROR: Trigger not found in DLQ: $trigger_filename" >&2
    echo "Available DLQ triggers:" >&2
    ls -1 "$dlq_dir"/*.trigger 2>/dev/null | xargs -n1 basename || echo "  (none)"
    return 1
  fi

  # Move trigger back to active queue
  mv "$dlq_trigger_file" "$dest_trigger_file"

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to move trigger back to queue" >&2
    return 1
  fi

  # Keep metadata in DLQ for audit trail, but mark as retried
  local meta_file="$dlq_dir/$trigger_filename.meta.json"
  if [ -f "$meta_file" ]; then
    local retry_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # Add retry timestamp to metadata
    jq --arg ts "$retry_timestamp" '. + {manual_retry_timestamp: $ts}' "$meta_file" > "$meta_file.tmp" && mv "$meta_file.tmp" "$meta_file"
  fi

  echo "✅ Trigger moved back to queue: $trigger_filename"
  echo "   The daemon will process it on next cycle."

  return 0
}

# Cleanup old DLQ triggers (archive items >7 days old)
#
# Args:
#   $1 - age_days: Age threshold in days (default: 7)
#
# Returns:
#   Number of triggers cleaned up
cleanup_old_dlq_triggers() {
  local age_days=${1:-7}
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local dlq_dir="$claude_dir/triggers/dead-letter"
  local archive_dir="$claude_dir/triggers/processed/failed"

  if [ ! -d "$dlq_dir" ]; then
    echo "0"
    return 0
  fi

  mkdir -p "$archive_dir"

  local count=0
  local timestamp=$(date +%Y%m%d-%H%M%S)

  # Find triggers older than age_days (based on file modification time)
  # Use -mtime for "modified more than N days ago"
  local old_triggers=$(find "$dlq_dir" -name "*.trigger" -type f -mtime +$age_days 2>/dev/null)

  for trigger_file in $old_triggers; do
    local filename=$(basename "$trigger_file")
    local meta_file="$trigger_file.meta.json"

    # Move trigger to archive
    mv "$trigger_file" "$archive_dir/dlq-archived-$timestamp-$filename" 2>/dev/null

    if [ $? -eq 0 ]; then
      count=$((count + 1))

      # Also archive metadata if exists
      if [ -f "$meta_file" ]; then
        mv "$meta_file" "$archive_dir/dlq-archived-$timestamp-$filename.meta.json" 2>/dev/null
      fi

      echo "Archived old DLQ trigger: $filename (>$age_days days old)" >&2
    fi
  done

  echo "$count"
}

# Get DLQ statistics
#
# Returns:
#   JSON object with DLQ stats
get_dlq_stats() {
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local dlq_dir="$claude_dir/triggers/dead-letter"

  if [ ! -d "$dlq_dir" ]; then
    echo '{"count": 0, "oldest_entry": null, "newest_entry": null}'
    return 0
  fi

  local trigger_count=$(find "$dlq_dir" -name "*.trigger" -type f 2>/dev/null | wc -l | tr -d ' ')

  if [ "$trigger_count" -eq 0 ]; then
    echo '{"count": 0, "oldest_entry": null, "newest_entry": null}'
    return 0
  fi

  # Find oldest and newest DLQ entries by metadata timestamp
  local oldest=$(find "$dlq_dir" -name "*.meta.json" -type f -exec jq -r '.dlq_entry_timestamp' {} \; 2>/dev/null | sort | head -1 || echo "null")
  local newest=$(find "$dlq_dir" -name "*.meta.json" -type f -exec jq -r '.dlq_entry_timestamp' {} \; 2>/dev/null | sort | tail -1 || echo "null")

  cat << STATS_JSON
{
  "count": $trigger_count,
  "oldest_entry": "$oldest",
  "newest_entry": "$newest"
}
STATS_JSON
}
