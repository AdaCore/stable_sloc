import os

from typing import Optional

from e3.fs import sync_tree
from e3.testsuite.control import YAMLTestControlCreator
from e3.testsuite.driver.classic import (
    ClassicTestDriver,
    TestAbortWithError,
)
from e3.testsuite.result import TestResult

from SUITE.utils import LOG_FILE


class BaseDriver(ClassicTestDriver):
    """
    Base class to provide common test driver helpers.
    """

    def shared_dir(self, *name: str) -> str:
        """Get full path to a resource.

        :param name: Parameters as passed to `os.path.join`.
        """
        return os.path.join(self.env.root_dir, "shared", *name)

    def sync_res(self, name: str, dest: Optional[str] = None) -> None:
        """Sync resources to working directory.

        :param name: Name of the resource (path relative to SHARED_DIR).
        :param dest: Destination. If None, the resource is synchronized
            into the working directory.
        """

        dest = self.working_dir() if dest is None else self.working_dir(dest)

        try:
            sync_tree(self.shared_dir(name), dest, delete=False)
        except Exception as exc:
            raise TestAbortWithError(
                f"error during copy of shared resource {name}: {exc}"
            )

    @property
    def test_control_creator(self):
        return YAMLTestControlCreator(self.env.control_env)

    def set_up(self) -> None:
        super().set_up()

        # Sync the required resources for the test
        if "resources" in self.test_env:
            for src_dir, dest_dir in self.test_env["resources"].items():
                self.sync_res(src_dir, dest_dir)

    def push_result(self, result: Optional[TestResult] = None) -> None:
        """Add whatever the test logged to its result before recording it.

        This is the hook every outcome goes through. tear_down would be too
        late: a test aborting on a failure has its result pushed on the way out
        of run_wrapper's try block, before the finally that tears down.
        """
        target = self.result if result is None else result
        log_file = self.working_dir(LOG_FILE)
        if os.path.exists(log_file):
            with open(log_file) as f:
                target.log += f"\nTest log:\n{f.read()}"

        super().push_result(result)
