"""
Test that writing the entry database back to one of the spec files rewrites
only the entries that came from it, instead of collapsing every spec into it.
"""

import shutil
import tomllib

from SUITE.cli import run_cli
from SUITE.utils import contents_of, fail_if_not_equal, log


def entry_names(filename):
    """Sorted identifiers of the entries in the given spec file."""
    return sorted(tomllib.loads(contents_of(filename)).keys())


def step(what):
    """
    Announce a step, so that the log says which one a failure stopped on: the
    checks below exit on the first mismatch.
    """
    log(f"== {what} ==")


# The test rewrites the spec files in place, so keep pristine copies.
shutil.copy("a.toml", "a.orig.toml")
shutil.copy("b.toml", "b.orig.toml")

# Writing to a file that is none of the specs still merges all of them. This
# is the control: without it, the checks below would also pass if writing
# simply dropped entries.

step("output that is none of the specs")
run_cli(["-sa.toml", "-sb.toml", "-omerged.toml", "-q"])
fail_if_not_equal(
    "entries written to a file that is not one of the specs",
    expected=["from_a", "from_b"],
    actual=entry_names("merged.toml"),
)

# Writing back to one of the specs rewrites that one only.

step("output that is one of the specs")
run_cli(["-sa.toml", "-sb.toml", "-oa.toml", "-q"])
fail_if_not_equal(
    "entries left in the rewritten spec file",
    expected=["from_a"],
    actual=entry_names("a.toml"),
)
fail_if_not_equal(
    "contents of the spec file that was not written",
    expected=contents_of("b.orig.toml"),
    actual=contents_of("b.toml"),
)

# The output file has to be spelled as the spec file is. Two spellings of the
# same file compare equal on Unix, where GNATCOLL resolves both through the
# filesystem, but not on Windows, where it only compares them textually.

# An entry created on the command line was loaded from no file at all, so it
# belongs to whichever file is written.

step("entry created on the command line")
shutil.copy("a.orig.toml", "a.toml")
run_cli(
    [
        "-sa.toml",
        "-sb.toml",
        '-ucreated:absolute:content.txt:1:1:2:2:{message="created"}',
        "-oa.toml",
        "-q",
    ]
)
fail_if_not_equal(
    "entries written alongside a created one",
    expected=["created", "from_a"],
    actual=entry_names("a.toml"),
)

print("ok")
