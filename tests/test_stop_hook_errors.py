#!/usr/bin/env python3

"""
Integration tests for stop hook error handling (Task 4.2).

Tests that malformed triggers are handled gracefully with clear error messages
and moved to failed/ directory for debugging.
"""

import json
import os
import subprocess
import tempfile
import shutil
from pathlib import Path
import pytest


class TestStopHookErrorHandling:
    """Test stop hook handles malformed triggers gracefully."""

    def setup_method(self):
        """Create temporary test environment."""
        self.test_dir = tempfile.mkdtemp()
        self.triggers_dir = Path(self.test_dir) / ".claude" / "triggers"
        self.triggers_dir.mkdir(parents=True)

        # Create logs directory
        logs_dir = Path(self.test_dir) / "logs"
        logs_dir.mkdir(parents=True)

        # Original directory
        self.original_dir = os.getcwd()

    def teardown_method(self):
        """Clean up test environment."""
        os.chdir(self.original_dir)
        shutil.rmtree(self.test_dir)

    def run_stop_hook(self):
        """
        Run stop hook with test conversation input.

        Returns:
            tuple: (stdout, stderr, returncode)
        """
        # Create minimal conversation input
        input_data = {"conversation_id": "test"}

        # Run stop hook from test directory
        os.chdir(self.test_dir)

        result = subprocess.run(
            [str(Path(self.original_dir) / "templates" / "hooks" / "stop.py")],
            input=json.dumps(input_data),
            capture_output=True,
            text=True,
            timeout=5
        )

        return result.stdout, result.stderr, result.returncode

    def test_missing_command_field(self):
        """Test error handling when trigger missing 'command' field."""
        # Create malformed trigger (missing command)
        trigger = {
            "from_agent": "test-agent",
            "to_agent": "qa-engineer",
            "message": "Test message"
        }

        trigger_file = self.triggers_dir / "test-missing-command.trigger"
        with open(trigger_file, 'w') as f:
            json.dump(trigger, f)

        # Run stop hook
        stdout, stderr, returncode = self.run_stop_hook()

        # Assert: Hook exits gracefully
        assert returncode == 0, "Hook should exit gracefully even with malformed trigger"

        # Assert: Clear error message printed
        assert "Malformed trigger" in stderr, "Should print error about malformed trigger"
        assert "command" in stderr, "Should mention missing 'command' field"
        assert "test-missing-command.trigger" in stderr, "Should mention trigger filename"

        # Assert: Trigger moved to failed/ directory
        failed_dir = self.triggers_dir / "failed"
        assert failed_dir.exists(), "Should create failed/ directory"

        failed_files = list(failed_dir.glob("malformed-*.trigger"))
        assert len(failed_files) == 1, "Should move malformed trigger to failed/"

        # Assert: Original trigger file removed
        assert not trigger_file.exists(), "Should remove original trigger file"

    def test_missing_message_field(self):
        """Test error handling when trigger missing 'message' field."""
        trigger = {
            "from_agent": "test-agent",
            "to_agent": "qa-engineer",
            "command": "Use qa-engineer. Review PR."
        }

        trigger_file = self.triggers_dir / "test-missing-message.trigger"
        with open(trigger_file, 'w') as f:
            json.dump(trigger, f)

        stdout, stderr, returncode = self.run_stop_hook()

        assert returncode == 0
        assert "Malformed trigger" in stderr
        assert "message" in stderr

        failed_dir = self.triggers_dir / "failed"
        assert failed_dir.exists()
        assert len(list(failed_dir.glob("malformed-*.trigger"))) == 1

    def test_missing_to_agent_field(self):
        """Test error handling when trigger missing 'to_agent' field."""
        trigger = {
            "from_agent": "test-agent",
            "command": "Use qa-engineer. Review PR.",
            "message": "Test message"
        }

        trigger_file = self.triggers_dir / "test-missing-to-agent.trigger"
        with open(trigger_file, 'w') as f:
            json.dump(trigger, f)

        stdout, stderr, returncode = self.run_stop_hook()

        assert returncode == 0
        assert "Malformed trigger" in stderr
        assert "to_agent" in stderr

        failed_dir = self.triggers_dir / "failed"
        assert failed_dir.exists()
        assert len(list(failed_dir.glob("malformed-*.trigger"))) == 1

    def test_valid_trigger_no_regression(self):
        """Test that valid triggers still work correctly (no regression)."""
        # Create valid trigger
        trigger = {
            "from_agent": "test-agent",
            "to_agent": "qa-engineer",
            "command": "Use qa-engineer. Review PR #123.",
            "message": "PR ready for review"
        }

        trigger_file = self.triggers_dir / "test-valid.trigger"
        with open(trigger_file, 'w') as f:
            json.dump(trigger, f)

        stdout, stderr, returncode = self.run_stop_hook()

        # Assert: Hook succeeds
        assert returncode == 0

        # Assert: No error messages
        assert "Malformed trigger" not in stderr

        # Assert: Handoff notification printed
        assert "AGENT HANDOFF READY" in stderr
        assert "qa-engineer" in stderr

        # Assert: Trigger moved to processed/ (not failed/)
        processed_dir = self.triggers_dir / "processed"
        assert processed_dir.exists()
        assert len(list(processed_dir.glob("*.trigger"))) == 1

        # Assert: Not in failed/ directory
        failed_dir = self.triggers_dir / "failed"
        if failed_dir.exists():
            assert len(list(failed_dir.glob("*.trigger"))) == 0

    def test_error_message_includes_required_fields(self):
        """Test that error message lists all required fields."""
        trigger = {
            "from_agent": "test-agent"
        }

        trigger_file = self.triggers_dir / "test-minimal.trigger"
        with open(trigger_file, 'w') as f:
            json.dump(trigger, f)

        stdout, stderr, returncode = self.run_stop_hook()

        assert returncode == 0
        assert "Required fields" in stderr, "Should list required fields"
        assert "to_agent" in stderr
        assert "command" in stderr
        assert "message" in stderr

    def test_invalid_json_still_handled(self):
        """Test that invalid JSON is still handled gracefully (existing behavior)."""
        trigger_file = self.triggers_dir / "test-invalid-json.trigger"
        with open(trigger_file, 'w') as f:
            f.write("{invalid json}")

        stdout, stderr, returncode = self.run_stop_hook()

        # Should still exit gracefully
        assert returncode == 0

        # Should mention malformed trigger
        assert "malformed" in stderr.lower() or "Malformed" in stderr

        # Should move to processed/ or failed/
        assert not trigger_file.exists()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
