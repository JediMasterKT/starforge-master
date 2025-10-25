# Comprehensive Testing Plan for PR #138 - Autonomous Daemon

**PR**: #138 - Autonomous Daemon for 24/7 Operation
**Branch**: feature/autonomous-daemon
**Files Changed**: 5 files, 1,384 additions
**Test Plan Created**: 2025-10-24
**QA Engineer**: Claude Code QA

---

## Executive Summary

This testing plan covers all quality gates for the autonomous daemon implementation. The daemon enables 90% autonomy by automatically detecting and processing agent triggers without human intervention.

**Test Coverage Overview**:
- **Unit Tests**: 42 test cases
- **Integration Tests**: 18 test cases
- **Manual Tests**: 12 scenarios
- **Performance Tests**: 8 benchmarks
- **Total**: 80 comprehensive test cases

---

## GATE 1: Unit Tests

### 1.1 Daemon Lifecycle Management (daemon.sh)

#### Test 1.1.1: Start Daemon - Fresh Start
**Preconditions**: No daemon running, no stale PID file
**Steps**:
```bash
cd /Users/krunaaltavkar/starforge-master
starforge daemon start
```
**Expected Results**:
- Daemon starts successfully
- PID file created at `.claude/daemon.pid`
- Lock directory created at `.claude/daemon.lock`
- Log file created at `.claude/logs/daemon.log`
- Success message displays with PID
- Exit code: 0
**Pass Criteria**: All conditions met, daemon process running
**Priority**: P0 (Critical)
**Automation**: Yes - scriptable

---

#### Test 1.1.2: Start Daemon - Already Running
**Preconditions**: Daemon already running
**Steps**:
```bash
starforge daemon start
```
**Expected Results**:
- Error message: "Daemon already running (PID: XXXX)"
- No new daemon process created
- Existing PID unchanged
- Exit code: 1
**Pass Criteria**: Prevents duplicate instances
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.1.3: Start Daemon - Stale PID Cleanup
**Preconditions**: PID file exists but process is dead
**Setup**:
```bash
echo "99999" > .claude/daemon.pid
```
**Steps**:
```bash
starforge daemon start
```
**Expected Results**:
- Warning message: "Cleaning up stale PID file"
- Stale PID removed
- New daemon starts successfully
- New PID written
**Pass Criteria**: Automatic stale cleanup works
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.1.4: Start Daemon - Missing fswatch
**Preconditions**: fswatch not in PATH
**Setup**:
```bash
# Temporarily rename fswatch
mv $(which fswatch) $(which fswatch).bak
```
**Steps**:
```bash
starforge daemon start
```
**Expected Results**:
- Error message: "fswatch not installed"
- Helpful message: "Install with: brew install fswatch"
- Daemon does not start
- Exit code: 1
**Pass Criteria**: Clear error message, graceful failure
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.1.5: Start Daemon - Lock Conflict
**Preconditions**: Lock directory exists from another process
**Setup**:
```bash
mkdir -p .claude/daemon.lock
```
**Steps**:
```bash
starforge daemon start
```
**Expected Results**:
- Error message: "Failed to acquire lock"
- Daemon does not start
- Exit code: 1
**Pass Criteria**: Prevents race conditions
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.1.6: Stop Daemon - Graceful Shutdown
**Preconditions**: Daemon running
**Steps**:
```bash
starforge daemon stop
```
**Expected Results**:
- SIGTERM sent to daemon process
- Process stops within 5 seconds
- PID file removed
- Lock directory removed
- Success message displayed
- Exit code: 0
**Pass Criteria**: Clean shutdown, no orphan processes
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.1.7: Stop Daemon - Not Running
**Preconditions**: No daemon running
**Steps**:
```bash
starforge daemon stop
```
**Expected Results**:
- Message: "Daemon is not running"
- Lock cleanup attempted
- Exit code: 0 (success, idempotent)
**Pass Criteria**: Idempotent operation
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 1.1.8: Stop Daemon - Force Kill After Timeout
**Preconditions**: Daemon stuck in long operation
**Setup**: Mock daemon that ignores SIGTERM
**Steps**:
```bash
starforge daemon stop
```
**Expected Results**:
- SIGTERM sent first
- Waits up to 5 seconds
- Message: "Graceful shutdown timed out, forcing..."
- SIGKILL sent
- Process terminated
- Cleanup completed
**Pass Criteria**: Force kill works when graceful fails
**Priority**: P1 (High)
**Automation**: Yes (with mock)

---

#### Test 1.1.9: Status - Daemon Running
**Preconditions**: Daemon running for 2+ minutes
**Steps**:
```bash
starforge daemon status
```
**Expected Results**:
- Status: "Daemon is running"
- PID displayed
- Uptime displayed (e.g., "2m")
- Log path shown
- Last 5 log entries displayed
- Exit code: 0
**Pass Criteria**: Accurate status information
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.1.10: Status - Daemon Not Running
**Preconditions**: No daemon running
**Steps**:
```bash
starforge daemon status
```
**Expected Results**:
- Status: "Daemon is not running"
- Last 5 log entries shown (if available)
- Exit code: 1
**Pass Criteria**: Clear stopped status
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 1.1.11: Restart - Full Cycle
**Preconditions**: Daemon running
**Steps**:
```bash
starforge daemon restart
```
**Expected Results**:
- Stop sequence executes
- 1-second pause
- Start sequence executes
- New PID different from old PID
- Success messages for both operations
**Pass Criteria**: Complete restart cycle
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.1.12: Logs - Tail Output
**Preconditions**: Daemon running, active logging
**Steps**:
```bash
starforge daemon logs &
LOGS_PID=$!
sleep 2
kill $LOGS_PID
```
**Expected Results**:
- Real-time log streaming
- Ctrl+C stops gracefully
- No errors
**Pass Criteria**: Continuous log output
**Priority**: P2 (Medium)
**Automation**: Partial (manual verification needed)

---

