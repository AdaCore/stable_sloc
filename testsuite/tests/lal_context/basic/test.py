"""
Simple test for a LAL-context based matcher. The spec file in this test is not
re-generated from source, see the "entry-update" test for that.
"""

import glob

from SUITE.cli import run_cli

run_cli(
    ["-slal_test.toml", "--json-output", "-v"] + sorted(glob.glob("*.ad*"))
)
