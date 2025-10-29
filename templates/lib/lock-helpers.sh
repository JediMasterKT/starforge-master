#!/bin/bash
# StarForge Distributed Locking Library
# Provides file-based mutual exclusion using flock for coordination files

# Lock directory
LOCK_DIR="${STARFORGE_CLAUDE_DIR:-$PWD/.claude}/locks"

# Ensure lock directory exists
mkdir -p "$LOCK_DIR" 2>/dev/null

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Core Locking Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# acquire_lock - Acquire exclusive lock on a resource
#
# Usage: acquire_lock "resource-name" [timeout]
#
# Arguments:
#   resource-name: Unique identifier for the resource (e.g., "agent-junior-dev-a")
#   timeout: Optional timeout in seconds (default: 30)
#
# Returns:
#   0: Lock acquired successfully
#   1: Lock acquisition failed (timeout or error)
#
# Example:
#   if acquire_lock "agent-junior-dev-a" 30; then
#     # Critical section - modify agent status
#     echo "status: working" > .claude/coordination/junior-dev-a-status.json
#     release_lock
#   else
#     echo "Failed to acquire lock"
#   fi
#
# Implementation: Uses mkdir for atomic lock acquisition (cross-platform)
#
acquire_lock() {
  local resource="$1"
  local timeout="${2:-30}"
  local lock_dir="$LOCK_DIR/${resource}.lock"

  # Validate resource name
  if [ -z "$resource" ]; then
    echo "ERROR: acquire_lock requires resource name" >&2
    return 1
  fi

  # Store lock dir in global for release_lock
  CURRENT_LOCK_DIR="$lock_dir"

  # Try to acquire lock with timeout
  local elapsed=0
  while [ $elapsed -lt $timeout ]; do
    # Try to create lock directory (atomic operation)
    if mkdir "$lock_dir" 2>/dev/null; then
      # Write lock metadata for debugging
      echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") PID:$$ HOST:$(hostname)" > "$lock_dir/metadata"
      return 0
    fi

    # Lock acquisition failed, wait and retry
    sleep 0.1
    elapsed=$((elapsed + 1))
  done

  # Timeout
  return 1
}

# release_lock - Release previously acquired lock
#
# Usage: release_lock
#
# Returns:
#   0: Lock released successfully
#
# Example:
#   acquire_lock "agent-junior-dev-a" 30
#   # ... do work ...
#   release_lock
#
release_lock() {
  # Release lock by removing lock directory
  if [ -n "$CURRENT_LOCK_DIR" ] && [ -d "$CURRENT_LOCK_DIR" ]; then
    rmdir "$CURRENT_LOCK_DIR" 2>/dev/null || rm -rf "$CURRENT_LOCK_DIR"
    CURRENT_LOCK_DIR=""
    return 0
  else
    # No lock held - not an error
    return 0
  fi
}

