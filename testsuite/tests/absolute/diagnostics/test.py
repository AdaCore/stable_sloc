"""
Test that the backend emits correct diagnostics in case an entry
is ill formed, or there is an error while attempting to match a file.
"""

from SUITE.cli import run_cli

for extra_arg in ["", "--json-output"]:
    run_cli(
        ["-sannotations.toml", "inexistent.txt", "content.txt", extra_arg]
    )
