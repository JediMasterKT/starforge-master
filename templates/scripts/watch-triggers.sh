#!/bin/bash
# Watches for agent triggers and notifies human using fswatch

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

echo "👀 Watching for agent triggers (using fswatch)..."
echo "Press Ctrl+C to stop"
echo ""

# Function to process a trigger file
process_trigger() {
  local trigger_file="$1"
  
  # Only process .trigger files (not .processed or other files)
  if [[ ! "$trigger_file" =~ \.trigger$ ]]; then
    return
  fi
  
  # Skip if file doesn't exist (might have been processed already)
  if [ ! -f "$trigger_file" ]; then
    return
  fi
  
  # Parse trigger
  TO_AGENT=$(jq -r .to_agent "$trigger_file" 2>/dev/null)
  MESSAGE=$(jq -r .message "$trigger_file" 2>/dev/null)
  COMMAND=$(jq -r .command "$trigger_file" 2>/dev/null)
  
  # Skip if jq parsing failed
  if [ -z "$TO_AGENT" ] || [ "$TO_AGENT" = "null" ]; then
    return
  fi
  
  # Display notification
  echo ""
  echo "🔔 ================================"
  echo "   AGENT HANDOFF NEEDED"
  echo "================================"
  echo "→ Next agent: $TO_AGENT"
  echo "→ Action: $MESSAGE"
  echo ""
  echo "📋 Command to run:"
  echo "   $COMMAND"
  echo ""
  echo "================================"
  echo ""
  
  # macOS desktop notification
  if command -v osascript &> /dev/null; then
    osascript -e "display notification \"$MESSAGE\" with title \"Agent Handoff: $TO_AGENT\"" 2>/dev/null
  fi
  
  # Copy command to clipboard
  if command -v pbcopy &> /dev/null; then
    echo "$COMMAND" | pbcopy
    echo "✅ Command copied to clipboard"
  fi
  
  # Archive trigger
  mv "$trigger_file" "$TRIGGER_DIR/processed/$(basename "$trigger_file")" 2>/dev/null
}

# Watch for file creation/modification events
# -0: Use null separator (handles filenames with spaces)
# --event Created --event Updated: Only watch for new/modified files
fswatch -0 --event Created --event Updated "$TRIGGER_DIR" | while read -d "" event; do
  process_trigger "$event"
done