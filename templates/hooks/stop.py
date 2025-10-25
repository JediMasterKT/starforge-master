#!/usr/bin/env python3

"""
Stop Hook for StarForge Agent System

Detects when agents complete and processes trigger files to enable
autonomous agent handoffs. This hook runs after every agent session ends.

Trigger File Format:
{
  "from_agent": "senior-engineer",
  "to_agent": "tpm",
  "action": "create_tickets",
  "message": "5 subtasks ready",
  "command": "Use tpm. Create GitHub issues from breakdown.",
  "context": {"feature": "name", "subtasks": 5},
  "timestamp": "2025-10-24T00:00:00Z"
}

Behavior:
1. Reads stop hook input from stdin
2. Checks for pending trigger files in .claude/triggers/
3. Processes oldest trigger first (FIFO)
4. Logs handoff to .claude/agent-handoff.log
5. Archives trigger to .claude/triggers/processed/
6. Sends macOS notification
7. Sends Discord notification (optional)
8. Prints handoff info to terminal

Exit codes:
0 - Success (even if no triggers found)
"""

import json
import sys
import os
import subprocess
from pathlib import Path
from datetime import datetime
import urllib.request
import urllib.error


def send_discord_notification(from_agent, to_agent, message, command):
    """
    Send rich notification to Discord (optional).

    Requires DISCORD_WEBHOOK_URL environment variable.
    Fails gracefully if not configured or if request fails.

    Args:
        from_agent: Source agent name
        to_agent: Target agent name
        message: Handoff message
        command: Command to run next agent
    """
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL")
    if not webhook_url:
        return  # Discord not configured, skip silently

    try:
        # Create rich embed for Discord
        embed = {
            "embeds": [{
                "title": f"🤖 Agent Handoff: {to_agent}",
                "description": message,
                "color": 3447003,  # Blue color
                "fields": [
                    {
                        "name": "From Agent",
                        "value": from_agent,
                        "inline": True
                    },
                    {
                        "name": "To Agent",
                        "value": to_agent,
                        "inline": True
                    },
                    {
                        "name": "Next Action",
                        "value": f"```bash\n{command}\n```",
                        "inline": False
                    }
                ],
                "timestamp": datetime.utcnow().isoformat(),
                "footer": {
                    "text": "StarForge Agent System"
                }
            }]
        }

        # Send POST request to Discord webhook
        data = json.dumps(embed).encode('utf-8')
        req = urllib.request.Request(
            webhook_url,
            data=data,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'StarForge-Agent-System/1.0'
            },
            method='POST'
        )

        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 204:
                # Discord webhooks return 204 No Content on success
                pass

    except (urllib.error.URLError, urllib.error.HTTPError, Exception):
        # Fail gracefully - don't break the hook if Discord is down
        pass


def get_next_trigger():
    """
    Find next pending trigger file.

    Returns:
        Path object of oldest trigger file, or None if no triggers exist.
    """
    trigger_dir = Path(".claude/triggers")
    if not trigger_dir.exists():
        return None

    # Get all .trigger files, sorted by creation time (oldest first)
    trigger_files = sorted(trigger_dir.glob("*.trigger"))
    return trigger_files[0] if trigger_files else None


def process_trigger(trigger_file):
    """
    Process trigger file and prepare for next agent invocation.

    Args:
        trigger_file: Path to trigger JSON file

    Returns:
        dict with agent, command, and message keys

    Raises:
        json.JSONDecodeError: If trigger file contains invalid JSON
    """
    # Parse trigger JSON
    with open(trigger_file) as f:
        trigger = json.load(f)

    next_agent = trigger["to_agent"]
    command = trigger["command"]
    message = trigger["message"]
    from_agent = trigger.get("from_agent", "unknown")

    # Log handoff
    log_file = Path(".claude/agent-handoff.log")
    log_file.parent.mkdir(parents=True, exist_ok=True)

    with open(log_file, 'a') as f:
        timestamp = datetime.utcnow().isoformat()
        f.write(f"[{timestamp}Z] {from_agent} -> {next_agent}: {message}\n")

    # Archive trigger to processed/
    processed_dir = Path(".claude/triggers/processed")
    processed_dir.mkdir(parents=True, exist_ok=True)
    trigger_file.rename(processed_dir / trigger_file.name)

    # Send macOS notification
    try:
        subprocess.run([
            "osascript", "-e",
            f'display notification "{message}" with title "Agent Handoff: {next_agent}" sound name "Purr"'
        ], capture_output=True, timeout=2, check=False)
    except Exception:
        # Fail gracefully if notification fails
        pass

    # Send Discord notification (optional)
    send_discord_notification(from_agent, next_agent, message, command)

    return {
        "agent": next_agent,
        "command": command,
        "message": message
    }


def main():
    """Main stop hook execution."""
    try:
        # Read stop hook input from stdin
        input_data = json.load(sys.stdin)

        # Log stop event (for debugging)
        log_dir = Path("logs")
        log_dir.mkdir(parents=True, exist_ok=True)

        with open(log_dir / "stop.json", 'a') as f:
            json.dump(input_data, f)
            f.write('\n')

        # Check for pending triggers
        next_trigger = get_next_trigger()

        if next_trigger:
            try:
                # Process and notify human to invoke next agent
                trigger_data = process_trigger(next_trigger)

                # Print notification to terminal (stderr to not interfere with stdout)
                print("\n" + "="*50, file=sys.stderr)
                print(f"🤖 AGENT HANDOFF READY", file=sys.stderr)
                print("="*50, file=sys.stderr)
                print(f"Next Agent: {trigger_data['agent']}", file=sys.stderr)
                print(f"Action: {trigger_data['message']}", file=sys.stderr)
                print(f"\nRun: starforge use {trigger_data['agent']}", file=sys.stderr)
                print("="*50 + "\n", file=sys.stderr)

            except json.JSONDecodeError as e:
                # Handle malformed JSON gracefully
                print(f"Warning: Malformed trigger file {next_trigger}: {e}", file=sys.stderr)
                # Move malformed trigger to processed/ to avoid blocking
                processed_dir = Path(".claude/triggers/processed")
                processed_dir.mkdir(parents=True, exist_ok=True)
                next_trigger.rename(processed_dir / f"malformed-{next_trigger.name}")

        # Always exit 0 (fail gracefully)
        sys.exit(0)

    except Exception as e:
        # Log error but don't fail
        print(f"Stop hook error: {e}", file=sys.stderr)
        sys.exit(0)  # Fail gracefully - don't block agent exit


if __name__ == "__main__":
    main()