#### Test 1.1.13: Help Command
**Preconditions**: None
**Steps**:
```bash
starforge daemon help
```
**Expected Results**:
- Complete usage information
- All commands listed (start/stop/status/restart/logs)
- Examples provided
- File locations shown
- Requirements listed (fswatch, jq)
**Pass Criteria**: Comprehensive help text
**Priority**: P3 (Low)
**Automation**: Yes

---

#### Test 1.1.14: Uptime Calculation - Seconds
**Preconditions**: Daemon running <1 minute
**Steps**:
```bash
starforge daemon status | grep "Uptime:"
```
**Expected Results**:
- Format: "Xs" (e.g., "45s")
**Pass Criteria**: Correct time unit
**Priority**: P3 (Low)
**Automation**: Yes

---

#### Test 1.1.15: Uptime Calculation - Minutes
**Preconditions**: Daemon running 1-59 minutes
**Steps**:
```bash
starforge daemon status | grep "Uptime:"
```
**Expected Results**:
- Format: "Xm" (e.g., "15m")
**Pass Criteria**: Correct time unit
**Priority**: P3 (Low)
**Automation**: Yes

---

#### Test 1.1.16: Uptime Calculation - Hours
**Preconditions**: Daemon running 1+ hours
**Steps**:
```bash
starforge daemon status | grep "Uptime:"
```
**Expected Results**:
- Format: "Xh Ym" (e.g., "2h 15m")
**Pass Criteria**: Correct time unit and formatting
**Priority**: P3 (Low)
**Automation**: Yes

---

### 1.2 Daemon Runner Logic (daemon-runner.sh)

#### Test 1.2.1: Logging - Structured Format
**Preconditions**: Daemon running
**Steps**:
```bash
grep "^\[.*\] .*: .*" .claude/logs/daemon.log
```
**Expected Results**:
- All lines match format: `[timestamp] LEVEL: message`
- Timestamp in ISO 8601 UTC format
- Valid levels: START, STOP, INVOKE, COMPLETE, ERROR, RETRY, CRITICAL, MONITOR, BACKLOG, ARCHIVE, SKIP, TRIGGER, RESUME
**Pass Criteria**: 100% log entries correctly formatted
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.2: State Persistence - Save
**Preconditions**: Daemon processing trigger
**Steps**:
```bash
cat .claude/daemon-state.json | jq .
```
**Expected Results**:
- Valid JSON
- Fields present: daemon_started, last_trigger_processed, total_triggers_processed, current_trigger
- Timestamps in ISO 8601 format
- Total count >= 0
**Pass Criteria**: State file valid and complete
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.3: State Persistence - Load
**Preconditions**: Previous state file exists
**Setup**:
```bash
cat > .claude/daemon-state.json << EOF
{
  "daemon_started": "2025-10-24T10:00:00Z",
  "last_trigger_processed": "2025-10-24T10:05:00Z",
  "total_triggers_processed": 42,
  "current_trigger": "none"
}
EOF
```
**Steps**:
```bash
# Restart daemon and check logs
starforge daemon restart
grep "RESUME.*processed: 42" .claude/logs/daemon.log
```
**Expected Results**:
- State loaded successfully
- PROCESSED_COUNT = 42
- Log entry: "RESUME: Loaded previous state (processed: 42)"
**Pass Criteria**: State restored correctly
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.4: Deduplication - Mark as Processed
**Preconditions**: Trigger processed successfully
**Steps**:
```bash
cat .claude/.daemon-seen-triggers
```
**Expected Results**:
- File contains processed trigger filenames
- One filename per line
- No duplicates
**Pass Criteria**: Tracking file accurate
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.5: Deduplication - Skip Duplicate
**Preconditions**: Trigger already in seen file
**Setup**:
```bash
echo "test-trigger.trigger" >> .claude/.daemon-seen-triggers
cp .claude/triggers/test-trigger.trigger .claude/triggers/test-trigger.trigger
```
**Steps**:
```bash
# Wait for daemon to process
sleep 2
grep "SKIP.*Already processed" .claude/logs/daemon.log
```
**Expected Results**:
- Log entry: "SKIP: Already processed: test-trigger.trigger"
- Trigger file deleted
- No agent invocation
**Pass Criteria**: Duplicate prevention works
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.6: JSON Validation - Valid Trigger
**Preconditions**: None
**Setup**:
```bash
cat > .claude/triggers/valid.trigger << EOF
{
  "to_agent": "orchestrator",
  "from_agent": "tpm-agent",
  "action": "assign_next_work"
}
EOF
```
**Steps**:
```bash
# Wait for processing
sleep 2
grep "INVOKE.*tpm-agent → orchestrator" .claude/logs/daemon.log
```
**Expected Results**:
- JSON validation passes
- Agent invoked
- Trigger archived to processed/
**Pass Criteria**: Valid JSON accepted
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.7: JSON Validation - Malformed JSON
**Preconditions**: None
**Setup**:
```bash
cat > .claude/triggers/invalid.trigger << EOF
{
  "to_agent": "orchestrator"
  "missing_comma": true
}
EOF
```
**Steps**:
```bash
sleep 2
grep "ERROR.*Malformed JSON" .claude/logs/daemon.log
ls .claude/triggers/processed/invalid/
```
**Expected Results**:
- Log entry: "ERROR: Malformed JSON in invalid.trigger"
- No agent invocation
- Trigger archived to processed/invalid/
- No retry attempted
**Pass Criteria**: Malformed JSON rejected, no retry
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.8: JSON Validation - Missing to_agent
**Preconditions**: None
**Setup**:
```bash
cat > .claude/triggers/no-agent.trigger << EOF
{
  "from_agent": "tpm-agent",
  "action": "test"
}
EOF
```
**Steps**:
```bash
sleep 2
grep "ERROR.*Missing 'to_agent'" .claude/logs/daemon.log
ls .claude/triggers/processed/invalid/
```
**Expected Results**:
- Log entry: "ERROR: Missing 'to_agent' field"
- Archived to processed/invalid/
- No retry
**Pass Criteria**: Missing field detected
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.9: Trigger Archival - Success
**Preconditions**: Agent completes successfully
**Steps**:
```bash
ls .claude/triggers/processed/ | grep "^\d{8}-\d{6}-.*\.trigger$"
```
**Expected Results**:
- Trigger moved to processed/
- Filename format: YYYYMMDD-HHMMSS-original-name.trigger
- Log entry: "ARCHIVE: Trigger filename → success"
**Pass Criteria**: Successful archival
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.10: Trigger Archival - Invalid
**Preconditions**: Malformed JSON trigger
**Steps**:
```bash
ls .claude/triggers/processed/invalid/
```
**Expected Results**:
- Trigger in processed/invalid/
- Timestamped filename
- Log entry: "ARCHIVE: Trigger filename → invalid"
**Pass Criteria**: Invalid triggers segregated
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.11: Trigger Archival - Failed
**Preconditions**: Agent fails 3 times
**Steps**:
```bash
ls .claude/triggers/processed/failed/
```
**Expected Results**:
- Trigger in processed/failed/
- Timestamped filename
- Log entry: "ARCHIVE: Trigger filename → failed"
**Pass Criteria**: Failed triggers tracked
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.12: FIFO Queue - Oldest First
**Preconditions**: Multiple triggers exist
**Setup**:
```bash
# Create triggers with different timestamps
touch -t 202510240900 .claude/triggers/old.trigger
touch -t 202510241000 .claude/triggers/middle.trigger
touch -t 202510241100 .claude/triggers/new.trigger
```
**Steps**:
```bash
# Check processing order in logs
grep "TRIGGER: Detected" .claude/logs/daemon.log | tail -3
```
**Expected Results**:
- old.trigger processed first
- middle.trigger processed second
- new.trigger processed third
**Pass Criteria**: FIFO ordering maintained
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.13: Agent Invocation - Success
**Preconditions**: Valid trigger, working agent
**Steps**:
```bash
# Check logs for complete flow
grep -A1 "INVOKE.*orchestrator" .claude/logs/daemon.log
```
**Expected Results**:
- Log: "INVOKE: tpm-agent → orchestrator (action)"
- Log: "COMPLETE: orchestrator completed in Xs"
- Exit code stored: 0
- Duration logged
**Pass Criteria**: Full invocation cycle logged
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.14: Agent Invocation - Failure
**Preconditions**: Agent fails (exit code != 0)
**Steps**:
```bash
grep "ERROR.*failed.*exit:" .claude/logs/daemon.log
```
**Expected Results**:
- Log: "ERROR: agent-name failed (exit: X)"
- Retry initiated
- Exit code captured
**Pass Criteria**: Failure detected and logged
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.15: Agent Invocation - Timeout
**Preconditions**: Agent runs >30 minutes
**Setup**: Mock agent with infinite loop
**Steps**:
```bash
# Wait 31 minutes (or use shorter timeout for test)
grep "ERROR.*timed out after" .claude/logs/daemon.log
```
**Expected Results**:
- Process killed after 30 minutes (1800s)
- Log: "ERROR: agent-name timed out after 1800s"
- Retry initiated
**Pass Criteria**: Timeout enforced
**Priority**: P1 (High)
**Automation**: Partial (long running)

