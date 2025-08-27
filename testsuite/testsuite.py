#!/usr/bin/env python

import sys

from e3.testsuite import Testsuite
from e3.testsuite.driver import TestDriver

from drivers.python_driver import PythonDriver


class StableSlocTestsuite(Testsuite):

    @property
    def tests_subdir(self):
        return "tests"

    @property
    def test_driver_map(self) -> dict[str, type[TestDriver]]:
        return {"python": PythonDriver}

    def add_options(self, parser):
        parser.add_argument(
            "--rewrite-baselines",
            "-r",
            action="store_true",
            help=(
                "Replace output baselines with actual outputs for tests where"
                " it makes sense."
            ),
        )

    def set_up(self):
        super().set_up()
        self.env.rewrite_baselines = self.main.args.rewrite_baselines
        self.env.control_env = {}

        # This allows the drivers and test cases to access the SUITE package
        self.env.add_search_path("PYTHONPATH", self.root_dir)


if __name__ == "__main__":
    sys.exit(StableSlocTestsuite().testsuite_main())
