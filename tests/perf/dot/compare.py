"""Alternate two dot benchmark binaries and save their matched elapsed times."""
import argparse
import csv
import io
import statistics
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
modes = parser.add_mutually_exclusive_group()
modes.add_argument("--rectangular", action="store_true")
modes.add_argument("--mixed", action="store_true")
parser.add_argument("baseline_binary", type=Path)
parser.add_argument("candidate_binary", type=Path)
parser.add_argument("destination", type=Path)
args = parser.parse_args()
if args.mixed:
    sizes = tuple(f"{shape}-{percent}" for shape in ("tall", "wide") for percent in (0, 5, 10, 50))
elif args.rectangular:
    sizes = ("mv-128x32", "mv-32x128", "vm-128x32", "vm-32x128")
else:
    sizes = ("1", "8", "128", "4096", "32768")
records = []
for trial in range(8):
    builds = [("baseline", args.baseline_binary), ("candidate", args.candidate_binary)]
    if trial % 2:
        builds.reverse()
    for position, (name, binary) in enumerate(builds):
        output = subprocess.check_output([binary.resolve()], text=True)
        rows = list(csv.reader(io.StringIO(output)))
        if tuple(row[0] for row in rows) != sizes:
            raise ValueError(f"Unexpected size sequence from {name} in trial {trial}")
        for size, reps, elapsed, sink in rows:
            records.append((trial, position, name, size, int(reps), int(elapsed), float(sink)))

for size in sizes:
    ratios = []
    for trial in range(8):
        pair = {row[2]: row for row in records if row[0] == trial and row[3] == size}
        baseline, candidate = pair["baseline"], pair["candidate"]
        if baseline[4] != candidate[4] or baseline[6] != candidate[6]:
            raise ValueError(f"Repetition or sink mismatch at size {size}, trial {trial}")
        ratios.append(candidate[5] / baseline[5])
    print(size, round(statistics.median(ratios), 4), min(ratios), max(ratios),
          sum(ratio < 1 for ratio in ratios))

with args.destination.open("x", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    case_column = "case" if args.rectangular or args.mixed else "size"
    writer.writerow(("trial", "position", "build", case_column, "reps", "elapsed_ns", "sink"))
    writer.writerows(records)