---

#### Test 1.2.16: Retry Mechanism - First Retry
**Preconditions**: Agent fails on first attempt
**Steps**:
```bash
grep "RETRY: Attempt 2/3" .claude/logs/daemon.log
grep "RETRY: Waiting 5s" .claude/logs/daemon.log
```
**Expected Results**:
- Retry message logged
- 5-second delay before retry
- Agent invoked again
**Pass Criteria**: First retry executes
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.17: Retry Mechanism - Second Retry
**Preconditions**: Agent fails twice
**Steps**:
```bash
grep "RETRY: Attempt 3/3" .claude/logs/daemon.log
grep "RETRY: Waiting 10s" .claude/logs/daemon.log
```
**Expected Results**:
- Second retry message logged
- 10-second delay (exponential backoff)
- Third attempt made
**Pass Criteria**: Exponential backoff works
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.18: Retry Mechanism - Max Retries
**Preconditions**: Agent fails 3 times
**Steps**:
```bash
grep "CRITICAL: Failed after 3 attempts" .claude/logs/daemon.log
ls .claude/triggers/processed/failed/
```
**Expected Results**:
- CRITICAL log entry
- Trigger moved to processed/failed/
- No 4th retry
**Pass Criteria**: Max retries enforced
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.19: Retry Mechanism - No Retry for Parse Errors
**Preconditions**: Malformed JSON
**Steps**:
```bash
grep -c "RETRY" .claude/logs/daemon.log
```
**Expected Results**:
- 0 retry attempts
- Immediate archival to invalid/
- Log: "ERROR: Parse error, no retry"
**Pass Criteria**: Parse errors skip retry
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.20: Backlog Processing - Multiple Triggers
**Preconditions**: 5 triggers exist before daemon starts
**Setup**:
```bash
for i in {1..5}; do
  cat > .claude/triggers/backlog-$i.trigger << EOF
{"to_agent": "orchestrator", "from_agent": "test", "action": "test"}
EOF
done
```
**Steps**:
```bash
starforge daemon start
sleep 10
grep "BACKLOG: Found 5 pending trigger" .claude/logs/daemon.log
```
**Expected Results**:
- Log: "BACKLOG: Found 5 pending trigger(s)"
- All 5 triggers processed
- Log: "BACKLOG: Backlog processing complete"
**Pass Criteria**: All backlog triggers processed
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.21: Backlog Processing - Empty Backlog
**Preconditions**: No triggers exist
**Steps**:
```bash
starforge daemon start
grep "BACKLOG" .claude/logs/daemon.log
```
**Expected Results**:
- No BACKLOG log entries (or "Found 0 triggers")
- Daemon proceeds to monitoring
**Pass Criteria**: Empty backlog handled gracefully
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 1.2.22: Crash Recovery - Interrupted Trigger
**Preconditions**: Daemon killed mid-processing
**Setup**:
```bash
# Set current_trigger in state
cat > .claude/daemon-state.json << EOF
{
  "daemon_started": "2025-10-24T10:00:00Z",
  "last_trigger_processed": "2025-10-24T10:05:00Z",
  "total_triggers_processed": 5,
  "current_trigger": "interrupted.trigger"
}
EOF
# Create the interrupted trigger
echo '{"to_agent": "test"}' > .claude/triggers/interrupted.trigger
```
**Steps**:
```bash
starforge daemon start
grep "RESUME: Found interrupted trigger" .claude/logs/daemon.log
ls .claude/triggers/processed/failed/interrupted.trigger
```
**Expected Results**:
- Log: "RESUME: Found interrupted trigger: interrupted.trigger"
- Trigger marked as seen
- Trigger archived to processed/failed/
- Not re-processed
**Pass Criteria**: Interrupted trigger handled
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.23: fswatch Event Detection - <5 Seconds
**Preconditions**: Daemon running
**Steps**:
```bash
# Create trigger and measure detection time
START=$(date +%s)
echo '{"to_agent": "orchestrator"}' > .claude/triggers/timing-test.trigger
# Wait for TRIGGER log entry
while ! grep "TRIGGER: Detected: timing-test.trigger" .claude/logs/daemon.log; do
  sleep 0.1
done
END=$(date +%s)
DURATION=$((END - START))
```
**Expected Results**:
- Detection time < 5 seconds
- fswatch event captured
**Pass Criteria**: Event-driven detection <5s
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.2.24: Signal Handling - Graceful SIGTERM
**Preconditions**: Daemon running
**Steps**:
```bash
PID=$(cat .claude/daemon.pid)
kill -TERM $PID
sleep 1
grep "STOP: Daemon shutting down gracefully" .claude/logs/daemon.log
```
**Expected Results**:
- Log: "STOP: Daemon shutting down gracefully"
- State saved before exit
- Clean shutdown
**Pass Criteria**: SIGTERM handled properly
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.25: Signal Handling - SIGINT (Ctrl+C)
**Preconditions**: Daemon running in foreground
**Steps**:
```bash
# Run daemon directly (not via daemon.sh)
bash bin/daemon-runner.sh &
PID=$!
sleep 2
kill -INT $PID
```
**Expected Results**:
- Same as SIGTERM test
- Graceful shutdown
**Pass Criteria**: SIGINT handled properly
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 1.2.26: Directory Creation - Auto-create
**Preconditions**: Required directories don't exist
**Setup**:
```bash
rm -rf .claude/triggers/processed
```
**Steps**:
```bash
starforge daemon start
ls -la .claude/triggers/
```
**Expected Results**:
- processed/ created
- processed/invalid/ created
- processed/failed/ created
- .claude/logs/ created
**Pass Criteria**: All directories auto-created
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.27: Log File - Auto-create
**Preconditions**: Log file doesn't exist
**Setup**:
```bash
rm -f .claude/logs/daemon.log
```
**Steps**:
```bash
starforge daemon start
test -f .claude/logs/daemon.log
```
**Expected Results**:
- daemon.log created
- First entry: "START: Daemon started"
**Pass Criteria**: Log file initialized
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.28: Dependency Check - Missing jq
**Preconditions**: jq not in PATH
**Steps**:
```bash
# Temporarily rename jq
mv $(which jq) $(which jq).bak
starforge daemon start
```
**Expected Results**:
- Error: "jq not installed. Install with: brew install jq"
- Daemon exits
- Exit code: 1
**Pass Criteria**: Missing dependency detected
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.2.29: Dependency Check - Missing starforge
**Preconditions**: starforge not in PATH
**Setup**:
```bash
# Temporarily remove from PATH
export PATH=$(echo $PATH | sed 's|:/Users/krunaaltavkar/starforge-master/bin||')
```
**Steps**:
```bash
# Invoke agent (will fail)
```
**Expected Results**:
- Error: "starforge command not found in PATH"
- Agent invocation fails
- Retry attempted
**Pass Criteria**: Missing command detected
**Priority**: P1 (High)
**Automation**: Yes

