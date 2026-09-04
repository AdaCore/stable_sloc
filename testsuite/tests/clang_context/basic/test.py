"""
Test simple generation and match for a clang_context based matcher
"""

from SUITE.cli import (
    check_single_match,
    cli_arg_for_entry_update,
    Location,
    LocationSpan,
    match_annotations,
    run_cli,
)

# First, generate an entry both for C and C++, and dump its representation to
# stdout.
annotation_file = "annotations.toml"

run_cli(
    [
        cli_arg_for_entry_update(
            identifier="c_entry",
            kind="clang_context",
            filename="foo.c",
            span=LocationSpan(Location(3, 3), Location(4, 13)),
            payload='{message="sample text"}',
        ),
        cli_arg_for_entry_update(
            identifier="cpp_entry",
            kind="clang_context",
            filename="bar.cpp",
            span=LocationSpan(Location(7, 5), Location(8, 15)),
            payload='{message="sample text"}',
        ),
        "-o",
        annotation_file,
        "-v",
    ]
)

# Check that we get the expected matches for each file from the annotation file
c_matches = match_annotations(
    annotations=[annotation_file],
    files=["foo.c"],
)
check_single_match(
    c_matches,
    "foo.c",
    LocationSpan(Location(3, 3), Location(4, 13)),
)

cpp_matches = match_annotations(
    annotations=[annotation_file],
    files=["bar.cpp"],
)
check_single_match(
    cpp_matches,
    "bar.cpp",
    LocationSpan(Location(7, 5), Location(8, 15)),
)
