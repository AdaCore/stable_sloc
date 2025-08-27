"""
Test that the purpose filter works as intended, i.e. that
the only entries that are processed are the ones with at least one
annotation with no purpose field, or one annotation with a purpose
field that begins with the argument --filter passed to the cli.
"""

import json

from SUITE.cli import run_cli
from SUITE.utils import contents_of, fail_if, fail_if_not_equal


def check_one(prefix):
    """
    Run the cli with the annotations.toml spec file on content.txt
    and check that all the match results have either no purpose or
    have a purpose that beings with prefix
    """
    out_file = f"{prefix}_result.json"
    run_cli(
        ["-sannotations.toml", "--json-output", "content.txt"]
        + ([f"--filter={prefix}"] if prefix else []),
        out=out_file,
    )
    results = json.loads(contents_of(out_file))
    fail_if_not_equal(
        f"cli diagnostics for prefix '{prefix}'",
        expected=[],
        actual=results["load_diagnostics"],
    )
    for result in results["match_results"]:
        purpose = result["annotation"].get("purpose", "")
        if purpose:
            fail_if(
                not purpose.startswith(prefix),
                comment="wrong purpose prefix for entry "
                + result["identifier"]
                + f". Expected {prefix} but got: "
                + str(result),
            )


for prefix in ["", "abc", "abcdef"]:
    check_one(prefix)
