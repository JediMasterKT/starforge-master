# PR #138 Testing Plan - Executive Summary

**PR**: Autonomous Daemon for 24/7 Operation
**Branch**: feature/autonomous-daemon
**QA Engineer**: Claude Code QA
**Date**: 2025-10-24

---

## Quick Reference

**Total Test Cases**: 80
- Unit Tests: 42
- Integration Tests: 18
- Manual Tests: 12
- Performance Tests: 8

**Must Pass Before Merge**: 28 critical tests
**Should Pass Before Merge**: 24 high-priority tests
**Can Be Post-Merge**: 28 medium/low-priority tests

---

## Testing Strategy

### Phase 1: Automated Critical Path (Est. 2 hours)
Run all P0 critical automated tests to verify core functionality.

**Command**:
```bash
cd /Users/krunaaltavkar/starforge-master
bash tests/test_daemon_comprehensive.sh --critical-only
```

**Expected Result**: 28/28 critical tests pass

---

### Phase 2: Integration Testing (Est. 1 hour)
Verify end-to-end workflows with real agents.

**Key Tests**:
1. Complete trigger flow (happy path)
2. Multi-trigger sequential processing
3. Crash recovery without data loss
4. TPM → Orchestrator handoff

---

### Phase 3: Manual Validation (Est. 1 hour)
Human verification of user experience and edge cases.

**Key Scenarios**:
1. First-time daemon start (user experience)
2. Real development workflow (issue → PR)
3. Status output clarity
4. Error message friendliness

---

### Phase 4: Performance Benchmarking (Est. 30 min)
Verify performance targets are met.

**Critical Metric**:
- Trigger detection latency <5 seconds

**Secondary Metrics**:
- CPU usage <1% idle, <10% under load
- Memory stable after 100 triggers
- No memory leaks

---

## Test Coverage by Component

### daemon.sh (Lifecycle Manager)
- **Lines**: 332
- **Test Cases**: 16 unit tests
- **Coverage**: Lifecycle operations, PID management, locking, status reporting

### daemon-runner.sh (Core Logic)
- **Lines**: 350
- **Test Cases**: 26 unit tests + 12 integration tests
- **Coverage**: Event detection, JSON parsing, agent invocation, retry logic, state persistence, crash recovery

### bin/starforge (CLI Integration)
- **Lines**: 20 new lines
- **Test Cases**: 4 unit tests + regression tests
- **Coverage**: Command routing, help text, error handling

---

## Quality Gates

### Gate 1: Unit Tests ✅
**Target**: >80% code coverage, all tests passing
**Critical Tests**: 17
**Status**: PENDING EXECUTION

**Validation Checklist**:
- [ ] All lifecycle operations work (start/stop/restart/status)
- [ ] PID/lock management prevents duplicates
- [ ] Stale process cleanup automatic
- [ ] JSON validation catches malformed triggers
- [ ] FIFO queue ordering maintained
- [ ] Retry mechanism: 3 attempts with exponential backoff
- [ ] Trigger archival to correct directories
- [ ] State persistence across restarts
- [ ] fswatch detection <5 seconds
- [ ] Graceful signal handling (SIGTERM/SIGINT)

---

### Gate 2: Integration Tests ✅
**Target**: End-to-end workflows complete successfully
**Critical Tests**: 6
**Status**: PENDING EXECUTION

**Validation Checklist**:
- [ ] Complete trigger flow (detect → invoke → archive)
- [ ] Multi-trigger sequential processing (no parallelism)
- [ ] State survives daemon restart
- [ ] Mixed valid/invalid triggers isolated
- [ ] Retry recovers from transient failures
- [ ] Crash recovery with no data loss
- [ ] Real agent handoffs (TPM → Orchestrator)

---

### Gate 3: Manual Testing ✅
**Target**: User experience is intuitive and error-free
**Critical Tests**: 2
**Status**: PENDING EXECUTION

**Validation Checklist**:
- [ ] First-time user experience smooth
- [ ] Real development workflow (issue → PR) autonomous
- [ ] Status output clear and informative
- [ ] Error messages helpful and actionable
- [ ] Help text comprehensive

