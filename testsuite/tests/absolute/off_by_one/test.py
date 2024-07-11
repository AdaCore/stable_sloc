"""
Test that the verification of source locations does not make off by one
errors.
"""

from SUITE.cli import run_cli

run_cli(["-s", "simple_absolute.toml", "content.txt", "-v"])
