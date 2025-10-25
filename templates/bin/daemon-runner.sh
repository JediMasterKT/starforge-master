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

# Parallel execution configuration
PARALLEL_DAEMON=${PARALLEL_DAEMON:-false}  # Feature flag (default: sequential mode)
MAX_CONCURRENT_AGENTS=${MAX_CONCURRENT_AGENTS:-999}  # Unlimited by default
AGENT_SLOTS_FILE="$CLAUDE_DIR/daemon/agent-slots.json"
PROCESS_MONITOR_INTERVAL=10  # Check running processes every 10 seconds

# Ensure required directories exist
mkdir -p "$TRIGGER_DIR/processed/invalid"
mkdir -p "$TRIGGER_DIR/processed/failed"
mkdir -p "$CLAUDE_DIR/logs"
mkdir -p "$CLAUDE_DIR/daemon"

# Touch log file
touch "$LOG_FILE"

# Load environment variables (Discord webhooks, etc.)
if [ -f "$PROJECT_ROOT/.env" ]; then
  source "$PROJECT_ROOT/.env"
fi

# Load Discord notification helper (optional - gracefully skips if not present)
if [ -f "$PROJECT_ROOT/.claude/lib/discord-notify.sh" ]; then
  source "$PROJECT_ROOT/.claude/lib/discord-notify.sh"
fi

# Initialize agent slots file
if [ ! -f "$AGENT_SLOTS_FILE" ]; then
  echo '{}' > "$AGENT_SLOTS_FILE"
fi

# Source agent slot management library (if parallel mode enabled)
if [ "$PARALLEL_DAEMON" = "true" ]; then
  if [ -f "$CLAUDE_DIR/../templates/lib/agent-slots.sh" ]; then
    source "$CLAUDE_DIR/../templates/lib/agent-slots.sh"
  elif [ -f "$PROJECT_ROOT/templates/lib/agent-slots.sh" ]; then
    source "$PROJECT_ROOT/templates/lib/agent-slots.sh"
  else
    log_event "ERROR" "agent-slots.sh not found, falling back to sequential mode"
    PARALLEL_DAEMON=false
  fi
fi

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
# Progress Monitoring
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

