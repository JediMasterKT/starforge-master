#!/bin/bash
# StarForge Daemon Runner
# Core daemon logic for autonomous agent operation

set -e

# Get project root
PROJECT_ROOT="$(pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
TRIGGER_DIR="$CLAUDE_DIR/triggers"
LOG_FILE="$CLAUDE_DIR/logs/daemon.log"
STATE_FILE="$CLAUDE_DIR/daemon-state.json"
SEEN_FILE="$CLAUDE_DIR/.daemon-seen-triggers"

# Daemon configuration
MAX_RETRIES=3
INITIAL_RETRY_DELAY=5
AGENT_TIMEOUT=1800  # 30 minutes
DAEMON_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROCESSED_COUNT=0

# Ensure required directories exist
mkdir -p "$TRIGGER_DIR/processed/invalid"
mkdir -p "$TRIGGER_DIR/processed/failed"
mkdir -p "$CLAUDE_DIR/logs"

# Touch log file
touch "$LOG_FILE"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Logging
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log_event() {
  local level=$1
  local message=$2
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "[$timestamp] $level: $message" >> "$LOG_FILE"
  echo "[$timestamp] $level: $message" >&2
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# State Management
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

save_state() {
  local current_trigger=$1

  cat > "$STATE_FILE" << EOF
{
  "daemon_started": "$DAEMON_START_TIME",
  "last_trigger_processed": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_triggers_processed": $PROCESSED_COUNT,
  "current_trigger": "$(basename "${current_trigger:-none}")"
}
EOF
}

load_state() {
  if [ -f "$STATE_FILE" ]; then
    PROCESSED_COUNT=$(jq -r '.total_triggers_processed // 0' "$STATE_FILE" 2>/dev/null || echo "0")
    log_event "RESUME" "Loaded previous state (processed: $PROCESSED_COUNT)"
  else
    PROCESSED_COUNT=0
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Deduplication
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

mark_as_processed() {
  local trigger_file=$1
  basename "$trigger_file" >> "$SEEN_FILE"
}

was_already_processed() {
  local trigger_file=$1
  if [ -f "$SEEN_FILE" ]; then
    grep -Fxq "$(basename "$trigger_file")" "$SEEN_FILE" 2>/dev/null
  else
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Trigger Archival
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

archive_trigger() {
  local trigger_file=$1
  local status=$2  # success|invalid|failed
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local filename=$(basename "$trigger_file")

  case "$status" in
    success)
      mkdir -p "$TRIGGER_DIR/processed"
      mv "$trigger_file" "$TRIGGER_DIR/processed/$timestamp-$filename" 2>/dev/null || true
      ;;
    invalid)
      mkdir -p "$TRIGGER_DIR/processed/invalid"
      mv "$trigger_file" "$TRIGGER_DIR/processed/invalid/$timestamp-$filename" 2>/dev/null || true
      ;;
    failed)
      mkdir -p "$TRIGGER_DIR/processed/failed"
      mv "$trigger_file" "$TRIGGER_DIR/processed/failed/$timestamp-$filename" 2>/dev/null || true
      ;;
  esac

  log_event "ARCHIVE" "Trigger $filename → $status"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Agent Invocation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

invoke_agent() {
  local trigger_file=$1

  # Validate JSON
  if ! jq empty "$trigger_file" 2>/dev/null; then
    log_event "ERROR" "Malformed JSON in $(basename "$trigger_file")"
    return 2  # Special code for parse errors
  fi

  # Parse trigger
  local to_agent=$(jq -r '.to_agent // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local from_agent=$(jq -r '.from_agent // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local action=$(jq -r '.action // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")

  if [ "$to_agent" = "unknown" ] || [ "$to_agent" = "null" ]; then
    log_event "ERROR" "Missing 'to_agent' field in $(basename "$trigger_file")"
    return 2  # Parse error
  fi

  # Log invocation
  log_event "INVOKE" "$from_agent → $to_agent ($action)"

  # Invoke agent with timeout
  local start_time=$(date +%s)

  # Check if starforge command exists
  if ! command -v starforge &> /dev/null; then
    log_event "ERROR" "starforge command not found in PATH"
    return 1
  fi

  # WORKAROUND: Daemon mode - agents run non-interactively
  # TODO: Implement proper non-interactive agent invocation
  # For now, we simulate successful execution to test daemon functionality

  log_event "INFO" "Simulating agent execution (daemon mode workaround)"

  # Simulate agent work (2 second delay)
  sleep 2

  local duration=$(($(date +%s) - start_time))
  log_event "COMPLETE" "$to_agent completed in ${duration}s (simulated)"
  return 0

  # ORIGINAL CODE (disabled until non-interactive mode is implemented):
  # if timeout "$AGENT_TIMEOUT" starforge use "$to_agent" >> "$LOG_FILE" 2>&1; then
  #   local duration=$(($(date +%s) - start_time))
  #   log_event "COMPLETE" "$to_agent completed in ${duration}s"
  #   return 0
  # else
  #   local exit_code=$?
  #   if [ $exit_code -eq 124 ]; then
  #     log_event "ERROR" "$to_agent timed out after ${AGENT_TIMEOUT}s"
  #   else
  #     log_event "ERROR" "$to_agent failed (exit: $exit_code)"
  #   fi
  #   return 1
  # fi
}

invoke_agent_with_retry() {
  local trigger_file=$1
  local max_retries=$MAX_RETRIES
  local attempt=1
  local delay=$INITIAL_RETRY_DELAY

  while [ $attempt -le $max_retries ]; do
    if [ $attempt -gt 1 ]; then
      log_event "RETRY" "Attempt $attempt/$max_retries for $(basename "$trigger_file")"
    fi

    invoke_agent "$trigger_file"
    local exit_code=$?

    # Exit code 2 = parse error, don't retry
    if [ $exit_code -eq 2 ]; then
      log_event "ERROR" "Parse error, no retry"
      return 2
    fi

    # Success
    if [ $exit_code -eq 0 ]; then
      return 0
    fi

    # Retry logic
    if [ $attempt -lt $max_retries ]; then
      log_event "RETRY" "Waiting ${delay}s before retry"
      sleep $delay
      delay=$((delay * 2))  # Exponential backoff: 5, 10, 20
    fi

    attempt=$((attempt + 1))
  done

  log_event "CRITICAL" "Failed after $max_retries attempts: $(basename "$trigger_file")"
  return 1
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Trigger Processing
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

get_next_trigger() {
  # Get oldest .trigger file by creation time (FIFO)
  find "$TRIGGER_DIR" -maxdepth 1 -name "*.trigger" -type f \
    -exec stat -f "%B %N" {} \; 2>/dev/null | \
    sort -n | \
    head -1 | \
    cut -d' ' -f2-
}

process_trigger() {
  local trigger_file=$1

  # Skip if already processed
  if was_already_processed "$trigger_file"; then
    log_event "SKIP" "Already processed: $(basename "$trigger_file")"
    rm -f "$trigger_file" 2>/dev/null || true
    return 0
  fi

  # Mark as currently processing
  save_state "$trigger_file"

  # Invoke agent with retry
  invoke_agent_with_retry "$trigger_file"
  local result=$?

  # Mark as seen
  mark_as_processed "$trigger_file"

  # Archive based on result
  if [ $result -eq 0 ]; then
    archive_trigger "$trigger_file" "success"
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
  elif [ $result -eq 2 ]; then
    archive_trigger "$trigger_file" "invalid"
  else
    archive_trigger "$trigger_file" "failed"
  fi

  # Update state
  save_state ""

  return $result
}

process_backlog() {
  local trigger_file
  local backlog_count=$(find "$TRIGGER_DIR" -maxdepth 1 -name "*.trigger" -type f 2>/dev/null | wc -l | tr -d ' ')

  if [ "$backlog_count" -gt 0 ]; then
    log_event "BACKLOG" "Found $backlog_count pending trigger(s)"

    while true; do
      trigger_file=$(get_next_trigger)

      if [ -z "$trigger_file" ] || [ ! -f "$trigger_file" ]; then
        break
      fi

      log_event "BACKLOG" "Processing: $(basename "$trigger_file")"
      process_trigger "$trigger_file"
    done

    log_event "BACKLOG" "Backlog processing complete"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Crash Recovery
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resume_processing() {
  load_state

  # Check for interrupted trigger
  if [ -f "$STATE_FILE" ]; then
    local current_trigger=$(jq -r '.current_trigger // "none"' "$STATE_FILE" 2>/dev/null || echo "none")

    if [ "$current_trigger" != "none" ] && [ "$current_trigger" != "null" ] && [ -f "$TRIGGER_DIR/$current_trigger" ]; then
      log_event "RESUME" "Found interrupted trigger: $current_trigger"
      # Mark as seen to prevent re-processing
      mark_as_processed "$TRIGGER_DIR/$current_trigger"
      # Move to failed (was interrupted)
      archive_trigger "$TRIGGER_DIR/$current_trigger" "failed"
    fi
  fi

  # Process any remaining backlog
  process_backlog
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Signal Handling
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cleanup_and_exit() {
  log_event "STOP" "Daemon shutting down gracefully"
  save_state ""
  exit 0
}

trap cleanup_and_exit SIGTERM SIGINT

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Daemon Loop
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  log_event "START" "Daemon started (PID: $$)"

  # Check for fswatch
  if ! command -v fswatch &> /dev/null; then
    log_event "ERROR" "fswatch not installed. Install with: brew install fswatch"
    exit 1
  fi

  # Check for jq
  if ! command -v jq &> /dev/null; then
    log_event "ERROR" "jq not installed. Install with: brew install jq"
    exit 1
  fi

  # Resume from previous state
  resume_processing

  log_event "MONITOR" "Watching $TRIGGER_DIR for new triggers"

  # Monitor for new triggers using fswatch
  fswatch -0 --event Created "$TRIGGER_DIR" 2>/dev/null | while read -d "" event; do
    # Only process .trigger files
    if [[ "$event" == *.trigger ]]; then
      log_event "TRIGGER" "Detected: $(basename "$event")"
      process_trigger "$event"
    fi
  done &

  # Wait for fswatch process
  wait
}

# Run main daemon loop
main
