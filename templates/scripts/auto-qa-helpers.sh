#!/bin/bash
# Auto-QA Helper Functions
# Safety mechanisms for automatic QA trigger creation
# Purpose: Idempotent detection, duplicate prevention, multi-instance safety

# Source project environment
if [ -f ".claude/lib/project-env.sh" ]; then
  source .claude/lib/project-env.sh
else
  echo "ERROR: project-env.sh not found. Run 'starforge install' first."
  exit 1
fi

TRIGGER_DIR="${STARFORGE_CLAUDE_DIR}/triggers"
AUTO_QA_LOG="${STARFORGE_CLAUDE_DIR}/metrics/auto-qa.log"

# Ensure directories exist
mkdir -p "$TRIGGER_DIR"
mkdir -p "$(dirname "$AUTO_QA_LOG")"
touch "$AUTO_QA_LOG"

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Idempotent Detection (Prevents Duplicate Triggers)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if QA trigger already exists for a PR
# Returns 0 (true) if trigger exists, 1 (false) if safe to create
trigger_exists_for_pr() {
  local pr=$1

  # Check 1: Trigger file exists (active or processed)
  if ls "$TRIGGER_DIR"/*qa-engineer*pr_${pr}-* 2>/dev/null | grep -q .; then
    return 0  # Trigger exists
  fi

  if ls "$TRIGGER_DIR"/processed/*qa-engineer*pr_${pr}-* 2>/dev/null | grep -q .; then
    return 0  # Trigger already processed
  fi

  # Check 2: QA already commented on PR
  if command -v gh &> /dev/null; then
    if gh pr view "$pr" --json comments --jq '.comments[].author.login' 2>/dev/null | grep -q "qa-engineer"; then
      return 0  # QA already engaged
    fi
  fi

  # Check 3: PR already has qa-approved or qa-declined label
  if command -v gh &> /dev/null; then
    if gh pr view "$pr" --json labels --jq '.labels[].name' 2>/dev/null | grep -qE "qa-approved|qa-declined"; then
      return 0  # QA already completed
    fi
  fi

  return 1  # Safe to create trigger
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Atomic Trigger Creation
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Create QA trigger with unique ID (nanosecond precision)
# Multi-instance safe: Different instances will create different filenames
create_qa_trigger_for_pr() {
  local pr=$1
  local from_agent=${2:-"auto-qa"}

  # Get PR metadata
  local ticket=""
  local pr_title=""

  if command -v gh &> /dev/null; then
    # Extract ticket number from PR title or body
    ticket=$(gh pr view "$pr" --json title,body --jq '.title + " " + .body' 2>/dev/null | grep -oP '#\K\d+' | head -1 || echo "")
    pr_title=$(gh pr view "$pr" --json title --jq '.title' 2>/dev/null || echo "PR #${pr}")
  fi

  # Generate unique timestamp (nanosecond precision on Linux, milliseconds on macOS)
  local timestamp
  if date --version 2>&1 | grep -q GNU; then
    timestamp=$(date +%s%N)  # Linux: nanoseconds
  else
    timestamp=$(date +%s)$(( RANDOM % 1000 ))  # macOS: seconds + random milliseconds
  fi

  local trigger_file="$TRIGGER_DIR/qa-engineer-review_pr_${pr}-${timestamp}.trigger"

  # Create trigger JSON
  cat > "$trigger_file" << TRIGGER
{
  "from_agent": "$from_agent",
  "to_agent": "qa-engineer",
  "action": "review_pr",
  "context": {
    "pr": $pr,
    "ticket": ${ticket:-null},
    "auto_triggered": true
  },
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "message": "PR #${pr} ready for review${ticket:+ (ticket #$ticket)}",
  "command": "Use qa-engineer. Review PR #${pr}."
}
TRIGGER

  # Validate JSON
  if ! jq empty "$trigger_file" 2>/dev/null; then
    echo "ERROR: Invalid JSON in trigger file"
    rm -f "$trigger_file"
    return 1
  fi

  # Log creation
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] AUTO-QA: Created trigger for PR #${pr} → $trigger_file" >> "$AUTO_QA_LOG"

  return 0
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PR Discovery (GitHub API)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Get list of PRs with "needs-review" label
get_prs_needing_review() {
  if ! command -v gh &> /dev/null; then
    echo "ERROR: gh CLI not installed"
    return 1
  fi

  # Get PRs with needs-review label, output as JSON array
  gh pr list --label "needs-review" --json number --jq '.[].number' 2>/dev/null || echo ""
}

# Check if PR is still open and mergeable
is_pr_valid() {
  local pr=$1

  if ! command -v gh &> /dev/null; then
    return 1
  fi

  local state=$(gh pr view "$pr" --json state --jq '.state' 2>/dev/null)

  if [ "$state" = "OPEN" ]; then
    return 0
  else
    return 1
  fi
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Metrics & Logging
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Log auto-QA activity
log_auto_qa() {
  local level=$1
  local message=$2
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] AUTO-QA-${level}: ${message}" >> "$AUTO_QA_LOG"
}

# Get auto-QA metrics
get_auto_qa_metrics() {
  if [ ! -f "$AUTO_QA_LOG" ]; then
    echo "No metrics available"
    return
  fi

  local total_triggers=$(grep -c "Created trigger" "$AUTO_QA_LOG" 2>/dev/null || echo "0")
  local skipped=$(grep -c "SKIP" "$AUTO_QA_LOG" 2>/dev/null || echo "0")
  local errors=$(grep -c "ERROR" "$AUTO_QA_LOG" 2>/dev/null || echo "0")

  cat << METRICS
Auto-QA Metrics:
  Total triggers created: $total_triggers
  Skipped (already exists): $skipped
  Errors: $errors
METRICS
}