---

### Gate 4: Regression ✅
**Target**: No breaking changes to existing functionality
**Critical Tests**: 2
**Status**: PENDING EXECUTION

**Validation Checklist**:
- [ ] Manual agent invocation (`starforge use`) still works
- [ ] All 96 existing tests pass (test-install.sh, test-cli.sh)
- [ ] Trigger monitor script unaffected
- [ ] Update command includes daemon files
- [ ] Fresh installation includes daemon

---

### Gate 5: Performance ✅
**Target**: <5s detection, <1% CPU idle, no memory leaks
**Critical Tests**: 1
**Status**: PENDING EXECUTION

**Validation Checklist**:
- [ ] Trigger detection <5 seconds (95th percentile)
- [ ] CPU <1% when idle
- [ ] Memory stable after 100 triggers
- [ ] No memory leaks over time

---

## Known Risks & Mitigations

### Risk 1: Race Conditions in Concurrent Trigger Creation
**Severity**: P1 (High)
**Mitigation**: Lock directory prevents multiple daemon instances. fswatch event-driven detection ensures sequential processing.
**Test Coverage**: Test 2.2.2 (Concurrent Trigger Creation)

### Risk 2: Data Loss on Daemon Crash
**Severity**: P0 (Critical)
**Mitigation**: State file updated after each trigger. Interrupted triggers marked as failed on restart. Deduplication prevents re-processing.
**Test Coverage**: Test 2.2.1 (Kill During Processing)

### Risk 3: Infinite Retry Loop
**Severity**: P1 (High)
**Mitigation**: Max 3 retries enforced. Parse errors skip retry. Exponential backoff prevents rapid retries.
**Test Coverage**: Test 1.2.18 (Max Retries), Test 1.2.19 (No Retry for Parse Errors)

### Risk 4: PID File Stale After System Crash
**Severity**: P2 (Medium)
**Mitigation**: Automatic stale PID detection and cleanup on daemon start.
**Test Coverage**: Test 1.1.3 (Stale PID Cleanup)

### Risk 5: fswatch Not Installed
**Severity**: P1 (High)
**Mitigation**: Clear error message with installation instructions. Daemon exits gracefully.
**Test Coverage**: Test 1.1.4 (Missing fswatch)

---

## Edge Cases Covered

1. **Empty trigger directory**: Daemon runs idle, monitors for events
2. **Malformed JSON**: Archived to invalid/, no retry
3. **Missing required field (to_agent)**: Treated as parse error, no retry
4. **Large trigger payload (10KB)**: Parsed successfully, no truncation
5. **Rapid trigger creation (10 simultaneous)**: All detected and processed sequentially
6. **Daemon killed mid-processing**: Interrupted trigger marked failed, no re-process
7. **Offline trigger creation (daemon stopped)**: Backlog processed on startup
8. **Duplicate trigger filename**: Deduplication prevents re-processing
9. **Stale PID file**: Automatic cleanup, new daemon starts
10. **Multiple daemon start attempts**: Lock prevents duplicates

---

## Test Execution Instructions

### Quick Start (Critical Tests Only)
```bash
cd /Users/krunaaltavkar/starforge-master
git checkout feature/autonomous-daemon

# Run critical automated tests (Est. 30 min)
bash tests/test_daemon_critical.sh

# Manual critical tests (Est. 30 min)
# 1. First-time daemon start UX test
# 2. Real workflow test (issue → PR)

# Performance critical test (Est. 5 min)
bash tests/test_daemon_performance.sh --latency-only
```

**Total Time**: ~1 hour
**Decision Point**: If all critical tests pass → APPROVE for merge

---

