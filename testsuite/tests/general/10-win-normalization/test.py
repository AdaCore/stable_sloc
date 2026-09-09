"""
Check that specs can work across host OSes. A spec file with a
unix-style pattern for the file that match should work on Windows, and vice
versa.
"""

from os.path import join
from os import getcwd

from SUITE.cli import (
    match_annotations,
    check_single_match,
    LocationSpan,
    Location,
)

spec_files = ["win.toml", "unix.toml"]

target_file = join(getcwd(), "src", "content.txt")

for spec_file in spec_files:
    res = match_annotations(annotations=[spec_file], files=[target_file])
    check_single_match(
        res,
        target_file,
        LocationSpan(Location(3, 39), Location(5, 45)),
    )
