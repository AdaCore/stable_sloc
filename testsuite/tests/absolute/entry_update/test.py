"""
Test simple entry generation for an absolute matcher
"""

from SUITE.cli import run_cli

# First, generate an entry, and dump its representation to stdout.
annotation_file = "annotations.toml"

run_cli(
    [
        "-u'my_spec:absolute:content.txt:5:7:7:3:"
        "{message=\"sample text\"}",
        "-o",
        annotation_file,
        "-v",
    ]
)

# Then match it on the same file, as a sanity check measure
run_cli(
    ["-s", annotation_file, "content.txt"]
)