---

### 1.3 CLI Integration (bin/starforge)

#### Test 1.3.1: Daemon Command Routing
**Preconditions**: StarForge installed
**Steps**:
```bash
starforge daemon status
```
**Expected Results**:
- Command routed to bin/daemon.sh
- Correct arguments passed
- Output matches daemon.sh directly
**Pass Criteria**: CLI routing works
**Priority**: P0 (Critical)
**Automation**: Yes

---

#### Test 1.3.2: Help Text - Daemon Section
**Preconditions**: None
**Steps**:
```bash
starforge help | grep -A10 "daemon"
```
**Expected Results**:
- Daemon commands documented
- All 5 subcommands listed (start/stop/status/restart/logs)
- Examples provided
**Pass Criteria**: Help text complete
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 1.3.3: Not Installed - Error Handling
**Preconditions**: .claude/ directory doesn't exist
**Steps**:
```bash
rm -rf .claude
starforge daemon start
```
**Expected Results**:
- Error: "StarForge not installed in this project"
- Message: "Run: starforge install"
- Exit code: 1
**Pass Criteria**: Clear error for uninitialized project
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 1.3.4: Invalid Subcommand
**Preconditions**: None
**Steps**:
```bash
starforge daemon invalid-command
```
**Expected Results**:
- Error: "Unknown command 'invalid-command'"
- Help text displayed
- Exit code: 1
**Pass Criteria**: Invalid commands rejected
**Priority**: P2 (Medium)
**Automation**: Yes

---

---

## GATE 2: Integration Tests

### 2.1 End-to-End Workflows

#### Test 2.1.1: Complete Trigger Flow - Happy Path
**Preconditions**: Clean environment, daemon not running
**Steps**:
```bash
# 1. Start daemon
starforge daemon start

# 2. Create trigger
cat > .claude/triggers/e2e-test.trigger << EOF
{
  "to_agent": "orchestrator",
  "from_agent": "tpm-agent",
  "action": "assign_next_work",
  "context": {
    "count": 1,
    "completed_tickets": [42]
  }
}
EOF

# 3. Wait for processing
sleep 10

# 4. Verify
grep "INVOKE.*tpm-agent → orchestrator" .claude/logs/daemon.log
grep "COMPLETE.*orchestrator completed" .claude/logs/daemon.log
ls .claude/triggers/processed/ | grep "e2e-test.trigger"
```
**Expected Results**:
- Trigger detected <5s
- Agent invoked successfully
- Trigger archived to processed/
- State updated
**Pass Criteria**: Full cycle works end-to-end
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Yes

