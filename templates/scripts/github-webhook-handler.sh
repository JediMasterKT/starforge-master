#!/bin/bash
# GitHub Webhook Handler for StarForge
# Processes GitHub events and creates appropriate triggers

set -e

# Source trigger helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/trigger-helpers.sh"

# Parse GitHub event from environment (set by GitHub Actions)
EVENT_NAME="${GITHUB_EVENT_NAME:-}"
EVENT_ACTION="${EVENT_ACTION:-}"
PR_NUMBER="${PR_NUMBER:-}"
LABEL_NAME="${LABEL_NAME:-}"
PR_STATE="${PR_STATE:-}"
PR_MERGED="${PR_MERGED:-false}"
PR_AUTHOR="${PR_AUTHOR:-}"
PR_BRANCH="${PR_BRANCH:-}"

log_event() {
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >&2
}

# Main handler
case "$EVENT_NAME" in
  pull_request)
    case "$EVENT_ACTION" in
      labeled)
        log_event "Label '$LABEL_NAME' added to PR #$PR_NUMBER"

        case "$LABEL_NAME" in
          qa-declined)
            # QA declined - create rework trigger
            log_event "Creating rework trigger for PR #$PR_NUMBER"
            create_rework_trigger "$PR_NUMBER" "$PR_BRANCH" "$PR_AUTHOR"
            ;;

          human-approved)
            # Human approved - create merge trigger
            log_event "Creating human approval trigger for PR #$PR_NUMBER"
            create_human_approval_trigger "$PR_NUMBER"
            ;;

          *)
            log_event "No action for label: $LABEL_NAME"
            ;;
        esac
        ;;

      closed)
        if [ "$PR_MERGED" = "true" ]; then
          # PR merged - log completion
          log_event "Logging completion for merged PR #$PR_NUMBER"
          log_completion "$PR_NUMBER" "$PR_AUTHOR"
        fi
        ;;

      *)
        log_event "No action for event: $EVENT_NAME.$EVENT_ACTION"
        ;;
    esac
    ;;

  *)
    log_event "Unhandled event: $EVENT_NAME"
    exit 0
    ;;
esac

log_event "Webhook processing complete"
