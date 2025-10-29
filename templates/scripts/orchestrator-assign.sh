#!/bin/bash
# Orchestrator Atomic Ticket Assignment
# Purpose: Bundle 10+ assignment operations into 1 permission-free script
# Impact: 10 prompts → 1 prompt per assignment × 3 agents = 27 prompts saved
#
# Workaround for: https://github.com/anthropics/claude-code/issues/5465
# (Permission patterns fail to match piped commands)

set -e  # Exit on any error

# Load lock helpers for agent coordination
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/lock-helpers.sh"

# Validate arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: orchestrator-assign.sh TICKET AGENT"
    echo "Example: orchestrator-assign.sh 104 junior-dev-a"
    exit 1
fi

TICKET=$1
AGENT=$2

# Validate ticket is a number
if ! [[ "$TICKET" =~ ^[0-9]+$ ]]; then
    echo "❌ ERROR: TICKET must be a number, got: $TICKET"
    exit 1
fi

# Validate agent name
if ! [[ "$AGENT" =~ ^junior-dev-[a-c]$ ]]; then
    echo "❌ ERROR: AGENT must be junior-dev-a, junior-dev-b, or junior-dev-c, got: $AGENT"
    exit 1
fi

# Ensure environment is loaded
if [ -z "$STARFORGE_PROJECT_NAME" ]; then
    echo "❌ ERROR: Environment not loaded. Run: source .claude/scripts/agent-init.sh"
    exit 1
fi

WORKTREE="$HOME/${STARFORGE_PROJECT_NAME}-${AGENT}"

echo "========================================="
echo "ASSIGNING TICKET #$TICKET TO $AGENT"
echo "========================================="

# Step 1: Verify ticket exists
echo "📋 Step 1/8: Verifying ticket exists..."
if ! gh issue view $TICKET > /dev/null 2>&1; then
    echo "❌ Ticket #$TICKET not found in GitHub"
    exit 1
fi
echo "✅ Ticket #$TICKET verified"

# Step 2: Update GitHub issue labels
echo "🏷️  Step 2/8: Updating GitHub labels..."
gh issue edit $TICKET --add-label "in-progress" --remove-label "ready"
echo "✅ Labels updated: ready → in-progress"

# Step 3: Add GitHub comment
echo "💬 Step 3/8: Adding assignment comment..."
gh issue comment $TICKET --body "Assigned to $AGENT. Starting implementation."
echo "✅ Comment added"

# Step 4: Verify worktree exists
echo "📁 Step 4/8: Verifying worktree..."
if [ ! -d "$WORKTREE" ]; then
    echo "❌ Worktree not found: $WORKTREE"
    echo "   Create it with: git worktree add $WORKTREE main"
    exit 1
fi
echo "✅ Worktree verified: $WORKTREE"

# Step 5: Fetch latest main
echo "🔄 Step 5/8: Fetching latest main..."
cd "$WORKTREE"
git fetch origin main
echo "✅ Fetched origin/main"

# Step 6: Create feature branch from origin/main
echo "🌿 Step 6/8: Creating feature branch..."
BRANCH="feature/ticket-${TICKET}"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "⚠️  Branch $BRANCH already exists, deleting..."
    git branch -D "$BRANCH"
fi
git checkout -b "$BRANCH" origin/main
echo "✅ Created branch: $BRANCH (from origin/main)"

# Step 7: Create coordination status file (WITH LOCK)
echo "📝 Step 7/8: Creating status file..."
cd "$STARFORGE_MAIN_REPO"

# Acquire lock on agent to prevent concurrent assignments
if ! lock_agent "$AGENT" 30; then
  echo "❌ ERROR: Could not acquire lock on $AGENT (another orchestrator may be assigning)"
  echo "   This agent is likely already being assigned. Choose a different agent."
  exit 1
fi

# Ensure lock is released on ANY exit (normal or error)
trap 'unlock_agent "$AGENT"' EXIT ERR

