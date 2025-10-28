#!/usr/bin/env bash
#
# ci-notify-failure.sh - CI test failure notification helper
#
# Called by GitHub Actions when CI tests fail.
# Parses job results and sends Discord notification via notify_tests_failed().
#
# Usage:
#   ci-notify-failure.sh <pr_number> <failed_job> <error_message> <logs_url>
#

set -e

# Source router.sh for notify_tests_failed function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROUTER_LIB="$SCRIPT_DIR/../lib/router.sh"

if [ ! -f "$ROUTER_LIB" ]; then
    echo "ERROR: router.sh not found at $ROUTER_LIB" >&2
    exit 1
fi

source "$ROUTER_LIB"

# Parse arguments
PR_NUMBER=${1:-""}
FAILED_JOB=${2:-"Unknown test"}
ERROR_MESSAGE=${3:-"Test failed (see logs for details)"}
LOGS_URL=${4:-""}

# Validate PR number
if [ -z "$PR_NUMBER" ]; then
    echo "ERROR: PR number required as first argument" >&2
    echo "Usage: ci-notify-failure.sh <pr_number> <failed_job> <error_message> <logs_url>" >&2
    exit 1
fi

# Call notify_tests_failed from router.sh
# This will use send_discord_system_notification from discord-notify.sh
notify_tests_failed "$PR_NUMBER" "$FAILED_JOB" "$ERROR_MESSAGE" "$LOGS_URL"

exit_code=$?

if [ $exit_code -eq 0 ]; then
    echo "✅ Test failure notification sent successfully for PR #$PR_NUMBER"
else
    echo "❌ Failed to send test failure notification (exit code: $exit_code)" >&2
    # Don't fail the workflow - notifications are optional
    exit 0
fi
