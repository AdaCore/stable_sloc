"""
Test simple entry generation for a lal-context based matcher
"""

from SUITE.cli import run_cli

# First, generate an entry, and dump its representation to stdout.
annotation_file = "annotations.toml"

run_cli(
    [
        "-umy_spec:lal_context:pkg.adb:16:7:16:24:" '{message="sample text"}',
        "-o",
        annotation_file,
        "-v",
    ]
)

# Then match it on the same file, as a sanity check measure
run_cli(["-s", annotation_file, "pkg.adb"])

# Try to generate a bunch of entries for which the backend can't produce a
# valid matcher, and log the diagnostics.
run_cli(
    [
        "-umissing_file:lal_context:nonexistant.adb:1:1:1:1:"
        '{message="fail due to missing file"}',
        "-uno_basic_decl_start:lal_context:main.adb:1:1:2:1:"
        '{message="fail due to not within a basic decl"}',
        "-uno_basic_decl_end:lal_context:pkg.ads:5:1:12:17:"
        '{message="fail due to not within a basic decl"}',
        "-uno_node_start:lal_context:main.adb:20:1:2:1:"
        '{message="fail due to no within text range"}',
        "-usno_node_end:lal_context:main.adb:5:1:22:1:"
        '{message="fail due to no within text range"}',
        "-v",
    ],
)
