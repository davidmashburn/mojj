"""Alternate two dot benchmark binaries and save their matched elapsed times."""
import csv
import io
import statistics
import subprocess
import sys
from pathlib import Path

baseline_binary, candidate_binary, destination = map(Path, sys.argv[1:])
sizes = (1, 8, 128, 4096, 32768)
records = []
for trial in range(8):
    builds = [("baseline", baseline_binary), ("candidate", candidate_binary)]
    if trial % 2:
        builds.reverse()
    for position, (name, binary) in enumerate(builds):
        output = subprocess.check_output([binary.resolve()], text=True)
        rows = list(csv.reader(io.StringIO(output)))
        if tuple(int(row[0]) for row in rows) != sizes:
            raise ValueError(f"Unexpected size sequence from {name} in trial {trial}")
        for size, reps, elapsed, sink in rows:
            records.append((trial, position, name, int(size), int(reps), int(elapsed), float(sink)))

with destination.open("x", newline="") as stream:
    writer = csv.writer(stream, lineterminator="\n")
    writer.writerow(("trial", "position", "build", "size", "reps", "elapsed_ns", "sink"))
    writer.writerows(records)

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
