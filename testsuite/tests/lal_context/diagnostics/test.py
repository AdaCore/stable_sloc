"""
Test that the backends emits appropriate diagnostics in case
an entry isn't well formed, or some error happens during matching.
"""

import glob

from SUITE.cli import run_cli

extra_args: list[list[str]] = [[], ["--json-output"]]

for format_args in extra_args:
    p = run_cli(
        [f"-s{file}" for file in sorted(glob.glob("*.toml"))]
        + format_args + ["inexistent.adb"] + sorted(glob.glob("*.ad*"))
    )
