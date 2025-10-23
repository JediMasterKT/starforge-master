#!/bin/bash
# StarForge Trigger Router Library
# Routes trigger files to agent queues
# Part of queue system implementation

# Source logger if available (tests provide their own)
if [ -z "$(type -t log_info 2>/dev/null)" ]; then
    # Fallback logger functions
    log_info() {
        local component="$1"
        local message="$2"
        echo "[$(date -Iseconds)] [INFO] [$component] $message" >> .claude/router.log
    }

    log_error() {
        local component="$1"
        local message="$2"
        echo "[$(date -Iseconds)] [ERROR] [$component] $message" >> .claude/router.log
    }

    log_warn() {
        local component="$1"
        local message="$2"
        echo "[$(date -Iseconds)] [WARN] [$component] $message" >> .claude/router.log
    }
fi

# Route trigger file to queue
# Args:
#   $1 - Path to trigger file
# Returns:
#   0 on success, 1 on failure
route_trigger_to_queue() {
    local trigger_file="$1"

    if [ -z "$trigger_file" ]; then
        log_error "router" "No trigger file specified"
        return 1
    fi

    if [ ! -f "$trigger_file" ]; then
        log_error "router" "Trigger file not found: $trigger_file"
        return 1
    fi

    # Validate JSON
    if ! jq empty "$trigger_file" 2>/dev/null; then
        log_error "router" "Invalid JSON in trigger file: $trigger_file"
        # Move to invalid directory
        local invalid_dir=".claude/triggers/invalid"
        mkdir -p "$invalid_dir"
        mv "$trigger_file" "$invalid_dir/" 2>/dev/null
        return 1
    fi

    # Extract fields from trigger
    local agent=$(jq -r '.to_agent' "$trigger_file" 2>/dev/null)
    local action=$(jq -r '.action' "$trigger_file" 2>/dev/null)
    local context=$(jq -c '.context' "$trigger_file" 2>/dev/null)

    # Validate required fields
    if [ -z "$agent" ] || [ "$agent" = "null" ]; then
        log_error "router" "Missing 'to_agent' field in trigger: $trigger_file"
        local invalid_dir=".claude/triggers/invalid"
        mkdir -p "$invalid_dir"
        mv "$trigger_file" "$invalid_dir/" 2>/dev/null
        return 1
    fi

    if [ -z "$action" ] || [ "$action" = "null" ]; then
        log_error "router" "Missing 'action' field in trigger: $trigger_file"
        local invalid_dir=".claude/triggers/invalid"
        mkdir -p "$invalid_dir"
        mv "$trigger_file" "$invalid_dir/" 2>/dev/null
        return 1
    fi

    # Set default context if missing
    if [ -z "$context" ] || [ "$context" = "null" ]; then
        context="{}"
    fi

    # Create task ID (timestamp-based for FIFO ordering)
    # Use nanoseconds for uniqueness within same second
    local timestamp=$(date +%s)
    local random_suffix=$(( RANDOM % 10000 ))
    local task_id="task-${timestamp}-${random_suffix}"

    # Ensure queue directory exists
    local queue_dir=".claude/queues/$agent/pending"
    mkdir -p "$queue_dir"

    # Create task file
    local task_file="$queue_dir/$task_id.json"

    cat > "$task_file" <<EOF
{
  "id": "$task_id",
  "agent": "$agent",
  "action": "$action",
  "context": $context,
  "created_at": "$(date -Iseconds)",
  "priority": "normal",
  "retry_count": 0,
  "source_trigger": "$trigger_file"
}
EOF

    # Validate created task file
    if ! jq empty "$task_file" 2>/dev/null; then
        log_error "router" "Failed to create valid task file: $task_file"
        rm -f "$task_file"
        return 1
    fi

    # Archive original trigger
    local processed_dir=".claude/triggers/processed"
    mkdir -p "$processed_dir"

    # Use basename to avoid path issues
    local trigger_basename=$(basename "$trigger_file")
    mv "$trigger_file" "$processed_dir/$trigger_basename" 2>/dev/null

    # Log success
    log_info "router" "Routed $action to $agent queue (task: $task_id)"

    return 0
}