---

#### Test 2.1.2: Multi-Trigger Processing - Sequential
**Preconditions**: Daemon running
**Steps**:
```bash
# Create 3 triggers rapidly
for i in {1..3}; do
  cat > .claude/triggers/multi-$i.trigger << EOF
{"to_agent": "orchestrator", "from_agent": "test-$i", "action": "test"}
EOF
  sleep 0.1
done

# Wait for all to process
sleep 30

# Verify processing order
grep "TRIGGER: Detected: multi-" .claude/logs/daemon.log
```
**Expected Results**:
- All 3 triggers detected
- Processed sequentially (not parallel)
- Processing order: multi-1, multi-2, multi-3 (FIFO)
- All archived to processed/
**Pass Criteria**: Sequential processing maintained
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Yes

---

#### Test 2.1.3: Daemon Restart - State Persistence
**Preconditions**: Daemon processed 5 triggers
**Steps**:
```bash
# 1. Process some triggers
# ... (5 triggers)

# 2. Check state
BEFORE=$(jq -r '.total_triggers_processed' .claude/daemon-state.json)

# 3. Restart daemon
starforge daemon restart

# 4. Verify state restored
AFTER=$(jq -r '.total_triggers_processed' .claude/daemon-state.json)
test "$BEFORE" -eq "$AFTER"
```
**Expected Results**:
- State file preserved
- Trigger count persists across restart
- Log: "RESUME: Loaded previous state"
**Pass Criteria**: State survives restart
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Yes

---

#### Test 2.1.4: Mixed Valid/Invalid Triggers
**Preconditions**: Daemon running
**Steps**:
```bash
# Create valid trigger
echo '{"to_agent": "orchestrator"}' > .claude/triggers/valid.trigger

# Create invalid trigger
echo '{"invalid json}' > .claude/triggers/invalid.trigger

# Create another valid
echo '{"to_agent": "tpm-agent"}' > .claude/triggers/valid2.trigger

# Wait for processing
sleep 20

# Verify
ls .claude/triggers/processed/ | grep "valid.trigger\|valid2.trigger"
ls .claude/triggers/processed/invalid/ | grep "invalid.trigger"
```
**Expected Results**:
- Valid triggers processed and archived to processed/
- Invalid trigger archived to processed/invalid/
- Processing continues after invalid trigger
- No crash or halt
**Pass Criteria**: Error isolation works
**Priority**: P1 (High) - MUST PASS BEFORE MERGE
**Automation**: Yes

---

#### Test 2.1.5: Retry with Recovery
**Preconditions**: Mock agent that fails twice then succeeds
**Setup**: Create mock agent script
**Steps**:
```bash
# Create trigger for mock agent
echo '{"to_agent": "mock-fail-twice"}' > .claude/triggers/retry-test.trigger

# Wait for 3 attempts
sleep 35  # 5s + 10s + 20s delays

# Verify
grep -c "RETRY: Attempt" .claude/logs/daemon.log  # Should be 2
grep "COMPLETE: mock-fail-twice completed" .claude/logs/daemon.log
```
**Expected Results**:
- Attempt 1: Fails
- Retry after 5s
- Attempt 2: Fails
- Retry after 10s
- Attempt 3: Succeeds
- Trigger archived to processed/
**Pass Criteria**: Retry mechanism recovers from transient failures
**Priority**: P1 (High) - MUST PASS BEFORE MERGE
**Automation**: Yes (with mock)

---

#### Test 2.1.6: Retry Max Failure
**Preconditions**: Mock agent that always fails
**Steps**:
```bash
# Create trigger for always-fail agent
echo '{"to_agent": "mock-always-fail"}' > .claude/triggers/max-retry-test.trigger

# Wait for all retries
sleep 40

# Verify
grep -c "RETRY: Attempt" .claude/logs/daemon.log  # Should be 2 (attempts 2 and 3)
grep "CRITICAL: Failed after 3 attempts" .claude/logs/daemon.log
ls .claude/triggers/processed/failed/ | grep "max-retry-test.trigger"
```
**Expected Results**:
- 3 attempts made
- CRITICAL log entry
- Trigger archived to processed/failed/
- Daemon continues processing (not crashed)
**Pass Criteria**: Max retries enforced, graceful failure
**Priority**: P1 (High) - MUST PASS BEFORE MERGE
**Automation**: Yes (with mock)

---

### 2.2 Crash Recovery & Edge Cases

#### Test 2.2.1: Kill During Processing - No Data Loss
**Preconditions**: Daemon processing long-running trigger
**Steps**:
```bash
# Start long-running trigger
echo '{"to_agent": "mock-slow-agent"}' > .claude/triggers/crash-test.trigger

# Wait for processing to start
sleep 2

# Kill daemon (SIGKILL, not graceful)
kill -KILL $(cat .claude/daemon.pid)

# Restart
starforge daemon start

# Verify
ls .claude/triggers/processed/failed/ | grep "crash-test.trigger"
grep "RESUME: Found interrupted trigger" .claude/logs/daemon.log
```
**Expected Results**:
- Interrupted trigger moved to failed/
- State file indicates last known trigger
- No data corruption
- Daemon resumes normally
**Pass Criteria**: Data integrity after crash
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Yes (with mock slow agent)

---

