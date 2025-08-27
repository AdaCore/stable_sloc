"""
Utilities to manipulate toml entries
"""

from SUITE.utils import fail_or_false


def equivalent_field(
    left: dict, right: dict, key: str, register_failure=True, default=None
):
    """
    Check that left and right have the same value at key, using default as
    default value if it not present in either dict.

    If the values differ, and that register_failure is True, print an error
    and exit with an error status.
    """
    l_val = left.get(key, default)
    r_val = right.get(key, default)
    if l_val != r_val:
        return fail_or_false(
            f"different {key}: {l_val} and {r_val}", register_failure
        )
    return True


def equivalent_base(left, right, register_failure=True):
    """
    Check that left and right are equivalent entries, except for
    the matcher specific content. This assumes that left and right
    are properly formatted entries.

    Make the test fail if register_failure is True
    """
    # Check the files first
    if not equivalent_field(left, right, "file", register_failure):
        return False
    # Check the kind
    if not equivalent_field(left, right, "kind", register_failure):
        return False

    # Check the 'at_most_once' flag
    if not equivalent_field(
        left, right, "at_most_once", register_failure, default=False
    ):
        return False

    # Check that the annotations are identical
    if not equivalent_field(left, right, "annotations", register_failure):
        return False
    return True
