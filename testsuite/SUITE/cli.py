"""
Various utilities abstracting the use of the stable sloc CLI
"""

import sys

from e3.os.process import Run, command_line_image
from e3.testsuite.driver.classic import TestAbortWithFailure


def exe_ext():
    return ".exe" if sys.platform == "win32" else ""


def run_cli(args, out=None, err=None, ignore_failure=False):
    """
    Invoke the stable_sloc_cli executable with the given
    args. Return the process handle for the invocation.

    Args:
        args (list[str] | None): List of arguments to be passed to
        stable_sloc_cli.
        ignore_failure (bool): If True, ignore the return status of
        the command invocation. Otherwise the test fails.
    """
    p = Run(["stable_sloc_cli" + exe_ext()] + args, output=out, error=err)
    if not ignore_failure and p.status != 0:
        raise TestAbortWithFailure(
            "stable_sloc_cli returned a non-zero status code"
        )
    return p
