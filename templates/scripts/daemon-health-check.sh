#!/bin/bash
# StarForge Daemon Health Monitor
# Checks daemon heartbeat and reports health status

set -e

# Get project root
PROJECT_ROOT="$(pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
HEARTBEAT_FILE="$CLAUDE_DIR/heartbeat.timestamp"
PID_FILE="$CLAUDE_DIR/daemon.pid"

# Configuration
HEARTBEAT_TIMEOUT=120  # 2 minutes (4 missed heartbeats at 30s interval)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if daemon PID file exists
if [ ! -f "$PID_FILE" ]; then
  echo -e "${YELLOW}⚠ Daemon not running (no PID file)${NC}"
  exit 1
fi

# Get daemon PID
DAEMON_PID=$(cat "$PID_FILE")

# Check if daemon process is alive
if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
  echo -e "${RED}✗ Daemon process not found (PID: $DAEMON_PID)${NC}"
  echo -e "${YELLOW}Stale PID file detected. Run: starforge daemon stop${NC}"
  exit 2
fi

# Check if heartbeat file exists
if [ ! -f "$HEARTBEAT_FILE" ]; then
  echo -e "${RED}✗ No heartbeat file found${NC}"
  echo -e "${YELLOW}Daemon may be starting up or unhealthy${NC}"
  exit 3
fi

# Read heartbeat timestamp
HEARTBEAT_JSON=$(cat "$HEARTBEAT_FILE")
HEARTBEAT_TS=$(echo "$HEARTBEAT_JSON" | jq -r '.timestamp')
HEARTBEAT_PID=$(echo "$HEARTBEAT_JSON" | jq -r '.pid')

# Validate heartbeat PID matches daemon PID
if [ "$HEARTBEAT_PID" != "$DAEMON_PID" ]; then
  echo -e "${RED}✗ Heartbeat PID mismatch${NC}"
  echo -e "  Expected: $DAEMON_PID"
  echo -e "  Got: $HEARTBEAT_PID"
  echo -e "${YELLOW}Daemon may have been restarted. Check logs.${NC}"
  exit 4
fi

# Convert heartbeat timestamp to epoch
# macOS date format handling
if date --version >/dev/null 2>&1; then
  # GNU date (Linux)
  HEARTBEAT_EPOCH=$(date -d "$HEARTBEAT_TS" +%s 2>/dev/null || echo "0")
else
  # BSD date (macOS)
  HEARTBEAT_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$HEARTBEAT_TS" +%s 2>/dev/null || echo "0")
fi

if [ "$HEARTBEAT_EPOCH" = "0" ]; then
  echo -e "${RED}✗ Failed to parse heartbeat timestamp: $HEARTBEAT_TS${NC}"
  exit 5
fi

# Get current time
CURRENT_EPOCH=$(date +%s)

# Calculate age
AGE=$((CURRENT_EPOCH - HEARTBEAT_EPOCH))

# Check if heartbeat is stale
if [ $AGE -gt $HEARTBEAT_TIMEOUT ]; then
  echo -e "${RED}✗ Daemon heartbeat stale (age: ${AGE}s, threshold: ${HEARTBEAT_TIMEOUT}s)${NC}"
  echo -e "  Last heartbeat: $HEARTBEAT_TS"
  echo -e "  Daemon PID: $DAEMON_PID"
  echo -e "${YELLOW}Daemon may be hung. Run: starforge daemon restart${NC}"
  exit 6
fi

# Healthy
echo -e "${GREEN}✓ Daemon healthy${NC}"
echo -e "  PID: $DAEMON_PID"
echo -e "  Last heartbeat: $HEARTBEAT_TS (${AGE}s ago)"
exit 0
