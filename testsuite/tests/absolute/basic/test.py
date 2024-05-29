"""
Test that loading a matching a simple regular expression entry works and
matches the expected location range.
"""

from SUITE.cli import run_cli

run_cli(["-s", "simple_absolute.toml", "content.txt", "-v"])