monitor_agent_progress() {
  local agent=$1
  local start_time=$2
  local ticket=$3
  local interval=300  # 5 minutes

  while true; do
    sleep $interval

    # Check if parent process still exists
    if ! ps -p $PPID > /dev/null 2>&1; then
      break
    fi

    local elapsed=$(($(date +%s) - start_time))
    local elapsed_min=$((elapsed / 60))

    # Send progress notification (if Discord configured)
    if type send_agent_progress_notification &>/dev/null; then
      send_agent_progress_notification "$agent" "$elapsed_min" "$ticket"
    fi
  done
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

  # Extract additional context from trigger
  local message=$(jq -r '.message // ""' "$trigger_file" 2>/dev/null || echo "")
  local ticket=$(jq -r '.ticket // ""' "$trigger_file" 2>/dev/null || echo "")
  local command=$(jq -r '.command // ""' "$trigger_file" 2>/dev/null || echo "")

  # Build prompt for agent
  local prompt="Task from $from_agent: $action"
  [ -n "$message" ] && prompt="$prompt\n\nMessage: $message"
  [ -n "$ticket" ] && prompt="$prompt\nTicket: $ticket"
  [ -n "$command" ] && prompt="$prompt\n\nCommand: $command"
  prompt="$prompt\n\nTrigger file: $trigger_file"

  # Invoke agent via Task tool using claude --print (non-interactive)
  log_event "TASKTOOL" "Invoking $to_agent via Task tool"

  # Extract ticket from context (if present)
  local ticket=$(jq -r '.context.ticket // "N/A"' "$trigger_file" 2>/dev/null || echo "N/A")

  # Send agent start notification (if Discord configured)
  if type send_agent_start_notification &>/dev/null; then
    send_agent_start_notification "$to_agent" "$action" "$from_agent" "$ticket"
  fi

  # Start background progress monitor
  monitor_agent_progress "$to_agent" "$start_time" "$ticket" &
  MONITOR_PID=$!

  if timeout "$AGENT_TIMEOUT" claude --print --permission-mode bypassPermissions "Use the $to_agent agent. $prompt" >> "$LOG_FILE" 2>&1; then
    local duration=$(($(date +%s) - start_time))
    log_event "COMPLETE" "$to_agent completed in ${duration}s"

    # Kill progress monitor
    kill $MONITOR_PID 2>/dev/null || true

    # Send completion notification (if Discord configured)
    if type send_agent_complete_notification &>/dev/null; then
      local duration_min=$((duration / 60))
      local duration_sec=$((duration % 60))
      send_agent_complete_notification "$to_agent" "$duration_min" "$duration_sec" "$action" "$ticket"
    fi

    return 0
  else
    local exit_code=$?
    local duration=$(($(date +%s) - start_time))

    # Kill progress monitor
    kill $MONITOR_PID 2>/dev/null || true

    if [ $exit_code -eq 124 ]; then
      log_event "ERROR" "$to_agent timed out after ${AGENT_TIMEOUT}s"

      # Send timeout notification (if Discord configured)
      if type send_agent_timeout_notification &>/dev/null; then
        send_agent_timeout_notification "$to_agent" "$action" "$ticket"
      fi
    else
      log_event "ERROR" "$to_agent failed (exit: $exit_code)"

      # Send error notification (if Discord configured)
      if type send_agent_error_notification &>/dev/null; then
        local duration_min=$((duration / 60))
        send_agent_error_notification "$to_agent" "$exit_code" "$duration_min" "$ticket"
      fi
    fi
    return 1
  fi
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
# Parallel Execution Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# invoke_agent_parallel - Spawn agent in background with slot management
# Usage: invoke_agent_parallel "trigger-file.trigger"
# Returns: 0 if spawned, 1 if agent busy, 2 if parse error
invoke_agent_parallel() {
  local trigger_file=$1

  # Validate JSON
  if ! jq empty "$trigger_file" 2>/dev/null; then
    log_event "ERROR" "Malformed JSON in $(basename "$trigger_file")"
    return 2  # Parse error
  fi

  # Parse trigger
  local to_agent=$(jq -r '.to_agent // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local from_agent=$(jq -r '.from_agent // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local action=$(jq -r '.action // "unknown"' "$trigger_file" 2>/dev/null || echo "unknown")
  local ticket=$(jq -r '.context.ticket // ""' "$trigger_file" 2>/dev/null || echo "")

  if [ "$to_agent" = "unknown" ] || [ "$to_agent" = "null" ]; then
    log_event "ERROR" "Missing 'to_agent' field in $(basename "$trigger_file")"
    return 2  # Parse error
  fi

  # Check if agent slot is available
  if is_agent_busy "$to_agent"; then
    log_event "QUEUE" "$to_agent busy, trigger stays in queue"
    return 1  # Agent busy
  fi

  # Check concurrent agent limit
  local busy_count=$(get_agent_count_busy)
  if [ "$busy_count" -ge "$MAX_CONCURRENT_AGENTS" ]; then
    log_event "QUEUE" "Max concurrent agents reached ($MAX_CONCURRENT_AGENTS), trigger stays in queue"
    return 1  # Queue full
  fi

  # Spawn background process
  log_event "SPAWN" "Starting $to_agent in background ($from_agent → $to_agent: $action)"

  (
    # Reserve agent slot immediately
    mark_agent_busy "$to_agent" "$$" "$ticket"

    # Ensure slot is released on exit
    trap "mark_agent_idle \"$to_agent\"" EXIT

    # Log file for this agent execution
    local agent_log="$CLAUDE_DIR/logs/${to_agent}-$(date +%s).log"

    # WORKAROUND: Daemon mode - agents run non-interactively
    # TODO: Implement proper claude --print invocation with stream-json
    # For now, we simulate successful execution

    log_event "INFO" "$to_agent: Simulating agent execution (daemon mode workaround)" >> "$LOG_FILE"
    echo "Agent: $to_agent" > "$agent_log"
    echo "Trigger: $(basename "$trigger_file")" >> "$agent_log"
    echo "Started: $(date)" >> "$agent_log"

    # Simulate agent work (2 second delay)
    sleep 2

    echo "Completed: $(date)" >> "$agent_log"
    log_event "COMPLETE" "$to_agent completed (simulated)" >> "$LOG_FILE"

    exit 0

    # FUTURE CODE (when claude --print is ready):
    # claude --print \
    #   --permission-mode bypassPermissions \
    #   --output-format stream-json \
    #   "Use $to_agent agent. Process trigger: $(cat "$trigger_file")" \
    #   2>&1 | tee "$agent_log" | process_stream_output "$to_agent"
    #
    # exit ${PIPESTATUS[0]}
  ) &

  # Save PID
  local agent_pid=$!

  # Update slot with actual background PID
  mark_agent_busy "$to_agent" "$agent_pid" "$ticket"

  log_event "SPAWNED" "$to_agent started (PID: $agent_pid)"
  return 0
}

# process_stream_output - Parse stream-json output for real-time updates
# Usage: ... | process_stream_output "agent-id"
# Future implementation for streaming output
process_stream_output() {
  local agent=$1
  local last_notification=0

  while IFS= read -r line; do
    # Parse JSONL format
    local msg_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)

    case "$msg_type" in
      "tool_use")
        # Future: Send progress notification every 5 minutes
        local current_time=$(date +%s)
        if [ $((current_time - last_notification)) -ge 300 ]; then
          log_event "PROGRESS" "$agent: Still working..."
          last_notification=$current_time
        fi
        ;;

      "completion")
        # Final result
        log_event "OUTPUT" "$agent: Completed"
        ;;
    esac
  done
}

