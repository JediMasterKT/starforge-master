#!/bin/bash
# Atomic Trigger File Operations
# Prevents race conditions in trigger creation and processing
# Issue #331: https://github.com/JediMasterKT/starforge-master/issues/331

# State Transitions:
# 1. .pending   → File being written (in staging/)
# 2. .trigger   → Ready for daemon to process
# 3. .processing → Daemon has claimed it
# 4. .completed/.failed → Final state (in processed/)

# Create trigger file atomically using staging directory
# This prevents the daemon from picking up partial writes
#
# Args:
#   $1 - trigger_json: Complete JSON content for trigger
#   $2 - trigger_filename: Target filename (without extension)
#        Example: "junior-dev-a-implement-1234567890"
#
# Returns:
#   0 on success, 1 on failure
#   Sets $TRIGGER_FILE_PATH to final trigger location
create_trigger_atomic() {
  local trigger_json=$1
  local trigger_filename=$2

  # Validate inputs
  if [ -z "$trigger_json" ] || [ -z "$trigger_filename" ]; then
    echo "ERROR: create_trigger_atomic requires trigger_json and trigger_filename" >&2
    return 1
  fi

  # STARFORGE_CLAUDE_DIR override support
  # --------------------------------------
  # Environment variable: STARFORGE_CLAUDE_DIR (optional)
  # Fallback: .claude (standard production path)
  #
  # Why we need the fallback:
  # 1. Enables testing with alternate .claude locations
  # 2. Supports git worktrees (each has its own STARFORGE_CLAUDE_DIR)
  # 3. Future: Multi-project scenarios (one daemon, multiple projects)
  # 4. Standard case: Variable unset, fallback to .claude (99% of usage)
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local staging_dir="$claude_dir/triggers/staging"
  local triggers_dir="$claude_dir/triggers"

  # Ensure directories exist
  mkdir -p "$staging_dir"
  mkdir -p "$triggers_dir"

  # Generate unique staging filename with .pending extension
  local staging_file="$staging_dir/${trigger_filename}.pending"
  local final_file="$triggers_dir/${trigger_filename}.trigger"

  # Write to staging with .pending extension
  # If this fails (disk full, permissions, etc.), the .pending file is left behind
  # but will never be promoted to .trigger
  echo "$trigger_json" > "$staging_file"

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to write trigger to staging: $staging_file" >&2
    return 1
  fi

  # Atomic rename to final location
  # This is atomic on the same filesystem (Linux/macOS guarantee)
  # If daemon tries to read mid-write, it gets either:
  #   - File not found (if rename hasn't completed)
  #   - Complete file (if rename completed)
  # Never a partial file
  mv "$staging_file" "$final_file"

  if [ $? -ne 0 ]; then
    echo "ERROR: Failed to move trigger from staging to final location" >&2
    echo "  Staging: $staging_file" >&2
    echo "  Final: $final_file" >&2
    return 1
  fi

  # Set global variable for caller
  export TRIGGER_FILE_PATH="$final_file"

  return 0
}

# Atomically claim a trigger for processing
# Renames .trigger → .processing to prevent concurrent processing
#
# Args:
#   $1 - trigger_file: Path to .trigger file
#
# Returns:
#   0 on success (file renamed, safe to process)
#   1 on failure (file already claimed by another daemon, or doesn't exist)
#   Sets $PROCESSING_FILE_PATH to .processing file location
claim_trigger_for_processing() {
  local trigger_file=$1

  if [ ! -f "$trigger_file" ]; then
    # File doesn't exist (already claimed or deleted)
    return 1
  fi

  # Generate .processing filename
  local processing_file="${trigger_file%.trigger}.processing"

  # Atomic rename
  # If two daemons try simultaneously, only one succeeds
  # The other gets ENOENT (file not found) when mv fails
  mv "$trigger_file" "$processing_file" 2>/dev/null

  if [ $? -ne 0 ]; then
    # Another daemon won the race
    return 1
  fi

  # Set global variable for caller
  export PROCESSING_FILE_PATH="$processing_file"

  return 0
}

# Detect orphaned .pending files (abandoned writes)
# These indicate Main Claude crashed mid-write
#
# Args:
#   $1 - age_minutes: Files older than this are considered orphaned (default: 5)
#
# Returns:
#   List of orphaned .pending files
detect_orphaned_pending() {
  local age_minutes=${1:-5}
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local staging_dir="$claude_dir/triggers/staging"

  if [ ! -d "$staging_dir" ]; then
    return 0
  fi

  # Find .pending files older than age_minutes
  # Uses -mmin for "modified more than N minutes ago"
  find "$staging_dir" -name "*.pending" -type f -mmin +$age_minutes 2>/dev/null
}

# Detect orphaned .processing files (hung/crashed daemon)
# These indicate daemon crashed mid-processing
#
# Args:
#   $1 - age_minutes: Files older than this are considered orphaned (default: 30)
#
# Returns:
#   List of orphaned .processing files
detect_orphaned_processing() {
  local age_minutes=${1:-30}
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local triggers_dir="$claude_dir/triggers"

  if [ ! -d "$triggers_dir" ]; then
    return 0
  fi

  # Find .processing files older than age_minutes
  find "$triggers_dir" -name "*.processing" -type f -mmin +$age_minutes 2>/dev/null
}

# Cleanup orphaned files
# Moves orphaned .pending and .processing files to failed/ directory
#
# Args:
#   None
#
# Returns:
#   Number of files cleaned up
cleanup_orphaned_files() {
  local claude_dir="${STARFORGE_CLAUDE_DIR:-.claude}"
  local failed_dir="$claude_dir/triggers/processed/failed"
  mkdir -p "$failed_dir"

  local count=0
  local timestamp=$(date +%Y%m%d-%H%M%S)

  # Cleanup orphaned .pending files (5+ minutes old)
  local orphaned_pending=$(detect_orphaned_pending 5)
  for file in $orphaned_pending; do
    local filename=$(basename "$file")
    mv "$file" "$failed_dir/orphaned-pending-$timestamp-$filename" 2>/dev/null
    if [ $? -eq 0 ]; then
      count=$((count + 1))
      echo "Cleaned up orphaned .pending file: $filename" >&2
    fi
  done

  # Cleanup orphaned .processing files (30+ minutes old)
  local orphaned_processing=$(detect_orphaned_processing 30)
  for file in $orphaned_processing; do
    local filename=$(basename "$file")
    mv "$file" "$failed_dir/orphaned-processing-$timestamp-$filename" 2>/dev/null
    if [ $? -eq 0 ]; then
      count=$((count + 1))
      echo "Cleaned up orphaned .processing file: $filename" >&2
    fi
  done

  echo "$count"
}