#### Test 2.2.2: Concurrent Trigger Creation
**Preconditions**: Daemon running
**Steps**:
```bash
# Create 10 triggers simultaneously
for i in {1..10}; do
  (echo '{"to_agent": "orchestrator"}' > ".claude/triggers/concurrent-$i.trigger") &
done
wait

# Wait for all to process
sleep 60

# Verify
PROCESSED=$(ls .claude/triggers/processed/ | grep -c "concurrent-")
test "$PROCESSED" -eq 10
```
**Expected Results**:
- All 10 triggers detected
- All processed (no race conditions)
- All archived correctly
- No duplicate processing
**Pass Criteria**: Handles rapid trigger creation
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 2.2.3: Large Trigger Payload
**Preconditions**: Daemon running
**Steps**:
```bash
# Create trigger with large context (10KB JSON)
jq -n '{
  to_agent: "orchestrator",
  from_agent: "test",
  action: "test",
  context: {
    large_data: (range(1000) | tostring)
  }
}' > .claude/triggers/large.trigger

# Wait for processing
sleep 10

# Verify
grep "COMPLETE.*orchestrator" .claude/logs/daemon.log
```
**Expected Results**:
- Large trigger parsed successfully
- Agent invoked with full payload
- No truncation or corruption
**Pass Criteria**: Handles large payloads
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 2.2.4: Empty Trigger Directory
**Preconditions**: No triggers exist
**Steps**:
```bash
starforge daemon start
sleep 5
# No triggers created
# Stop daemon
starforge daemon stop
```
**Expected Results**:
- Daemon starts successfully
- No errors logged
- MONITOR state active
- Graceful shutdown
**Pass Criteria**: Handles idle state
**Priority**: P2 (Medium)
**Automation**: Yes

---

#### Test 2.2.5: Trigger Created While Offline
**Preconditions**: Daemon stopped
**Steps**:
```bash
# Create triggers while offline
for i in {1..3}; do
  echo '{"to_agent": "orchestrator"}' > ".claude/triggers/offline-$i.trigger"
done

# Start daemon
starforge daemon start

# Verify backlog processing
grep "BACKLOG: Found 3 pending trigger" .claude/logs/daemon.log
```
**Expected Results**:
- Backlog detected on startup
- All 3 triggers processed
- FIFO order maintained
**Pass Criteria**: Offline queue processing
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 2.2.6: Disk Space - Full Disk Simulation
**Preconditions**: Simulate full disk (if possible)
**Steps**:
```bash
# Create trigger when disk is full
# (Implementation depends on test environment)
```
**Expected Results**:
- Graceful error handling
- Error logged
- Daemon doesn't crash
**Pass Criteria**: Survives disk full condition
**Priority**: P2 (Medium)
**Automation**: Partial (environment-dependent)

---

### 2.3 Real Agent Workflows

#### Test 2.3.1: TPM → Orchestrator Handoff
**Preconditions**: Daemon running, real agents
**Steps**:
```bash
# Manually trigger TPM agent (which creates orchestrator trigger)
starforge use tpm-agent

# Wait for daemon to pick up orchestrator trigger
sleep 10

# Verify
grep "INVOKE.*tpm-agent → orchestrator" .claude/logs/daemon.log
grep "COMPLETE.*orchestrator" .claude/logs/daemon.log
```
**Expected Results**:
- TPM creates orchestrator trigger
- Daemon detects <5s
- Orchestrator invoked
- Handoff complete
**Pass Criteria**: Real agent handoff works
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Partial (requires real agents)

---

#### Test 2.3.2: Orchestrator → Junior-Dev Handoff
**Preconditions**: Work assigned, junior-dev trigger created
**Steps**:
```bash
# Similar to 2.3.1 but for orchestrator → junior-dev
# Verify junior-dev agent invoked by daemon
```
**Expected Results**:
- Orchestrator creates junior-dev trigger
- Daemon invokes junior-dev
- Junior-dev processes ticket
**Pass Criteria**: Multi-hop handoff works
**Priority**: P1 (High)
**Automation**: Partial

---

#### Test 2.3.3: QA → Orchestrator Feedback Loop
**Preconditions**: QA approves PR
**Steps**:
```bash
# QA creates orchestrator trigger after PR approval
# Daemon should invoke orchestrator for next assignment
```
**Expected Results**:
- QA trigger detected
- Orchestrator invoked for next work
- Feedback loop completes
**Pass Criteria**: Full cycle automation
**Priority**: P1 (High)
**Automation**: Partial

---

---

## GATE 3: Manual Testing

### 3.1 User Experience

#### Manual Test 3.1.1: First-Time Daemon Start
**Steps**:
1. Fresh StarForge installation
2. Run `starforge daemon help`
3. Read help text
4. Run `starforge daemon start`
5. Observe output and logs
6. Run `starforge daemon status`
7. Run `starforge daemon logs` (Ctrl+C to stop)
8. Run `starforge daemon stop`

**Expected**:
- Clear, helpful output at each step
- No confusing error messages
- Intuitive command structure
- Logs are readable

**Result**: [PASS/FAIL]
**Priority**: P1 (High) - MUST PASS BEFORE MERGE

---

#### Manual Test 3.1.2: Status Output Clarity
**Steps**:
1. Start daemon
2. Let it run for different durations (1 min, 5 min, 1 hour)
3. Check `starforge daemon status` output
4. Verify uptime formatting
5. Verify recent activity display

**Expected**:
- Uptime accurate and readable
- Recent activity informative
- No jargon or confusing terms

**Result**: [PASS/FAIL]
**Priority**: P2 (Medium)

---

#### Manual Test 3.1.3: Error Messages - User Friendliness
**Steps**:
1. Try to start daemon when already running
2. Try to start without fswatch installed
3. Try invalid daemon commands
4. Try daemon commands without StarForge installation

**Expected**:
- All error messages clear and actionable
- Helpful suggestions provided (e.g., "Install with: brew install fswatch")
- No stack traces or internal errors exposed

**Result**: [PASS/FAIL]
**Priority**: P2 (Medium)

---

### 3.2 Real-World Scenarios

#### Manual Test 3.2.1: 24/7 Operation - Overnight Run
**Steps**:
1. Start daemon at 5 PM
2. Create 5 test triggers
3. Let daemon run overnight
4. Check status next morning
5. Verify all triggers processed
6. Check log file integrity

**Expected**:
- Daemon still running after 12+ hours
- All triggers processed correctly
- No memory leaks or performance degradation
- Logs continuous and complete

