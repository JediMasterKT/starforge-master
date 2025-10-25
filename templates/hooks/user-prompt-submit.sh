#!/bin/bash
#
# user-prompt-submit.sh - Prevent main-claude from modifying .claude/ system files
#
# This hook blocks Write/Edit operations to .claude/bin/, .claude/lib/, .claude/scripts/
# when the context indicates StarForge development (not user customization).
#

# Get the user's message
MESSAGE="$1"

# Define patterns that indicate StarForge system files (not user config)
SYSTEM_DIRS="(\.claude/(bin|lib|scripts|agents/[^/]+\.md))"

# Define patterns that indicate StarForge development work
STARFORGE_KEYWORDS="(daemon|trigger|discord|validation|helper|agent|parallel|backlog|notification|schema|jq)"

# Check if message contains Write/Edit operations to system directories
if echo "$MESSAGE" | grep -qE "(Write|Edit).*${SYSTEM_DIRS}"; then
  # Check if this looks like StarForge development (not user's custom files)
  if echo "$MESSAGE" | grep -qiE "${STARFORGE_KEYWORDS}"; then
    echo ""
    echo "❌ ================================================================================================"
    echo "❌ BLOCKED: You're trying to modify .claude/ system files for StarForge development!"
    echo "❌ ================================================================================================"
    echo ""
    echo "StarForge system improvements must go in the templates/ directory:"
    echo ""
    echo "  WRONG PATH                              →  CORRECT PATH"
    echo "  ─────────────────────────────────────────────────────────────────────────────────"
    echo "  .claude/bin/daemon-runner.sh            →  templates/bin/daemon-runner.sh"
    echo "  .claude/lib/discord-notify.sh           →  templates/lib/discord-notify.sh"
    echo "  .claude/scripts/trigger-helpers.sh      →  templates/scripts/trigger-helpers.sh"
    echo "  .claude/agents/orchestrator.md          →  templates/agents/orchestrator.md"
    echo ""
    echo "Why?"
    echo "  • templates/ = Source of truth (deployed to users via 'starforge update')"
    echo "  • .claude/   = Deployed instance (gets overwritten on update)"
    echo ""
    echo "Exception: User configuration files ARE allowed in .claude/:"
    echo "  • .claude/hooks/             ✅ (user hooks)"
    echo "  • .claude/CLAUDE.md          ✅ (project instructions)"
    echo "  • .claude/settings.json      ✅ (user settings)"
    echo ""
    echo "Please modify the templates/ version instead."
    echo "❌ ================================================================================================"
    echo ""
    exit 1
  fi
fi

# Allow the operation
exit 0
