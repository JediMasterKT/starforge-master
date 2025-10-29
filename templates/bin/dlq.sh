#!/bin/bash
# StarForge Dead Letter Queue Manager
# Manages triggers that failed after max retries

set -e

# Get StarForge directory
STARFORGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$STARFORGE_DIR/.claude"
DLQ_DIR="$CLAUDE_DIR/triggers/dead-letter"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Source DLQ helpers
DLQ_LIB="$STARFORGE_DIR/lib/dead-letter-queue.sh"
if [ ! -f "$DLQ_LIB" ]; then
    echo -e "${RED}❌ DLQ library not found: $DLQ_LIB${NC}"
    echo -e "   This should not happen. Please report this issue."
    exit 1
fi

source "$DLQ_LIB"

# Ensure DLQ directory exists
mkdir -p "$DLQ_DIR"

# Handle subcommands
subcommand="$1"
shift || true

case "$subcommand" in
    list|ls)
        list_dlq_triggers
        ;;
    retry)
        if [ -z "$1" ]; then
            echo -e "${RED}❌ Trigger filename required${NC}"
            echo ""
            echo "Usage: starforge dlq retry <trigger-filename>"
            echo ""
            echo "Available DLQ triggers:"
            list_dlq_triggers
            exit 1
        fi
        retry_dlq_trigger "$1"
        ;;
    cleanup)
        age_days="${1:-7}"
        echo "Cleaning up DLQ triggers older than $age_days days..."
        count=$(cleanup_old_dlq_triggers "$age_days")
        if [ "$count" -eq 0 ]; then
            echo "No DLQ triggers to clean up"
        else
            echo "Archived $count DLQ trigger(s)"
        fi
        ;;
    stats)
        echo "Dead Letter Queue Statistics:"
        echo ""
        get_dlq_stats | jq .
        ;;
    ""|help)
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}💀 Dead Letter Queue Management${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Commands:"
        echo "  starforge dlq list              - List all DLQ triggers"
        echo "  starforge dlq retry <filename>  - Retry a DLQ trigger"
        echo "  starforge dlq cleanup [days]    - Archive DLQ triggers older than N days (default: 7)"
        echo "  starforge dlq stats             - Show DLQ statistics"
        echo ""
        echo "DLQ contains triggers that failed after max retries."
        echo "Use 'retry' to move triggers back to the active queue for reprocessing."
        ;;
    *)
        echo -e "${RED}❌ Unknown dlq subcommand: $subcommand${NC}"
        echo ""
        echo "Usage: starforge dlq <list|retry|cleanup|stats>"
        echo "       starforge dlq help"
        exit 1
        ;;
esac
