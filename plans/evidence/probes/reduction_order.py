"""Check whether J's +/ on floats reassociates relative to strict left-to-right."""
from pathlib import Path
import subprocess

ROOT = Path.cwd()
J = ROOT / "build/reference/runtime/j64/jconsole"
if not J.exists():
    raise SystemExit(f"Pinned J not found at {J}; run `pixi run compare-j --fetch-j` first.")


def left_to_right(v):
    total = 0.0
    for x in v:
        total += x
    return total


def right_to_left(v):
    total = 0.0
    for x in reversed(v):
        total += x
    return total


def blocked4(v):
    acc = [0.0, 0.0, 0.0, 0.0]
    for i, x in enumerate(v):
        acc[i % 4] += x
    return (acc[0] + acc[1]) + (acc[2] + acc[3])


def pairwise(v):
    values = list(v)
    while len(values) > 1:
        nxt = []
        for i in range(0, len(values) - 1, 2):
            nxt.append(values[i] + values[i + 1])
        if len(values) % 2:
            nxt.append(values[-1])
        values = nxt
    return values[0] if values else 0.0


def run_j(values):
    script = ROOT / "build/reduction-order.ijs"
    script.parent.mkdir(parents=True, exist_ok=True)
    def token(x):
        text = repr(x)
        if text.startswith("-"):
            text = "_" + text[1:]
        return text.replace("e+", "e").replace("e-", "e_")
    body = " ".join(token(x) for x in values)
    script.write_text(
        "output=: 1!:2&2\n9!:11 ] 17\n"
        f"v=: {body}\n"
        "output 'DTYPE|',\":3!:0 v\n"
        "output 'SUM|',\":,+/v\n"
        "output 'DONE'\n2!:55''\n"
    )
    escaped = str(script).replace("'", "''")
    result = subprocess.run([str(J), "-jprofile", "/dev/null"],
                            input=f"0!:0 <'{escaped}'\n", text=True,
                            capture_output=True, timeout=120)
    dtype = sum = None
    for line in result.stdout.splitlines():
        if line.startswith("DTYPE|"):
            dtype = int(line.split("|")[1])
        if line.startswith("SUM|"):
            sum = float(line.split("|")[1])
    if dtype is None or sum is None:
        raise RuntimeError(result.stdout + result.stderr)
    return dtype, sum
    raise RuntimeError(result.stdout + result.stderr)


CASES = {
    "n=4 [1, 1e16, -1e16, 1]": [1.0, 1e16, -1e16, 1.0],
    "n=8 [1e16,1,-1e16,1]*2": [1e16, 1.0, -1e16, 1.0] * 2,
    "n=100000 repeating 1e16,1,-1e16,1": ([1e16, 1.0, -1e16, 1.0] * 25000),
    "n=100000 1s plus one 1e16 at start": [1e16] + [1.0] * 99999,
    "n=100000 1s plus one 1e16 at end": [1.0] * 99999 + [1e16],
}

for name, values in CASES.items():
    dtype, got = run_j(values)
    print(name)
    print(f"  J storage dtype      = {dtype} (4=Int, 8=Float64)")
    print(f"  J                    = {got!r}")
    print(f"  strict left-to-right = {left_to_right(values)!r}")
    print(f"  strict right-to-left = {right_to_left(values)!r}")
    print(f"  4-block accumulators = {blocked4(values)!r}")
    print(f"  pairwise             = {pairwise(values)!r}")
    print()
