#!/bin/bash
# StarForge Logging Library
# Centralized logging for queue events and operations
# Part of Queue System Phase 1

# Configuration
LOG_FILE="${LOG_FILE:-.claude/queue-activity.log}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"
USE_SYSLOG="${USE_SYSLOG:-false}"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Log levels
LOG_LEVEL_INFO="INFO"
LOG_LEVEL_WARN="WARN"
LOG_LEVEL_ERROR="ERROR"

# Internal logging function
_log() {
    local level="$1"
    local component="$2"
    local message="$3"

    # Format: [timestamp] [level] [component] message
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local log_entry="[$timestamp] [$level] [$component] $message"

    # Write to log file
    echo "$log_entry" >> "$LOG_FILE"

    # Optionally log to syslog if available
    if [ "$USE_SYSLOG" = "true" ] && command -v logger >/dev/null 2>&1; then
        logger -t "starforge-$component" -p "user.$level" "$message"
    fi
}

# Public API functions

# Log info message
# Usage: log_info "component" "message"
log_info() {
    local component="$1"
    local message="$2"
    _log "$LOG_LEVEL_INFO" "$component" "$message"
}

# Log warning message
# Usage: log_warn "component" "message"
log_warn() {
    local component="$1"
    local message="$2"
    _log "$LOG_LEVEL_WARN" "$component" "$message"
}

# Log error message
# Usage: log_error "component" "message"
log_error() {
    local component="$1"
    local message="$2"
    _log "$LOG_LEVEL_ERROR" "$component" "$message"
}

# Rotate logs (keep last N days)
# Usage: rotate_logs [days]
rotate_logs() {
    local retention_days="${1:-$LOG_RETENTION_DAYS}"

    if [ ! -f "$LOG_FILE" ]; then
        return 0
    fi

    # Create temporary file for recent logs
    local temp_log="/tmp/starforge-logs-$$"

    # Calculate cutoff date (N days ago)
    local cutoff_date
    if date -v-${retention_days}d >/dev/null 2>&1; then
        # macOS date command
        cutoff_date=$(date -v-${retention_days}d -u +"%Y-%m-%d")
    else
        # Linux date command
        cutoff_date=$(date -d "$retention_days days ago" -u +"%Y-%m-%d")
    fi

    # Keep only logs from after cutoff date
    # Format: [2025-10-23T...] so we can grep by date
    # Use sed for better portability across macOS and Linux
    if grep -E "^\[20[0-9]{2}-[0-9]{2}-[0-9]{2}" "$LOG_FILE" | \
       sed -n "s/^\[\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1 &/p" | \
       awk -v cutoff="$cutoff_date" '$1 >= cutoff {sub(/^[^ ]+ /, ""); print}' > "$temp_log"; then

        # Replace log file with filtered logs
        mv "$temp_log" "$LOG_FILE"
    else
        # If filtering failed, keep original log
        rm -f "$temp_log"
    fi
}

# Get recent log entries
# Usage: get_recent_logs [count]
get_recent_logs() {
    local count="${1:-50}"

    if [ ! -f "$LOG_FILE" ]; then
        echo "No logs found"
        return 1
    fi

    tail -n "$count" "$LOG_FILE"
}

# Get logs for specific component
# Usage: get_component_logs "component" [count]
get_component_logs() {
    local component="$1"
    local count="${2:-50}"

    if [ ! -f "$LOG_FILE" ]; then
        echo "No logs found"
        return 1
    fi

    grep "\[$component\]" "$LOG_FILE" | tail -n "$count"
}

# Get logs by level
# Usage: get_logs_by_level "level" [count]
get_logs_by_level() {
    local level="$1"
    local count="${2:-50}"

    if [ ! -f "$LOG_FILE" ]; then
        echo "No logs found"
        return 1
    fi

    grep "\[$level\]" "$LOG_FILE" | tail -n "$count"
}

# Get error logs (convenience function)
# Usage: get_error_logs [count]
get_error_logs() {
    get_logs_by_level "ERROR" "${1:-50}"
}

# Get warning logs (convenience function)
# Usage: get_warning_logs [count]
get_warning_logs() {
    get_logs_by_level "WARN" "${1:-50}"
}

# Clear old logs (more aggressive than rotation)
# Usage: clear_logs
clear_logs() {
    if [ -f "$LOG_FILE" ]; then
        > "$LOG_FILE"
        log_info "logger" "Log file cleared"
    fi
}

# Export functions for use by other scripts
export -f log_info log_warn log_error
export -f rotate_logs get_recent_logs get_component_logs
export -f get_logs_by_level get_error_logs get_warning_logs
export -f clear_logs
