#!/bin/bash
# Event-Driven Trigger Monitor - Uses fswatch for instant detection
# Requires: fswatch (brew install fswatch)

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

# Use environment variables from project-env.sh
TRIGGER_DIR="$STARFORGE_CLAUDE_DIR/triggers"
PROCESSED_DIR="$STARFORGE_CLAUDE_DIR/triggers/processed"
LOG_FILE="$STARFORGE_CLAUDE_DIR/trigger-monitor.log"
SEEN_FILE="$STARFORGE_CLAUDE_DIR/.trigger-monitor-seen"

# Ensure directories exist
mkdir -p "$TRIGGER_DIR"
mkdir -p "$PROCESSED_DIR"

# Initialize seen file if doesn't exist
touch "$SEEN_FILE"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🤖 AGENT TRIGGER MONITOR - EVENT-DRIVEN     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}👀 Watching:${NC} $TRIGGER_DIR"
echo -e "${YELLOW}📝 Logging:${NC} $LOG_FILE"
echo -e "${YELLOW}📦 Archive:${NC} $PROCESSED_DIR"
echo -e "${YELLOW}🔧 Mode:${NC} fswatch (event-driven, instant detection)"
echo ""

# Check if fswatch is installed
if ! command -v fswatch >/dev/null 2>&1; then
  echo -e "${RED}❌ ERROR: fswatch not found${NC}"
  echo -e "${YELLOW}Install with: brew install fswatch${NC}"
  exit 1
fi

# Check for existing triggers on startup
shopt -s nullglob
existing_triggers=("$TRIGGER_DIR"/*.trigger)
shopt -u nullglob

EXISTING_COUNT=${#existing_triggers[@]}

if [ $EXISTING_COUNT -gt 0 ]; then
  echo -e "${YELLOW}⚠️  Found $EXISTING_COUNT unprocessed trigger(s)${NC}"
  echo -e "${YELLOW}📋 Processing backlog...${NC}"
  echo ""
fi

# Log start
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Monitor started (event-driven, found $EXISTING_COUNT existing triggers)" >> "$LOG_FILE"

# Cleanup function on exit
cleanup() {
  echo ""
  echo -e "${YELLOW}🛑 Stopping trigger monitor...${NC}"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Monitor stopped" >> "$LOG_FILE"
  exit 0
}

trap cleanup SIGINT SIGTERM

# Function to check if file was already seen
was_seen() {
  local filename="$1"
  grep -Fxq "$filename" "$SEEN_FILE" 2>/dev/null
  return $?
}

# Function to mark file as seen
mark_seen() {
  local filename="$1"
  echo "$filename" >> "$SEEN_FILE"
}

# Function to process a trigger
process_trigger() {
  local trigger_file="$1"
  
  # Validate file path
  if [ ! -f "$trigger_file" ]; then
    return
  fi
  
  # Only process .trigger files
  if [[ ! "$trigger_file" == *.trigger ]]; then
    return
  fi
  
  local filename=$(basename "$trigger_file")
  
  # Skip if already processed
  if was_seen "$filename"; then
    return
  fi
  
  # Small delay to ensure file is fully written
  sleep 0.1
  
  # Parse trigger JSON
  FROM_AGENT=$(jq -r .from_agent "$trigger_file" 2>/dev/null || echo "null")
  TO_AGENT=$(jq -r .to_agent "$trigger_file" 2>/dev/null || echo "null")
  ACTION=$(jq -r .action "$trigger_file" 2>/dev/null || echo "null")
  MESSAGE=$(jq -r .message "$trigger_file" 2>/dev/null || echo "null")
  COMMAND=$(jq -r .command "$trigger_file" 2>/dev/null || echo "null")
  TIMESTAMP=$(jq -r .timestamp "$trigger_file" 2>/dev/null || echo "null")
  
  # Validate JSON parsing
  if [ "$FROM_AGENT" == "null" ] || [ "$TO_AGENT" == "null" ]; then
    echo -e "${RED}❌ Invalid trigger file: $filename${NC}"
    mark_seen "$filename"
    mv "$trigger_file" "$PROCESSED_DIR/invalid-$filename" 2>/dev/null
    return
  fi
  
  # Display notification in terminal
  echo -e "${MAGENTA}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${MAGENTA}║         🔔 AGENT HANDOFF TRIGGERED            ║${NC}"
  echo -e "${MAGENTA}╚════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${CYAN}⏰ Time:${NC}        $TIMESTAMP"
  echo -e "${CYAN}🤖 From:${NC}        $FROM_AGENT"
  echo -e "${CYAN}👉 To:${NC}          $TO_AGENT"
  echo -e "${CYAN}🎯 Action:${NC}      $ACTION"
  echo -e "${GREEN}📋 Message:${NC}     $MESSAGE"
  echo ""
  echo -e "${YELLOW}💻 Next Command:${NC}"
  echo -e "${BLUE}   $COMMAND${NC}"
  echo ""
  echo "────────────────────────────────────────────────"
  echo ""
  
  # macOS Desktop Notification
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "🤖 Agent Handoff" -subtitle "$FROM_AGENT → $TO_AGENT" -message "$MESSAGE" -sender com.googlecode.iterm2 >/dev/null 2>&1 || true
    # Play sound separately (terminal-notifier sound doesn't work with -sender)
    afplay /System/Library/Sounds/Ping.aiff 2>/dev/null &
  elif command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"$MESSAGE\" with title \"🤖 Agent Handoff\" subtitle \"$FROM_AGENT → $TO_AGENT\" sound name \"Ping\"" 2>/dev/null || true
  fi
  
  # Copy command to clipboard (macOS)
  if command -v pbcopy >/dev/null 2>&1; then
    echo "$COMMAND" | pbcopy 2>/dev/null || true
    echo -e "${GREEN}✅ Command copied to clipboard!${NC}"
    echo ""
  fi
  
  # Log the trigger
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $FROM_AGENT → $TO_AGENT | $ACTION | $MESSAGE" >> "$LOG_FILE"
  
  # Mark as seen BEFORE archiving (prevents race conditions)
  mark_seen "$filename"
  
  # Archive trigger (move to processed)
  PROCESSED_FILE="$PROCESSED_DIR/$(date +'%Y%m%d-%H%M%S')-$filename"
  mv "$trigger_file" "$PROCESSED_FILE" 2>/dev/null || true
  
  echo -e "${GREEN}📦 Trigger archived to: $(basename "$PROCESSED_FILE")${NC}"
  echo ""
  echo "════════════════════════════════════════════════"
  echo ""
}

# Process existing triggers (backlog)
for trigger_file in "${existing_triggers[@]}"; do
  process_trigger "$trigger_file"
done

if [ $EXISTING_COUNT -gt 0 ]; then
  echo -e "${GREEN}✅ Backlog processed ($EXISTING_COUNT triggers)${NC}"
  echo ""
fi

echo -e "${GREEN}✅ Monitor active. Listening for filesystem events...${NC}"
echo -e "${YELLOW}   Press Ctrl+C to stop.${NC}"
echo ""
echo "────────────────────────────────────────────────"
echo ""

# Start event-driven monitoring with fswatch
# -0: Use NUL character as separator
# -e Created: Only watch for file creation events
# -r: Recursive (though we only have one dir)
fswatch -0 --event Created "$TRIGGER_DIR" | while read -d "" event; do
  # fswatch returns full path to changed file
  if [[ "$event" == *.trigger ]]; then
    process_trigger "$event"
  fi
done