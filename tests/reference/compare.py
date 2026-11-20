"""Bounded live-J comparison; runtime/build artifacts stay under build/reference."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from enum import StrEnum
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BUILD = ROOT / "build" / "reference"
DEFAULT_TIMEOUT_SECONDS = 180
SAMPLES = 5
TARGET_NS = 50_000_000
MAX_REPETITIONS = 65_536
INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1
SIZES = (1_000, 10_000, 100_000)
WORKLOADS = {"double": "+:", "sum": "+/", "rms": "%: @: (+/ % #) @: *:"}


class Mode(StrEnum):
    VALUE = "value"
    MONAD = "monad"
    DYAD = "dyad"


class DType(StrEnum):
    BOOL = "Bool"
    INT = "Int"
    FLOAT = "Float64"
    COMPLEX = "Complex"


class Expectation(StrEnum):
    MATCH = "match"
    DIFFERENT = "different"


class Status(StrEnum):
    VALUE = "value"
    ERROR = "error"


J_TYPES = {1: DType.BOOL, 4: DType.INT, 8: DType.FLOAT, 16: DType.COMPLEX}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run(argv: list[str], *, input: str | None = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS) -> str:
    result = subprocess.run(argv, input=input, text=True, capture_output=True,
                            cwd=ROOT, timeout=timeout, check=False)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {argv[0]}\n"
                           + result.stdout[-6000:] + result.stderr[-6000:])
    return result.stdout


def runtime(fetch: bool, supplied: Path | None) -> tuple[Path, dict]:
    pins = json.loads((HERE / "runtime.json").read_text())
    host = f"{platform.system()}-{platform.machine()}"
    if host not in pins:
        raise RuntimeError(f"No J runtime pinned for {host}. Supported: {', '.join(pins)}")
    pin = pins[host]
    destination = BUILD / "runtime"
    if fetch:
        data = urllib.request.urlopen(pin["archive_url"], timeout=60).read()
        if sha(data) != pin["archive_sha256"]:
            raise RuntimeError("Reference archive changed: checksum mismatch")
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for name, digest in pin["files"].items():
                content = archive.read(name)
                if sha(content) != digest:
                    raise RuntimeError(f"Reference member checksum mismatch: {name}")
                target = destination / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
        (destination / "j64/jconsole").chmod(0o755)
    executable = (supplied or destination / "j64/jconsole").resolve()
    for name, digest in pin["files"].items():
        path = executable if name == "j64/jconsole" else executable.parent / Path(name).name
        if not path.exists() or sha(path.read_bytes()) != digest:
            raise RuntimeError(f"Pinned J file missing/mismatched: {path.name}; use --fetch-j")
    return executable, pin


def j_run(executable: Path, source: str, name: str) -> str:
    path = BUILD / (name + ".ijs")
    path.write_text(source + "\noutput 'DONE'\n2!:55''\n")
    escaped = str(path).replace("'", "''")
    output = run([str(executable), "-jprofile", "/dev/null"],
                 input=f"0!:0 <'{escaped}'\n")
    # J can return exit code zero after a script error. Require completion.
    if "DONE" not in output.splitlines():
        raise RuntimeError("J script did not finish:\n" + output[-4000:])
    return output


def mojo_build(source: str, name: str, timeout: int) -> Path:
    path = BUILD / (name + ".mojo")
    path.write_text(source)
    binary = BUILD / name
    run(["pixi", "run", "mojo", "build", "--fp-mode", "contract=off",
         "-I", "src", str(path), "-o", str(binary)], timeout=timeout)
    return binary


def _input_shape(noun: dict) -> list[int]:
    rank = noun["rank"]
    if type(rank) is not int or rank < 0:
        raise ValueError("input noun rank must be a nonnegative integer")
    length = len(noun["values"])
    if "shape" in noun:
        shape = noun["shape"]
    elif rank == 0:
        shape = []
    elif rank == 1:
        shape = [length]
    else:
        shape = None
    if not isinstance(shape, list) or len(shape) != rank:
        raise ValueError(f"input noun shape must contain {rank} axes")
    if any(type(axis) is not int or not 0 <= axis <= INT64_MAX for axis in shape):
        raise ValueError("input noun shape axes must be nonnegative Int64 integers")
    if math.prod(shape) != length:
        raise ValueError("input noun shape atom count must match the number of values")
    return shape


def _input_values(noun: dict, dtype: DType) -> list:
    values = noun["values"]
    if dtype == DType.INT:
        if any(type(value) is not int or not INT64_MIN <= value <= INT64_MAX for value in values):
            raise ValueError("Int input noun values must be Int64 integers")
    elif dtype == DType.BOOL:
        if any(type(value) not in (bool, int) or value not in (0, 1) for value in values):
            raise ValueError("Bool input noun values must be booleans or 0/1 integers")
    elif dtype == DType.FLOAT:
        try:
            finite = all(type(value) in (int, float) and math.isfinite(value) for value in values)
        except OverflowError:
            finite = False
        if not finite:
            raise ValueError("Float64 input noun values must be finite numbers")
        return [float(value) for value in values]
    return values


def mojo_noun(noun: dict) -> str:
    shape = _input_shape(noun)
    dtype = DType(noun["dtype"])
    values = [repr(v) for v in _input_values(noun, dtype)]
    if not shape:
        return f"Noun({dtype}({values[0]}))"
    atoms = ", ".join(f"{dtype}({value})" for value in values)
    list_arg = f"[{atoms}]" if values else ""
    expression = f"Noun(List[{dtype}]({list_arg}))"
    return f"{expression}.with_shape({shape})" if len(shape) > 1 else expression


def j_noun(noun: dict) -> str:
    shape = _input_shape(noun)
    dtype = DType(noun["dtype"])
    atoms = _input_values(noun, dtype)
    values = [str(int(v)) if dtype == DType.BOOL else
              repr(v).replace("e+", "e").replace("-", "_")
              for v in atoms]
    phrase = " ".join(values)
    if len(shape) > 1 or not values:
        axes = " ".join(str(axis) for axis in shape)
        seed = "0.0" if dtype == DType.FLOAT else "0"
        expression = f"({axes}${phrase or seed})"
    elif shape:
        expression = f"(,{phrase})"
    else:
        expression = f"({phrase})"
    # J infers Bool when a literal contains only 0 and 1. Integer addition
    # keeps the atoms and shape, including when reshaped from a Boolean seed.
    if dtype == DType.INT and all(value in (0, 1) for value in atoms):
        return f"(0+{expression})"
    return expression


J_HEADER = """output=: 1!:2&2
9!:11 ] 17
9!:37 ] 0 20000000 0 10000
output 'VERSION|',9!:14''
emit=: 4 : 0
 output 'RESULT|',x,'|',(":3!:0 y),'|',(":#$y),'|',(":$y),'|',":,y
)
"""
MOJO_HEADER = '''from std.collections import List
from mojj.nouns import Noun, NounDType
from mojj.strings import Expr

def emit(id: String, value: Noun) raises:
    var values = String("")
    for i in range(value.length()):
        if i > 0:
            values += " "
        var cell = value.at(i)
        if value.dtype == NounDType.FLOAT64:
            values += String(cell.as_float())
        elif value.dtype == NounDType.BOOL:
            values += String(Int(cell.as_bool()))
        else:
            values += String(cell.as_int())
    var shape = String("")
    var dimensions = value.dims()
    for i in range(value.rank):
        if i > 0:
            shape += " "
        shape += String(dimensions[i])
    print("RESULT|" + id + "|" + value.dtype.describe() + "|" + String(value.rank) + "|" + shape + "|" + values)
'''


def number(token: str) -> int | float | str:
    if "j" in token:
        return token  # Complex is an intentionally unsupported domain.
    token = token.replace("_", "-")
    return float(token) if any(c in token.lower() for c in ".e") else int(token)


def parse_results(output: str, is_j: bool) -> dict:
    results = {}
    for line in output.splitlines():
        if line.startswith("ERROR|"):
            results[line.split("|")[1]] = {"status": Status.ERROR}
        elif line.startswith("RESULT|"):
            _, id, dtype, rank, payload = line.split("|", 4)
            if "|" in payload:
                dimensions, values = payload.split("|")
                shape = [int(v) for v in dimensions.split()]
            else:
                values = payload
                if int(rank) > 1:
                    raise ValueError("array result is missing dimensions")
                shape = [] if int(rank) == 0 else [len(values.split())]
            dtype = J_TYPES[int(dtype)] if is_j else DType(dtype)
            results[id] = {"status": Status.VALUE, "dtype": dtype,
                           "rank": int(rank), "shape": shape, "values": [number(v) for v in values.split()]}
    return results


def equal_values(left: dict, right: dict) -> bool:
    if left["status"] != right["status"]:
        return False
    if left["status"] == Status.ERROR:
        return True  # Error categories/messages are recorded as outside this comparison.
    if (left.get("shape") != right.get("shape") or left["rank"] != right["rank"]
            or len(left["values"]) != len(right["values"])):
        return False
    exact = (left["dtype"] in (DType.INT, DType.BOOL)
             or right["dtype"] in (DType.INT, DType.BOOL))
    for x, y in zip(left["values"], right["values"]):
        if exact or (isinstance(x, int) and isinstance(y, int)):
            if x != y:
                return False
        elif isinstance(x, (int, float)) and isinstance(y, (int, float)):
            if not math.isclose(x, y, rel_tol=1e-12, abs_tol=1e-12):
                return False
        elif x != y:
            return False
    return True


def expectation_met(case: dict, jr: dict, mr: dict) -> bool:
    return (equal_values(jr, mr) == (Expectation(case["expected"]) == Expectation.MATCH)
            and jr["status"] == Status(case["j_status"])
            and mr["status"] == Status(case["mojj_status"])
            and (not case.get("require_dtype_match", False) or jr.get("dtype") == mr.get("dtype")))


def conformance(jconsole: Path, pin: dict, compile_timeout: int = DEFAULT_TIMEOUT_SECONDS) -> list[dict]:
    cases = json.loads((HERE / "cases.json").read_text())
    mojo = MOJO_HEADER + "\ndef main() raises:\n"
    j = J_HEADER + "cases=: 3 : 0\n"
    for case in cases:
        mode = Mode(case["mode"])
        expr = case["expression"]
        call = f"Expr[{json.dumps(expr)}].{mode}("
        j_call = f"({expr})"
        if mode != Mode.VALUE:
            call += mojo_noun(case["y"]) if mode == Mode.MONAD else (
                mojo_noun(case["x"]) + ", " + mojo_noun(case["y"]))
            j_call += " " + j_noun(case["y"])
            if mode == Mode.DYAD:
                j_call = j_noun(case["x"]) + " " + j_call
        call += ")"
        mojo += f'    try:\n        emit("{case["id"]}", {call})\n    except:\n        print("ERROR|{case["id"]}")\n'
        j += f" try.\n  '{case['id']}' emit {j_call}\n catch.\n  output 'ERROR|{case['id']}'\n end.\n"
    j += ")\ncases''\n"
    j_output = j_run(jconsole, j, "conformance")
    if "VERSION|" + pin["version"] not in j_output.splitlines():
        raise RuntimeError("J reported an unexpected version")
    mojo_output = run([str(mojo_build(mojo, "conformance", compile_timeout))])
    (BUILD / "conformance-j.txt").write_text(j_output)
    (BUILD / "conformance-mojj.txt").write_text(mojo_output)
    j_results, mojo_results = parse_results(j_output, True), parse_results(mojo_output, False)
    if set(j_results) != {c['id'] for c in cases} or set(mojo_results) != set(j_results):
        raise RuntimeError("Missing conformance output")
    rows = []
    for case in cases:
        jr, mr = j_results[case["id"]], mojo_results[case["id"]]
        same = equal_values(jr, mr)
        rows.append({**case, "j": jr, "mojj": mr, "values_and_shape_match": same,
                     "dtype_match": jr.get("dtype") == mr.get("dtype"),
                     "expectation_met": expectation_met(case, jr, mr)})
    return rows


MOJO_BENCH = '''from std.time import perf_counter_ns

@no_inline
def batch[source: StringLiteral](mut data: Noun, repetitions: Int) raises -> Float64:
    var sink: Float64 = 0
    for i in range(repetitions):
        data.float_values[0] = Float64(i % 17) / 16.0
        var result = Expr[source].monad(data)
        sink += result.at(0).as_float()
    return sink

def bench[source: StringLiteral](id: String, size: Int) raises:
    var values = List[Float64]()
    for i in range(size):
        values.append(Float64(i % 97) / 16.0)
    var data = Noun(values)
    var check = Expr[source].monad(data)
    emit(id + "-" + String(size), check)
    var sink = batch[source](data, 2)
    var repetitions = 1
    while True:
        var start = perf_counter_ns()
        sink += batch[source](data, repetitions)
        var elapsed = perf_counter_ns() - start
        if elapsed >= TARGET_NS or repetitions >= MAX_REPETITIONS:
            break
        repetitions *= 2
    for sample in range(SAMPLES):
        var start = perf_counter_ns()
        sink += batch[source](data, repetitions)
        var elapsed = perf_counter_ns() - start
        print("TIME|" + id + "|" + String(size) + "|" + String(repetitions) + "|" + String(Float64(elapsed) / Float64(repetitions)))
    print("SINK|" + String(sink))
'''
J_BENCH = '''batch=: 4 : 0
 data=. y
 sink=. 0.0
 for_i. i.x do.
  data=. ((17|i)%16.0) 0}data
  result=. op data
  sink=. sink + {. ,result
 end.
 sink
)
bench=: 4 : 0
 data=. (97|i.y)%16.0
 (x,'-',":y) emit op data
 sink=. 2 batch data
 repetitions=. 1
 while. 1 do.
  start=. 6!:1''
  sink=. sink + repetitions batch data
  elapsed=. (6!:1'') - start
  if. (elapsed >: TARGET_SECONDS) +. repetitions >: MAX_REPETITIONS do. break. end.
  repetitions=. 2*repetitions
 end.
 for_sample. i.SAMPLES do.
  start=. 6!:1''
  sink=. sink + repetitions batch data
  elapsed=. (6!:1'') - start
  output 'TIME|',x,'|',(":y),'|',(":repetitions),'|',":1e9*elapsed%repetitions
 end.
 output 'SINK|',":sink
)
'''


def timings(output: str) -> dict:
    rows = {}
    for line in output.splitlines():
        if line.startswith("TIME|"):
            _, name, size, repetitions, ns = line.split("|")
            row = rows.setdefault((name, int(size)), {"repetitions": int(repetitions), "ns_per_call": []})
            row["ns_per_call"].append(float(ns))
    return rows


def benchmark_match(left: dict, right: dict) -> bool:
    return (left["status"] == right["status"] == Status.VALUE
            and left["dtype"] == right["dtype"] and equal_values(left, right))


def output_summary(result: dict) -> dict:
    return {"dtype": result["dtype"], "rank": result["rank"], "length": len(result["values"])}


def benchmarks(jconsole: Path, compile_timeout: int = DEFAULT_TIMEOUT_SECONDS) -> list[dict]:
    mojo_bench = MOJO_BENCH.replace("TARGET_NS", str(TARGET_NS)).replace(
        "MAX_REPETITIONS", str(MAX_REPETITIONS)).replace("SAMPLES", str(SAMPLES))
    j_bench = J_BENCH.replace("TARGET_SECONDS", str(TARGET_NS / 1e9)).replace(
        "MAX_REPETITIONS", str(MAX_REPETITIONS)).replace("SAMPLES", str(SAMPLES))
    mojo = MOJO_HEADER + mojo_bench + "\ndef main() raises:\n"
    j = J_HEADER + j_bench
    for name, expression in WORKLOADS.items():
        j += f"op=: {expression}\n"
        for size in SIZES:
            mojo += f'    bench[{json.dumps(expression)}]("{name}", {size})\n'
            j += f"'{name}' bench {size}\n"
    binary = mojo_build(mojo, "benchmarks", compile_timeout)
    # No concurrent benchmarking; compilation and process launch are outside timers.
    mo = run([str(binary)])
    jo = j_run(jconsole, j, "benchmarks")
    (BUILD / "benchmarks-mojj.txt").write_text(mo)
    (BUILD / "benchmarks-j.txt").write_text(jo)
    mr, jr = parse_results(mo, False), parse_results(jo, True)
    if set(mr) != set(jr) or len(mr) != len(WORKLOADS) * len(SIZES):
        raise RuntimeError("Missing benchmark value checks")
    for id in mr:
        if not benchmark_match(mr[id], jr[id]):
            raise RuntimeError("Benchmark results differ: " + id)
    mt, jt = timings(mo), timings(jo)
    rows = []
    for name in WORKLOADS:
        for size in SIZES:
            m, j = mt[name, size], jt[name, size]
            if len(m["ns_per_call"]) != SAMPLES or len(j["ns_per_call"]) != SAMPLES:
                raise RuntimeError("Incomplete timing samples")
            mm, jm = statistics.median(m["ns_per_call"]), statistics.median(j["ns_per_call"])
            if min(m["ns_per_call"] + j["ns_per_call"]) <= 0:
                raise RuntimeError("Invalid timing sample")
            rows.append({"workload": name, "expression": WORKLOADS[name], "size": size,
                         "mojj": m, "j": j, "mojj_median_ns": mm, "j_median_ns": jm,
                         "mojj_over_j": mm / jm, "values_and_shape_match": True,
                         "dtype_match": True, "mojj_result": output_summary(mr[f"{name}-{size}"]),
                         "j_result": output_summary(jr[f"{name}-{size}"])})
    return rows


def host_metadata() -> dict:
    system = platform.system()
    if system == "Darwin":
        version = platform.mac_ver()[0]
        cpu = run(["sysctl", "-n", "machdep.cpu.brand_string"]).strip()
    else:
        version = platform.freedesktop_os_release().get("PRETTY_NAME", platform.release())
        cpu = next((line.partition(":")[2].strip()
                    for line in Path("/proc/cpuinfo").read_text().splitlines()
                    if line.partition(":")[0].strip() == "model name"), platform.machine())
    return {"system": system, "machine": platform.machine(), "os_version": version, "cpu": cpu}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch-j", action="store_true", help="Download checksum-pinned J into build/reference")
    parser.add_argument("--jconsole", type=Path, help="Existing matching pinned J executable")
    parser.add_argument("--conformance-only", action="store_true", help="Check live J results and skip timings")
    parser.add_argument("--output", type=Path, default=BUILD / "results.json")
    parser.add_argument("--compile-timeout-seconds", type=int, default=DEFAULT_TIMEOUT_SECONDS,
                        help="Time limit for each Mojo build in seconds (default: %(default)s)")
    args = parser.parse_args()
    if args.compile_timeout_seconds < 1:
        parser.error("--compile-timeout-seconds must be a positive integer")
    BUILD.mkdir(parents=True, exist_ok=True)
    executable, pin = runtime(args.fetch_j, args.jconsole)
    load_before = os.getloadavg()
    cases = conformance(executable, pin, args.compile_timeout_seconds)
    bench = [] if args.conformance_only else benchmarks(executable, args.compile_timeout_seconds)
    load_after = os.getloadavg()
    source_files = sorted((ROOT / "src/mojj").glob("*.mojo"))
    harness_files = [HERE / name for name in ("compare.py", "test_compare.py", "cases.json", "runtime.json")]
    result = {"recorded_at": datetime.now(timezone.utc).isoformat(),
              "source_revision": run(["git", "rev-parse", "HEAD"]).strip(),
              "file_sha256": {str(p.relative_to(ROOT)): sha(p.read_bytes()) for p in source_files + harness_files + [ROOT / "pixi.toml", ROOT / "pixi.lock"]},
              "host_load_average": {"before": load_before, "after": load_after},
              "platform": host_metadata(),
              "mojo_version": run(["pixi", "run", "mojo", "--version"]).strip(),
              "j_runtime": pin, "compile_flags": ["--fp-mode", "contract=off"],
              "benchmarks_requested": not args.conformance_only,
              "method": {"samples": SAMPLES, "target_batch_ns": TARGET_NS, "maximum_repetitions": MAX_REPETITIONS,
                         "input": "Float64(i % 97) / 16; first cell changes to (iteration % 17) / 16 inside each timed call",
                         "timed": "batch loop, first-cell update, operation, first-result-cell consumption, allocation and destruction",
                         "excluded": "compilation, process startup, initial input construction, output serialization",
                         "order": "all Mojj workloads, then all J workloads; single process per runtime; no parallel runs",
                         "comparison": "exact values whenever either storage dtype is integer/Boolean; otherwise float abs/relative tolerance 1e-12; shape, rank and length; dtype equality required for flagged conformance cases and benchmarks"},
              "conformance": cases, "benchmarks": bench}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n")
    failures = [c["id"] for c in cases if not c["expectation_met"]]
    print(f"{len(cases) - len(failures)}/{len(cases)} conformance expectations met; {len(bench)} benchmark comparisons")
    for row in bench:
        print(f"{row['workload']} n={row['size']}: Mojj/J={row['mojj_over_j']:.2f}x")
    if failures:
        raise SystemExit("Unexpected conformance differences: " + ", ".join(failures))


if __name__ == "__main__":
    main()
