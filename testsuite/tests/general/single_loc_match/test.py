"""
Test that the single location match mechanism works as intended,
i.e. an entry with the at_most_once flag set to true should only return a
successful match result on the first successful match location, but not only
subsequent other match locations. It should still however return a successful
match on the first match location across multiple match calls.
"""

from SUITE.cli import match_annotations, CliResults
from SUITE.utils import fail_if_not_equal, fail_if

match_res: CliResults = match_annotations(
    annotations=["annotation.toml"],
    files=["pkg.adb", "pkg.adb", "pkg-child.adb"],
)

fail_if_not_equal(
    "Unexpected entry load failures", 0, len(match_res.load_diagnostics)
)

fail_if_not_equal(
    "Unexpected number of match results", 3, len(match_res.match_results)
)

success_count = 0
fail_count = 0

for res in match_res.match_results:
    if res.success:
        fail_if_not_equal(
            "match success on unexpected file", "pkg.adb", res.file
        )
        success_count += 1
    else:
        fail_if(res.file == "pkg.adb", "match fail on unexpected file")
        fail_count += 1

fail_if(
    success_count != 2 and fail_count != 1,
    "Unexpected success / fail distribution",
)
