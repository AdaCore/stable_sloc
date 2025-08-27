"""
Test that the proper diagnostics are emitted when some part
of an entry is missing or ill-formatted. This test focuses on the common
entry fields, which are not matcher specific.
"""

from SUITE.cli import run_cli

# Explicit listing of the spec files as the order matters here, we need
# wrong_type.toml to be passed last.
run_cli(
    [
        "-smissing_field.toml",
        "-smatch_errors.toml",
        "-swrong_type.toml",
        "-snon_existant.toml",
        "--json-output",
        "--warn-unknown-matcher",
        "content.txt",
    ]
)
