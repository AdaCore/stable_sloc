"""
Test that generating an entry with a '\' character in the filename (such as on
Windows with at least one directory) yields an entry with a correct file
pattern, i.e. with escaped backslashes.
"""

import os

from SUITE.cli import run_cli, match_annotations, Location, LocationSpan
from SUITE.utils import fail_if_not_equal, fail_if

# Create an annotation for the file. Ensure we use the system's directory
# separator.

target_file = os.path.join("src", "content.txt")

run_cli(
    [
        '-utest:absolute:' + target_file + ':1:1:2:2:{foo="bar"}',
        "-q",
        "-oannotation.toml",
    ]
)

res = match_annotations(
    ["annotation.toml"],
    [os.path.abspath(target_file)],
)

fail_if(
    len(res.load_diagnostics) != 0,
    "unexpected entry diagnostics" + str(res.load_diagnostics)
)

fail_if_not_equal(
    "Number of match results",
    actual=len(res.match_results),
    expected=1
)

fail_if(
    not res.match_results[0].success,
    "Expected match success",
)

fail_if_not_equal(
    "Unexpected match location",
    actual=res.match_results[0].sloc_range,
    expected=LocationSpan(Location(1, 1), Location(2, 2))
)
