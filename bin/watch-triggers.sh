#!/bin/bash
# StarForge File Watcher for Trigger Directory
# Watches .claude/triggers/ for new .trigger files and routes them automatically
# Supports fswatch (macOS), inotifywait (Linux), and polling fallback

set -e

# Source project environment detection
# Try current directory first, then fallback to main repo
if [ -f ".claude/lib/project-env.sh" ]; then
  source .claude/lib/project-env.sh
elif [ -f "$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | cut -d' ' -f2)/.claude/lib/project-env.sh" ]; then
  source "$(git worktree list --porcelain 2>/dev/null | grep "^worktree" | head -1 | cut -d' ' -f2)/.claude/lib/project-env.sh"
else
  echo "ERROR: project-env.sh not found. Run 'starforge install' first."
  exit 1
fi

# Configuration
TRIGGER_DIR="$STARFORGE_CLAUDE_DIR/triggers"
PROCESSED_DIR="$TRIGGER_DIR/processed"
LOG_FILE="${WATCHER_LOG:-$STARFORGE_CLAUDE_DIR/watcher.log}"
POLL_INTERVAL=2  # seconds
SHUTDOWN=false

# Ensure directories exist
mkdir -p "$TRIGGER_DIR"
mkdir -p "$PROCESSED_DIR"