# monitor_running_agents - Background loop to detect agent completion
# Polls every PROCESS_MONITOR_INTERVAL seconds
monitor_running_agents() {
  while true; do
    # Get all busy agents
    local busy_agents=$(list_busy_agents 2>/dev/null || echo "")

    while IFS= read -r agent; do
      [ -z "$agent" ] && continue

      local agent_pid=$(get_agent_pid "$agent")

      if [ -n "$agent_pid" ] && ! kill -0 "$agent_pid" 2>/dev/null; then
        # Process finished
        wait "$agent_pid" 2>/dev/null
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
          log_event "FINISH" "$agent completed successfully (PID: $agent_pid)"
        else
          log_event "FINISH" "$agent failed (PID: $agent_pid, exit: $exit_code)"
        fi

        # Release slot
        mark_agent_idle "$agent"
      fi
    done <<< "$busy_agents"

    sleep $PROCESS_MONITOR_INTERVAL
  done
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

      if [ "$PARALLEL_DAEMON" = "true" ]; then
        # Parallel mode: Try to spawn, leave in queue if agent busy
        invoke_agent_parallel "$trigger_file"
        local result=$?

        if [ $result -eq 0 ]; then
          # Successfully spawned, archive trigger
          archive_trigger "$trigger_file" "in-progress"
          mark_as_processed "$trigger_file"
        elif [ $result -eq 2 ]; then
          # Parse error, archive as invalid
          archive_trigger "$trigger_file" "invalid"
          mark_as_processed "$trigger_file"
        fi
        # If result=1 (agent busy), leave trigger in queue
      else
        # Sequential mode: Process synchronously
        process_trigger "$trigger_file"
      fi
    done

    log_event "BACKLOG" "Backlog processing complete"
  fi
}

