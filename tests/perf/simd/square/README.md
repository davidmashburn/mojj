# Float64 square SIMD trial

The experiment times two public `Expr` calls, square via `Expr["*:"].map(data)`
and RMS via `Expr["sqrt of mean of square"].reduce(data)`. RMS includes the
same square pass followed by the strict sum and scalar operations. Both
workloads include input copying, allocation and destruction.

## Results

The selection rule did not justify replacing the scalar square path. All three widths qualified in the first Apple
M4 run. Width four remained the preferred candidate because neither
alternative displaced it head-to-head. No width reproduced seven wins on
that host. Width four also recorded a 1.34× median slowdown for
seven-element RMS and a 1.25× slowdown for 100,000-element RMS, with seven
losses in each comparison. The host was substantially more loaded during
the repeat, which limits what those slowdowns establish.

On hosted Linux x86-64, width four won all eight blocks for 100,000-element
square map with a 1.093× median speedup, below the 1.10× threshold. At
1,024 elements it was 1.79× faster for square map and 1.23× faster for RMS,
with eight wins each. The Linux result shows gains in that run at those sizes, but falls short
of the primary selection rule at 100,000 elements.

| Workload at 100,000 elements | Width | M4 first run | M4 repeat | Linux x86-64 |
| --- | ---: | ---: | ---: | ---: |
| Square map | 2 | 1.240×, 7/8 | 1.571×, 6/8 | 1.093×, 7/8 |
| Square map | 4 | 1.411×, 7/8 | 1.226×, 5/8 | 1.093×, 8/8 |
| Square map | 8 | 1.431×, 7/8 | 1.150×, 4/8 | 1.092×, 6/8 |
| RMS | 2 | 1.228×, 8/8 | 0.976×, 3/8 | 1.050×, 7/8 |
| RMS | 4 | 1.187×, 6/8 | 0.805×, 1/8 | 1.051×, 8/8 |
| RMS | 8 | 1.159×, 6/8 | 0.856×, 3/8 | 1.048×, 7/8 |

The Apple M4 runs used macOS 27.2 arm64. All runs used Mojo 1.1.0
(8189361e) with `--fp-mode contract=off`. The first M4 run started on 2026-11-20 at
18:33:36 UTC and ended at 18:34:17 UTC. The one-minute load average went from
14.48 to 12.88. The independently rebuilt repeat ran from 18:36:24 to
18:37:52 UTC, with load rising from 100.88 to 224.37.
[First run samples](measurements.csv) and [repeat samples](replication.csv).

The Linux x86-64 run used an Intel Xeon 6975P-C KVM guest with four vCPUs.
Its build and measurement workflow passed, and the timing step ran from
18:37:48 to 18:38:04 UTC on 2026-11-20.
[Hosted workflow](https://github.com/davidmashburn/mojj/actions/runs/44794466778)
and [Linux samples](linux-x86_64.csv).

The sample files give per-call nanoseconds for each workload, length, build
and block. Each table entry reports the median of the eight per-block
baseline-to-candidate time ratios and the number of faster candidate blocks.

## Selection rule

The primary comparison is square map at 100,000 elements. A candidate
qualifies if it wins at least seven of eight matched blocks with a median
paired speedup of at least 1.10×. A median slowdown of at least 1.10× with
seven or more losses at any tested size or workload disqualifies it. Width
four is the default candidate because double uses it. Another qualifying
width can displace it by meeting the same primary speedup and win criteria
head-to-head. An independent rebuild and timing repeat checks that the
selected result reproduces.

## Reproduction

From the project root, build into a fresh directory and use the existing SIMD
runner in public mode.

```sh
mkdir -p build/perf
out=build/perf/square-rerun
sh tests/perf/simd/square/build.sh "$out"
python3 tests/perf/simd/run.py "$out/baseline/trials" "$out/width2/trials" \
    "$out/width4/trials" "$out/width8/trials" --mode public --output-dir "$out/results"
```

The build script archives one source revision for all four builds. In the
temporary candidate copies it substitutes the existing double SIMD loop for
the square Float64 vector loop, with multiplication and the selected lane
width. The baseline is the scalar pointer loop in the same revision. The
runner balances build order across eight serial blocks. The two workloads
alternate order across blocks. Each timed batch warms the public path on
the same input.

Every binary checks square output and unchanged input bits at lengths 0–32,
rotating signed zero, infinities, NaN payloads, underflow, overflow and
ordinary finite values through SIMD lanes and tails. It also checks result
independence, atom and vector rank, empty dtype, matrix shape, Boolean
promotion, checked integer square above 2⁵³, overflow, Boolean NAND and
expression descriptions. RMS is checked bit-for-bit against a scalar square
and right-fold oracle, including empty input and a rounding-order fixture.

The runner keeps all timings and block-level ratios. Its ratios are
candidate time divided by baseline time, while reported speedups use the
inverse convention.

Disassembling `Squared.monad` in the first pair of timed binaries with
`otool -tv` showed scalar `fmul` in the baseline and two `fmul.2d`
instructions per four-element loop iteration in the width-four build.
The candidate also emitted scalar `fmul` for the tail.
