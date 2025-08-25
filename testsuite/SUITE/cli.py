"""
Various utilities abstracting the use of the stable sloc CLI
"""

from dataclasses import dataclass
import json
from typing import Any
import sys
import tomllib

from e3.os.process import Run, PIPE
from e3.testsuite.driver.classic import TestAbortWithFailure

from SUITE.utils import fail_if, fail_if_not_equal


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
            "stable_sloc_cli returned a non-zero status code. Command was:\n"
            f"{p.command_line_image()}"
        )
    return p


class CLIResultError(Exception):
    pass


def field_or_error(source: dict[str, Any], key: str, field_type: Any) -> Any:
    if key not in source or not isinstance(source[key], field_type):
        raise CLIResultError(f'Missing or incorrect type for "{key}" field')
    return source[key]


@dataclass
class Location:
    line: int
    col: int

    @classmethod
    def from_json_dict(cls, source: dict[str, Any]):
        line = field_or_error(source, "line", int)
        col = field_or_error(source, "column", int)
        return cls(line, col)

    def __str__(self) -> str:
        return f"{self.line}:{self.col}"


@dataclass
class LocationSpan:
    first: Location
    last: Location

    @classmethod
    def from_json_dict(cls, source: dict[str, Any]):
        sl = field_or_error(source, "start_line", int)
        sc = field_or_error(source, "start_column", int)
        el = field_or_error(source, "end_line", int)
        ec = field_or_error(source, "end_column", int)
        first = Location(sl, sc)
        last = Location(el, ec)
        return cls(first, last)


@dataclass
class LoadDiagnostic:
    """
    Class representing a entry load diagnostic
    """

    file: str
    sloc: Location
    diagnostic: str

    @classmethod
    def from_json_dict(cls, source: dict[str, Any]):
        file = field_or_error(source, "file", str)
        diagnostic = field_or_error(source, "diagnostic", str)
        sloc = Location.from_json_dict(
            field_or_error(source, "location", dict)
        )
        return cls(file, sloc, diagnostic)


@dataclass
class MatchResult:
    """
    Class representing a match result
    """

    success: bool
    identifier: str
    file: str
    annotation: dict[str, Any]
    sloc_range: LocationSpan | None
    diagnostic: str | None

    @classmethod
    def from_json_dict(cls, source: dict[str, Any]):
        success = field_or_error(source, "success", bool)
        identifier = field_or_error(source, "identifier", str)
        annotation = field_or_error(source, "annotation", dict)
        file = field_or_error(source, "file", str)
        if success:
            diagnostic = None
            sloc_range = LocationSpan.from_json_dict(
                field_or_error(source, "location", dict)
            )
        else:
            sloc_range = None
            diagnostic = field_or_error(source, "diagnostic", str)

        return cls(
            success, identifier, file, annotation, sloc_range, diagnostic
        )


@dataclass
class CliResults:
    """
    Represents the results of a stable_sloc_cli invocation
    """

    load_diagnostics: list[LoadDiagnostic]
    match_results: list[MatchResult]

    @classmethod
    def from_json_dict(cls, source: dict[str, Any]):
        diags = field_or_error(source, "load_diagnostics", list)
        matches = field_or_error(source, "match_results", list)
        load_diagnostics = []
        for diag in diags:
            load_diagnostics.append(LoadDiagnostic.from_json_dict(diag))

        match_results = []
        for match in matches:
            match_results.append(MatchResult.from_json_dict(match))

        return cls(load_diagnostics, match_results)


def match_annotations(
    annotations: list[str],
    files: list[str],
    extra_opts: list[str] | None = None,
    register_failure=True,
) -> CliResults:
    """
    Run the cli on the specified files, to match the given annotations, and
    return the results as a CliResults. extra_args are passed to the cli
    invocation between the annotation spec arguments and the file arguments.
    The final command line invocation contains the --json-output switch, to
    ensure the results can be loaded.
    """
    p_cli = run_cli(
        [f"--spec={annot}" for annot in annotations]
        + (extra_opts if extra_opts else [])
        + files
        + ["--json-output"],
        out=PIPE,
        ignore_failure=not register_failure,
    )
    return CliResults.from_json_dict(json.loads(p_cli.out))


def check_single_match(res: CliResults, expected_span: LocationSpan):
    """
    Check that res contains no diagnostics, and only a single successful match
    corresponding to the expected_span.
    """

    fail_if_not_equal("Unexpected diagnostics", 0, len(res.load_diagnostics))

    fail_if_not_equal(
        what="Unexpected amount of matches",
        expected=1,
        actual=len(res.match_results),
    )

    match_res = res.match_results[0]

    fail_if(
        not match_res.success,
        f"Unexpected match failure for {match_res.identifier}:"
        f" {match_res.diagnostic}",
    )

    fail_if_not_equal(
        what="wrong matched location span",
        expected=expected_span,
        actual=match_res.sloc_range,
    )


def cli_arg_for_entry_update(
    identifier: str, kind: str, filename: str, span: LocationSpan, payload: str
):
    """
    Generate the command line option to request the creation of a matcher
    entry of the given kind, identifier, matching the designated span in
    filename, and payload. Payload must parse as a valid TOML inline table.
    """
    parsed_payload = tomllib.loads(f"[root]\n foo={payload}")["root"]["foo"]
    if not isinstance(parsed_payload, dict):
        TestAbortWithFailure("Expected Payload to parse as a TOML table")

    return (
        f"-u{identifier}:{kind}:{filename}:"
        f"{span.first}:{span.last}:{payload}"
    )