# process_trigger_queue_parallel - Main loop for parallel execution
# Continuously processes trigger queue with round-robin slot checking
process_trigger_queue_parallel() {
  while true; do
    local trigger_file=$(get_next_trigger)

    # No triggers, wait for new ones
    if [ -z "$trigger_file" ] || [ ! -f "$trigger_file" ]; then
      sleep 5
      continue
    fi

    # Skip if already processed
    if was_already_processed "$trigger_file"; then
      log_event "SKIP" "Already processed: $(basename "$trigger_file")"
      rm -f "$trigger_file" 2>/dev/null || true
      continue
    fi

    # Try to invoke agent
    invoke_agent_parallel "$trigger_file"
    local result=$?

    if [ $result -eq 0 ]; then
      # Successfully spawned
      archive_trigger "$trigger_file" "in-progress"
      mark_as_processed "$trigger_file"
      PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    elif [ $result -eq 2 ]; then
      # Parse error
      archive_trigger "$trigger_file" "invalid"
      mark_as_processed "$trigger_file"
    else
      # Agent busy, try next trigger (round-robin)
      log_event "QUEUE" "$(jq -r '.to_agent' "$trigger_file") busy, checking next trigger"
      sleep 1
    fi
  done
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Crash Recovery
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

resume_processing() {
  load_state

  # Parallel mode: Clean up orphaned PIDs
  if [ "$PARALLEL_DAEMON" = "true" ]; then
    log_event "RECOVERY" "Checking for orphaned agent processes"
    cleanup_orphaned_pids
  fi

  # Check for interrupted trigger (sequential mode only)
  if [ "$PARALLEL_DAEMON" != "true" ] && [ -f "$STATE_FILE" ]; then
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

  # Parallel mode: Kill all running agent processes
  if [ "$PARALLEL_DAEMON" = "true" ]; then
    log_event "STOP" "Terminating all running agents"

    # Get list of all busy agents
    local busy_agents=$(list_busy_agents 2>/dev/null || echo "")

    while IFS= read -r agent; do
      [ -z "$agent" ] && continue

      local agent_pid=$(get_agent_pid "$agent")

      if [ -n "$agent_pid" ] && kill -0 "$agent_pid" 2>/dev/null; then
        log_event "STOP" "Terminating $agent (PID: $agent_pid)"
        kill "$agent_pid" 2>/dev/null
        wait "$agent_pid" 2>/dev/null
      fi
    done <<< "$busy_agents"

    # Kill process monitor if running
    if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
      log_event "STOP" "Stopping process monitor (PID: $MONITOR_PID)"
      kill "$MONITOR_PID" 2>/dev/null
    fi

    # Kill queue processor if running
    if [ -n "$QUEUE_PID" ] && kill -0 "$QUEUE_PID" 2>/dev/null; then
      log_event "STOP" "Stopping queue processor (PID: $QUEUE_PID)"
      kill "$QUEUE_PID" 2>/dev/null
    fi
  fi

  # Kill orchestrator background process if running
  if [ -n "$ORCHESTRATOR_PID" ] && kill -0 "$ORCHESTRATOR_PID" 2>/dev/null; then
    log_event "STOP" "Stopping orchestrator process (PID: $ORCHESTRATOR_PID)"
    kill "$ORCHESTRATOR_PID" 2>/dev/null
  fi

  save_state ""
  exit 0
}

trap cleanup_and_exit SIGTERM SIGINT

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Orchestrator Periodic Check
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

orchestrator_check() {
  while true; do
    log_event "ORCHESTRATOR" "Running periodic check for ready issues"

    # Invoke orchestrator via Task tool to check for work and create triggers
    # IMPORTANT: Use imperative prompt - orchestrator is running autonomously in daemon mode
    if claude --print --permission-mode bypassPermissions "You are the orchestrator agent running in AUTONOMOUS DAEMON MODE.

CRITICAL: All permissions are PRE-APPROVED. Execute commands IMMEDIATELY without asking for confirmation or listing what you plan to do.

Execute this workflow NOW:

1. Run: gh issue list --label ready --json number,title,labels
2. Run: gh pr list --json number,title,labels
3. Read coordination status files in .claude/coordination/
4. For any idle junior-dev agent with a ready issue: create trigger file in .claude/triggers/
5. For any qa-approved PR: merge it directly

DO NOT:
- Ask \"Would you like me to proceed?\"
- List commands for approval
- Request permission for ANY operation
- Explain what you're going to do - just DO IT

All bash commands (gh, git, jq, cat, grep, etc.) are pre-approved in .claude/settings.json. Execute them directly. This is non-interactive batch mode." >> "$LOG_FILE" 2>&1; then
      log_event "ORCHESTRATOR" "Check complete"
    else
      log_event "ERROR" "Orchestrator check failed (exit: $?)"
    fi

    # Wait 60 seconds before next check
    sleep 60
  done
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Daemon Loop
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  log_event "START" "Daemon started (PID: $$)"

  # Log execution mode
  if [ "$PARALLEL_DAEMON" = "true" ]; then
    log_event "MODE" "Parallel execution enabled (max concurrent: $MAX_CONCURRENT_AGENTS)"
  else
    log_event "MODE" "Sequential execution (set PARALLEL_DAEMON=true for parallel mode)"
  fi

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

  # Start orchestrator periodic check loop in background
  log_event "ORCHESTRATOR" "Starting orchestrator periodic check (60s interval)"
  orchestrator_check &
  ORCHESTRATOR_PID=$!

  # Parallel mode: Start process monitor
  if [ "$PARALLEL_DAEMON" = "true" ]; then
    log_event "MONITOR" "Starting process monitor (checking every ${PROCESS_MONITOR_INTERVAL}s)"
    monitor_running_agents &
    MONITOR_PID=$!
  fi

  log_event "MONITOR" "Watching $TRIGGER_DIR for new triggers"

  if [ "$PARALLEL_DAEMON" = "true" ]; then
    # Parallel mode: Process queue continuously
    process_trigger_queue_parallel &
    QUEUE_PID=$!

    # Wait for all background processes
    wait
  else
    # Sequential mode: Use fswatch
    fswatch -0 --event Created "$TRIGGER_DIR" 2>/dev/null | while read -d "" event; do
      # Only process .trigger files
      if [[ "$event" == *.trigger ]]; then
        log_event "TRIGGER" "Detected: $(basename "$event")"
        process_trigger "$event"
      fi
    done &

    # Wait for fswatch process
    wait
  fi
}

# Run main daemon loop
main
