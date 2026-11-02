"""Compile-fail checks for bounded expression-string parsing."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = (ROOT / "pixi.toml").resolve()
SOURCE_ROOT = (ROOT / "src").resolve()
TIMEOUT_SECONDS = 30
DIAGNOSTIC_LIMIT = 4000


def _bounded(text: str) -> str:
    if len(text) <= DIAGNOSTIC_LIMIT:
        return text
    return text[:DIAGNOSTIC_LIMIT] + "\n...[diagnostic truncated]"


def _fixture(source: str, entrypoint: str) -> str:
    literal = json.dumps(source, ensure_ascii=False)
    if entrypoint == "describe":
        operation = f"    comptime description = Candidate.describe()\n    print(description)"
    elif entrypoint == "apply":
        operation = "    var value = Candidate.apply(2.0)\n    print(value)"
    elif entrypoint == "map":
        operation = (
            "    var data: List[Float64] = [1.0]\n"
            "    var mapped = Candidate.map(data)\n"
            "    print(mapped[0])"
        )
    elif entrypoint == "reduce":
        operation = (
            "    var data: List[Float64] = [1.0, -2.0]\n"
            "    var value = Candidate.reduce(data)\n"
            "    print(value)"
        )
    else:
        raise ValueError(f"unknown entrypoint: {entrypoint}")

    return (
        "from std.collections import List\n"
        "from mojj.strings import Expr\n\n"
        f"comptime Candidate = Expr[{literal}]\n\n"
        "def main() raises:\n"
        f"{operation}\n"
    )


def _balanced_scalar_expression(leaf_count: int) -> str:
    if leaf_count <= 0:
        raise ValueError("leaf_count must be positive")
    if leaf_count == 1:
        return "]"
    left_count = leaf_count // 2
    right_count = leaf_count - left_count
    return (
        "("
        + _balanced_scalar_expression(left_count)
        + " of "
        + _balanced_scalar_expression(right_count)
        + ")"
    )


def _compile(
    fixture: Path, binary: Path
) -> subprocess.CompletedProcess[str]:
    argv = [
        "pixi",
        "run",
        "--manifest-path",
        str(MANIFEST),
        "mojo",
        "build",
        "--fp-mode",
        "contract=off",
        "-I",
        str(SOURCE_ROOT),
        str(fixture),
        "-o",
        str(binary),
    ]
    return subprocess.run(
        argv,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=TIMEOUT_SECONDS,
        check=False,
    )


def _diagnostics(result: subprocess.CompletedProcess[str]) -> str:
    return result.stdout + result.stderr


def _run_control(directory: Path) -> None:
    fixture = directory / "control.mojo"
    binary = directory / "control"
    # Binary composition trees have odd node counts: 32 leaves use 63 nodes,
    # the largest valid tree under the 64-node limit.
    boundaries = [
        "square" + (" " * 506),
        ("(" * 16) + "square" + (")" * 16),
        _balanced_scalar_expression(32),
    ]
    boundary_checks = "".join(
        f"    print(Expr[{json.dumps(source)}].apply(2.0))\n"
        for source in boundaries
    )
    fixture.write_text(
        (
            "from std.collections import List\n"
            "from mojj.strings import Expr\n\n"
            "comptime Scalar = Expr[\"square\"]\n"
            "comptime Reduction = Expr[\"sum of square\"]\n\n"
            "def main() raises:\n"
            "    var data: List[Float64] = [1.0, -2.0]\n"
            "    var scalar_value = Scalar.apply(3.0)\n"
            "    var mapped = Scalar.map(data)\n"
            "    var reduced = Reduction.reduce(data)\n"
            "    comptime description = Reduction.describe()\n"
            "    print(scalar_value)\n"
            "    print(mapped[0])\n"
            "    print(reduced)\n"
            "    print(description)\n"
        ) + boundary_checks,
        encoding="utf-8",
    )
    try:
        result = _compile(fixture, binary)
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(
            f"valid control timed out after {TIMEOUT_SECONDS} seconds"
        ) from error
    if result.returncode != 0:
        raise RuntimeError(
            "valid control failed; parser negatives were not attempted\n"
            + _bounded(_diagnostics(result))
        )


def _negative_cases() -> list[tuple[str, str, str, str]]:
    oversized = "square" + (" " * 507)
    nested = ("(" * 17) + "square" + (")" * 17)
    balanced = _balanced_scalar_expression(33)
    if len(oversized.encode("utf-8")) <= 512:
        raise AssertionError("oversized fixture must exceed 512 bytes")
    if len(balanced.encode("utf-8")) > 512:
        raise AssertionError("node-limit fixture must stay within 512 bytes")

    return [
        ("empty", "", "describe", "Mojj syntax at byte 0:"),
        ("unknown-word", "mystery", "apply", "Mojj syntax at byte 0:"),
        ("trailing-junk", "square ?", "map", "Mojj syntax at byte 7:"),
        ("dangling-of", "square of", "reduce", "Mojj syntax at byte 9:"),
        ("dangling-at-colon", "square @:", "describe", "Mojj syntax at byte 9:"),
        ("wrong-parentheses", "(square", "apply", "Mojj syntax at byte"),
        ("wrong-parentheses-closing", "square)", "apply", "Mojj syntax at byte"),
        ("wrong-group-closing", "group square", "map", "Mojj syntax at byte"),
        ("mismatched-group-closing", "group square)", "map", "Mojj syntax at byte"),
        ("extra-group-end", "group square end end", "describe", "Mojj syntax at byte"),
        ("standalone-percent", "%", "apply", "Mojj syntax at byte 0:"),
        ("non-ascii", "squär", "reduce", "Mojj syntax at byte 3:"),
        (
            "reducer-after-reducer",
            "sum of mean",
            "reduce",
            "Mojj category at byte",
        ),
        ("reduce-scalar", "square", "reduce", "Mojj category at byte"),
        ("apply-reducer", "sum", "apply", "Mojj category at byte"),
        ("map-reducer", "mean", "map", "Mojj category at byte"),
        ("over-512-bytes", oversized, "describe", "Mojj syntax at byte 512: source exceeds 512 bytes"),
        ("over-16-depth", nested, "describe", "expression nesting exceeds 16 levels"),
        ("over-64-nodes", balanced, "describe", "expression exceeds 64 AST nodes"),
        ("describe-validation", "unknown", "describe", "Mojj syntax at byte 0:"),
        ("implicit-reducers", "sum mean", "reduce", "Mojj category at byte 4:"),
        ("implicit-unknown", "square mystery", "apply", "Mojj syntax at byte 7:"),
        ("merged-words", "squaresquare", "apply", "Mojj syntax at byte 0:"),
        ("missing-separator", "square(square)", "apply", "Mojj syntax at byte 6:"),
        ("implicit-depth", " ".join(["square"] * 18), "describe", "expression nesting exceeds 16 levels"),
    ]


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="mojj-syntax-") as temporary:
        directory = Path(temporary)
        try:
            _run_control(directory)
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            print(f"FAIL check_syntax control: {error}", file=sys.stderr)
            return 1

        failures: list[str] = []
        cases = _negative_cases()
        for name, source, entrypoint, expected in cases:
            fixture = directory / f"{name}.mojo"
            binary = directory / name
            fixture.write_text(
                _fixture(source, entrypoint),
                encoding="utf-8",
            )
            try:
                result = _compile(fixture, binary)
            except subprocess.TimeoutExpired:
                failures.append(
                    f"{name}: compiler timed out after {TIMEOUT_SECONDS} seconds"
                )
                continue
            diagnostics = _diagnostics(result)
            if result.returncode == 0:
                failures.append(f"{name}: invalid fixture compiled successfully")
                continue
            if expected not in diagnostics:
                failures.append(
                    f"{name}: expected {expected!r}; diagnostics:\n"
                    + _bounded(diagnostics)
                )
                continue
            lowered = diagnostics.lower()
            if any(
                marker in lowered
                for marker in (
                    "cannot find module",
                    "no module named",
                    "unknown module",
                    "file not found",
                    "unable to locate module",
                )
            ):
                failures.append(
                    f"{name}: toolchain/import failure appeared in parser diagnostics:\n"
                    + _bounded(diagnostics)
                )

        if failures:
            print("FAIL check_syntax:", file=sys.stderr)
            for failure in failures:
                print(f"\n{failure}", file=sys.stderr)
            return 1

        print(
            "PASS check_syntax: control compiled and "
            f"{len(cases)} negative fixtures rejected by parser/category diagnostics"
        )
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
