"""
Test that the backend emits correct diagnostics in case an entry
is ill formed, or there is an error while attempting to match a file.
"""

from SUITE.cli import run_cli

format_args: list[list[str]] = [[], ["--json-output"]]

for extra_arg in format_args:
    run_cli(["-sannotations.toml", "non_existent.txt"] + extra_arg)
