import argparse
import csv
import statistics
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description="Pair the public owned identity map timings.")
parser.add_argument("baseline", type=Path)
parser.add_argument("identity", type=Path)
parser.add_argument("samples", type=Path)
args = parser.parse_args()
binaries = {"baseline": args.baseline.resolve(), "identity": args.identity.resolve()}
results = {}
print(subprocess.check_output(["uptime"], text=True).strip(), flush=True)
print("Gate: primary n=100000 median paired ratio <=0.80, wins >=75%. Short size diagnostic.", flush=True)
with args.samples.open("x", newline="") as log:
    writer = csv.writer(log, lineterminator="\n")
    writer.writerow(("edition", "block", "position", "size", "reps", "batch", "elapsed_ns"))
    for block, order in enumerate((("baseline", "identity"), ("identity", "baseline")) * 2):
        for position, edition in enumerate(order):
            raw = subprocess.check_output([binaries[edition]], text=True)
            for size, reps, batch, elapsed in csv.reader(raw.splitlines()):
                size, reps, batch, elapsed = map(int, (size, reps, batch, elapsed))
                assert elapsed > 0
                writer.writerow((edition, block, position, size, reps, batch, elapsed))
                if batch:
                    results[edition, block, size, batch] = elapsed / reps
    for size in (16, 100000):
        baseline = [results["baseline", block, size, batch] for block in range(4) for batch in range(1, 5)]
        identity = [results["identity", block, size, batch] for block in range(4) for batch in range(1, 5)]
        ratios = [candidate / control for candidate, control in zip(identity, baseline)]
        print(
            f"n={size}, n_pairs={len(ratios)}, baseline_ns={statistics.median(baseline):.1f}, "
            f"candidate_ns={statistics.median(identity):.1f}, paired_ratio={statistics.median(ratios):.3f}, "
            f"wins={sum(ratio < 1 for ratio in ratios)}, pair_range={min(ratios):.3f}–{max(ratios):.3f}",
            flush=True,
        )
print(subprocess.check_output(["uptime"], text=True).strip())
