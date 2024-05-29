"""
Test that a regexp based entry can match multiple times, both in the same file
and across multiple files.
"""

from SUITE.cli import run_cli

run_cli(
    ["-sannotations.toml", "--json-output", "pkg.adb", "pkg-child.adb"]
)
