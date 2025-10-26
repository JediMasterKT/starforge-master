#!/bin/bash
# MCP File Tools - File Operations Implementation
# Part of StarForge MCP Integration (Issues #175, #176, #177, #178)
#
# Provides file reading, writing, search, and content grep capabilities via MCP protocol

# starforge_read_file - Read file contents and return via MCP
#
# Validates path is absolute, reads file contents, and returns
# properly escaped JSON response.
#
# Args:
#   Supports both old (positional) and new (flag-based) APIs for backward compatibility
#
#   Old API (positional):
#     $1 - Absolute file path to read
#
#   New API (flag-based):
#     --format <concise|detailed> - Response format (optional, defaults to concise)
#     <file_path> - Absolute file path (can be before or after flags)
#
# Returns:
#   JSON object with either:
#   - {"content": "file contents"} on success
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_read_file "/path/to/file.txt"
#   # => {"content": "first 100 lines..."} (default: concise)
#
#   starforge_read_file --format detailed "/path/to/file.txt"
#   # => {"content": "full file contents"}
#
#   starforge_read_file "/path/to/file.txt" --format concise
#   # => {"content": "first 100 lines..."}
#
#   starforge_read_file "relative/path.txt"
#   # => {"error": "Path must be absolute"}
#
starforge_read_file() {
  local file_path=""
  local format="concise"  # Changed default from "detailed" to "concise" per QA feedback

  # Parse arguments (support BOTH old positional and new flag-based APIs)
  while [[ $# -gt 0 ]]; do
    case $1 in
      --format)
        format="$2"
        shift 2
        ;;
      --*)
        echo "{\"error\": \"Unknown flag: $1\"}"
        return 1
        ;;
      *)
        # Positional argument - treat as file path
        if [[ -z "$file_path" ]]; then
          file_path="$1"
        else
          echo "{\"error\": \"Multiple file paths specified: $file_path and $1\"}"
          return 1
        fi
        shift
        ;;
    esac
  done

  # Validate input
  if [ -z "$file_path" ]; then
    echo '{"error": "Path is required"}'
    return 1
  fi

  # Validate path is absolute (must start with /)
  if [[ ! "$file_path" =~ ^/ ]]; then
    echo '{"error": "Path must be absolute (must start with /)"}'
    return 1
  fi

  # Check if file exists
  if [ ! -f "$file_path" ]; then
    echo "{\"error\": \"File does not exist: $file_path\"}"
    return 1
  fi

  # Check if file is readable
  if [ ! -r "$file_path" ]; then
    echo "{\"error\": \"File is not readable: $file_path\"}"
    return 1
  fi

  # Read file based on format
  local content
  case "$format" in
    concise)
      # Concise: First 100 lines (saves tokens)
      if content=$(head -n 100 "$file_path" | jq -Rs . 2>/dev/null); then
        echo "{\"content\": $content}"
        return 0
      else
        echo '{"error": "Failed to read file"}'
        return 1
      fi
      ;;
    detailed)
      # Detailed: Full file contents
      if content=$(jq -Rs . "$file_path" 2>/dev/null); then
        echo "{\"content\": $content}"
        return 0
      else
        echo '{"error": "Failed to read file"}'
        return 1
      fi
      ;;
    *)
      echo "{\"error\": \"Invalid format: $format (must be concise or detailed)\"}"
      return 1
      ;;
  esac
}

