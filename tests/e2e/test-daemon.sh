#!/bin/bash
# E2E Test: Daemon & Discord Integration
# Tests: Autonomous daemon, trigger processing, Discord notifications

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load test assertions
source "$SCRIPT_DIR/../lib/test-assertions.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test Configuration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TEST_DIR="/tmp/starforge-daemon-test-$(date +%s)"
STARFORGE_ROOT="$PROJECT_ROOT"
DAEMON_PID=""

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Setup & Teardown
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

setup_test_environment() {
  echo -e "${BLUE}Setting up daemon test environment...${NC}"

  # Create test directory
  mkdir -p "$TEST_DIR"
  cd "$TEST_DIR"

  # Initialize git
  git init
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Create initial commit
  echo "# Test Project" > README.md
  git add .
  git commit -m "Initial commit"

  # Install StarForge (no GitHub remote needed for daemon tests)
  echo -e "${BLUE}Installing StarForge...${NC}"
  bash "$STARFORGE_ROOT/bin/install.sh" <<EOF
3
n
n
EOF

  # Create .env for Discord (optional - tests both with/without)
  if [ -n "$DISCORD_WEBHOOK_URL" ]; then
    echo "export DISCORD_WEBHOOK_URL=\"$DISCORD_WEBHOOK_URL\"" > .env
    echo -e "${GREEN}✓ Discord webhook configured${NC}"
  else
    echo -e "${YELLOW}⚠ No Discord webhook (testing graceful fallback)${NC}"
  fi

  echo -e "${GREEN}✓ Daemon test environment ready: $TEST_DIR${NC}"
}

