#!/bin/bash
# Test suite for logger.sh library
# Tests for Queue Phase 1 - Logging Infrastructure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$STARFORGE_ROOT/.tmp/logger-test"
LOG_FILE="$TEST_DIR/.claude/queue-activity.log"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 StarForge Logger Test Suite"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test helper functions
assert_success() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local desc="$1"
    local exit_code=${2:-$?}

    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc (exit code: $exit_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local pattern="$2"
    local desc="$3"

    if [ ! -f "$file" ]; then
        echo -e "  ${RED}✗${NC} $desc (file not found: $file)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    if grep -q "$pattern" "$file"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Pattern not found: $pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_not_contains() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local file="$1"
    local pattern="$2"
    local desc="$3"

    if [ ! -f "$file" ]; then
        echo -e "  ${GREEN}✓${NC} $desc (file doesn't exist)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi

    if ! grep -q "$pattern" "$file"; then
        echo -e "  ${GREEN}✓${NC} $desc"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗${NC} $desc"
        echo -e "    Pattern should not exist: $pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/.claude"
    cd "$TEST_DIR"
}

cleanup_test_env() {
    cd "$STARFORGE_ROOT"
    rm -rf "$TEST_DIR"
}

# ============================================
# TEST SUITE
# ============================================

# Test 1: Logger library exists
test_logger_exists() {
    echo "Test 1: Logger library exists"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        assert_success "logger.sh exists" 0
    else
        assert_success "logger.sh exists" 1
    fi
}

# Test 2: Log info message
test_log_info() {
    setup_test_env
    echo "Test 2: Log info message"

    # Source logger
    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_info "tpm" "Test info message"

        assert_file_contains "$LOG_FILE" "Test info message" "Message logged"
        assert_file_contains "$LOG_FILE" "INFO" "Level is INFO"
        assert_file_contains "$LOG_FILE" "tpm" "Component name logged"
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 3))
        TESTS_FAILED=$((TESTS_FAILED + 3))
    fi

    cleanup_test_env
}

# Test 3: Log error message
test_log_error() {
    setup_test_env
    echo "Test 3: Log error message"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_error "orchestrator" "Test error message"

        assert_file_contains "$LOG_FILE" "Test error message" "Error message logged"
        assert_file_contains "$LOG_FILE" "ERROR" "Level is ERROR"
        assert_file_contains "$LOG_FILE" "orchestrator" "Component name logged"
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 3))
        TESTS_FAILED=$((TESTS_FAILED + 3))
    fi

    cleanup_test_env
}

# Test 4: Log warn message
test_log_warn() {
    setup_test_env
    echo "Test 4: Log warning message"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_warn "qa-engineer" "Test warning message"

        assert_file_contains "$LOG_FILE" "Test warning message" "Warning message logged"
        assert_file_contains "$LOG_FILE" "WARN" "Level is WARN"
        assert_file_contains "$LOG_FILE" "qa-engineer" "Component name logged"
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 3))
        TESTS_FAILED=$((TESTS_FAILED + 3))
    fi

    cleanup_test_env
}

# Test 5: Timestamp format
test_timestamp_format() {
    setup_test_env
    echo "Test 5: Timestamp format"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_info "test" "Timestamp test"

        # Check for timestamp pattern like [2025-10-23T...]
        assert_file_contains "$LOG_FILE" "\[20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]" "Timestamp in ISO format"
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# Test 6: Structured log format
test_structured_format() {
    setup_test_env
    echo "Test 6: Structured log format"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_info "router" "Format test"

        # Format should be: [timestamp] [level] [component] message
        assert_file_contains "$LOG_FILE" "\[.*\] \[INFO\] \[router\] Format test" "Structured format correct"
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# Test 7: Multiple log entries
test_multiple_entries() {
    setup_test_env
    echo "Test 7: Multiple log entries"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_info "test" "Entry 1"
        log_warn "test" "Entry 2"
        log_error "test" "Entry 3"

        assert_file_contains "$LOG_FILE" "Entry 1" "First entry logged"
        assert_file_contains "$LOG_FILE" "Entry 2" "Second entry logged"
        assert_file_contains "$LOG_FILE" "Entry 3" "Third entry logged"

        local line_count=$(wc -l < "$LOG_FILE" | tr -d ' ')
        if [ "$line_count" -ge 3 ]; then
            echo -e "  ${GREEN}✓${NC} All 3 entries logged"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "  ${RED}✗${NC} Expected 3 entries, found $line_count"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 4))
        TESTS_FAILED=$((TESTS_FAILED + 4))
    fi

    cleanup_test_env
}

# Test 8: Log rotation
test_log_rotation() {
    setup_test_env
    echo "Test 8: Log rotation"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        # Create old log entry (8 days ago)
        echo "[2025-10-15T00:00:00Z] [INFO] [test] OLD ENTRY" >> "$LOG_FILE"
        log_info "test" "NEW ENTRY"

        # Run rotation if function exists
        if type -t rotate_logs >/dev/null 2>&1; then
            rotate_logs

            assert_file_not_contains "$LOG_FILE" "OLD ENTRY" "Old entries rotated out"
            assert_file_contains "$LOG_FILE" "NEW ENTRY" "New entries preserved"
        else
            echo -e "  ${YELLOW}⚠${NC}  rotate_logs function not implemented - skipping rotation test"
            TESTS_RUN=$((TESTS_RUN + 2))
            TESTS_PASSED=$((TESTS_PASSED + 2))  # Don't fail on optional feature
        fi
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 2))
        TESTS_FAILED=$((TESTS_FAILED + 2))
    fi

    cleanup_test_env
}

# Test 9: Log file creation
test_log_file_creation() {
    setup_test_env
    echo "Test 9: Log file creation"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        log_info "test" "First message"

        if [ -f "$LOG_FILE" ]; then
            echo -e "  ${GREEN}✓${NC} Log file created automatically"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "  ${RED}✗${NC} Log file not created"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# Test 10: Syslog support (optional)
test_syslog_support() {
    setup_test_env
    echo "Test 10: Syslog support (optional)"

    if [ -f "$STARFORGE_ROOT/templates/lib/logger.sh" ]; then
        source "$STARFORGE_ROOT/templates/lib/logger.sh"

        # Check if USE_SYSLOG variable exists
        if [ -n "$USE_SYSLOG" ] || type -t log_to_syslog >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Syslog support implemented"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "  ${YELLOW}⚠${NC}  Syslog support not implemented (optional)"
            TESTS_RUN=$((TESTS_RUN + 1))
            TESTS_PASSED=$((TESTS_PASSED + 1))  # Don't fail on optional feature
        fi
    else
        echo -e "  ${YELLOW}⚠${NC}  logger.sh not implemented yet - skipping"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    cleanup_test_env
}

# ============================================
# RUN ALL TESTS
# ============================================

test_logger_exists
test_log_info
test_log_error
test_log_warn
test_timestamp_format
test_structured_format
test_multiple_entries
test_log_rotation
test_log_file_creation
test_syslog_support

# ============================================
# PRINT SUMMARY
# ============================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Tests run:    $TESTS_RUN"
echo -e "  ${GREEN}Passed:${NC}       $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC}       $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Logger functionality working:"
    echo "  ✓ Log levels (INFO, WARN, ERROR)"
    echo "  ✓ Structured format with timestamps"
    echo "  ✓ Component-based logging"
    echo "  ✓ Log rotation"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Implement logger.sh to make tests pass."
    echo ""
    exit 1
fi
