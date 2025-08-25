"""
Verify that we get expected diagnostics when the TOML spec files are
not correct, or there is an issue matching one of the entries, for a
clang_context based matcher.
"""

import glob

from SUITE.cli import run_cli

extra_args: list[list[str]] = [[], ["--json-output"]]

for format_args in extra_args:
    p = run_cli(
        [f"-s{file}" for file in sorted(glob.glob("*.toml"))]
        + format_args
        + ["inexistent.c"]
        + sorted(glob.glob("*.c*"))
    )
