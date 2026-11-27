# Float64 double SIMD experiments

Four-wide SIMD is the selected Float64 vector implementation of `+:`
(double), based on the Apple M4 trials recorded here.
The primary comparison timed the complete `Expr["+:"].map(data)` call,
including input copying, output allocation and destruction. Width four won
eight of eight paired blocks at 100,000 elements. Its median paired speedup
was 1.63×. Small vectors showed no consistent advantage.

The [square SIMD trial](square/README.md) records the separate decision for Float64 square on Apple Silicon and Linux x86-64.

## Ten comparisons

Speedup is baseline time divided by candidate time **within each block**,
then the median across eight blocks. A win means a lower time in that block.
The preallocated raw loops isolate arithmetic and memory access. Public rows
include input copying, output allocation, and destruction.

| # | Question | Median speedup | Wins |
| ---: | --- | --- | --- |
| 1 | Raw width 2 vs scalar, 100,000 elements | 1.89× | 8/8 |
| 2 | Raw width 4 vs scalar, 100,000 elements | 2.18× | 8/8 |
| 3 | Raw width 8 vs scalar, 100,000 elements | 2.28× | 8/8 |
| 4 | Public width 4, lengths 1, 3, 4 and 16 | 1.03×, 1.04×, 0.98×, 1.00× | 5, 5, 3, 4 of 8 |
| 5 | Public width 4 with 1, 2 and 3 trailing cells (lengths 5–7) | 1.06×, 1.04×, 1.00× | 6, 5, 4 of 8 |
| 6 | Public width 4, 1,024 elements | 1.53× | 8/8 |
| 7 | Public width 4, 100,000 elements | 1.63× | 8/8 |
| 8 | Public width 4, 100,003 elements | 1.48× | 8/8 |
| 9 | Public width 4, 1,048,576 elements | 1.32× | 7/8 |
| 10 | Public widths 2 and 8 vs width 4 at 100,000 elements | 0.90×, 0.96× | 1/8, 3/8 |

The rule fixed before measurement required a median speedup of at least
1.10× at 100,000 elements and wins in at least seven blocks. Any tested size
with a median slowdown of at least 1.10× and losses in seven or more blocks
would disqualify that width. Width four was the proposed implementation. A
different qualifying width could displace it by meeting the same speedup and
win criteria head-to-head. Width two won six primary blocks. Width eight
qualified against baseline but did not displace width four.

## Measurement and reproduction

Apple M4, macOS 27.2 arm64, Mojo 1.1.0 (8189361e), `--fp-mode contract=off`,
2026-11-20 08:24 UTC. One-minute load averages were 19.39 at the start and
17.16 at the end. The four binaries used identical harness code. The baseline
was `1e042d2`. The others used the production loop in `e0ed509`, varying
only its compile-time lane count.

Eight blocks ran serially. Each binary occupied each position twice.
Raw kernel order rotated. Each batch warmed the path before timing repeated
calls on the same data. The program checked output bits against scalar
addition across lengths 0–56, including signed zero, subnormals, overflow,
infinities and NaN payloads. The public regression also checks independence
of input and result. The captured timings describe this loaded M4 on warmed
inputs. Fresh allocations and CPU scheduling add variability, especially for
short calls. Other CPUs and other verbs need their own measurements.

From the project root with Pixi installed, choose a fresh output directory:

```sh
mkdir -p build/perf
sh tests/perf/simd/reproduce.sh build/perf/simd-rerun
```

[Recorded measurements](measurements.csv) contain per-call nanoseconds for
each block and length. The raw columns come from the baseline binary, where
all four raw loops were timed in the same process. The reproduction command
also emits all individual samples, candidate/reference time ratios and a
summary. In that diagnostic summary a ratio below one is faster.

A second execution of the reproduction command rebuilt all four binaries.
Width four again cleared the selection rule, with a 1.19× median paired
speedup and seven wins at 100,000 elements. Widths two and eight each won
six blocks and neither cleared the consistency threshold. The smaller gain
on repetition limits the precision of any single speedup figure.
[Replication measurements](replication.csv).
