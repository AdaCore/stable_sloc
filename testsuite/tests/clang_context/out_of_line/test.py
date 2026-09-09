"""
Check correct matching and rejection of invalidated matchers when
the designated region is located in a out-of-line declaration.
"""

from SUITE.cli import (
    check_single_match,
    cli_arg_for_entry_update,
    Location,
    LocationSpan,
    match_annotations,
    run_cli,
)

from SUITE.utils import fail_if, fail_if_not_equal

# First, generate an entry for the out-of-line baz method in bar.cpp
annotation_file = "annotations.toml"

run_cli(
    [
        cli_arg_for_entry_update(
            identifier="cpp_entry",
            kind="clang_context",
            filename="bar.cpp",
            span=LocationSpan(Location(37, 3), Location(38, 15)),
            payload='{message="sample text"}',
        ),
        "-o",
        annotation_file,
        "-v",
    ]
)

# Check that we get the expected matches from the generated annotation file
cpp_matches = match_annotations(
    annotations=[annotation_file],
    files=["bar.cpp"],
)
check_single_match(
    cpp_matches, "bar.cpp", LocationSpan(Location(37, 3), Location(38, 15))
)

# Same, but check that we relocate correctly if the enclosing decl hasn't
# changed (file m_ok_bar.cpp)
ok_cpp_matches = match_annotations(
    annotations=[annotation_file],
    files=["m_ok_bar.cpp"],
)
check_single_match(
    ok_cpp_matches,
    "m_ok_bar.cpp",
    LocationSpan(Location(11, 3), Location(12, 15)),
)

# Check Stable_Sloc correctly reject the annotation if we do modify the
# out-of-line method decl
nok_cpp_matches = match_annotations(
    annotations=[annotation_file],
    files=["m_nok_bar.cpp"],
)

# CHeck we got the expected result
fail_if_not_equal(
    actual=len(nok_cpp_matches.match_results),
    expected=1,
    what="Only expected a single match result",
)

fail_if(
    nok_cpp_matches.match_results[0].success,
    "Expected a match failure but got a success",
)

fail_if_not_equal(
    actual=nok_cpp_matches.match_results[0].diagnostic,
    expected="Content of declaration Out_Of_Line::Some_Class::baz has"
    " changed",
    what="Unexpected diagnostic message for match failure",
)