# Check if agent is already assigned (double-check after acquiring lock)
STATUS_FILE="$STARFORGE_CLAUDE_DIR/coordination/${AGENT}-status.json"
if [ -f "$STATUS_FILE" ]; then
  CURRENT_STATUS=$(jq -r '.status' "$STATUS_FILE" 2>/dev/null || echo "unknown")
  if [ "$CURRENT_STATUS" = "working" ]; then
    CURRENT_TICKET=$(jq -r '.ticket' "$STATUS_FILE" 2>/dev/null || echo "unknown")
    unlock_agent "$AGENT"
    echo "❌ ERROR: $AGENT is already working on ticket #$CURRENT_TICKET"
    echo "   Cannot assign ticket #$TICKET to busy agent."
    exit 1
  fi
fi

# Write status file (protected by lock)
jq -n \
  --arg agent "$AGENT" \
  --arg ticket "$TICKET" \
  --arg assigned_at "$(date -Iseconds)" \
  --arg worktree "${STARFORGE_PROJECT_NAME}-${AGENT}" \
  --arg branch "$BRANCH" \
  '{
    agent: $agent,
    status: "working",
    ticket: ($ticket | tonumber),
    assigned_at: $assigned_at,
    worktree: $worktree,
    branch: $branch,
    based_on: "origin/main"
  }' > "$STATUS_FILE"
echo "✅ Status file created: $STATUS_FILE"

# Release lock (agent is now marked as working)
unlock_agent "$AGENT"

# Step 8: Create trigger for junior-dev
echo "🔔 Step 8/8: Creating trigger..."
# Load trigger helpers if not already loaded
if ! type trigger_junior_dev &> /dev/null; then
    source "$STARFORGE_CLAUDE_DIR/scripts/trigger-helpers.sh"
fi

trigger_junior_dev "$AGENT" $TICKET

# Verify trigger was created
sleep 1  # Allow filesystem sync
TRIGGER_FILE=$(ls -t "$STARFORGE_CLAUDE_DIR/triggers/${AGENT}-implement_ticket-"*.trigger 2>/dev/null | head -1)

if [ ! -f "$TRIGGER_FILE" ]; then
    echo "❌ TRIGGER CREATION FAILED"
    echo "   Rolling back assignment..."
    gh issue edit $TICKET --remove-label "in-progress" --add-label "ready"
    rm -f "$STATUS_FILE"
    exit 1
fi

# Validate trigger JSON
if ! jq empty "$TRIGGER_FILE" 2>/dev/null; then
    echo "❌ TRIGGER INVALID JSON"
    cat "$TRIGGER_FILE"
    exit 1
fi

# Verify trigger fields
TO_AGENT=$(jq -r '.to_agent' "$TRIGGER_FILE")
ACTION=$(jq -r '.action' "$TRIGGER_FILE")
TICKET_IN_TRIGGER=$(jq -r '.context.ticket' "$TRIGGER_FILE")

if [ "$TO_AGENT" != "$AGENT" ] || [ "$ACTION" != "implement_ticket" ] || [ "$TICKET_IN_TRIGGER" != "$TICKET" ]; then
    echo "❌ TRIGGER DATA MISMATCH"
    echo "   Expected: $AGENT/implement_ticket/ticket=$TICKET"
    echo "   Got: $TO_AGENT/$ACTION/ticket=$TICKET_IN_TRIGGER"
    exit 1
fi

echo "✅ Trigger created and verified: $(basename $TRIGGER_FILE)"

echo ""
echo "========================================="
echo "✅ ASSIGNMENT COMPLETE"
echo "========================================="
echo "Ticket:   #$TICKET"
echo "Agent:    $AGENT"
echo "Branch:   $BRANCH"
echo "Worktree: $WORKTREE"
echo "Trigger:  $(basename $TRIGGER_FILE)"
echo "========================================="
