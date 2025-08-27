"""
Test that dumping a regexp entry to file produces a spec
that is equivalent.
"""

from SUITE.cli import run_cli
from SUITE.entries import equivalent_base, equivalent_field
from SUITE.utils import contents_of
import tomllib


original_f = "annotations.toml"
new_f = "new_annotations.toml"

# Load a spec file and dump it to a new file
run_cli([f"-s{original_f}", f"-o{new_f}", "-q"])

# Load the new specs to ensure they are valid
run_cli([f"-s{new_f}", "--strict", "-v"])

# Compare the two files. The TOML library doesn't preserve the original
# formatting, and there are optional fields that may not have been set in
# the original entries but which are in the dumped entries, so compare the
# parsed toml objects instead.

orig_specs = tomllib.loads(contents_of(original_f))
new_specs = tomllib.loads(contents_of(new_f))

# First check that we have the same entry identifiers in both cases
for key in orig_specs.keys():
    if key not in new_specs:
        print(f"Entry {key} not found in new spec file")
for key in new_specs.keys():
    if key not in orig_specs:
        print(f"Entry {key} present in new spec file but not in the original")

# The check for each key that the entries are equivalent
entries = [(orig_specs[key], new_specs[key]) for key in orig_specs.keys()]
for old, new in entries:
    equivalent_base(old, new)
    old_m = old["matcher"]
    new_m = new["matcher"]
    equivalent_field(old_m, new_m, "regexp")
    equivalent_field(old_m, new_m, "case_insensitive", default=False)
    equivalent_field(old_m, new_m, "multi_line", default=False)
    equivalent_field(old_m, new_m, "single_line", default=False)

print("ok")
