#!/bin/bash
# Smoke test for parallel daemon execution
# Manual test to verify parallel processing actually works

set -e

echo "=========================================="
echo "Parallel Daemon Smoke Test"
echo "=========================================="
echo ""

# Setup test environment
TEST_DIR=$(mktemp -d)
export PROJECT_ROOT="$TEST_DIR"
export CLAUDE_DIR="$PROJECT_ROOT/.claude"
export TRIGGER_DIR="$CLAUDE_DIR/triggers"
export PARALLEL_DAEMON=true
export MAX_CONCURRENT_AGENTS=3

echo "Test environment: $TEST_DIR"
echo "Parallel mode: $PARALLEL_DAEMON"
echo "Max concurrent: $MAX_CONCURRENT_AGENTS"
echo ""

# Create directory structure
mkdir -p "$TRIGGER_DIR"
mkdir -p "$CLAUDE_DIR/daemon"
mkdir -p "$CLAUDE_DIR/logs"

# Copy daemon runner to test dir
cp "$(dirname "$0")/../templates/bin/starforged" "$TEST_DIR/starforged"
cp "$(dirname "$0")/../templates/lib/agent-slots.sh" "$CLAUDE_DIR/agent-slots.sh"

# Modify starforged to source agent-slots.sh from test location
sed -i '' 's|source "$CLAUDE_DIR/../templates/lib/agent-slots.sh"|source "$CLAUDE_DIR/agent-slots.sh"|g' "$TEST_DIR/starforged"
sed -i '' 's|source "$PROJECT_ROOT/templates/lib/agent-slots.sh"|source "$CLAUDE_DIR/agent-slots.sh"|g' "$TEST_DIR/starforged"

# Create test triggers
echo "Creating test triggers..."

cat > "$TRIGGER_DIR/junior-dev-a_ticket-1.trigger" << 'EOF'
{
  "to_agent": "junior-dev-a",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {
    "ticket": 1
  }
}
EOF

cat > "$TRIGGER_DIR/junior-dev-b_ticket-2.trigger" << 'EOF'
{
  "to_agent": "junior-dev-b",
  "from_agent": "orchestrator",
  "action": "implement_ticket",
  "context": {
    "ticket": 2
  }
}
EOF

cat > "$TRIGGER_DIR/qa-engineer_review.trigger" << 'EOF'
{
  "to_agent": "qa-engineer",
  "from_agent": "junior-dev-a",
  "action": "review_pr",
  "context": {
    "pr": 161
  }
}
EOF

echo "Created 3 triggers for different agents"
echo ""

# Start daemon in background (with timeout)
echo "Starting daemon (parallel mode)..."
cd "$TEST_DIR"

# Run daemon for 10 seconds then kill it
timeout 10 bash "$TEST_DIR/starforged" > "$CLAUDE_DIR/logs/daemon-output.log" 2>&1 || true

echo ""
echo "=========================================="
echo "Test Results"
echo "=========================================="
echo ""

# Check logs
echo "Daemon output:"
cat "$CLAUDE_DIR/logs/daemon-output.log" | head -30
echo ""

# Check if parallel mode was enabled
if grep -q "MODE.*Parallel execution enabled" "$CLAUDE_DIR/logs/daemon-output.log"; then
  echo "✓ Parallel mode enabled"
else
  echo "✗ Parallel mode NOT enabled"
fi

# Check if agents were spawned
spawned_count=$(grep -c "SPAWNED" "$CLAUDE_DIR/logs/daemon-output.log" || echo "0")
echo "✓ Spawned $spawned_count agents"

# Check if process monitor started
if grep -q "Starting process monitor" "$CLAUDE_DIR/logs/daemon-output.log"; then
  echo "✓ Process monitor started"
else
  echo "✗ Process monitor NOT started"
fi

# Check agent logs
agent_log_count=$(ls -1 "$CLAUDE_DIR/logs/" | grep -c "junior-dev\|qa-engineer" || echo "0")
echo "✓ Created $agent_log_count agent log files"

# Check slots file
if [ -f "$CLAUDE_DIR/daemon/agent-slots.json" ]; then
  echo "✓ Agent slots file created"
  echo ""
  echo "Slots file content:"
  cat "$CLAUDE_DIR/daemon/agent-slots.json" | jq .
else
  echo "✗ Agent slots file NOT created"
fi

echo ""
echo "=========================================="
echo "Cleanup"
echo "=========================================="
rm -rf "$TEST_DIR"
echo "Test environment cleaned up"
echo ""

echo "Smoke test complete!"
echo ""
echo "Note: This is a manual verification test."
echo "Review the output above to ensure parallel execution worked correctly."
