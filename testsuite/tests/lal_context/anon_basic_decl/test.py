"""
Test that generation of lal_context entries does not crash when
reaching a basic decl with no defining name. These should be ignored.
"""

from SUITE.cli import (
    match_annotations, Location, LocationSpan, run_cli
)
from SUITE.utils import fail_if_not_equal, fail_if

# First generate an annotation in the exception handler, which is an un-named
# basic decl.

annotation_file = "annotations.toml"

run_cli([
    "-umy_spec:lal_context:subp.adb:9:7:9:43:{message=\"handler stmt\"}",
    f"-o{annotation_file}",
    "-q"
])

# Match the new entry to ensure we have a correct spec

annots = match_annotations([annotation_file], ["subp.adb"])

fail_if_not_equal("Unexpected diagnostics", 0, len(annots.load_diagnostics))

fail_if_not_equal("Unexpected amount of matches", 1, len(annots.match_results))

res = annots.match_results[0]

fail_if(not res.success, "Unexpected match failure")

fail_if_not_equal(
    "wrong matched location span",
    res.sloc_range,
    LocationSpan(Location(9, 7), Location(9, 43))
)