# with_lock - Execute function with automatic lock acquisition/release
#
# Usage: with_lock "resource-name" function_name [args...]
#
# Arguments:
#   resource-name: Unique identifier for the resource
#   function_name: Function to execute while holding lock
#   args: Optional arguments to pass to function
#
# Returns:
#   Exit code of the function
#
# Example:
#   update_agent_status() {
#     local agent=$1
#     local status=$2
#     echo "{\"status\":\"$status\"}" > ".claude/coordination/${agent}-status.json"
#   }
#
#   with_lock "agent-junior-dev-a" update_agent_status "junior-dev-a" "working"
#
with_lock() {
  local resource="$1"
  local func="$2"
  shift 2

  # Validate inputs
  if [ -z "$resource" ] || [ -z "$func" ]; then
    echo "ERROR: with_lock requires resource name and function name" >&2
    return 1
  fi

  # Check if function exists
  if ! declare -f "$func" >/dev/null 2>&1; then
    echo "ERROR: Function '$func' not found" >&2
    return 1
  fi

  # Acquire lock
  if ! acquire_lock "$resource" 30; then
    echo "ERROR: Failed to acquire lock on '$resource'" >&2
    return 1
  fi

  # Execute function with automatic cleanup
  local exit_code=0
  (
    # Trap ensures release_lock runs even on errors
    trap 'release_lock' EXIT
    "$func" "$@"
  ) || exit_code=$?

  # Release lock
  release_lock

  return $exit_code
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# High-Level Locking Functions
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# lock_agent - Acquire lock on agent status file
#
# Usage: lock_agent "agent-name" [timeout]
#
# Example:
#   if lock_agent "junior-dev-a" 30; then
#     # Modify agent status
#     unlock_agent "junior-dev-a"
#   fi
#
lock_agent() {
  local agent="$1"
  local timeout="${2:-30}"
  acquire_lock "agent-$agent" "$timeout"
}

# unlock_agent - Release agent lock
#
# Usage: unlock_agent "agent-name"
#
unlock_agent() {
  release_lock
}

# lock_trigger - Acquire lock on trigger file
#
# Usage: lock_trigger "trigger-file" [timeout]
#
# Example:
#   if lock_trigger "orchestrator-assign-123.trigger" 5; then
#     # Move trigger through state transitions
#     mv .claude/triggers/foo.trigger .claude/triggers/foo.processing
#     unlock_trigger
#   fi
#
lock_trigger() {
  local trigger_basename=$(basename "$1")
  local timeout="${2:-5}"
  acquire_lock "trigger-$trigger_basename" "$timeout"
}

# unlock_trigger - Release trigger lock
#
# Usage: unlock_trigger
#
unlock_trigger() {
  release_lock
}

# lock_coordination_file - Acquire lock on coordination file
#
# Usage: lock_coordination_file "filename" [timeout]
#
# Example:
#   if lock_coordination_file "orchestrator.json" 30; then
#     # Update orchestrator state
#     echo "$new_state" > .claude/coordination/orchestrator.json
#     unlock_coordination_file
#   fi
#
lock_coordination_file() {
  local filename=$(basename "$1")
  local timeout="${2:-30}"
  acquire_lock "coord-$filename" "$timeout"
}

# unlock_coordination_file - Release coordination file lock
#
# Usage: unlock_coordination_file
#
unlock_coordination_file() {
  release_lock
}

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Lock Diagnostics
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# list_active_locks - List all currently held locks
#
# Usage: list_active_locks
#
# Output: JSON array of active locks with metadata
#
list_active_locks() {
  local locks=()

  if [ ! -d "$LOCK_DIR" ]; then
    echo "[]"
    return 0
  fi

  for lock_dir in "$LOCK_DIR"/*.lock; do
    [ -d "$lock_dir" ] || continue

    local resource=$(basename "$lock_dir" .lock)
    local metadata=$(cat "$lock_dir/metadata" 2>/dev/null || echo "unknown")

    locks+=("{\"resource\":\"$resource\",\"metadata\":\"$metadata\",\"held\":true}")
  done

  # Output as JSON array
  printf "["
  printf "%s" "${locks[0]}"
  for ((i=1; i<${#locks[@]}; i++)); do
    printf ",%s" "${locks[i]}"
  done
  printf "]\n"
}

# is_locked - Check if resource is currently locked
#
# Usage: is_locked "resource-name"
#
# Returns:
#   0: Resource is locked
#   1: Resource is not locked
#
is_locked() {
  local resource="$1"
  local lock_dir="$LOCK_DIR/${resource}.lock"

  # Check if lock directory exists
  if [ -d "$lock_dir" ]; then
    return 0  # Locked
  else
    return 1  # Not locked
  fi
}

# cleanup_stale_locks - Remove lock directories for non-existent PIDs
#
# Usage: cleanup_stale_locks
#
# Note: Only cleans lock directories that contain PID metadata
#
cleanup_stale_locks() {
  local cleaned=0

  if [ ! -d "$LOCK_DIR" ]; then
    return 0
  fi

  for lock_dir in "$LOCK_DIR"/*.lock; do
    [ -d "$lock_dir" ] || continue

    # Extract PID from metadata file
    local metadata_file="$lock_dir/metadata"
    if [ -f "$metadata_file" ]; then
      local pid=$(grep -oE 'PID:[0-9]+' "$metadata_file" 2>/dev/null | cut -d: -f2)

      if [ -n "$pid" ]; then
        # Check if PID exists
        if ! kill -0 "$pid" 2>/dev/null; then
          # Process dead, remove stale lock
          rm -rf "$lock_dir" 2>/dev/null && cleaned=$((cleaned + 1))
        fi
      fi
    fi
  done

  [ $cleaned -gt 0 ] && echo "Cleaned $cleaned stale lock(s)" >&2
  return 0
}
