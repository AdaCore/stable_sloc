"""
Check that specs can work across host OSes. A spec file with a
unix-style pattern for the file that match should work on Windows, and vice
versa.
"""

from os.path import join

from SUITE.cli import (
    match_annotations,
    check_single_match,
    LocationSpan,
    Location,
)

target_file = join("bar", "..", "src", "content.txt")

res = match_annotations(annotations=["matcher.toml"], files=[target_file])
check_single_match(
    res,
    target_file,
    LocationSpan(Location(3, 39), Location(5, 45)),
)