**Result**: [PASS/FAIL]
**Priority**: P1 (High) - NICE TO HAVE (can be post-merge)

---

#### Manual Test 3.2.2: Development Workflow - Real Ticket
**Steps**:
1. Start daemon
2. Create a real GitHub issue
3. Let TPM agent analyze
4. Observe daemon detect and process each handoff:
   - TPM → Orchestrator
   - Orchestrator → Junior-Dev
   - Junior-Dev → QA
5. Verify autonomous operation

**Expected**:
- Zero manual intervention required
- All agents invoked automatically
- Complete workflow from issue to PR
- Logs show full trace

**Result**: [PASS/FAIL]
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE

---

#### Manual Test 3.2.3: Daemon Under Load - 50 Triggers
**Steps**:
1. Create 50 test triggers
2. Start daemon
3. Monitor resource usage (CPU, memory)
4. Verify all 50 processed
5. Check processing time

**Expected**:
- All 50 triggers processed
- CPU usage <10% on average
- Memory stable (no leaks)
- Completion time reasonable

**Result**: [PASS/FAIL]
**Priority**: P2 (Medium)

---

### 3.3 Edge Case Exploration

#### Manual Test 3.3.1: System Restart - macOS Reboot
**Steps**:
1. Start daemon
2. Process some triggers
3. Reboot computer (without stopping daemon)
4. After reboot, check daemon status
5. Verify no stale processes
6. Restart daemon
7. Verify recovery

**Expected**:
- No stale processes after reboot
- Clean startup after reboot
- State file intact
- Recovery successful

**Result**: [PASS/FAIL]
**Priority**: P2 (Medium)

---

#### Manual Test 3.3.2: Network Issues - GitHub API Down
**Steps**:
1. Start daemon
2. Disconnect network
3. Create trigger that invokes agent needing GitHub
4. Observe behavior
5. Reconnect network
6. Verify recovery

**Expected**:
- Agent failure logged
- Retry mechanism activates
- Recovery after network restore
- No crash

**Result**: [PASS/FAIL]
**Priority**: P2 (Medium)

---

#### Manual Test 3.3.3: Trigger File Race Condition
**Steps**:
1. Start daemon
2. Rapidly create trigger, delete it, recreate it
3. Observe daemon behavior
4. Check for crashes or errors

**Expected**:
- Graceful handling of file disappearance
- No crashes
- Errors logged appropriately

**Result**: [PASS/FAIL]
**Priority**: P3 (Low)

---

#### Manual Test 3.3.4: Permissions - Read-Only Trigger Directory
**Steps**:
1. Make .claude/triggers read-only
2. Start daemon
3. Observe behavior when unable to archive

**Expected**:
- Error logged clearly
- Daemon doesn't crash
- Permission issue identified

**Result**: [PASS/FAIL]
**Priority**: P3 (Low)

---

#### Manual Test 3.3.5: Log Rotation - Large Log File
**Steps**:
1. Let daemon run until log file >10MB
2. Check performance
3. Verify log file grows correctly

**Expected**:
- No performance degradation
- Log file continues to grow
- (Note: Log rotation not implemented in this PR, just verify growth)

**Result**: [PASS/FAIL]
**Priority**: P3 (Low) - NICE TO HAVE

---

---

## GATE 4: Regression Tests

### 4.1 Existing Functionality

#### Test 4.1.1: Manual Agent Invocation Still Works
**Preconditions**: Daemon stopped
**Steps**:
```bash
starforge use orchestrator
echo $?
```
**Expected Results**:
- Agent invoked manually
- Works as before daemon implementation
- Exit code 0
**Pass Criteria**: No regression in manual invocation
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Yes

---

#### Test 4.1.2: Existing Tests Pass
**Preconditions**: None
**Steps**:
```bash
bash bin/test-install.sh
bash bin/test-cli.sh
```
**Expected Results**:
- All 96 existing tests pass
- No new failures introduced
**Pass Criteria**: 100% existing test pass rate
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE
**Automation**: Yes

---

#### Test 4.1.3: Trigger Monitor Script Unaffected
**Preconditions**: None
**Steps**:
```bash
starforge monitor &
MONITOR_PID=$!
sleep 5
kill $MONITOR_PID
```
**Expected Results**:
- Monitor script runs as before
- No interference from daemon code
- Works independently
**Pass Criteria**: Monitor script unchanged functionality
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 4.1.4: Update Command Works
**Preconditions**: None
**Steps**:
```bash
starforge update
```
**Expected Results**:
- Update includes new daemon files
- Templates updated correctly
- No errors during update
**Pass Criteria**: Daemon integrated into update flow
**Priority**: P1 (High)
**Automation**: Yes

---

#### Test 4.1.5: Fresh Installation Includes Daemon
**Preconditions**: Uninstalled project
**Steps**:
```bash
starforge install
ls bin/daemon.sh bin/daemon-runner.sh
```
**Expected Results**:
- daemon.sh and daemon-runner.sh installed
- Executable permissions set
- No installation errors
**Pass Criteria**: Daemon included in fresh installs
**Priority**: P1 (High)
**Automation**: Yes

---

---

## GATE 5: Performance Tests

### 5.1 Detection Latency

#### Performance Test 5.1.1: Trigger Detection Time
**Method**:
```bash
START=$(date +%s.%N)
echo '{"to_agent": "test"}' > .claude/triggers/perf-test.trigger
# Wait for detection log entry
while ! grep "TRIGGER: Detected: perf-test.trigger" .claude/logs/daemon.log; do
  sleep 0.01
done
END=$(date +%s.%N)
LATENCY=$(echo "$END - $START" | bc)
```
**Target**: <5 seconds
**Pass Criteria**: 95% of triggers detected in <5s
**Priority**: P0 (Critical) - MUST PASS BEFORE MERGE

---

#### Performance Test 5.1.2: Invocation Overhead
**Method**: Measure time from detection to agent start
**Target**: <100ms
**Pass Criteria**: Overhead <200ms
**Priority**: P1 (High)

---

### 5.2 Resource Usage

