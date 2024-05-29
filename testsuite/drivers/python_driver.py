import os
import sys

from e3.testsuite.driver.diff import DiffTestDriver

from drivers.base_driver import BaseDriver


class PythonDriver(BaseDriver, DiffTestDriver):
    """Run a "test.py" script an check its output.

    A test will fail if the script output is different from the expected one
    (see DiffTestDriver for the details) or if it exits with a non-zero status
    code.
    """

    def run(self):
        # Run the Python script, with the utils directory in the PYTHONPATH
        # to provide access to the testsuite's utilities.

        self.shell([sys.executable, "test.py"])
