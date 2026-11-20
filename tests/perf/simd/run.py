#!/usr/bin/env python3
"""Run four prebuilt benchmark executables and compare paired block timings."""

import argparse
import csv
import io
import math
from pathlib import Path
from statistics import median
import subprocess


VARIANTS = ("baseline", "width2", "width4", "width8")
WILLIAMS_FIRST_ROW = (0, 1, 3, 2)
BLOCK_SHIFTS = (0, 1, 2, 3, 2, 3, 0, 1)
TIMING_FIELDS = ("label", "size", "width", "time_ns")
SAMPLE_FIELDS = ("block", "position", "raw_order_offset", "variant")
PAIR_FIELDS = (
    "comparison",
    "variant",
    "block",
    "label",
    "size",
    "width",
    "reference_ns",
    "candidate_ns",
    "ratio",
)
RAW_COMPARISON_SIZE = 100_000


def read_timings(stdout, source):
    reader = csv.DictReader(io.StringIO(stdout))
    if not reader.fieldnames or not set(TIMING_FIELDS).issubset(reader.fieldnames):
        raise ValueError(f"{source}: expected CSV fields {', '.join(TIMING_FIELDS)}")
    rows = list(reader)
    if not rows:
        raise ValueError(f"{source}: no timings")
    timings = {}
    for row in rows:
        key = (row["label"], int(row["size"]), int(row["width"]))
        timing = float(row["time_ns"])
        if key in timings or timing <= 0 or not math.isfinite(timing):
            raise ValueError(f"{source}: invalid or duplicate timing for {key}: {timing}")
        timings[key] = timing
    return reader.fieldnames, rows, timings


def run_blocks(binaries, mode, output_dir):
    blocks = []
    with (output_dir / "samples.csv").open("w", newline="") as samples:
        writer = None
        expected_fields = None
        expected_keys = None
        for block, shift in enumerate(BLOCK_SHIFTS, start=1):
            raw_offset = (block - 1) % 4
            order = [VARIANTS[(index + shift) % 4] for index in WILLIAMS_FIRST_ROW]
            print(f"Block {block}/{len(BLOCK_SHIFTS)}: {' '.join(order)}", flush=True)
            runs = {}
            for position, variant in enumerate(order, start=1):
                source = f"block {block} {variant}"
                command = [str(binaries[variant]), mode, str(raw_offset)]
                result = subprocess.run(command, capture_output=True, text=True)
                if result.stderr:
                    (output_dir / f"block-{block}-{variant}.stderr").write_text(result.stderr)
                if result.returncode:
                    (output_dir / f"block-{block}-{variant}.stdout").write_text(result.stdout)
                    raise RuntimeError(f"{source}: process exited with status {result.returncode}")
                fields, rows, timings = read_timings(result.stdout, source)
                keys = timings.keys()
                if writer is None:
                    expected_fields, expected_keys = fields, keys
                    writer = csv.DictWriter(samples, (*SAMPLE_FIELDS, *fields))
                    writer.writeheader()
                if fields != expected_fields or keys != expected_keys:
                    raise ValueError(
                        f"{source}: CSV schema or timing set differs. "
                        f"Missing: {sorted(expected_keys - keys)}. "
                        f"Extra: {sorted(keys - expected_keys)}."
                    )
                metadata = {
                    "block": block,
                    "position": position,
                    "raw_order_offset": raw_offset,
                    "variant": variant,
                }
                writer.writerows({**metadata, **row} for row in rows)
                samples.flush()
                runs[variant] = timings
            blocks.append(runs)
    return blocks


def paired_ratios(blocks, output_dir):
    ratios = {}
    with (output_dir / "pairs.csv").open("w", newline="") as pairs:
        writer = csv.writer(pairs)
        writer.writerow(PAIR_FIELDS)
        for block, runs in enumerate(blocks, start=1):
            baseline = runs["baseline"]
            for variant in VARIANTS[1:]:
                for (label, size, width), candidate in sorted(runs[variant].items()):
                    reference = baseline[label, size, width]
                    key = ("build_vs_baseline", variant, label, size, width)
                    ratio = candidate / reference
                    writer.writerow((*key[:2], block, *key[2:], reference, candidate, ratio))
                    ratios.setdefault(key, []).append(ratio)
            scalar_key = ("raw", RAW_COMPARISON_SIZE, 1)
            if scalar_key in baseline:
                scalar = baseline[scalar_key]
                for width in (2, 4, 8):
                    candidate = baseline["raw", RAW_COMPARISON_SIZE, width]
                    key = ("raw_vs_scalar", "baseline", "raw", RAW_COMPARISON_SIZE, width)
                    ratio = candidate / scalar
                    writer.writerow((*key[:2], block, *key[2:], scalar, candidate, ratio))
                    ratios.setdefault(key, []).append(ratio)
    return ratios


def summarize(ratios):
    lines = [
        "Ratios are candidate time / reference time. Values below 1 are faster.",
        "Faster/slower/tied counts are based on each matched block.",
        "",
        "comparison         variant  label      size width   median faster slower tied   max",
    ]
    for (comparison, variant, label, size, width), values in sorted(ratios.items()):
        faster = sum(value < 1 for value in values)
        slower = sum(value > 1 for value in values)
        tied = len(values) - faster - slower
        lines.append(
            f"{comparison:18} {variant:8} {label:6} {size:8} {width:5} "
            f"{median(values):8.4f} {faster:6} {slower:6} {tied:4} {max(values):7.4f}"
        )
    lines.append("")
    for variant in VARIANTS[1:]:
        for label in sorted({key[2] for key in ratios if key[:2] == ("build_vs_baseline", variant)}):
            groups = [
                (key, values)
                for key, values in ratios.items()
                if key[:3] == ("build_vs_baseline", variant, label)
            ]
            median_key, median_values = max(groups, key=lambda item: median(item[1]))
            max_key, max_values = max(groups, key=lambda item: max(item[1]))
            block = max_values.index(max(max_values)) + 1
            lines.append(
                f"{variant} {label} vs baseline: highest median {median(median_values):.4f} "
                f"(n={median_key[3]}, width={median_key[4]}), "
                f"highest paired ratio {max(max_values):.4f} "
                f"(n={max_key[3]}, width={max_key[4]}, block={block})"
            )
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for variant in VARIANTS:
        parser.add_argument(variant, type=Path, help=f"prebuilt {variant} executable")
    parser.add_argument("--output-dir", required=True, type=Path, help="new output directory")
    parser.add_argument("--mode", choices=("all", "raw", "public", "smoke"), default="all")
    args = parser.parse_args()
    binaries = {variant: getattr(args, variant).resolve() for variant in VARIANTS}
    try:
        for variant, binary in binaries.items():
            if not binary.is_file():
                raise ValueError(f"{variant}: no executable at {binary}")
        args.output_dir.mkdir(parents=True)
        blocks = run_blocks(binaries, args.mode, args.output_dir)
        summary = summarize(paired_ratios(blocks, args.output_dir))
        (args.output_dir / "summary.txt").write_text(summary)
        print(summary, end="")
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