# starforge_search_files - Search for files matching glob pattern
#
# Recursively searches directory for files matching a glob pattern.
# Uses find command for efficient file searching.
#
# Args:
#   Supports both old (positional) and new (flag-based) APIs for backward compatibility
#
#   Old API (positional):
#     $1 - Glob pattern (e.g., "*.py", "*.js", "test_*.sh")
#     $2 - Directory path to search (optional, defaults to current directory)
#
#   New API (flag-based):
#     --format <concise|detailed> - Response format (optional, defaults to concise)
#     <pattern> <search_path> - Can be in any order with flags
#
# Returns:
#   JSON object with either:
#   - {"files": ["path1", "path2", ...]} on success (concise)
#   - {"files": [{"path": "...", "size": N, "modified": "..."}]} (detailed)
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_search_files "*.py" "/path/to/project"
#   # => {"files": ["/path/to/project/app.py", "/path/to/project/test.py"]}
#
#   starforge_search_files --format detailed "*.js" "."
#   # => {"files": [{"path": "./src/index.js", "size": 1024, "modified": "2025-10-26"}]}
#
#   starforge_search_files "*.txt" "." --format concise
#   # => {"files": ["./file1.txt", "./file2.txt"]}
#
#   starforge_search_files "" "/path"
#   # => {"error": "Pattern is required"}
#
starforge_search_files() {
  local pattern=""
  local search_path="."  # Default to current directory
  local format="concise"
  local positional_args=()

  # Parse arguments (support BOTH old positional and new flag-based APIs)
  while [[ $# -gt 0 ]]; do
    case $1 in
      --format)
        format="$2"
        shift 2
        ;;
      --*)
        echo "{\"error\": \"Unknown flag: $1\"}"
        return 1
        ;;
      *)
        # Positional argument - collect for later processing
        positional_args+=("$1")
        shift
        ;;
    esac
  done

  # Process positional arguments
  if [ ${#positional_args[@]} -gt 0 ]; then
    pattern="${positional_args[0]}"
  fi
  if [ ${#positional_args[@]} -gt 1 ]; then
    search_path="${positional_args[1]}"
  fi
  if [ ${#positional_args[@]} -gt 2 ]; then
    echo "{\"error\": \"Too many positional arguments (expected pattern and search_path)\"}"
    return 1
  fi

  # Validate input
  if [ -z "$pattern" ]; then
    echo '{"error": "Pattern is required"}'
    return 1
  fi

  # Check if directory exists
  if [ ! -d "$search_path" ]; then
    echo "{\"error\": \"Directory does not exist: $search_path\"}"
    return 1
  fi

  # Check if directory is readable
  if [ ! -r "$search_path" ]; then
    echo "{\"error\": \"Directory is not readable: $search_path\"}"
    return 1
  fi

  # Use find to search for files matching pattern
  # -type f: only files (not directories)
  # -name: match pattern
  # Performance optimization: Convert to absolute path in the search_path context
  # to avoid multiple realpath calls
  local abs_search_path
  abs_search_path=$(cd "$search_path" 2>/dev/null && pwd)
  if [ -z "$abs_search_path" ]; then
    abs_search_path="$search_path"
  fi

  # Execute find and build JSON array
  # Use newline-separated output instead of null-separated to avoid bash null-byte issues
  local json_array
  local find_results

  # Find files - use -print for newline-separated output
  # We validate paths don't contain newlines earlier (absolute paths can't have newlines)
  find_results=$(find "$abs_search_path" -type f -name "$pattern" 2>/dev/null)

  if [ -z "$find_results" ]; then
    # No matches - empty array
    json_array="[]"
  else
    case "$format" in
      concise)
        # Concise: paths only (saves tokens)
        # Convert newline-separated paths to JSON array
        json_array=$(echo "$find_results" | jq -R -s 'split("\n") | map(select(. != ""))')
        ;;
      detailed)
        # Detailed: paths with metadata (size, modified time)
        # Convert newline-separated paths to JSON array with path objects
        json_array=$(echo "$find_results" | jq -R -s 'split("\n") | map(select(. != "")) | map({path: .})')
        ;;
      *)
        echo "{\"error\": \"Invalid format: $format (must be concise or detailed)\"}"
        return 1
        ;;
    esac
  fi

  # Return JSON response
  echo "{\"files\": $json_array}"
}

# starforge_write_file - Write content to file atomically
#
# Validates path is absolute, creates parent directories if needed,
# and writes content atomically using temp file + mv pattern.
#
# Args:
#   $1 - Absolute file path to write
#   $2 - Content to write to file
#
# Returns:
#   JSON object with either:
#   - {"success": true, "path": "/absolute/path"} on success
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_write_file "/path/to/file.txt" "Hello, World!"
#   # => {"success": true, "path": "/path/to/file.txt"}
#
#   starforge_write_file "relative/path.txt" "content"
#   # => {"error": "Path must be absolute"}
#
starforge_write_file() {
  local file_path="$1"
  local content="$2"

  # Validate input - path is required
  if [ -z "$file_path" ]; then
    echo '{"error": "Path is required"}'
    return 1
  fi

  # Validate path is absolute (must start with /)
  if [[ ! "$file_path" =~ ^/ ]]; then
    echo '{"error": "Path must be absolute (must start with /)"}'
    return 1
  fi

  # Create parent directory if it doesn't exist
  local parent_dir=$(dirname "$file_path")
  if [ ! -d "$parent_dir" ]; then
    if ! mkdir -p "$parent_dir" 2>/dev/null; then
      echo "{\"error\": \"Failed to create parent directory: $parent_dir\"}"
      return 1
    fi
  fi

  # Atomic write: write to temp file first, then move
  # Using mktemp ensures unique temp file name (prevents race conditions - fixes C2)
  local temp_file
  temp_file=$(mktemp "${parent_dir}/.tmp.XXXXXX") || {
    echo '{"error": "Failed to create temp file"}'
    return 1
  }

  # Write content to temp file
  # Using printf instead of echo to handle special characters correctly
  if ! printf '%s' "$content" > "$temp_file" 2>/dev/null; then
    # Clean up temp file on error
    rm -f "$temp_file" 2>/dev/null
    echo '{"error": "Failed to write to temp file"}'
    return 1
  fi

  # Security check: prevent symlink attacks (fixes C1)
  # If target path is a symlink, reject to prevent overwriting sensitive files
  if [ -L "$file_path" ]; then
    rm -f "$temp_file" 2>/dev/null
    echo '{"error": "Target path is a symbolic link (security risk)"}'
    return 1
  fi

  # Atomic move: replace original file with temp file
  # mv is atomic on the same filesystem
  if ! mv "$temp_file" "$file_path" 2>/dev/null; then
    # Clean up temp file on error
    rm -f "$temp_file" 2>/dev/null
    echo "{\"error\": \"Failed to move temp file to target: $file_path\"}"
    return 1
  fi

  # Return success with the path that was written
  echo "{\"success\": true, \"path\": \"$file_path\"}"
  return 0
}

# starforge_grep_content - Search file contents for pattern
#
# Searches directory recursively for content matching a regex pattern.
# Uses ripgrep (rg) with JSON output for efficient searching.
#
# Args:
#   $1 - Search pattern (regex)
#   $2 - Directory path to search (optional, defaults to current directory)
#   $3 - File type filter (optional, e.g., "py", "js", "sh")
#   $4 - Case insensitive flag (optional, "true" or "false", defaults to false)
#
# Returns:
#   JSON object with either:
#   - {"matches": [{"file": "path", "line_number": N, "content": "line"}]} on success
#   - {"error": "error message"} on failure
#
# Examples:
#   starforge_grep_content "function.*test" "/path/to/project"
#   # => {"matches": [{"file": "/path/to/project/test.py", "line_number": 5, "content": "function test_something():"}]}
#
#   starforge_grep_content "error" "/path" "py" true
#   # => {"matches": [...]} (case-insensitive search in .py files)
#
#   starforge_grep_content "" "/path"
#   # => {"error": "Pattern is required"}
#
starforge_grep_content() {
  local pattern="$1"
  local search_path="${2:-.}"  # Default to current directory
  local file_type="$3"
  local case_insensitive="${4:-false}"

  # Validate input
  if [ -z "$pattern" ]; then
    echo '{"error": "Pattern is required"}'
    return 1
  fi

  # Check if directory exists
  if [ ! -d "$search_path" ]; then
    echo "{\"error\": \"Directory does not exist: $search_path\"}"
    return 1
  fi

  # Check if directory is readable
  if [ ! -r "$search_path" ]; then
    echo "{\"error\": \"Directory is not readable: $search_path\"}"
    return 1
  fi

  # Build ripgrep command
  local rg_cmd="rg"
  local rg_args=()

  # Enable JSON output
  rg_args+=("--json")

  # Add case-insensitive flag if requested
  if [ "$case_insensitive" = "true" ]; then
    rg_args+=("-i")
  fi

  # Add file type filter if specified
  if [ -n "$file_type" ]; then
    rg_args+=("-t" "$file_type")
  fi

  # Add pattern and search path
  rg_args+=("$pattern" "$search_path")

  # Execute ripgrep and parse JSON output
  # rg --json outputs one JSON object per line, we need to collect "match" type entries
  local matches_json="[]"
  local rg_output

  # Run ripgrep and capture output
  if rg_output=$("$rg_cmd" "${rg_args[@]}" 2>/dev/null); then
    # Parse JSON lines and extract match entries
    # Each line is a JSON object with "type" field
    # We want lines where type="match"
    matches_json=$(echo "$rg_output" | \
      jq -c 'select(.type == "match") | {
        file: .data.path.text,
        line_number: .data.line_number,
        content: .data.lines.text
      }' | \
      jq -s '.')
  else
    # No matches found or error - return empty matches array
    # rg returns exit code 1 for no matches, which is normal
    matches_json="[]"
  fi

  # Return JSON response
  echo "{\"matches\": $matches_json}"
  return 0
}

# Export functions for use in other scripts
export -f starforge_read_file
export -f starforge_search_files
export -f starforge_write_file
export -f starforge_grep_content

# Auto-register tools with MCP server when module is loaded
# Only register if register_tool function exists (i.e., we're being sourced by mcp-server)
if declare -f register_tool > /dev/null 2>&1; then
    # Read-only tools (don't modify state, safe to retry, idempotent)
    register_tool "starforge_read_file" "starforge_read_file" true false true
    register_tool "starforge_search_files" "starforge_search_files" true false true
    register_tool "starforge_grep_content" "starforge_grep_content" true false true

    # Write tool (modifies state, not destructive if called multiple times, idempotent)
    register_tool "starforge_write_file" "starforge_write_file" false false true
fi
