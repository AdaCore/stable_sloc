"""
General purpose utilities
"""

import re
import sys


def fail_if_not_equal(what, expected, actual):
    """
    Make the testcase fail if expected and actual are not equal.
    what should describe the tested entity in the message printed
    on standard output.
    """

    if expected != actual:
        print(what + " differs from the expected baseline.")
        print("expected: ", end="")
        print(expected)
        print("actual: ", end="")
        print(actual)
        sys.exit(1)


def fail_if_no_match(what, pattern: str, actual: str):
    """
    Make the testcase fail if the re pattern does not match on actual.
    what should describe what is tested in the message printed on standard
    output.
    """
    if re.search(pattern=pattern, string=actual) is None:
        print("Could not match pattern on actual:")
        print("pattern: " + pattern)
        print("actual: " + actual)
        sys.exit(1)


def fail_if(expr, comment):
    """
    Fail the testcase if expr does not evaluate to false.
    Print comment on the standard output before exiting the test.
    """
    if expr:
        print(comment)
        sys.exit(1)


def contents_of(filename):
    """
    Return the contents of filename as a string
    """
    with open(filename) as fd:
        return fd.read()


def fail_or_false(what, do_fail):
    """
    If do_fail is True, print what and exit with an error status.
    Return False otherwise.
    """
    if do_fail:
        print(what)
        sys.exit(1)
    return False