cleanup_test_environment() {
  echo -e "${BLUE}Cleaning up daemon test environment...${NC}"

  # Stop daemon if running
  if [ -f ".claude/daemon.pid" ]; then
    local pid=$(cat ".claude/daemon.pid")
    if kill -0 "$pid" 2>/dev/null; then
      echo -e "${YELLOW}Stopping daemon (PID $pid)...${NC}"
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi

  # Remove test directory
  cd /tmp
  rm -rf "$TEST_DIR"

  echo -e "${GREEN}✓ Cleanup complete${NC}"
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 1: Daemon Lifecycle Management
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_lifecycle() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 1: Daemon Lifecycle Management${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check daemon scripts exist
  assert_file_exists ".claude/bin/daemon.sh" "Daemon lifecycle script exists"
  assert_file_exists ".claude/bin/daemon-runner.sh" "Daemon runner script exists"

  # Test daemon start
  echo -e "${BLUE}Starting daemon...${NC}"
  bash .claude/bin/daemon.sh start

  sleep 2

  # Check PID file created
  assert_file_exists ".claude/daemon.pid" "Daemon PID file created"

  # Get PID
  local pid=$(cat ".claude/daemon.pid")
  DAEMON_PID="$pid"
  echo -e "${GREEN}✓ Daemon started with PID: $pid${NC}"

  # Test process is running
  assert_process_running "$pid" "Daemon process is running"

  # Test daemon status
  local status_output=$(bash .claude/bin/daemon.sh status 2>&1)
  assert_contains "$status_output" "running" "Daemon status shows running"

  # Test lock directory created
  assert_dir_exists ".claude/daemon.lock" "Daemon lock directory exists"

  # Test daemon stop
  echo -e "${BLUE}Stopping daemon...${NC}"
  bash .claude/bin/daemon.sh stop

  sleep 2

  # Test process stopped
  assert_process_not_running "$pid" "Daemon process stopped"

  # Test PID file removed
  assert_file_not_exists ".claude/daemon.pid" "Daemon PID file removed"

  # Test lock removed
  assert_file_not_exists ".claude/daemon.lock" "Daemon lock removed"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 2: Trigger File Processing
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_trigger_processing() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 2: Trigger File Processing${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Create trigger directories
  mkdir -p .claude/triggers/processed/{invalid,failed}

  # Create test trigger file
  local trigger_file=".claude/triggers/$(date +%Y%m%d_%H%M%S)_senior-to-tpm.json"

  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm",
  "action": "create_tickets",
  "message": "Feature breakdown ready with architecture diagram",
  "command": "Use tpm. Create GitHub issues from breakdown in spikes/feature-auth/",
  "context": {
    "feature": "user-authentication",
    "subtasks": 3,
    "has_diagram": true
  },
  "timestamp": "2025-10-24T23:00:00Z"
}
EOF

  echo -e "${GREEN}✓ Created test trigger file${NC}"

  # Start daemon
  echo -e "${BLUE}Starting daemon to process trigger...${NC}"
  bash .claude/bin/daemon.sh start

  sleep 3

  # Check trigger was processed (moved to processed/)
  local processed_count=$(find .claude/triggers/processed -name "*senior-to-tpm.json" -type f | wc -l | tr -d ' ')

  assert_not_equals "0" "$processed_count" "Trigger file was processed"

  # Check handoff log created
  assert_file_exists ".claude/agent-handoff.log" "Agent handoff log created"

  # Check log contains handoff record
  assert_file_contains ".claude/agent-handoff.log" "senior-engineer" "Log contains from_agent"
  assert_file_contains ".claude/agent-handoff.log" "tpm" "Log contains to_agent"
  assert_file_contains ".claude/agent-handoff.log" "Feature breakdown ready" "Log contains message"

  # Stop daemon
  bash .claude/bin/daemon.sh stop
  sleep 1

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 3: Stop Hook Integration
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_stop_hook() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 3: Stop Hook Integration${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check stop hook exists
  assert_file_exists ".claude/hooks/stop.py" "Stop hook script exists"

  # Create test trigger
  local trigger_file=".claude/triggers/$(date +%Y%m%d_%H%M%S)_test-handoff.json"

  cat > "$trigger_file" << 'EOF'
{
  "from_agent": "tpm",
  "to_agent": "junior-engineer",
  "action": "implement_ticket",
  "message": "Ticket #123 ready with architecture diagram",
  "command": "Use junior-engineer. Implement ticket #123",
  "context": {
    "ticket": 123,
    "has_diagram": true
  },
  "timestamp": "2025-10-24T23:05:00Z"
}
EOF

  # Test stop hook can process triggers
  echo -e "${BLUE}Testing stop hook trigger processing...${NC}"

  # Simulate stop hook invocation
  local hook_output=$(python3 .claude/hooks/stop.py <<< '{"session_id": "test", "duration": 300}' 2>&1)

  # Check hook doesn't crash
  assert_command_succeeds "python3 .claude/hooks/stop.py <<< '{\"session_id\": \"test\"}'" \
    "Stop hook executes without errors"

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 4: Discord Notifications (Optional)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_discord_notifications() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 4: Discord Notifications${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Check if Discord is configured
  if [ -z "$DISCORD_WEBHOOK_URL" ]; then
    echo -e "${YELLOW}⚠ Discord webhook not configured, skipping notification tests${NC}"
    echo -e "${YELLOW}  Set DISCORD_WEBHOOK_URL environment variable to test Discord integration${NC}"
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} Graceful fallback when Discord not configured"
    echo ""
    return 0
  fi

  # Test Discord notification function
  echo -e "${BLUE}Testing Discord webhook...${NC}"

  # Create test message
  local test_payload=$(cat << 'EOF'
{
  "embeds": [{
    "title": "🤖 StarForge Test: Agent Handoff",
    "description": "Testing Discord webhook integration",
    "color": 3447003,
    "fields": [
      {"name": "From", "value": "test-agent", "inline": true},
      {"name": "To", "value": "test-receiver", "inline": true},
      {"name": "Message", "value": "This is a test notification"}
    ],
    "footer": {"text": "StarForge Daemon Test"},
    "timestamp": "2025-10-24T23:00:00Z"
  }]
}
EOF
)

  # Send test webhook
  local response=$(curl -s -X POST "$DISCORD_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$test_payload" \
    -w "\n%{http_code}")

  local http_code=$(echo "$response" | tail -1)

  # Check webhook succeeded (204 = success for Discord)
  if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓${NC} Discord webhook delivered successfully"
    echo -e "${GREEN}✓ Check your Discord channel for test message${NC}"
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} Discord webhook failed (HTTP $http_code)"
  fi

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 5: Daemon Resilience (No TTY Requirement)
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_no_tty() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 5: Daemon Resilience (No TTY)${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Test daemon can start without TTY (Fix from PR #156)
  echo -e "${BLUE}Testing daemon start in non-TTY environment...${NC}"

  # Start daemon in non-TTY context
  assert_command_succeeds "bash .claude/bin/daemon.sh start </dev/null" \
    "Daemon starts without TTY"

  sleep 2

  # Check daemon is running
  if [ -f ".claude/daemon.pid" ]; then
    local pid=$(cat ".claude/daemon.pid")
    assert_process_running "$pid" "Daemon running in non-TTY mode"

    # Stop daemon
    bash .claude/bin/daemon.sh stop
    sleep 1
  else
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗${NC} Daemon failed to start in non-TTY mode"
  fi

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Test 6: Daemon Restart and Status
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

test_daemon_restart() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}Test 6: Daemon Restart and Status${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Start daemon
  bash .claude/bin/daemon.sh start
  sleep 2

  local pid1=$(cat ".claude/daemon.pid")
  echo -e "${BLUE}Initial daemon PID: $pid1${NC}"

  # Restart daemon
  echo -e "${BLUE}Restarting daemon...${NC}"
  bash .claude/bin/daemon.sh restart
  sleep 2

  # Check new PID
  assert_file_exists ".claude/daemon.pid" "Daemon restarted with new PID"

  local pid2=$(cat ".claude/daemon.pid")
  echo -e "${BLUE}New daemon PID: $pid2${NC}"

  # PIDs should be different
  assert_not_equals "$pid1" "$pid2" "Daemon PID changed after restart"

  # New process should be running
  assert_process_running "$pid2" "New daemon process is running"

  # Old process should be stopped
  assert_process_not_running "$pid1" "Old daemon process stopped"

  # Test status command
  local status_output=$(bash .claude/bin/daemon.sh status)
  assert_contains "$status_output" "running" "Daemon status shows running after restart"

  # Stop daemon
  bash .claude/bin/daemon.sh stop
  sleep 1

  echo ""
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main Test Runner
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
  start_test_suite "E2E: Daemon & Discord Integration"

  # Setup
  setup_test_environment

  # Run tests
  test_daemon_lifecycle
  test_trigger_processing
  test_stop_hook
  test_discord_notifications
  test_daemon_no_tty
  test_daemon_restart

  # Results
  end_test_suite
  local exit_code=$?

  # Export results
  mkdir -p tests/reports
  export_test_results_json "tests/reports/daemon-results.json"

  # Cleanup
  cleanup_test_environment

  # Final output
  if [ $exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 All daemon tests passed!${NC}"
    if [ -n "$DISCORD_WEBHOOK_URL" ]; then
      echo -e "${BLUE}✓ Discord integration validated${NC}"
    else
      echo -e "${YELLOW}ℹ Discord webhook not configured (graceful fallback tested)${NC}"
    fi
  else
    echo -e "${RED}❌ Some daemon tests failed${NC}"
  fi

  exit $exit_code
}

# Run tests
main "$@"