# Logging function
log() {
  local level=$1
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Graceful shutdown handler
shutdown_handler() {
  log "INFO" "Received SIGTERM, shutting down gracefully..."
  SHUTDOWN=true

  # Kill background processes
  if [ -n "$FSWATCH_PID" ]; then
    kill $FSWATCH_PID 2>/dev/null || true
  fi

  log "INFO" "Watcher stopped"
  exit 0
}

# Set up signal handlers
trap shutdown_handler SIGTERM SIGINT

# Route trigger to appropriate queue
route_trigger() {
  local trigger_file="$1"

  # Skip if file doesn't exist
  if [ ! -f "$trigger_file" ]; then
    return
  fi

  # Only process .trigger files
  if [[ ! "$trigger_file" =~ \.trigger$ ]]; then
    return
  fi

  local basename=$(basename "$trigger_file")
  log "INFO" "Processing trigger: $basename"

  # Parse trigger file
  if ! jq empty "$trigger_file" 2>/dev/null; then
    log "ERROR" "Invalid JSON in $basename"
    # Move to processed with error marker
    mv "$trigger_file" "$PROCESSED_DIR/${basename%.trigger}.invalid" 2>/dev/null || true
    return
  fi

  local to_agent=$(jq -r '.to_agent // empty' "$trigger_file" 2>/dev/null)
  local action=$(jq -r '.action // empty' "$trigger_file" 2>/dev/null)
  local from_agent=$(jq -r '.from_agent // empty' "$trigger_file" 2>/dev/null)

  if [ -z "$to_agent" ]; then
    log "ERROR" "Missing to_agent in $basename"
    mv "$trigger_file" "$PROCESSED_DIR/${basename%.trigger}.invalid" 2>/dev/null || true
    return
  fi

  log "INFO" "Routing: $from_agent -> $to_agent ($action)"

  # TODO: Route to queue when queue infrastructure is ready (issue #52, #59)
  # For now, just move to processed directory
  # Future: router.sh will handle queue placement

  # Check if router.sh exists and use it
  if [ -f "$STARFORGE_CLAUDE_DIR/lib/router.sh" ]; then
    source "$STARFORGE_CLAUDE_DIR/lib/router.sh"
    if type route_trigger_to_queue &>/dev/null; then
      route_trigger_to_queue "$trigger_file"
      log "INFO" "Routed $basename to queue"
    else
      # Fallback: move to processed
      mv "$trigger_file" "$PROCESSED_DIR/$basename" 2>/dev/null || true
      log "INFO" "Archived $basename (queue routing not available)"
    fi
  else
    # Fallback: move to processed
    mv "$trigger_file" "$PROCESSED_DIR/$basename" 2>/dev/null || true
    log "INFO" "Archived $basename (router.sh not available)"
  fi

  log "INFO" "Completed processing: $basename"
}

# Process existing triggers
process_existing_triggers() {
  log "INFO" "Processing existing triggers..."

  local count=0
  for trigger_file in "$TRIGGER_DIR"/*.trigger; do
    # Skip if glob didn't match any files
    [ -e "$trigger_file" ] || continue

    route_trigger "$trigger_file"
    count=$((count + 1))
  done

  if [ $count -gt 0 ]; then
    log "INFO" "Processed $count existing trigger(s)"
  else
    log "INFO" "No existing triggers found"
  fi
}

# Watch using fswatch (macOS)
watch_with_fswatch() {
  log "INFO" "Starting watcher with fswatch..."

  # Process existing triggers first
  process_existing_triggers

  log "INFO" "Watching $TRIGGER_DIR for new triggers (fswatch mode)"
  log "INFO" "Press Ctrl+C to stop"

  # Watch for file creation and modification events
  # -0: Use null separator for filenames
  # --event Created --event Updated: Only watch for new/modified files
  # -r: Recursive (though triggers dir should be flat)
  fswatch -0 --event Created --event Updated "$TRIGGER_DIR" 2>/dev/null | while read -d "" event; do
    # Check for shutdown
    if [ "$SHUTDOWN" = true ]; then
      break
    fi

    # Only process trigger files
    if [[ "$event" =~ \.trigger$ ]] && [ -f "$event" ]; then
      # Small delay to ensure file is fully written
      sleep 0.1
      route_trigger "$event"
    fi
  done &

  FSWATCH_PID=$!

  # Wait for shutdown signal
  wait $FSWATCH_PID 2>/dev/null || true
}

# Watch using inotifywait (Linux)
watch_with_inotifywait() {
  log "INFO" "Starting watcher with inotifywait..."

  # Process existing triggers first
  process_existing_triggers

  log "INFO" "Watching $TRIGGER_DIR for new triggers (inotifywait mode)"
  log "INFO" "Press Ctrl+C to stop"

  # Monitor for created and moved-to events (covering new files)
  inotifywait -m -e create -e moved_to --format '%w%f' "$TRIGGER_DIR" 2>/dev/null | while read event; do
    # Check for shutdown
    if [ "$SHUTDOWN" = true ]; then
      break
    fi

    # Only process trigger files
    if [[ "$event" =~ \.trigger$ ]] && [ -f "$event" ]; then
      # Small delay to ensure file is fully written
      sleep 0.1
      route_trigger "$event"
    fi
  done &

  INOTIFY_PID=$!

  # Wait for shutdown signal
  wait $INOTIFY_PID 2>/dev/null || true
}

# Watch using polling (fallback)
watch_with_polling() {
  log "INFO" "Starting watcher with polling fallback..."
  log "WARN" "File watcher not available. Using polling (interval: ${POLL_INTERVAL}s)"

  # Process existing triggers first
  process_existing_triggers

  log "INFO" "Watching $TRIGGER_DIR for new triggers (polling mode)"
  log "INFO" "Press Ctrl+C to stop"

  # Track seen files to avoid reprocessing
  local seen_file="$STARFORGE_CLAUDE_DIR/.watcher-seen"
  touch "$seen_file"

  while [ "$SHUTDOWN" = false ]; do
    for trigger_file in "$TRIGGER_DIR"/*.trigger; do
      # Skip if glob didn't match any files
      [ -e "$trigger_file" ] || continue

      local basename=$(basename "$trigger_file")

      # Skip if already seen
      if grep -Fxq "$basename" "$seen_file" 2>/dev/null; then
        continue
      fi

      # Process new trigger
      route_trigger "$trigger_file"

      # Mark as seen
      echo "$basename" >> "$seen_file"
    done

    # Clean up seen file periodically (keep last 1000 entries)
    if [ $(wc -l < "$seen_file") -gt 1000 ]; then
      tail -1000 "$seen_file" > "${seen_file}.tmp"
      mv "${seen_file}.tmp" "$seen_file"
    fi

    sleep $POLL_INTERVAL
  done
}

# Main: Detect available file watcher and start
main() {
  log "INFO" "StarForge Trigger Watcher starting..."
  log "INFO" "Trigger directory: $TRIGGER_DIR"
  log "INFO" "Log file: $LOG_FILE"

  # Force polling mode if USE_POLLING is set
  if [ "${USE_POLLING:-0}" = "1" ]; then
    watch_with_polling
  # Prefer fswatch (macOS)
  elif command -v fswatch &> /dev/null; then
    watch_with_fswatch
  # Fall back to inotifywait (Linux)
  elif command -v inotifywait &> /dev/null; then
    watch_with_inotifywait
  # Fall back to polling
  else
    watch_with_polling
  fi
}

# Run main
main