### Full Test Suite (All Tests)
```bash
# Unit tests (Est. 1 hour)
bash tests/test_daemon_comprehensive.sh --unit

# Integration tests (Est. 1.5 hours)
bash tests/test_daemon_comprehensive.sh --integration

# Manual tests (Est. 1 hour)
# See test_daemon_comprehensive.md Manual Test section

# Regression tests (Est. 30 min)
bash bin/test-install.sh
bash bin/test-cli.sh
bash tests/test_daemon_comprehensive.sh --regression

# Performance tests (Est. 30 min)
bash tests/test_daemon_performance.sh --full
```

**Total Time**: ~4.5 hours
**Use Case**: Comprehensive validation before major release

---

## Approval Criteria

### Minimum for Merge (Fast Track)
- ✅ All 28 critical tests pass
- ✅ No regressions in existing functionality
- ✅ Trigger detection <5 seconds
- ✅ Real agent handoff works (TPM → Orchestrator)
- ✅ User experience validated (first-time start + real workflow)

**Estimated Time to Approval**: 1-2 hours

---

### Ideal for Merge (Thorough)
- ✅ All critical tests pass (28/28)
- ✅ All high-priority tests pass (24/24)
- ✅ 90%+ of medium/low-priority tests pass
- ✅ Performance benchmarks met
- ✅ All manual scenarios validated
- ✅ Overnight stability test passed

**Estimated Time to Approval**: 4-6 hours

---

## Post-Merge Testing Plan

### Nice-to-Have Tests (Can Be Post-Merge)
1. **Overnight stability test** (24-hour daemon run)
2. **Load test** (50+ concurrent triggers)
3. **Memory leak test** (1000+ triggers over 24 hours)
4. **System reboot recovery** (macOS restart with daemon running)
5. **Network failure recovery** (GitHub API down scenario)
6. **Disk full scenario** (graceful error handling)
7. **Log rotation** (>10MB log file handling)

**Timeline**: Week 1 after merge
**Owner**: QA Engineer

---

## Bug Severity Classification

**P0 (Critical)**: Daemon crash, data loss, infinite loop
**P1 (High)**: Trigger processing failure, retry mechanism broken, race conditions
**P2 (Medium)**: UI/UX issues, performance degradation, minor memory leaks
**P3 (Low)**: Cosmetic issues, edge cases, documentation

---

## Success Metrics

### Functional Metrics
- **Test Pass Rate**: ≥95% (76/80 tests)
- **Critical Test Pass Rate**: 100% (28/28 tests)
- **Regression Rate**: 0% (all existing tests pass)

### Performance Metrics
- **Trigger Detection Latency**: <5s (95th percentile)
- **CPU Usage (Idle)**: <1%
- **CPU Usage (Load)**: <10%
- **Memory Footprint**: <100MB
- **Memory Leak Rate**: 0

### User Experience Metrics
- **Setup Time**: <2 minutes (install to first trigger processed)
- **Error Recovery**: 100% (all error scenarios handled gracefully)
- **Documentation Completeness**: 100% (all commands documented in help)

---

## Next Steps

1. **Create automated test scripts**:
   - `tests/test_daemon_critical.sh` (28 critical tests)
   - `tests/test_daemon_comprehensive.sh` (all 80 tests)
   - `tests/test_daemon_performance.sh` (performance benchmarks)

2. **Execute critical tests** (1-2 hours)

3. **Manual validation** (1 hour)

4. **Generate QA report** with results

5. **Decision**: APPROVE or DECLINE with specific issues

---

## Files

**Test Plan**: `/Users/krunaaltavkar/starforge-master/tests/test_daemon_comprehensive.md`
**Summary**: `/Users/krunaaltavkar/starforge-master/tests/DAEMON_TEST_PLAN_SUMMARY.md` (this file)

**Code Under Test**:
- `/Users/krunaaltavkar/starforge-master/bin/daemon.sh`
- `/Users/krunaaltavkar/starforge-master/bin/daemon-runner.sh`
- `/Users/krunaaltavkar/starforge-master/bin/starforge`

**Related PRs**: #138

---

**QA Engineer**: Ready for test execution
**Estimated Review Time**: 1-6 hours (depending on thoroughness level)
**Recommendation**: Start with critical tests (1 hour), then decide on full suite
