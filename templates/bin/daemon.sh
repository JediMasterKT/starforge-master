#!/bin/bash
# StarForge Daemon Lifecycle Manager
# Manages daemon start/stop/status/restart operations

set -e

# Get StarForge directory
STARFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_DIR="$STARFORGE_DIR/.claude"
PID_FILE="$CLAUDE_DIR/daemon.pid"
LOCK_DIR="$CLAUDE_DIR/daemon.lock"
LOG_FILE="$CLAUDE_DIR/logs/daemon.log"
DAEMON_RUNNER="$CLAUDE_DIR/bin/starforged"

# Flags
SILENT_MODE=false
CHECK_ONLY_MODE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Output helper that respects silent mode
output() {
  if [ "$SILENT_MODE" = false ]; then
    echo -e "$@"
  fi
}

# Create required directories
mkdir -p "$CLAUDE_DIR/logs"
mkdir -p "$CLAUDE_DIR/triggers/processed/invalid"
mkdir -p "$CLAUDE_DIR/triggers/processed/failed"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Lock Management
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

create_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

remove_lock() {
  if [ -d "$LOCK_DIR" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}

check_stale_pid() {
  if [ ! -f "$PID_FILE" ]; then
    return 0  # No PID file, not stale
  fi

  local pid=$(cat "$PID_FILE")

  # Check if process exists
  if kill -0 "$pid" 2>/dev/null; then
    return 1  # Process exists, not stale
  else
    # Stale PID file
    output "${YELLOW}Cleaning up stale PID file (process $pid not found)${NC}"
    rm -f "$PID_FILE"
    remove_lock
    return 0
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Daemon Status
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

is_running() {
  if [ ! -f "$PID_FILE" ]; then
    return 1
  fi

  local pid=$(cat "$PID_FILE")

  if kill -0 "$pid" 2>/dev/null; then
    return 0  # Running
  else
    return 1  # Not running
  fi
}

get_uptime() {
  if [ ! -f "$PID_FILE" ]; then
    echo "N/A"
    return
  fi

  local pid=$(cat "$PID_FILE")

  if kill -0 "$pid" 2>/dev/null; then
    # Get process start time on macOS
    local start_time=$(ps -p "$pid" -o lstart= 2>/dev/null | xargs -I {} date -j -f "%a %b %d %T %Y" "{}" "+%s" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local uptime_seconds=$((current_time - start_time))

    if [ "$uptime_seconds" -lt 60 ]; then
      echo "${uptime_seconds}s"
    elif [ "$uptime_seconds" -lt 3600 ]; then
      echo "$((uptime_seconds / 60))m"
    else
      echo "$((uptime_seconds / 3600))h $((uptime_seconds % 3600 / 60))m"
    fi
  else
    echo "N/A"
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Daemon Operations
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

start_daemon() {
  # Check-only mode: just check if running and exit
  if [ "$CHECK_ONLY_MODE" = true ]; then
    if is_running; then
      output "${GREEN}Daemon is running${NC}"
      return 0
    else
      output "${YELLOW}Daemon is not running${NC}"
      return 1
    fi
  fi

  output "${BLUE}Starting StarForge daemon...${NC}"

  # Clean up stale state
  check_stale_pid

  # Check if already running
  if is_running; then
    local pid=$(cat "$PID_FILE")
    output "${YELLOW}Daemon already running (PID: $pid)${NC}"
    return 0  # Return success (0) when already running for idempotent behavior
  fi

  # Create lock
  if ! create_lock; then
    output "${RED}Failed to acquire lock. Another daemon may be starting.${NC}"
    return 1
  fi

  # Check if starforged daemon exists
  if [ ! -f "$DAEMON_RUNNER" ]; then
    output "${RED}Error: starforged daemon not found at $DAEMON_RUNNER${NC}"
    remove_lock
    return 1
  fi

  # Check for fswatch
  if ! command -v fswatch &> /dev/null; then
    output "${RED}Error: fswatch not installed${NC}"
    output "${YELLOW}Install with: brew install fswatch${NC}"
    remove_lock
    return 1
  fi

  # Start daemon in background
  nohup bash "$DAEMON_RUNNER" >> "$LOG_FILE" 2>&1 &
  local pid=$!

  # Save PID
  echo "$pid" > "$PID_FILE"

  # Verify it started
  sleep 0.5
  if kill -0 "$pid" 2>/dev/null; then
    output "${GREEN}✓ Daemon started successfully (PID: $pid)${NC}"
    output "${BLUE}Logs: $LOG_FILE${NC}"
    return 0
  else
    output "${RED}✗ Daemon failed to start${NC}"
    rm -f "$PID_FILE"
    remove_lock
    return 1
  fi
}

stop_daemon() {
  echo -e "${BLUE}Stopping StarForge daemon...${NC}"

  if ! is_running; then
    echo -e "${YELLOW}Daemon is not running${NC}"
    remove_lock
    return 0
  fi

  local pid=$(cat "$PID_FILE")

  # Send SIGTERM for graceful shutdown
  echo -e "${BLUE}Sending SIGTERM to PID $pid...${NC}"
  kill -TERM "$pid" 2>/dev/null || true

  # Wait for graceful shutdown (max 5 seconds)
  local waited=0
  while kill -0 "$pid" 2>/dev/null && [ $waited -lt 5 ]; do
    sleep 0.5
    waited=$((waited + 1))
  done

  # Force kill if still running
  if kill -0 "$pid" 2>/dev/null; then
    echo -e "${YELLOW}Graceful shutdown timed out, forcing...${NC}"
    kill -KILL "$pid" 2>/dev/null || true
    sleep 0.5
  fi

  # Clean up
  rm -f "$PID_FILE"
  remove_lock

  if kill -0 "$pid" 2>/dev/null; then
    echo -e "${RED}✗ Failed to stop daemon${NC}"
    return 1
  else
    echo -e "${GREEN}✓ Daemon stopped successfully${NC}"
    return 0
  fi
}

status_daemon() {
  if is_running; then
    local pid=$(cat "$PID_FILE")
    local uptime=$(get_uptime)

    echo -e "${GREEN}Daemon is running${NC}"
    echo -e "  PID: $pid"
    echo -e "  Uptime: $uptime"
    echo -e "  Log: $LOG_FILE"

    # Load queue status library
    if [ -f "$STARFORGE_DIR/templates/lib/queue-status.sh" ]; then
      source "$STARFORGE_DIR/templates/lib/queue-status.sh"

      # Show queue status
      echo -e "\n${BLUE}Queue Status:${NC}"
      local queue_json=$(get_queue_status)
      local pending=$(echo "$queue_json" | jq -r '.pending')
      local processing=$(echo "$queue_json" | jq -r '.processing')
      local completed=$(echo "$queue_json" | jq -r '.completed_1h')
      local failed=$(echo "$queue_json" | jq -r '.failed_1h')
      local dlq=$(echo "$queue_json" | jq -r '.dlq')

      echo -e "  Pending: $pending"
      echo -e "  Processing: $processing"
      echo -e "  Completed (1h): $completed"
      echo -e "  Failed (1h): $failed"
      if [ "$dlq" -gt 0 ]; then
        echo -e "  ${YELLOW}Dead Letter Queue: $dlq${NC}"
      fi

      # Show busy agents
      local agents_json=$(get_agent_status)
      local busy_count=$(echo "$agents_json" | jq -r 'length')
      if [ "$busy_count" -gt 0 ]; then
        echo -e "\n${BLUE}Busy Agents:${NC}"
        echo "$agents_json" | jq -r '.[] | "  \(.agent): \(.trigger)"'
      fi
    fi

    # Show recent activity
    if [ -f "$LOG_FILE" ]; then
      echo -e "\n${BLUE}Recent activity:${NC}"
      tail -5 "$LOG_FILE" | sed 's/^/  /'
    fi

    return 0
  else
    echo -e "${YELLOW}Daemon is not running${NC}"

    # Show last log entries if available
    if [ -f "$LOG_FILE" ]; then
      echo -e "\n${BLUE}Last activity:${NC}"
      tail -5 "$LOG_FILE" | sed 's/^/  /'
    fi

    return 1
  fi
}

restart_daemon() {
  echo -e "${BLUE}Restarting StarForge daemon...${NC}"

  if is_running; then
    stop_daemon || return 1
    sleep 1
  fi

  start_daemon
}

logs_daemon() {
  if [ ! -f "$LOG_FILE" ]; then
    echo -e "${YELLOW}No log file found${NC}"
    return 1
  fi

  echo -e "${BLUE}Tailing daemon logs (Ctrl+C to stop)...${NC}"
  tail -f "$LOG_FILE"
}

show_help() {
  cat << EOF
${BLUE}StarForge Daemon Manager${NC}

Manages the StarForge daemon for autonomous agent operation.

${YELLOW}Usage:${NC}
  starforge daemon [flags] <command>

${YELLOW}Commands:${NC}
  start      Start the daemon in background
  stop       Stop the daemon gracefully
  restart    Restart the daemon
  status     Show daemon status and recent activity
  logs       Tail the daemon log file
  help       Show this help message

${YELLOW}Flags:${NC}
  --silent       Suppress all output (useful for scripts)
  --check-only   Check if daemon is running without starting it

${YELLOW}Examples:${NC}
  starforge daemon start
  starforge daemon status
  starforge daemon logs
  starforge daemon --silent start           # Start quietly
  starforge daemon --check-only start       # Check if running

${YELLOW}Files:${NC}
  PID:   $PID_FILE
  Lock:  $LOCK_DIR
  Log:   $LOG_FILE

${YELLOW}Requirements:${NC}
  - fswatch (install: brew install fswatch)
  - jq (install: brew install jq)

EOF
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Parse flags and command
COMMAND=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --silent)
      SILENT_MODE=true
      shift
      ;;
    --check-only)
      CHECK_ONLY_MODE=true
      shift
      ;;
    start|stop|restart|status|logs|help|--help|-h)
      COMMAND="$1"
      shift
      break
      ;;
    *)
      if [ -z "$COMMAND" ]; then
        COMMAND="$1"
        shift
      else
        echo -e "${RED}Error: Unknown flag '$1'${NC}"
        echo ""
        show_help
        exit 1
      fi
      ;;
  esac
done

case "$COMMAND" in
  start)
    start_daemon
    ;;
  stop)
    stop_daemon
    ;;
  restart)
    restart_daemon
    ;;
  status)
    status_daemon
    ;;
  logs)
    logs_daemon
    ;;
  help|--help|-h)
    show_help
    ;;
  "")
    echo -e "${RED}Error: No command specified${NC}"
    echo ""
    show_help
    exit 1
    ;;
  *)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
    echo ""
    show_help
    exit 1
    ;;
esac
