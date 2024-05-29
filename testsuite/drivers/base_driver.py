import os

from typing import Dict, Optional

from e3.fs import sync_tree
from e3.testsuite.control import YAMLTestControlCreator
from e3.testsuite.driver.classic import (
    ClassicTestDriver,
    TestAbortWithError,
)


class BaseDriver(ClassicTestDriver):
    """
    Base class to provide common test driver helpers.
    """

    RESOURCES: Dict[str, str] = {}

    def shared_dir(self, *name: str) -> str:
        """Get full path to a resource.

        :param name: Parameters as passed to `os.path.join`.
        """
        return os.path.join(self.env.root_dir, "shared", *name)

    def check_file(self, filename: str) -> None:
        """Check file presence.

        If the file does not exist test is aborted.
        """
        if not os.path.isfile(filename):
            import traceback

            traceback.print_stack()
            raise TestAbortWithError("missing file: %s" % filename)

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

        # Synchronize all resources declared in the RESOURCES class variable
        for resource, dest in self.RESOURCES.items():
            self.sync_res(resource, dest)
