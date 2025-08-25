"""
Check that the clang_context matcher behaves correctly on spans
for which the enclosing declaration is in a private part.

"""

from SUITE.cli import (
    check_single_match,
    cli_arg_for_entry_update,
    Location,
    LocationSpan,
    match_annotations,
    run_cli,
)

# First, generate an entry for a location span which entirely fits within the
# private declarations
annotation_file = "annotations.toml"

run_cli(
    [
        cli_arg_for_entry_update(
            identifier="private_entry",
            kind="clang_context",
            filename="foo.cpp",
            span=LocationSpan(Location(9, 5), Location(9, 15)),
            payload='{message="sample text"}',
        ),
        "-o",
        annotation_file,
        "-v",
    ]
)

# Check that we get the expected matches for each file from the annotation file
cpp_matches = match_annotations(
    annotations=[annotation_file],
    files=["foo.cpp"],
)
check_single_match(cpp_matches, LocationSpan(Location(9, 5), Location(9, 15)))
