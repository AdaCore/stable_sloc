"""
Test that the proper diagnostics are emitted when trying to add
or update an entry in an incorrect way.
"""

from SUITE.cli import run_cli

# Check that an entry update is properly rejected when overwriting is forbidden
# (--strict command line argument)
run_cli(
    [
        "-uabcdef:absolute:content.txt:1:1:2:2:{message=\"test\"}",
        "-uabcdef:absolute:content.txt:2:1:3:2:{message=\"test\"}",
        "--strict"
    ],
    ignore_failure=True
)

# Check that requesting an entry update or addition for a backend that does
# not exist emits a diagnostic
run_cli(
    ["-uabcdef:nonexistant:content.txt:2:1:3:2:{message=\"test\"}"]
)
