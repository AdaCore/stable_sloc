"""
General purpose utilities
"""

import re
import sys


LOG_FILE = "test.log"
"""
Name of the file a test logs to, in its working directory. The driver adds its
contents to the test result.
"""


def log(message):
    """
    Append a message to the test log.

    What a test prints on standard output is compared against its test.out
    baseline, so anything meant for whoever reads a failure has to go
    somewhere else. This is that somewhere else.
    """
    with open(LOG_FILE, "a") as f:
        f.write(message + "\n")


def fail(message):
    """
    Report a failure and stop the test.

    The message goes to the log as well as to standard output, so that it sits
    right after the step it belongs to rather than after everything the test
    logged.
    """
    log(message)
    print(message)
    sys.exit(1)


def fail_if_not_equal(what, expected, actual):
    """
    Make the testcase fail if expected and actual are not equal.
    what should describe the tested entity in the message printed
    on standard output.
    """

    if expected != actual:
        fail(
            f"{what} differs from the expected baseline.\n"
            f"expected: {expected}\n"
            f"actual: {actual}"
        )


def fail_if_no_match(what, pattern: str, actual: str):
    """
    Make the testcase fail if the re pattern does not match on actual.
    what should describe what is tested in the message printed on standard
    output.
    """
    if re.search(pattern=pattern, string=actual) is None:
        fail(
            f"Could not match pattern on actual:\n"
            f"pattern: {pattern}\n"
            f"actual: {actual}"
        )


def fail_if(expr, comment):
    """
    Fail the testcase if expr does not evaluate to false.
    Print comment on the standard output before exiting the test.
    """
    if expr:
        fail(comment)


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
        fail(what)
    return False
