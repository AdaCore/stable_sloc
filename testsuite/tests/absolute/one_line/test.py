"""
Check that the absolute matchers work correctly on sloc regions
that span a single line.
"""

from SUITE.cli import match_annotations, CliResults, Location, LocationSpan
from SUITE.utils import fail_if_not_equal, fail_if

match_res: CliResults = match_annotations(
    annotations=["annotation.toml"],
    files=["content.txt"],
)

fail_if_not_equal(
    what="unexpected load diagnostics",
    expected=0,
    actual=len(match_res.load_diagnostics),
)

fail_if_not_equal(
    what="unexpected number of match results",
    expected=1,
    actual=len(match_res.match_results),
)

fail_if(
    not match_res.match_results[0].success,
    comment="expected a successful match",
)

fail_if_not_equal(
    what="incorrect location span",
    expected=LocationSpan(Location(1, 2), Location(1, 6)),
    actual=match_res.match_results[0].sloc_range,
)
