"""
Test that stable_sloc does not crash when generating a
lal_context entry where one of the columns of the designated region
is smaller than the start column of the enclosing entity. This generates
a negative relative offset which used to crash stable_sloc.
"""

import tomllib

from SUITE.cli import (
    match_annotations, Location, LocationSpan, run_cli, check_single_match
)
from SUITE.utils import contents_of, fail_if_not_equal

# Generate an entry where the resulting columns in the matcher will be negative
# and make sure stable_sloc does not crash.
#
# In the query bellow we ask the cli to create an annotation for the region
# starting at 13:1 and ending at 15:1 of pkg.adb, but the enclosing named
# declaration is the Foo function declaration, starting at 11:4. This should
# result in the relative location span'columns being negative (-3 in this
# case).
annotation_file = "annotations.toml"
run_cli([
    "-umy_spec:lal_context:pkg.adb:13:1:15:1:{message=\"negative offset\"}",
    f"-o{annotation_file}",
    "-q"
])

# Verify the generated column offsets are indeed negative
generated_entry = tomllib.loads(contents_of(annotation_file))
fail_if_not_equal(
    what="Generated column offset should be negative",
    expected=-3,
    actual=generated_entry["my_spec"]["matcher"]["start_col"],
)

# Match the new entry to ensure we have a correct spec and check the result
annots = match_annotations([annotation_file], ["pkg.adb"])
check_single_match(annots, LocationSpan(Location(13, 1), Location(15, 1)))