#### Performance Test 5.2.1: CPU Usage - Idle
**Method**:
```bash
top -pid $(cat .claude/daemon.pid) -l 2 | tail -1 | awk '{print $3}'
```
**Target**: <1% CPU when idle
**Pass Criteria**: <2% CPU sustained
**Priority**: P1 (High)

---

#### Performance Test 5.2.2: CPU Usage - Under Load
**Method**: Process 50 triggers, measure CPU
**Target**: <10% CPU average
**Pass Criteria**: <20% CPU peak
**Priority**: P2 (Medium)

---

#### Performance Test 5.2.3: Memory Usage - Idle
**Method**:
```bash
ps -p $(cat .claude/daemon.pid) -o rss=
```
**Target**: <50MB RSS
**Pass Criteria**: <100MB RSS
**Priority**: P2 (Medium)

---

#### Performance Test 5.2.4: Memory Usage - After 100 Triggers
**Method**: Process 100 triggers, check memory
**Target**: No memory leaks (stable after processing)
**Pass Criteria**: <150MB RSS, no growth trend
**Priority**: P1 (High)

---

### 5.3 Throughput

#### Performance Test 5.3.1: Triggers Per Minute
**Method**: Process 60 short triggers, measure time
**Target**: >10 triggers/minute
**Pass Criteria**: >5 triggers/minute
**Priority**: P2 (Medium)

---

#### Performance Test 5.3.2: Log Write Performance
**Method**: Measure time to write log entry
**Target**: <5ms per log entry
**Pass Criteria**: <10ms per entry
**Priority**: P3 (Low)

---

---

## Test Execution Summary

### Critical Tests (Must Pass Before Merge)

**Gate 1 - Unit Tests**: 17 critical tests
- All lifecycle operations (start/stop/restart/status)
- JSON validation and parsing
- Trigger archival (success/invalid/failed)
- FIFO queue ordering
- Retry mechanism (all scenarios)
- fswatch detection latency

**Gate 2 - Integration Tests**: 6 critical tests
- Complete trigger flow (happy path)
- Multi-trigger sequential processing
- Daemon restart with state persistence
- Mixed valid/invalid trigger handling
- Crash recovery without data loss
- TPM → Orchestrator real agent handoff

**Gate 3 - Manual Tests**: 2 critical tests
- First-time user experience
- Real-world development workflow (issue → PR)

**Gate 4 - Regression Tests**: 2 critical tests
- Manual agent invocation still works
- All existing 96 tests pass

**Gate 5 - Performance Tests**: 1 critical test
- Trigger detection <5 seconds

**Total Critical Tests**: 28 tests MUST PASS

---

### High Priority Tests (Should Pass Before Merge)

**Total High Priority**: 24 tests

---

### Medium/Low Priority Tests (Can Be Post-Merge)

**Total Medium/Low**: 28 tests
- Nice-to-have features
- Edge case exploration
- Long-running tests (overnight operation)
- Advanced manual scenarios

---

## Automated Test Script Structure

```bash
#!/bin/bash
# test_daemon_comprehensive.sh
# Comprehensive daemon testing suite

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
assert_equals() {
  local expected=$1
  local actual=$2
  local message=$3

  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓ PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: $message"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

assert_true() {
  local condition=$1
  local message=$2

  if eval "$condition"; then
    echo -e "${GREEN}✓ PASS${NC}: $message"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: $message"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  TESTS_RUN=$((TESTS_RUN + 1))
}

# Setup/teardown
setup_test_env() {
  # Clean state before each test
  starforge daemon stop 2>/dev/null || true
  rm -f .claude/daemon.pid
  rm -rf .claude/daemon.lock
  rm -f .claude/daemon-state.json
  rm -f .claude/.daemon-seen-triggers
  rm -rf .claude/triggers/*.trigger
  echo "" > .claude/logs/daemon.log
}

# Test suites
run_unit_tests() {
  echo "========================================="
  echo "GATE 1: Unit Tests"
  echo "========================================="

  # Test 1.1.1
  setup_test_env
  starforge daemon start > /dev/null 2>&1
  assert_true "[ -f .claude/daemon.pid ]" "Test 1.1.1: PID file created"
  assert_true "[ -d .claude/daemon.lock ]" "Test 1.1.1: Lock directory created"
  assert_true "kill -0 \$(cat .claude/daemon.pid) 2>/dev/null" "Test 1.1.1: Daemon process running"

  # Test 1.1.2
  starforge daemon start > /dev/null 2>&1
  EXIT_CODE=$?
  assert_equals "1" "$EXIT_CODE" "Test 1.1.2: Prevents duplicate instances"

  # ... more tests ...

  starforge daemon stop > /dev/null 2>&1
}

run_integration_tests() {
  echo "========================================="
  echo "GATE 2: Integration Tests"
  echo "========================================="

  # ... integration tests ...
}

run_regression_tests() {
  echo "========================================="
  echo "GATE 4: Regression Tests"
  echo "========================================="

  # ... regression tests ...
}

# Main execution
main() {
  cd "$PROJECT_ROOT"

  echo "Starting comprehensive daemon tests..."
  echo ""

  run_unit_tests
  run_integration_tests
  run_regression_tests

  echo ""
  echo "========================================="
  echo "Test Summary"
  echo "========================================="
  echo "Total tests run: $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"

  if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo ""
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
  fi
}

main "$@"
```

---

## Documentation

All test files referenced:
- `/Users/krunaaltavkar/starforge-master/tests/test_daemon_comprehensive.md` (this file)
- `/Users/krunaaltavkar/starforge-master/tests/test_daemon_comprehensive.sh` (automated test script - to be created)

Code files under test:
- `/Users/krunaaltavkar/starforge-master/bin/daemon.sh`
- `/Users/krunaaltavkar/starforge-master/bin/daemon-runner.sh`
- `/Users/krunaaltavkar/starforge-master/bin/starforge` (daemon command integration)
- `/Users/krunaaltavkar/starforge-master/templates/bin/daemon.sh`
- `/Users/krunaaltavkar/starforge-master/templates/bin/daemon-runner.sh`

---

**QA Engineer Sign-off**: Ready for test execution
