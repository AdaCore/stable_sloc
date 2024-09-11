"""
Test that absolute matchers generated include a sha256 digest of the file that
was used for generation, and that attempting to match on a modified version of
the file then results in a match failure.
"""

from SUITE.cli import match_annotations, run_cli
from SUITE.utils import fail_if_not_equal, fail_if

# First generate an annotation for a first version of the file

annotation_file = "annotations.toml"

run_cli([
    "-umy_spec:absolute:content.txt:1:7:2:3:{message=\"dummy\"}",
    f"-o{annotation_file}",
    "-q"
])

# Modify the file, by adding one character
with open("content.txt", "a") as f:
    f.write("a")

# Match the new entry and check we get a proper rejection

annots = match_annotations([annotation_file], ["content.txt"])

fail_if_not_equal("Unexpected diagnostics", 0, len(annots.load_diagnostics))

fail_if_not_equal("Unexpected amount of matches", 1, len(annots.match_results))

res = annots.match_results[0]

fail_if(res.success, "Unexpected match success")

fail_if_not_equal(
    "unexpected error message",
    res.diagnostic,
    "file has been modified"
)
